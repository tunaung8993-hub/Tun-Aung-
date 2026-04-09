import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _githubUser = 'tunaung8993-hub';
  static const String _githubRepo = 'Tun-Aung-';

  static const String _apiUrl =
      'https://api.github.com/repos/$_githubUser/$_githubRepo/releases/latest';

  /// Check for update and show dialog if available
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.0.0"

      final response = await http
          .get(Uri.parse(_apiUrl), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final latestTag = (data['tag_name'] as String).replaceAll('v', ''); // e.g. "1.1.0"
      final apkUrl = _getApkDownloadUrl(data);

      if (apkUrl == null) return;

      if (_isNewerVersion(latestTag, currentVersion)) {
        if (context.mounted) {
          _showUpdateDialog(context, latestTag, apkUrl);
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  static String? _getApkDownloadUrl(Map<String, dynamic> release) {
    final assets = release['assets'] as List<dynamic>? ?? [];
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith('.apk')) {
        return asset['browser_download_url'] as String?;
      }
    }
    return null;
  }

  static bool _isNewerVersion(String latest, String current) {
    final l = latest.split('.').map(int.tryParse).toList();
    final c = current.split('.').map(int.tryParse).toList();
    for (int i = 0; i < 3; i++) {
      final lv = (i < l.length ? l[i] : 0) ?? 0;
      final cv = (i < c.length ? c[i] : 0) ?? 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  static void _showUpdateDialog(
      BuildContext context, String version, String apkUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Color(0xFF6C63FF)),
            SizedBox(width: 8),
            Text('Update Available'),
          ],
        ),
        content: Text(
          'Version $version is available.\nUpdate now for new features and improvements.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _downloadAndInstall(context, apkUrl);
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  static void _downloadAndInstall(BuildContext context, String apkUrl) async {
    final Uri url = Uri.parse(apkUrl);
    
    // Show downloading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.download, color: Colors.white),
            SizedBox(width: 12),
            Text('Opening browser to download update...'),
          ],
        ),
        duration: Duration(seconds: 5),
      ),
    );

    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      debugPrint('Download failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open download link: $e')),
        );
      }
    }
  }
}
