import 'dart:async';
import 'dart:io';

import 'smb_service.dart';

/// A local HTTP proxy server that streams SMB files to media_kit.
///
/// Uses smb_connect's RandomAccessFile for instant seeking — no more
/// reading-and-discarding gigabytes of data to reach a byte offset.
/// Each request opens its own RandomAccessFile handle so concurrent
/// requests from the player (probing + streaming) don't stomp on each other.
class HttpProxyService {
  HttpServer? _server;
  SmbService? _smbService;
  String? _currentFilePath;
  int? _currentFileSize;

  int? get port => _server?.port;
  bool get isRunning => _server != null;

  /// How many bytes to read per chunk when piping to the response.
  /// 256 KB strikes a good balance between throughput and memory.
  static const int _chunkSize = 256 * 1024;

  /// Start the local HTTP proxy server.
  Future<String> startProxy({
    required SmbService smbService,
    required String filePath,
  }) async {
    await stopProxy();

    _smbService = smbService;
    _currentFilePath = filePath;

    // Pre-fetch file size once (used for every request's Content-Length).
    _currentFileSize = await smbService.getFileSize(filePath);

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handleRequest);

    return 'http://127.0.0.1:${_server!.port}/video';
  }

  /// Handle incoming HTTP requests from media_kit.
  Future<void> _handleRequest(HttpRequest request) async {
    if (_smbService == null || _currentFilePath == null) {
      request.response.statusCode = 500;
      request.response.write('No file configured');
      await request.response.close();
      return;
    }

    try {
      final fileSize = _currentFileSize ?? 0;
      if (fileSize == 0) {
        request.response.statusCode = 404;
        request.response.write('File is empty or not found');
        await request.response.close();
        return;
      }

      final fileName = _currentFilePath!.split('/').last;
      final contentType = _getContentType(fileName);

      // Parse the Range header, if present.
      final rangeHeader = request.headers.value('range');
      int start = 0;
      int end = fileSize - 1;
      bool isPartial = false;

      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        isPartial = true;
        final rangeStr = rangeHeader.substring(6);
        final parts = rangeStr.split('-');

        if (parts[0].isNotEmpty) {
          start = int.parse(parts[0]);
        }
        if (parts.length > 1 && parts[1].isNotEmpty) {
          end = int.parse(parts[1]);
        }

        // Clamp to valid range
        if (start >= fileSize) start = fileSize - 1;
        if (end >= fileSize) end = fileSize - 1;
        if (start > end) start = end;
      }

      final contentLength = end - start + 1;

      // Write response headers
      if (isPartial) {
        request.response.statusCode = 206;
        request.response.headers
            .set('Content-Range', 'bytes $start-$end/$fileSize');
      } else {
        request.response.statusCode = 200;
      }

      request.response.headers.set('Content-Type', contentType);
      request.response.headers.set('Content-Length', contentLength);
      request.response.headers.set('Accept-Ranges', 'bytes');
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers.set(
          'Connection', 'keep-alive');

      // Open a dedicated RandomAccessFile handle for this request.
      // This gives us O(1) seek — the SMB server jumps directly to
      // the requested offset instead of reading from byte 0.
      final raf = await _smbService!.openRandomAccess(_currentFilePath!);

      try {
        // Seek to the requested start position (instant at the protocol level).
        await raf.setPosition(start);

        // Stream data in chunks until we've served `contentLength` bytes.
        int remaining = contentLength;

        while (remaining > 0) {
          final toRead = remaining < _chunkSize ? remaining : _chunkSize;
          final bytes = await raf.read(toRead);

          if (bytes.lengthInBytes == 0) break; // EOF

          request.response.add(bytes);
          remaining -= bytes.lengthInBytes;
        }
      } finally {
        await raf.close();
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

  /// Stop the proxy server.
  Future<void> stopProxy() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _currentFilePath = null;
    _currentFileSize = null;
  }
}
