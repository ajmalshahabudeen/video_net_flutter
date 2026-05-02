import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const String githubApiUrl = 'https://api.github.com/repos/ajmalshahabudeen/video_net_flutter/releases/latest';

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final dio = Dio();
      final response = await dio.get(githubApiUrl);
      if (response.statusCode == 200) {
        final data = response.data;
        String latestTag = data['tag_name'];
        if (latestTag.startsWith('v')) {
          latestTag = latestTag.substring(1);
        }

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (_isNewerVersion(latestTag, currentVersion)) {
          // Find the APK asset
          List assets = data['assets'];
          String? downloadUrl;
          for (var asset in assets) {
            if (asset['name'].toString().endsWith('.apk')) {
              downloadUrl = asset['browser_download_url'];
              break;
            }
          }

          if (downloadUrl != null) {
            if (context.mounted) {
              _showUpdateDialog(context, latestTag, downloadUrl);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  static bool _isNewerVersion(String latest, String current) {
    List<int> latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      int l = i < latestParts.length ? latestParts[i] : 0;
      int c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, String version, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _UpdateDialog(version: version, downloadUrl: downloadUrl);
      },
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final String version;
  final String downloadUrl;

  const _UpdateDialog({required this.version, required this.downloadUrl});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;

  Future<void> _downloadAndInstall() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/update_${widget.version}.apk';
      
      final dio = Dio();
      await dio.download(
        widget.downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
            });
          }
        },
      );

      // Install APK
      await OpenFilex.open(savePath);
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download update: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: Colors.black, width: 4),
      ),
      title: const Text(
        'Update Available',
        style: TextStyle(fontFamily: 'Space Mono', fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Version ${widget.version} is available. Would you like to install it?',
            style: const TextStyle(fontFamily: 'Space Mono'),
          ),
          if (_isDownloading) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey[300],
              color: Colors.black,
              minHeight: 10,
            ),
            const SizedBox(height: 10),
            Text(
              '${(_progress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontFamily: 'Space Mono', fontWeight: FontWeight.bold),
            ),
          ]
        ],
      ),
      actions: [
        if (!_isDownloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later', style: TextStyle(color: Colors.black, fontFamily: 'Space Mono', fontWeight: FontWeight.bold)),
          ),
        if (!_isDownloading)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: _downloadAndInstall,
            child: const Text('Update Now', style: TextStyle(fontFamily: 'Space Mono', fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}
