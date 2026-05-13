import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'smb_service.dart';
import 'video_chunk_cache.dart';

/// A local HTTP proxy server that streams SMB files to media_kit.
///
/// All reads go through [VideoChunkCache] which:
///  - Caches 2 MB chunks to disk (seeking to cached positions is instant).
///  - Prefetches upcoming chunks in the background (YouTube-style buffer).
///  - Fetches multiple chunks in parallel (4 concurrent SMB workers).
///  - Pre-warms the first + last chunks on startup for fast MP4 init.
class HttpProxyService {
  HttpServer? _server;
  VideoChunkCache? _cache;
  int? _fileSize;
  String? _filePath;

  int? get port => _server?.port;
  bool get isRunning => _server != null;

  /// Expose the file path for auto-fix reconnection.
  String? get filePath => _filePath;

  /// Expose cache for progress/diagnostics if needed.
  VideoChunkCache? get cache => _cache;

  /// How many bytes to serve per response write.
  /// 512 KB keeps memory low while minimising per-write overhead.
  static const int _responseChunkSize = 512 * 1024;

  /// Start the proxy, initialise the chunk cache, and begin pre-warming.
  Future<String> startProxy({
    required SmbService smbService,
    required String filePath,
  }) async {
    await stopProxy();

    _fileSize = await smbService.getFileSize(filePath);
    _filePath = filePath;

    _cache = VideoChunkCache(
      smbService: smbService,
      filePath: filePath,
      fileSize: _fileSize!,
    );
    await _cache!.initialize();

    // Fire pre-warm in the background — fetches first + last chunks
    // in parallel so media_kit can start playing almost immediately.
    unawaited(_cache!.preWarm());

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handleRequest);

    return 'http://127.0.0.1:${_server!.port}/video';
  }

  /// Handle incoming HTTP requests from media_kit.
  Future<void> _handleRequest(HttpRequest request) async {
    final cache = _cache;
    final fileSize = _fileSize ?? 0;

    if (cache == null || fileSize == 0) {
      request.response.statusCode = 500;
      request.response.write('No file configured');
      await request.response.close();
      return;
    }

    try {
      // ── Parse Range header ──────────────────────────────
      final rangeHeader = request.headers.value('range');
      int start = 0;
      int end = fileSize - 1;
      bool isPartial = false;

      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        isPartial = true;
        final parts = rangeHeader.substring(6).split('-');
        if (parts[0].isNotEmpty) start = int.parse(parts[0]);
        if (parts.length > 1 && parts[1].isNotEmpty) {
          end = int.parse(parts[1]);
        }
        start = start.clamp(0, fileSize - 1);
        end = end.clamp(start, fileSize - 1);
      }

      final contentLength = end - start + 1;

      // ── Response headers ────────────────────────────────
      final fileName = request.uri.pathSegments.lastOrNull ?? 'video';
      request.response.statusCode = isPartial ? 206 : 200;
      request.response.headers.set('Content-Type', _getContentType(fileName));
      request.response.headers.set('Content-Length', contentLength);
      request.response.headers.set('Accept-Ranges', 'bytes');
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers.set('Connection', 'keep-alive');
      if (isPartial) {
        request.response.headers
            .set('Content-Range', 'bytes $start-$end/$fileSize');
      }

      // ── Stream from cache in manageable pieces ──────────
      int pos = start;
      while (pos <= end) {
        final readEnd = min(pos + _responseChunkSize - 1, end);
        final data = await cache.readRange(pos, readEnd);
        request.response.add(data);
        pos = readEnd + 1;
      }

      await request.response.close();
    } catch (e) {
      try {
        request.response.statusCode = 500;
        request.response.write('Error: $e');
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Get content type based on file extension.
  String _getContentType(String fileName) {
    final ext = fileName.toLowerCase();
    if (ext.endsWith('.mp4')) return 'video/mp4';
    if (ext.endsWith('.mkv')) return 'video/x-matroska';
    if (ext.endsWith('.avi')) return 'video/x-msvideo';
    if (ext.endsWith('.mov')) return 'video/quicktime';
    if (ext.endsWith('.wmv')) return 'video/x-ms-wmv';
    if (ext.endsWith('.flv')) return 'video/x-flv';
    if (ext.endsWith('.webm')) return 'video/webm';
    if (ext.endsWith('.m4v')) return 'video/x-m4v';
    if (ext.endsWith('.ts')) return 'video/mp2t';
    if (ext.endsWith('.3gp')) return 'video/3gpp';
    return 'application/octet-stream';
  }

  /// Stop the proxy server and dispose the cache.
  Future<void> stopProxy() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    if (_cache != null) {
      await _cache!.dispose();
      _cache = null;
    }
    _fileSize = null;
    _filePath = null;
  }
}
