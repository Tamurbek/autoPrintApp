
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_app_file/open_app_file.dart';

class UpdateService {
  static const String githubApiUrl = "https://api.github.com/repos/Tamurbek/autoPrintApp/releases/latest";

  Future<Map<String, dynamic>?> checkUpdate() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        githubApiUrl,
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        final latestVersion = data['tag_name'].toString().replaceFirst('v', '');
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (_isNewer(latestVersion, currentVersion)) {
          final assets = data['assets'] as List;
          final setupAsset = assets.firstWhere(
            (a) => a['name'].toString().contains('Setup') || a['name'].toString().endsWith('.exe'),
            orElse: () => null,
          );
          
          if (setupAsset != null) {
            return {
              'version': latestVersion,
              'url': setupAsset['browser_download_url'],
              'changelog': data['body'] ?? '',
            };
          }
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        print("Update check error: $e");
      }
    } catch (e) {
      print("Update check error: $e");
    }

    return null;
  }

  bool _isNewer(String latest, String current) {
    try {
      // Remove build fragments (+1, etc.)
      String latestClean = latest.split('+')[0];
      String currentClean = current.split('+')[0];

      List<int> latestParts = latestClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> currentParts = currentClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      
      for (int i = 0; i < latestParts.length; i++) {
          if (i >= currentParts.length) return true;
          if (latestParts[i] > currentParts[i]) return true;
          if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> downloadAndInstall(String url, Function(double) onProgress) async {
    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      
      // Use unique filename to avoid "Access Denied" errors if previous file is locked
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = "${tempDir.path}/AutoPrint_Update_$timestamp.exe";
      
      await dio.download(
        url, 
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      // Execute the installer
      await OpenAppFile.open(filePath);
      
      // Wait a bit and exit to allow installer to run
      await Future.delayed(const Duration(seconds: 1));
      exit(0);
    } catch (e) {
      throw e; // Rethrow to be caught by provider and shown in UI
    }
  }

}
