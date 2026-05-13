import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'smb_service.dart';

/// YouTube-style disk-backed chunk cache with read-ahead prefetching
/// and parallel fetching for fast video playback over SMB.
///
/// How it works:
///  1. The file is divided into 2MB chunks.
///  2. When the player requests a byte range, missing chunks are fetched
///     from SMB and written to the device's temp directory.
///  3. After serving a request, upcoming chunks are prefetched in parallel
///     in the background so data is ready before the player asks for it.
///  4. On startup, the first few chunks AND the last chunk (MP4 moov atom)
///     are fetched in parallel so playback can begin almost instantly.
class VideoChunkCache {
  /// Size of each cached chunk on disk.
  static const int chunkSize = 2 * 1024 * 1024; // 2 MB

  /// How many chunks to prefetch ahead of the current playback position.
  static const int prefetchAhead = 20; // ~40 MB buffer

  /// Maximum parallel SMB reads at any given time.
  static const int maxParallel = 8;

  /// Maximum retries per chunk fetch before giving up.
  static const int maxRetries = 3;

  /// Cache directory prefix for identifying our temp files.
  static const String _cacheDirPrefix = 'vnet_';

  final SmbService smbService;
  final String filePath;
  final int fileSize;

  late final int totalChunks;
  late final Directory _cacheDir;

  /// Chunk indices that are fully written to disk.
  final Set<int> _cached = {};

  /// Chunk indices currently being fetched (prevents duplicate work).
  final Set<int> _fetching = {};

  /// Completers so multiple callers can await the same in-flight fetch.
  final Map<int, Completer<void>> _fetchCompleters = {};

  /// Track chunks that have permanently failed (after retries).
  final Set<int> _failedChunks = {};

  /// Simple async semaphore to cap parallel SMB reads.
  final _Semaphore _sem = _Semaphore(maxParallel);

  bool _disposed = false;

  VideoChunkCache({
    required this.smbService,
    required this.filePath,
    required this.fileSize,
  }) {
    totalChunks = fileSize <= 0 ? 0 : ((fileSize - 1) ~/ chunkSize) + 1;
  }

  // ─── LIFECYCLE ────────────────────────────────────────────

  /// Prepare the cache directory and scan for already-cached chunks.
  Future<void> initialize() async {
    final hash = '${filePath.hashCode.abs()}_$fileSize';
    _cacheDir = Directory('${Directory.systemTemp.path}/$_cacheDirPrefix$hash');
    if (!await _cacheDir.exists()) {
      await _cacheDir.create(recursive: true);
    }

    // Recover chunks from a previous session on the same file.
    await for (final entity in _cacheDir.list()) {
      if (entity is File) {
        final idx = int.tryParse(
            entity.uri.pathSegments.last.replaceAll('.chunk', ''));
        if (idx != null) _cached.add(idx);
      }
    }
  }

