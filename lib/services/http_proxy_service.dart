import 'dart:async';
import 'dart:io';

import 'smb_service.dart';

/// A local HTTP proxy server that streams SMB files to media_kit.
/// Supports Range requests for seeking in large video files (including 4K).
class HttpProxyService {
  HttpServer? _server;
  SmbService? _smbService;
  String? _currentFilePath;
  int? _currentFileSize;

  int? get port => _server?.port;
  bool get isRunning => _server != null;

  /// Start the local HTTP proxy server.
  Future<String> startProxy({
    required SmbService smbService,
    required String filePath,
  }) async {
    await stopProxy();

    _smbService = smbService;
    _currentFilePath = filePath;

    // Get file size for Range support
    _currentFileSize = await smbService.getFileSize(filePath);

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    _server!.listen(_handleRequest);

    final url = 'http://127.0.0.1:${_server!.port}/video';
    return url;
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
      final fileName = _currentFilePath!.split('/').last;

      // Determine content type based on extension
      final contentType = _getContentType(fileName);

      // Check for Range header (seeking support)
      final rangeHeader = request.headers.value('range');

      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        await _handleRangeRequest(
          request,
          rangeHeader,
          fileSize,
          contentType,
        );
      } else {
        // Full file stream
        request.response.statusCode = 200;
        request.response.headers.set('Content-Type', contentType);
        request.response.headers.set('Content-Length', fileSize);
        request.response.headers.set('Accept-Ranges', 'bytes');
        request.response.headers
            .set('Access-Control-Allow-Origin', '*');

        final stream =
            await _smbService!.openReadStream(_currentFilePath!);
        await request.response.addStream(stream);
        await request.response.close();
      }
    } catch (e) {
      try {
        request.response.statusCode = 500;
        request.response.write('Error: $e');
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Handle HTTP Range requests for seeking.
  Future<void> _handleRangeRequest(
    HttpRequest request,
    String rangeHeader,
    int fileSize,
    String contentType,
  ) async {
    // Parse range: "bytes=START-END" or "bytes=START-"
    final rangeStr = rangeHeader.substring(6); // Remove "bytes="
    final parts = rangeStr.split('-');

    int start = 0;
    int end = fileSize - 1;

    if (parts[0].isNotEmpty) {
      start = int.parse(parts[0]);
    }
    if (parts.length > 1 && parts[1].isNotEmpty) {
      end = int.parse(parts[1]);
    }

    // Clamp values
    if (start >= fileSize) start = fileSize - 1;
    if (end >= fileSize) end = fileSize - 1;

    final contentLength = end - start + 1;

    request.response.statusCode = 206; // Partial Content
    request.response.headers.set('Content-Type', contentType);
    request.response.headers.set('Content-Length', contentLength);
    request.response.headers.set('Accept-Ranges', 'bytes');
    request.response.headers
        .set('Content-Range', 'bytes $start-$end/$fileSize');
    request.response.headers.set('Access-Control-Allow-Origin', '*');

    // Stream from SMB with range
    // Since smb_connect may not support native range requests,
    // we stream and skip/limit bytes
    final stream =
        await _smbService!.openReadStream(_currentFilePath!);

    int bytesSkipped = 0;
    int bytesSent = 0;

    await for (final chunk in stream) {
      if (bytesSent >= contentLength) break;

      int chunkStart = 0;
      int chunkEnd = chunk.length;

      // Skip bytes we don't need
      if (bytesSkipped < start) {
        final remaining = start - bytesSkipped;
        if (remaining >= chunk.length) {
          bytesSkipped += chunk.length;
          continue;
        }
        chunkStart = remaining;
        bytesSkipped = start;
      }

      // Limit to contentLength
      final available = chunkEnd - chunkStart;
      final needed = contentLength - bytesSent;
      final toSend = available < needed ? available : needed;

      request.response
          .add(chunk.sublist(chunkStart, chunkStart + toSend));
      bytesSent += toSend;
    }

    await request.response.close();
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
