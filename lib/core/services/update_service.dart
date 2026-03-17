// lib/core/services/update_service.dart
// ========================================================
// Auto-update service - TỰ ĐỘNG đọc version từ pubspec.yaml
// Không cần sửa thủ công khi build version mới
// ========================================================
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../constants/app_constants.dart';

class UpdateService {
  static const String _checkUrl =
      '${AppConstants.baseUrl}/api/app_version.php';

  static Future<void> checkForUpdate({bool silent = true}) async {
    if (!Platform.isAndroid) return;

    if (silent) {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt('last_update_check') ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - lastCheck < 4 * 3600 * 1000) {
        return;
      }
      await prefs.setInt(
          'last_update_check', DateTime.now().millisecondsSinceEpoch);
    }

    try {
      // Tự đọc version từ pubspec.yaml
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // VD: "1.0.1"
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 1;

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      final res = await dio.get(_checkUrl);
      if (res.data == null) return;

      Map<String, dynamic> data;
      if (res.data is Map) {
        data = Map<String, dynamic>.from(res.data);
      } else if (res.data is String) {
        final str = res.data as String;
        final jsonStart = str.indexOf('{');
        if (jsonStart < 0) return;
        data = Map<String, dynamic>.from(jsonDecode(str.substring(jsonStart)));
      } else {
        return;
      }

      if (data['ok'] != 1) return;

      final android = data['android'] as Map<String, dynamic>?;
      if (android == null) return;

      final newVersion = android['version'] ?? currentVersion;
      final newBuild = android['build'] ?? currentBuild;
      final downloadUrl = android['url'] ?? '';
      final notes = android['notes'] ?? '';
      final force = android['force'] ?? false;

      if (_compareVersion(newVersion, currentVersion) > 0 ||
          (newVersion == currentVersion && newBuild > currentBuild)) {
        _showUpdateDialog(
          version: newVersion,
          notes: notes,
          downloadUrl: downloadUrl,
          force: force,
        );
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  static int _compareVersion(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      final a = i < parts1.length ? parts1[i] : 0;
      final b = i < parts2.length ? parts2[i] : 0;
      if (a > b) return 1;
      if (a < b) return -1;
    }
    return 0;
  }

  static void _showUpdateDialog({
    required String version,
    required String notes,
    required String downloadUrl,
    required bool force,
  }) {
    Get.dialog(
      PopScope(
        canPop: !force,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.system_update,
                  color: Colors.green.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Co phien ban moi!',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Phien ban $version',
                    style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(notes,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.4)),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('Cap nhat de su dung tinh nang moi nhat',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange.shade700))),
                ]),
              ),
            ],
          ),
          actions: [
            if (!force)
              TextButton(
                onPressed: () => Get.back(),
                child: Text('De sau',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
            ElevatedButton.icon(
              onPressed: () {
                Get.back();
                _downloadAndInstall(downloadUrl);
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Cap nhat ngay'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
      barrierDismissible: !force,
    );
  }

  static Future<void> _downloadAndInstall(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      Get.snackbar('Loi', 'Khong the tai ban cap nhat',
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}
