import 'dart:async';
import 'dart:typed_data';

import 'package:smb_connect/smb_connect.dart';

import '../models/models.dart';

/// Service for connecting to SMB shares and browsing files.
class SmbService {
  SmbConnect? _connection;
  String? _currentHost;

  bool get isConnected => _connection != null;
  String? get currentHost => _currentHost;

  /// Connect to an SMB host with credentials.
  Future<void> connect({
    required String host,
    required SmbCredentials credentials,
  }) async {
    await disconnect();

    _connection = await SmbConnect.connectAuth(
      host: host,
      domain: credentials.domain.isEmpty ? '' : credentials.domain,
      username: credentials.username,
      password: credentials.password,
    );
    _currentHost = host;
  }

  /// Disconnect from the current SMB host.
  Future<void> disconnect() async {
    if (_connection != null) {
      try {
        await _connection!.close();
      } catch (_) {}
      _connection = null;
      _currentHost = null;
    }
  }

  /// List available shares on the connected host.
  Future<List<String>> listShares() async {
    if (_connection == null) throw Exception('Not connected');

    final shares = await _connection!.listShares();
    // listShares() returns List<SmbFile>, extract names
    // Filter out administrative shares (ending with $)
    return shares
        .map((smbFile) => smbFile.name)
        .where((name) => !name.endsWith('\$'))
        .toList()
      ..sort();
  }

  /// List files and directories at a given path.
  Future<List<SmbFileInfo>> listFiles(String shareName,
      [String path = '/']) async {
    if (_connection == null) throw Exception('Not connected');

    final smbPath = path.endsWith('/') ? path : '$path/';
    final fullPath = '/$shareName$smbPath';

    final folder = await _connection!.file(fullPath);
    final files = await _connection!.listFiles(folder);

    final result = <SmbFileInfo>[];
    for (final file in files) {
      final name = file.name;
      // Skip . and .. entries
      if (name == '.' || name == '..') continue;

      result.add(SmbFileInfo(
        name: name,
        path: file.path,
        isDirectory: file.isDirectory(),
        size: file.size,
      ));
    }

    // Sort: directories first, then alphabetically
    result.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return result;
  }

  /// Read a file as bytes (for smaller files or chunks).
  Future<Uint8List> readFile(String filePath) async {
    if (_connection == null) throw Exception('Not connected');

    final file = await _connection!.file(filePath);
    final stream = await _connection!.openRead(file);

    final chunks = <List<int>>[];
    await for (final chunk in stream) {
      chunks.add(chunk);
    }

    final totalLength = chunks.fold<int>(0, (sum, c) => sum + c.length);
    final result = Uint8List(totalLength);
    int offset = 0;
    for (final chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    return result;
  }

  /// Open a file read stream (for streaming large video files).
  Future<Stream<List<int>>> openReadStream(String filePath) async {
    if (_connection == null) throw Exception('Not connected');

    final file = await _connection!.file(filePath);
    return await _connection!.openRead(file);
  }

  /// Get file size.
  Future<int> getFileSize(String filePath) async {
    if (_connection == null) throw Exception('Not connected');

    final file = await _connection!.file(filePath);
    return file.size;
  }
}
