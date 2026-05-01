import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/credential_storage_service.dart';
import '../services/http_proxy_service.dart';
import '../services/network_scanner_service.dart';
import '../services/smb_service.dart';

/// Application state using ChangeNotifier for provider-based state management.
class AppState extends ChangeNotifier {
  final NetworkScannerService _scannerService = NetworkScannerService();
  final SmbService _smbService = SmbService();
  final HttpProxyService _proxyService = HttpProxyService();
  final CredentialStorageService _credentialStorage =
      CredentialStorageService();

  // ─── SCANNER STATE ──────────────────────────────────────
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  final List<DiscoveredHost> _discoveredHosts = [];
  List<DiscoveredHost> get discoveredHosts =>
      List.unmodifiable(_discoveredHosts);

  ScanProgress? _scanProgress;
  ScanProgress? get scanProgress => _scanProgress;

  String? _localIp;
  String? get localIp => _localIp;

  String? _scanError;
  String? get scanError => _scanError;

  StreamSubscription? _scanSubscription;

  // ─── CONNECTION STATE ────────────────────────────────────
  DiscoveredHost? _selectedHost;
  DiscoveredHost? get selectedHost => _selectedHost;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _connectionError;
  String? get connectionError => _connectionError;

  List<String> _shares = [];
  List<String> get shares => List.unmodifiable(_shares);

  SmbCredentials? _currentCredentials;
  SmbCredentials? get currentCredentials => _currentCredentials;

  // ─── BROWSER STATE ──────────────────────────────────────
  String? _currentShare;
  String? get currentShare => _currentShare;

  String _currentPath = '/';
  String get currentPath => _currentPath;

  final List<String> _pathHistory = [];
  List<String> get pathHistory => List.unmodifiable(_pathHistory);

  List<SmbFileInfo> _files = [];
  List<SmbFileInfo> get files => List.unmodifiable(_files);

  bool _isLoadingFiles = false;
  bool get isLoadingFiles => _isLoadingFiles;

  String? _browseError;
  String? get browseError => _browseError;

  // ─── VIDEO STATE ─────────────────────────────────────────
  String? _currentVideoUrl;
  String? get currentVideoUrl => _currentVideoUrl;

  String? _currentVideoName;
  String? get currentVideoName => _currentVideoName;

  // ─── SERVICES ACCESS ─────────────────────────────────────
  SmbService get smbService => _smbService;
  HttpProxyService get proxyService => _proxyService;
  CredentialStorageService get credentialStorage => _credentialStorage;

  // ─── SCANNER METHODS ─────────────────────────────────────

  /// Start scanning the local network.
  Future<void> startScan() async {
    if (_isScanning) return;

    _isScanning = true;
    _scanError = null;
    _discoveredHosts.clear();
    _scanProgress = null;
    notifyListeners();

    try {
      _localIp = await _scannerService.getLocalIp();
      if (_localIp == null) {
        _scanError = 'COULD NOT DETERMINE LOCAL IP.\nAre you connected to WiFi?';
        _isScanning = false;
        notifyListeners();
        return;
      }

      final subnet = _scannerService.getSubnet(_localIp!);
      final stream = _scannerService.scanSubnet(subnet: subnet);

      _scanSubscription = stream.listen(
        (event) {
          if (event is ScanProgress) {
            _scanProgress = event;
            notifyListeners();
          } else if (event is DiscoveredHost) {
            _discoveredHosts.add(event);
            notifyListeners();
          }
        },
        onDone: () {
          _isScanning = false;
          notifyListeners();
        },
        onError: (e) {
          _scanError = 'SCAN ERROR: $e';
          _isScanning = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _scanError = 'FAILED TO START SCAN: $e';
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Stop the current scan.
  void stopScan() {
    _scanSubscription?.cancel();
    _isScanning = false;
    notifyListeners();
  }

  // ─── CONNECTION METHODS ──────────────────────────────────

  /// Select a host to connect to.
  void selectHost(DiscoveredHost host) {
    _selectedHost = host;
    _connectionError = null;
    notifyListeners();
  }

  /// Check if saved credentials exist for a host.
  Future<SmbCredentials?> getSavedCredentials(String host) async {
    return await _credentialStorage.getCredentials(host);
  }

  /// Connect to the selected host with credentials.
  Future<bool> connectToHost(SmbCredentials credentials) async {
    if (_selectedHost == null) return false;

    _isConnecting = true;
    _connectionError = null;
    _shares = [];
    notifyListeners();

    try {
      await _smbService.connect(
        host: _selectedHost!.ip,
        credentials: credentials,
      );

      _currentCredentials = credentials;
      _isConnected = true;

      // Save credentials
      await _credentialStorage.saveCredentials(
          _selectedHost!.ip, credentials);

      // List shares
      _shares = await _smbService.listShares();

      _isConnecting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _connectionError = 'CONNECTION FAILED: $e';
      _isConnecting = false;
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  /// Disconnect from the current host.
  Future<void> disconnectFromHost() async {
    await _smbService.disconnect();
    await _proxyService.stopProxy();
    _isConnected = false;
    _shares = [];
    _files = [];
    _currentShare = null;
    _currentPath = '/';
    _pathHistory.clear();
    _currentVideoUrl = null;
    _currentVideoName = null;
    notifyListeners();
  }

  // ─── BROWSER METHODS ─────────────────────────────────────

  /// Navigate into a share.
  Future<void> openShare(String shareName) async {
    _currentShare = shareName;
    _currentPath = '/';
    _pathHistory.clear();
    await _loadFiles();
  }

  /// Navigate into a subdirectory.
  Future<void> openDirectory(String dirPath) async {
    _pathHistory.add(_currentPath);
    _currentPath = dirPath;
    await _loadFiles();
  }

  /// Navigate back up.
  Future<bool> navigateBack() async {
    if (_pathHistory.isEmpty) {
      if (_currentShare != null) {
        _currentShare = null;
        _currentPath = '/';
        _files = [];
        notifyListeners();
        return true;
      }
      return false;
    }

    _currentPath = _pathHistory.removeLast();
    await _loadFiles();
    return true;
  }

  /// Load files at the current path.
  Future<void> _loadFiles() async {
    if (_currentShare == null) return;

    _isLoadingFiles = true;
    _browseError = null;
    notifyListeners();

    try {
      _files = await _smbService.listFiles(_currentShare!, _currentPath);
      _isLoadingFiles = false;
      notifyListeners();
    } catch (e) {
      _browseError = 'FAILED TO LIST FILES: $e';
      _isLoadingFiles = false;
      notifyListeners();
    }
  }

  // ─── VIDEO METHODS ──────────────────────────────────────

  /// Prepare a video file for playback by starting the HTTP proxy.
  Future<String?> prepareVideo(SmbFileInfo file) async {
    try {
      _currentVideoName = file.name;

      final url = await _proxyService.startProxy(
        smbService: _smbService,
        filePath: file.path,
      );

      _currentVideoUrl = url;
      notifyListeners();
      return url;
    } catch (e) {
      _currentVideoUrl = null;
      notifyListeners();
      return null;
    }
  }

  /// Stop video playback proxy.
  Future<void> stopVideo() async {
    await _proxyService.stopProxy();
    _currentVideoUrl = null;
    _currentVideoName = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _smbService.disconnect();
    _proxyService.stopProxy();
    super.dispose();
  }
}
