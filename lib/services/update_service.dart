
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
      final response = await dio.get(githubApiUrl);
      
      if (response.statusCode == 200) {
        final data = response.data;
        final latestVersion = data['tag_name'].toString().replaceFirst('v', '');
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (_isNewer(latestVersion, currentVersion)) {
          final assets = data['assets'] as List;
          final setupAsset = assets.firstWhere(
            (a) => a['name'].toString().contains('Setup'),
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
      final filePath = "${tempDir.path}/AutoPrint_Update.exe";
      
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
      exit(0); // Close app to allow installation
    } catch (e) {
      print("Download/Install error: $e");
    }
  }
}
