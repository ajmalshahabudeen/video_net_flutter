import 'dart:async';
import 'dart:io' as io;

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
      if (name == '.' || name == '..') continue;

      result.add(SmbFileInfo(
        name: name,
        path: file.path,
        isDirectory: file.isDirectory(),
        size: file.size,
      ));
    }

    result.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return result;
  }

  /// Get file size.
  Future<int> getFileSize(String filePath) async {
    if (_connection == null) throw Exception('Not connected');

    final file = await _connection!.file(filePath);
    return file.size;
  }

  /// Open a RandomAccessFile for seeking directly at the SMB protocol level.
  /// This avoids the massive performance penalty of streaming-then-skipping.
  Future<io.RandomAccessFile> openRandomAccess(String filePath) async {
    if (_connection == null) throw Exception('Not connected');

    final file = await _connection!.file(filePath);
    return await _connection!.open(file);
  }

  /// Open a file read stream (for full sequential reads only).
  Future<Stream<List<int>>> openReadStream(String filePath) async {
    if (_connection == null) throw Exception('Not connected');

    final file = await _connection!.file(filePath);
    return await _connection!.openRead(file);
  }
}
