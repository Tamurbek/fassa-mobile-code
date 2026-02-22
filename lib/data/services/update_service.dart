import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../services/api_service.dart';
import '../../theme/app_colors.dart';

class UpdateService {
  final ApiService _api = ApiService();
  final Dio _dio = Dio();

  Future<void> checkForUpdate() async {
    try {
      final updateInfo = await _api.getLatestVersion();
      final packageInfo = await PackageInfo.fromPlatform();
      
      final currentBuild = int.parse(packageInfo.buildNumber);
      
      final latestVersion = updateInfo['latest_version'] ?? "1.0.0";
      final latestBuild = int.tryParse(updateInfo['build_number']?.toString() ?? "0") ?? 0;
      
      if (latestBuild > currentBuild) {
        _showUpdateDialog(
          version: latestVersion,
          notes: updateInfo['release_notes'] ?? "",
          url: updateInfo['url'] ?? "",
          critical: updateInfo['critical'] ?? false,
        );
      }
    } catch (e) {
      print("Update check failed: $e");
    }
  }

  void _showUpdateDialog({
    required String version,
    required String notes,
    required String url,
    required bool critical,
  }) {
    Get.dialog(
      WillPopScope(
        onWillPop: () async => !critical,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.system_update_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Text("Yangi versiya: v$version"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Yangi imkoniyatlar:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(notes),
              const SizedBox(height: 16),
              if (critical)
                const Text(
                  "Ushbu yangilanish majburiy. Ilovadan foydalanishda davom etish uchun yangilang.",
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
            ],
          ),
          actions: [
            if (!critical)
              TextButton(
                onPressed: () => Get.back(),
                child: const Text("Keyinroq", style: TextStyle(color: Colors.grey)),
              ),
            ElevatedButton(
              onPressed: () {
                Get.back();
                _downloadAndInstall(url, version);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Hozir yangilash", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
      barrierDismissible: !critical,
    );
  }

  Future<void> _downloadAndInstall(String url, String version) async {
    String absoluteUrl = url.startsWith('http') 
        ? url 
        : "${ApiService.baseUrl}$url";

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String savePath = "${tempDir.path}/FastSalePOS_v$version.apk";

      var progress = 0.0.obs;

      Get.dialog(
        Obx(() => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Yangilanish yuklanmoqda..."),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: progress.value,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text("${(progress.value * 100).toStringAsFixed(0)}%"),
            ],
          ),
        )),
        barrierDismissible: false,
      );

      await _dio.download(
        absoluteUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            progress.value = received / total;
          }
        },
      );

      Get.back(); // Close progress dialog

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        Get.snackbar("Xato", "APK faylni ochib bo'lmadi: ${result.message}");
      }
    } catch (e) {
      Get.back(); // Close progress dialog
      print("Download error: $e");
      Get.snackbar("Xato", "Yangilanishni yuklab bo'lmadi");
    }
  }
}
