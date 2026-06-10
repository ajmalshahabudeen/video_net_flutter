import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:smb_connect/smb_connect.dart';
// ignore: implementation_imports
import 'package:smb_connect/src/connect/smb_random_access_file.dart';
// ignore: implementation_imports
import 'package:smb_connect/src/connect/impl/smb2/smb2_random_access_file_controller.dart';
// ignore: implementation_imports
import 'package:smb_connect/src/connect/impl/smb1/smb1_random_access_file_controller.dart';

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
    final raf = await _connection!.open(file);
    return SafeSmbRandomAccessFile(raf, file.size);
  }

  /// Open a file read stream (for full sequential reads only).
  Future<Stream<List<int>>> openReadStream(String filePath) async {
    if (_connection == null) throw Exception('Not connected');

    final file = await _connection!.file(filePath);
    return await _connection!.openRead(file);
  }
}

/// A wrapper around [SmbRandomAccessFile] to fix infinite loop bugs on EOF.
class SafeSmbRandomAccessFile implements io.RandomAccessFile {
  final io.RandomAccessFile _delegate;
  int _position = 0;
  final int _fileSize;

  SafeSmbRandomAccessFile(this._delegate, this._fileSize);

  @override
  String get path => _delegate.path;

  @override
  Future<void> close() => _delegate.close();

  @override
  void closeSync() => _delegate.closeSync();

  @override
  Future<io.RandomAccessFile> flush() => _delegate.flush();

  @override
  void flushSync() => _delegate.flushSync();

  @override
  Future<int> length() => _delegate.length();

  @override
  int lengthSync() => _delegate.lengthSync();

  @override
  Future<int> position() async => _position;

  @override
  int positionSync() => _position;

  @override
  Future<io.RandomAccessFile> setPosition(int position) async {
    _position = position;
    await _delegate.setPosition(position);
    return this;
  }

  @override
  void setPositionSync(int position) {
    _position = position;
    _delegate.setPositionSync(position);
  }

  @override
  Future<Uint8List> read(int count) async {
    if (_position >= _fileSize) {
      return Uint8List(0);
    }
    final actualCount = (count + _position > _fileSize) ? _fileSize - _position : count;
    if (actualCount <= 0) {
      return Uint8List(0);
    }

    if (_delegate is SmbRandomAccessFile) {
      final controller = _delegate.controller;
      if (controller is Smb2RandomAccessFileController) {
        if (controller.fileId == null) {
          await controller.open();
        }
      } else if (controller is Smb1RandomAccessFileController) {
        if (controller.fid == 0) {
          await controller.open();
        }
      }
      final buffer = Uint8List(actualCount);
      int totalRead = 0;
      while (totalRead < actualCount) {
        final toRead = actualCount - totalRead;
        final tempBuf = Uint8List(toRead);
        final readOffset = _position + totalRead;
        final res = await controller.read(tempBuf, readOffset, toRead);
        if (res <= 0) {
          break;
        }
        buffer.setRange(totalRead, totalRead + res, tempBuf);
        totalRead += res;
      }
      _position += totalRead;
      await _delegate.setPosition(_position); // keep delegate in sync
      return Uint8List.sublistView(buffer, 0, totalRead);
    } else {
      final data = await _delegate.read(actualCount);
      _position += data.length;
      return data;
    }
  }

  @override
  Uint8List readSync(int count) => throw UnimplementedError();

  @override
  Future<int> readByte() async {
    final bytes = await read(1);
    return bytes.isEmpty ? -1 : bytes[0];
  }

  @override
  int readByteSync() => throw UnimplementedError();

  @override
  Future<int> readInto(List<int> buffer, [int start = 0, int? end]) async {
    end ??= buffer.length;
    final bytes = await read(end - start);
    buffer.setRange(start, start + bytes.length, bytes);
    return bytes.length;
  }

  @override
  int readIntoSync(List<int> buffer, [int start = 0, int? end]) => throw UnimplementedError();

  @override
  Future<io.RandomAccessFile> truncate(int length) => _delegate.truncate(length);

  @override
  void truncateSync(int length) => _delegate.truncateSync(length);

  @override
  Future<io.RandomAccessFile> writeByte(int value) => _delegate.writeByte(value);

  @override
  int writeByteSync(int value) => _delegate.writeByteSync(value);

  @override
  Future<io.RandomAccessFile> writeFrom(List<int> buffer, [int start = 0, int? end]) => _delegate.writeFrom(buffer, start, end);

  @override
  void writeFromSync(List<int> buffer, [int start = 0, int? end]) => _delegate.writeFromSync(buffer, start, end);

  @override
  Future<io.RandomAccessFile> writeString(String string, {Encoding encoding = utf8}) => _delegate.writeString(string, encoding: encoding);

  @override
  void writeStringSync(String string, {Encoding encoding = utf8}) => _delegate.writeStringSync(string, encoding: encoding);

  @override
  Future<io.RandomAccessFile> lock([io.FileLock mode = io.FileLock.exclusive, int start = 0, int end = -1]) => _delegate.lock(mode, start, end);

  @override
  void lockSync([io.FileLock mode = io.FileLock.exclusive, int start = 0, int end = -1]) => _delegate.lockSync(mode, start, end);

  @override
  Future<io.RandomAccessFile> unlock([int start = 0, int end = -1]) => _delegate.unlock(start, end);

  @override
  void unlockSync([int start = 0, int end = -1]) => _delegate.unlockSync(start, end);
}
