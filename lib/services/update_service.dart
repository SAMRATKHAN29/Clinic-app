// lib/services/update_service.dart
// Handles in-app update checks via Firebase Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  final String latestVersion;
  final int versionCode;
  final String downloadUrl;
  final String releaseNotes;
  final bool isMandatory;

  AppUpdateInfo({
    required this.latestVersion,
    required this.versionCode,
    required this.downloadUrl,
    required this.releaseNotes,
    this.isMandatory = false,
  });

  factory AppUpdateInfo.fromFirestore(Map<String, dynamic> data) {
    return AppUpdateInfo(
      latestVersion: data['latestVersion'] ?? '1.0.0',
      versionCode: data['versionCode'] ?? 1,
      downloadUrl: data['downloadUrl'] ??
          'https://github.com/SAMRATKHAN29/Clinic-app/releases/latest',
      releaseNotes: data['releaseNotes'] ??
          'A new update is available with performance improvements and bug fixes.',
      isMandatory: data['isMandatory'] ?? false,
    );
  }
}

class UpdateService {
  static const String currentVersion = '1.0.0';
  static const int currentVersionCode = 1;
  static const String developerName = 'Samrat Khan';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetches update info from Firestore (app_config/version)
  Future<AppUpdateInfo?> fetchUpdateInfo() async {
    try {
      final doc = await _db.collection('app_config').doc('version').get();
      if (!doc.exists || doc.data() == null) {
        // Seed default version document if absent
        final defaultInfo = {
          'latestVersion': currentVersion,
          'versionCode': currentVersionCode,
          'downloadUrl':
              'https://github.com/SAMRATKHAN29/Clinic-app/releases/latest',
          'releaseNotes': 'Initial release of Clinic Manager.',
          'isMandatory': false,
          'developer': developerName,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await _db.collection('app_config').doc('version').set(defaultInfo);
        return AppUpdateInfo.fromFirestore(defaultInfo);
      }
      return AppUpdateInfo.fromFirestore(doc.data()!);
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    }
  }

  /// Check if an update is available
  bool isUpdateAvailable(AppUpdateInfo info) {
    if (info.versionCode > currentVersionCode) return true;
    return _compareVersions(info.latestVersion, currentVersion) > 0;
  }

  /// Compares semantic version strings (e.g. "1.0.1" vs "1.0.0")
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  /// Prompt the user with an update dialog if an update is available
  Future<void> checkForUpdates(
    BuildContext context, {
    bool silentIfUpToDate = false,
  }) async {
    final updateInfo = await fetchUpdateInfo();

    if (!context.mounted) return;

    if (updateInfo != null && isUpdateAvailable(updateInfo)) {
      showDialog(
        context: context,
        barrierDismissible: !updateInfo.isMandatory,
        builder: (ctx) => _UpdateDialog(info: updateInfo),
      );
    } else if (!silentIfUpToDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('You are on the latest version (v$currentVersion)'),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Launch download URL
  static Future<void> launchUpdateUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _UpdateDialog extends StatelessWidget {
  final AppUpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !info.isMandatory,
      child: AlertDialog(
        icon: Icon(
          Icons.system_update_rounded,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        title: const Text(
          'New Update Available! 🚀',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'v${UpdateService.currentVersion} ➔ v${info.latestVersion}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "What's New:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              info.releaseNotes,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'A new update is available. Tap below to download and install the latest features.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          if (!info.isMandatory)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
          FilledButton.icon(
            onPressed: () {
              UpdateService.launchUpdateUrl(info.downloadUrl);
              if (!info.isMandatory) Navigator.pop(context);
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}