  /// Clean up temp files and cancel in-flight work.
  Future<void> dispose() async {
    _disposed = true;
    _fetching.clear();
    for (final c in _fetchCompleters.values) {
      if (!c.isCompleted) c.complete();
    }
    _fetchCompleters.clear();
    _cached.clear();
    _failedChunks.clear();
    try {
      if (await _cacheDir.exists()) {
        await _cacheDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  // ─── STATIC CACHE MANAGEMENT ─────────────────────────────

  /// Clear ALL video chunk caches from the temp directory.
  /// Call this on the home screen to free disk space.
  static Future<int> clearAllCaches() async {
    int bytesCleared = 0;
    final tempDir = Directory.systemTemp;

    try {
      await for (final entity in tempDir.list()) {
        if (entity is Directory &&
            entity.uri.pathSegments
                .any((seg) => seg.startsWith(_cacheDirPrefix))) {
          try {
            // Calculate size before deleting
            await for (final file in entity.list(recursive: true)) {
              if (file is File) {
                bytesCleared += await file.length();
              }
            }
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}

    return bytesCleared;
  }

  /// Get total size of all cached chunks on disk.
  static Future<int> getTotalCacheSize() async {
    int totalSize = 0;
    final tempDir = Directory.systemTemp;

    try {
      await for (final entity in tempDir.list()) {
        if (entity is Directory &&
            entity.uri.pathSegments
                .any((seg) => seg.startsWith(_cacheDirPrefix))) {
          try {
            await for (final file in entity.list(recursive: true)) {
              if (file is File) {
                totalSize += await file.length();
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    return totalSize;
  }

  // ─── PRE-WARM ─────────────────────────────────────────────

  /// Fetch the first N chunks + last chunk in parallel so media_kit
  /// can read both stream data and MP4 metadata without waiting.
  Future<void> preWarm() async {
    if (_disposed || totalChunks == 0) return;

    final targets = <int>[];

    // First 8 chunks (16 MB) — immediate playback data.
    for (int i = 0; i < min(8, totalChunks); i++) {
      if (!_cached.contains(i)) targets.add(i);
    }

    // Last chunk — MP4 moov/mdat atom is often here.
    final last = totalChunks - 1;
    if (last >= 8 && !_cached.contains(last)) targets.add(last);

    // Second-to-last chunk — some MP4s have moov spanning 2 chunks.
    final secondLast = totalChunks - 2;
    if (secondLast >= 8 && !_cached.contains(secondLast)) {
      targets.add(secondLast);
    }

    if (targets.isNotEmpty) {
      await _fetchMany(targets);
    }

    // Continue prefetching from chunk 8 onwards in the background.
    _prefetchFrom(min(8, totalChunks));
  }

  // ─── READ ─────────────────────────────────────────────────

  /// Read bytes [start]..[end] (inclusive) from the cache.
  /// Missing chunks are fetched on demand; upcoming chunks are prefetched.
  Future<Uint8List> readRange(int start, int end) async {
    if (_disposed) throw StateError('Cache disposed');

    final firstChunk = start ~/ chunkSize;
    final lastChunk = end ~/ chunkSize;

    // 1. Fetch any missing chunks that the request spans.
    final missing = <int>[];
    for (int i = firstChunk; i <= lastChunk; i++) {
      if (!_cached.contains(i)) missing.add(i);
    }
    if (missing.isNotEmpty) await _fetchMany(missing);

    // 2. Kick off background prefetch beyond this request.
    _prefetchFrom(lastChunk + 1);

    // 3. Assemble the response from cached chunk files.
    final length = end - start + 1;
    final result = Uint8List(length);
    int written = 0;

    for (int i = firstChunk; i <= lastChunk; i++) {
      final data = await _readFromDisk(i);
      if (data == null) break;

      final chunkOffset = i * chunkSize;
      final readStart = (i == firstChunk) ? start - chunkOffset : 0;
      final readEnd =
          (i == lastChunk) ? end - chunkOffset + 1 : data.length;
      final toWrite = min(readEnd - readStart, length - written);

      result.setRange(
          written, written + toWrite, data, readStart);
      written += toWrite;
    }

    return Uint8List.sublistView(result, 0, written);
  }

  // ─── INTERNALS ────────────────────────────────────────────

  /// Fetch a list of chunk indices in parallel (up to [maxParallel]).
  Future<void> _fetchMany(List<int> indices) async {
    await Future.wait(indices.map(_ensureFetched));
  }

  /// Guarantee that chunk [idx] is on disk. De-duplicates concurrent calls.
  /// Retries up to [maxRetries] times on failure.
  Future<void> _ensureFetched(int idx) async {
    if (_cached.contains(idx) || _disposed) return;

    // Another caller is already fetching this chunk — just wait for it.
    if (_fetching.contains(idx)) {
      await _fetchCompleters[idx]?.future;
      return;
    }

    _fetching.add(idx);
    final completer = Completer<void>();
    _fetchCompleters[idx] = completer;

    try {
      await _sem.acquire(); // wait for a slot
      if (_disposed || _cached.contains(idx)) return;

      // Retry loop
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          await _fetchFromSmb(idx);
          _cached.add(idx);
          _failedChunks.remove(idx);
          break; // success
        } catch (e) {
          if (attempt == maxRetries) {
            _failedChunks.add(idx);
            // Swallow — caller will see the chunk is still missing.
          } else {
            // Brief delay before retry
            await Future.delayed(
                Duration(milliseconds: 200 * attempt));
          }
        }
      }
    } finally {
      _sem.release();
      _fetching.remove(idx);
      if (!completer.isCompleted) completer.complete();
      _fetchCompleters.remove(idx);
    }
  }

  /// Open a dedicated RAF handle, seek to the chunk offset, read, write to disk.
  Future<void> _fetchFromSmb(int idx) async {
    if (_disposed) return;

    final offset = idx * chunkSize;
    final toRead = min(chunkSize, fileSize - offset);
    if (toRead <= 0) return;

    final raf = await smbService.openRandomAccess(filePath);
    try {
      await raf.setPosition(offset);
      final data = await raf.read(toRead);
      final file = File('${_cacheDir.path}/$idx.chunk');
      await file.writeAsBytes(data, flush: true);
    } finally {
      await raf.close();
    }
  }

  /// Read a chunk file from disk.
  Future<Uint8List?> _readFromDisk(int idx) async {
    final file = File('${_cacheDir.path}/$idx.chunk');
    if (await file.exists()) return file.readAsBytes();
    return null;
  }

  /// Fire-and-forget prefetch of [prefetchAhead] chunks starting at [from].
  void _prefetchFrom(int from) {
    if (_disposed) return;
    // Schedule on the microtask queue so it doesn't block the current response.
    Future.microtask(() async {
      for (int i = from;
          i < min(from + prefetchAhead, totalChunks);
          i++) {
        if (_disposed) break;
        if (!_cached.contains(i) &&
            !_fetching.contains(i) &&
            !_failedChunks.contains(i)) {
          unawaited(_ensureFetched(i));
        }
      }
    });
  }

  // ─── CACHE REPAIR ────────────────────────────────────────

  /// Clear this specific cache and reset state for re-fetching.
  /// Useful when playback is stuck due to corrupted or failed chunks.
  Future<void> clearAndReset() async {
    _cached.clear();
    _failedChunks.clear();
    _fetching.clear();
    for (final c in _fetchCompleters.values) {
      if (!c.isCompleted) c.complete();
    }
    _fetchCompleters.clear();

    try {
      if (await _cacheDir.exists()) {
        await _cacheDir.delete(recursive: true);
        await _cacheDir.create(recursive: true);
      }
    } catch (_) {}
  }

  // ─── DIAGNOSTICS ──────────────────────────────────────────

  int get cachedChunkCount => _cached.length;
  int get failedChunkCount => _failedChunks.length;
  double get progress =>
      totalChunks > 0 ? _cached.length / totalChunks : 0.0;
  bool isRangeCached(int start, int end) {
    for (int i = start ~/ chunkSize; i <= end ~/ chunkSize; i++) {
      if (!_cached.contains(i)) return false;
    }
    return true;
  }

  bool get hasFailedChunks => _failedChunks.isNotEmpty;
}

// ─── ASYNC SEMAPHORE ──────────────────────────────────────────

/// A simple async counting semaphore (avoids busy-wait spin-loops).
class _Semaphore {
  int _permits;
  final _waiters = <Completer<void>>[];

  _Semaphore(this._permits);

  Future<void> acquire() async {
    if (_permits > 0) {
      _permits--;
      return;
    }
    final c = Completer<void>();
    _waiters.add(c);
    await c.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    } else {
      _permits++;
    }
  }
}
