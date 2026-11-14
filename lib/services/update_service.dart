// lib/services/update_service.dart
// Handles in-app update checks via Firebase Firestore and In-App Auto-Installer (ota_update).

import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
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
  static const String currentVersion = '1.0.3';
  static const int currentVersionCode = 4;
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

class _UpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _progressValue = 0.0;
  String _progressText = '0%';
  String _statusText = '';
  String? _errorMessage;

  Future<void> _startUpdate() async {
    // If running on Web or Desktop, direct to browser download
    if (kIsWeb || !Platform.isAndroid) {
      UpdateService.launchUpdateUrl(widget.info.downloadUrl);
      if (!widget.info.isMandatory && mounted) Navigator.pop(context);
      return;
    }

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _statusText = 'Connecting to server…';
      _progressValue = 0.0;
      _progressText = '0%';
    });

    try {
      OtaUpdate()
          .execute(
        widget.info.downloadUrl,
        destinationFilename:
            'ClinicManager_v${widget.info.latestVersion}.apk',
      )
          .listen(
        (OtaEvent event) {
          if (!mounted) return;
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final parsed = double.tryParse(event.value ?? '0') ?? 0.0;
              setState(() {
                _progressValue = (parsed / 100).clamp(0.0, 1.0);
                _progressText = '${parsed.toInt()}%';
                _statusText = 'Downloading update… $_progressText';
              });
              break;
            case OtaStatus.INSTALLING:
              setState(() {
                _statusText = 'Launching installer…';
                _progressValue = 1.0;
                _progressText = '100%';
                _isDownloading = false;
              });
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
              setState(() {
                _errorMessage =
                    'An update download is already running in background.';
                _isDownloading = false;
              });
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              setState(() {
                _errorMessage =
                    'Install permission not granted. Please enable "Install unknown apps" for Clinic Manager in Android Settings.';
                _isDownloading = false;
              });
              break;
            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.CHECKSUM_ERROR:
            default:
              setState(() {
                _errorMessage =
                    'Auto-installer notice: ${event.value ?? event.status.name}. You can download directly via browser.';
                _isDownloading = false;
              });
              break;
          }
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Download error: $e';
            _isDownloading = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not start auto-installer: $e';
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMandatory = widget.info.isMandatory;

    return PopScope(
      canPop: !isMandatory && !_isDownloading,
      child: AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F766E).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.system_update_rounded,
            size: 38,
            color: Color(0xFF0F766E),
          ),
        ),
        title: const Text(
          'App Update Available! 🚀',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  'v${UpdateService.currentVersion} ➔ v${widget.info.latestVersion}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F766E),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "What's New in this update:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                widget.info.releaseNotes,
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
            ),
            const SizedBox(height: 16),

            // Live In-App Auto-Installer Progress Section
            if (_isDownloading || _statusText.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _statusText,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ),
                        Text(
                          _progressText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progressValue > 0 ? _progressValue : null,
                        backgroundColor: const Color(0xFFDCFCE7),
                        color: const Color(0xFF0F766E),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Error display with fallback
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                            fontSize: 11, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
        actions: [
          if (!isMandatory && !_isDownloading)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
          if (_errorMessage != null)
            TextButton.icon(
              icon: const Icon(Icons.open_in_browser_rounded, size: 16),
              label: const Text('Open in Browser'),
              onPressed: () {
                UpdateService.launchUpdateUrl(widget.info.downloadUrl);
                if (!isMandatory) Navigator.pop(context);
              },
            ),
          FilledButton.icon(
            onPressed: _isDownloading ? null : _startUpdate,
            icon: _isDownloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(_isDownloading ? 'Downloading…' : 'Update & Install Now'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
            ),
          ),
        ],
      ),
    );
  }
}
