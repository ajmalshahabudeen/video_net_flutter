import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:network_info_plus/network_info_plus.dart';

import '../models/models.dart';

/// Service for scanning the local network for hosts with SMB ports open.
class NetworkScannerService {
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Get the device's local WiFi IP.
  Future<String?> getLocalIp() async {
    return await _networkInfo.getWifiIP();
  }

  /// Extract subnet from IP (e.g., "192.168.1" from "192.168.1.105").
  String getSubnet(String ip) {
    return ip.substring(0, ip.lastIndexOf('.'));
  }

  /// Scan the subnet for hosts with SMB ports open.
  /// Returns a stream of discovered hosts and progress updates.
  Stream<dynamic> scanSubnet({
    required String subnet,
    List<int> ports = const [445, 139],
    int startHost = 1,
    int endHost = 254,
    Duration timeout = const Duration(milliseconds: 800),
  }) {
    final controller = StreamController<dynamic>.broadcast();

    _runScanInIsolate(
      subnet: subnet,
      ports: ports,
      startHost: startHost,
      endHost: endHost,
      timeoutMs: timeout.inMilliseconds,
      controller: controller,
    );

    return controller.stream;
  }

  Future<void> _runScanInIsolate({
    required String subnet,
    required List<int> ports,
    required int startHost,
    required int endHost,
    required int timeoutMs,
    required StreamController<dynamic> controller,
  }) async {
    final receivePort = ReceivePort();

    await Isolate.spawn(
      _scanIsolateEntry,
      _ScanParams(
        subnet: subnet,
        ports: ports,
        startHost: startHost,
        endHost: endHost,
        timeoutMs: timeoutMs,
        sendPort: receivePort.sendPort,
      ),
    );

    receivePort.listen((message) {
      if (message is Map<String, dynamic>) {
        final type = message['type'] as String;

        if (type == 'progress') {
          controller.add(ScanProgress(
            scanned: message['scanned'] as int,
            total: message['total'] as int,
            currentIp: message['currentIp'] as String?,
          ));
        } else if (type == 'host') {
          controller.add(DiscoveredHost(
            ip: message['ip'] as String,
            openPorts: List<int>.from(message['openPorts'] as List),
            hostname: message['hostname'] as String?,
          ));
        } else if (type == 'done') {
          controller.close();
          receivePort.close();
        }
      }
    });
  }

  /// Isolate entry point for scanning.
  static Future<void> _scanIsolateEntry(_ScanParams params) async {
    final total = params.endHost - params.startHost + 1;
    int scanned = 0;

    // Process in batches to avoid opening too many sockets
    const batchSize = 20;

    for (int i = params.startHost; i <= params.endHost; i += batchSize) {
      final batchEnd =
          (i + batchSize - 1).clamp(params.startHost, params.endHost);
      final futures = <Future<DiscoveredHost?>>[];

      for (int hostId = i; hostId <= batchEnd; hostId++) {
        final ip = '${params.subnet}.$hostId';
        futures.add(_scanHost(
          ip,
          params.ports,
          Duration(milliseconds: params.timeoutMs),
        ));
      }

      final results = await Future.wait(futures);

      for (final host in results) {
        scanned += 1;
        params.sendPort.send({
          'type': 'progress',
          'scanned': scanned,
          'total': total,
          'currentIp': '${params.subnet}.${i + results.indexOf(host)}',
        });

        if (host != null) {
          params.sendPort.send({
            'type': 'host',
            'ip': host.ip,
            'openPorts': host.openPorts,
            'hostname': host.hostname,
          });
        }
      }
    }

    params.sendPort.send({'type': 'done'});
  }

  /// Check a single host for open SMB ports.
  static Future<DiscoveredHost?> _scanHost(
    String ip,
    List<int> ports,
    Duration timeout,
  ) async {
    final openPorts = <int>[];

    for (final port in ports) {
      try {
        final socket = await Socket.connect(ip, port, timeout: timeout);
        openPorts.add(port);
        socket.destroy();
      } catch (_) {
        // Port is closed or host is unreachable
      }
    }

    if (openPorts.isEmpty) return null;

    // Try to resolve hostname
    String? hostname;
    try {
      final result = await InternetAddress(ip).reverse();
      hostname = result.host;
    } catch (_) {
      // Reverse DNS failed
    }

    return DiscoveredHost(
      ip: ip,
      openPorts: openPorts,
      hostname: hostname,
    );
  }
}

/// Parameters passed to the scan isolate.
class _ScanParams {
  final String subnet;
  final List<int> ports;
  final int startHost;
  final int endHost;
  final int timeoutMs;
  final SendPort sendPort;

  const _ScanParams({
    required this.subnet,
    required this.ports,
    required this.startHost,
    required this.endHost,
    required this.timeoutMs,
    required this.sendPort,
  });
}
