/// Video file extensions supported by media_kit
const Set<String> videoExtensions = {
  '.mp4',
  '.mkv',
  '.avi',
  '.mov',
  '.wmv',
  '.flv',
  '.webm',
  '.m4v',
  '.ts',
  '.m2ts',
  '.3gp',
  '.3g2',
  '.ogv',
  '.vob',
  '.divx',
  '.asf',
  '.rm',
  '.rmvb',
  '.mpg',
  '.mpeg',
  '.mpe',
};

/// A host discovered during network scanning.
class DiscoveredHost {
  final String ip;
  final List<int> openPorts;
  final String? hostname;
  final DateTime discoveredAt;

  DiscoveredHost({
    required this.ip,
    required this.openPorts,
    this.hostname,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  bool get hasSmbPort => openPorts.contains(445) || openPorts.contains(139);

  String get portsSummary => openPorts.map((p) => ':$p').join(', ');

  @override
  String toString() => 'DiscoveredHost($ip, ports=$portsSummary)';
}

/// Credentials for SMB authentication.
class SmbCredentials {
  final String username;
  final String password;
  final String domain;

  const SmbCredentials({
    required this.username,
    required this.password,
    this.domain = '',
  });

  bool get isGuest => username.isEmpty || username.toLowerCase() == 'guest';

  Map<String, String> toJson() => {
        'username': username,
        'password': password,
        'domain': domain,
      };

  factory SmbCredentials.fromJson(Map<String, dynamic> json) =>
      SmbCredentials(
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        domain: json['domain'] as String? ?? '',
      );

  factory SmbCredentials.guest() =>
      const SmbCredentials(username: 'guest', password: '');
}

/// Information about a file or folder on an SMB share.
class SmbFileInfo {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;

  const SmbFileInfo({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
  });

  bool get isVideo {
    if (isDirectory) return false;
    final lower = name.toLowerCase();
    return videoExtensions.any((ext) => lower.endsWith(ext));
  }

  String get extension {
    final idx = name.lastIndexOf('.');
    if (idx == -1) return '';
    return name.substring(idx).toLowerCase();
  }

  String get formattedSize {
    if (isDirectory) return '--';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  String toString() =>
      'SmbFileInfo($name, dir=$isDirectory, size=$formattedSize)';
}

/// Scan progress tracking.
class ScanProgress {
  final int scanned;
  final int total;
  final String? currentIp;

  const ScanProgress({
    required this.scanned,
    required this.total,
    this.currentIp,
  });

  double get percentage => total > 0 ? scanned / total : 0;

  @override
  String toString() => '$scanned/$total';
}
