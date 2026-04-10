import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_app_file/open_app_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../l10n/gen_l10n/app_localizations.dart';

class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    super.key,
    required this.version,
    required this.url,
    this.changelog,
    this.isMandatory = false,
  });

  final String version;
  final String url;
  final String? changelog;
  final bool isMandatory;

  static void show(BuildContext context, String version, String url, {String? changelog, bool isMandatory = false}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: !isMandatory,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => AppUpdateDialog(
        version: version,
        url: url,
        changelog: changelog,
        isMandatory: isMandatory,
      ),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool isDownloading = false;
  bool isInstalling = false;
  double downloadProgress = 0.0;
  String? errorMessage;
  String? downloadedBytesStr;
  String? totalBytesStr;
  
  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024) return "${bytes} B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(decimals)} KB";
    if (bytes < 1024 * 1024 * 1024) return "${(bytes / (1024 * 1024)).toStringAsFixed(decimals)} MB";
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(decimals)} GB";
  }

  Future<void> _startUpdate() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted && !await Permission.manageExternalStorage.request().isGranted) {
         setState(() { errorMessage = 'Fayllarni saqlash uchun ruxsat kerak.'; });
         return;
      }
    }

    setState(() {
      isDownloading = true;
      downloadProgress = 0.0;
      errorMessage = null;
    });

    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final downloadUrl = widget.url;
      
      String fileName = 'AutoPrint_Update_v${widget.version}.exe';
      if (Platform.isAndroid) {
        fileName = 'AutoPrint_v${widget.version}.apk';
      }
      
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      if (await file.exists()) await file.delete();

      await dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (mounted) {
            setState(() {
              if (total != -1) {
                downloadProgress = received / total;
                totalBytesStr = _formatBytes(total, 1);
              } else {
                downloadProgress = 0.05;
              }
              downloadedBytesStr = _formatBytes(received, 1);
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        isDownloading = false;
        isInstalling = true;
      });

      await Future.delayed(const Duration(milliseconds: 800));

      if (Platform.isWindows) {
        await Process.start(filePath, ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/SP-', '/NOCANCEL', '/NORESTART'], mode: ProcessStartMode.detached);
        await Future.delayed(const Duration(seconds: 1));
        exit(0);
      } else {
        final result = await OpenAppFile.open(filePath);
        if (result.type != ResultType.done) {
          throw Exception('O\'rnatishda xatolik: ${result.message}');
        }
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isDownloading = false;
        isInstalling = false;
        errorMessage = 'Xatolik: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = const Color(0xFF6366F1);
    final l10n = AppLocalizations.of(context)!;
    
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 440,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 50,
                spreadRadius: -10,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor.withOpacity(0.8), primaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: const Center(
                  child: Icon(Icons.system_update_alt_rounded, size: 56, color: Colors.white),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Yangi versiya tayyor!',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'v${widget.version}',
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    if (widget.changelog != null && widget.changelog!.isNotEmpty) ...[
                      const Text('Nimalar yangi:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            widget.changelog!,
                            style: const TextStyle(color: Colors.white60, height: 1.4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      const Text(
                        'Dasturning yangi versiyasi mavjud. Barqarorlik va yangi funksiyalar uchun yangilash tavsiya etiladi.',
                        style: TextStyle(color: Colors.white70, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                    ],

                    if (!isDownloading && !isInstalling) ...[
                      Row(
                        children: [
                          if (!widget.isMandatory)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white54,
                                  side: const BorderSide(color: Colors.white10),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Keyinroq'),
                              ),
                            ),
                          if (!widget.isMandatory) const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _startUpdate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Yangilash', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      _buildProgressSection(primaryColor, isInstalling ? 'O\'rnatilmoqda...' : 'Yuklanmoqda...'),
                    ],
                    
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(Color color, String status) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            if (totalBytesStr != null)
              Text('$downloadedBytesStr / $totalBytesStr', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: isInstalling ? null : downloadProgress,
            minHeight: 10,
            backgroundColor: Colors.white.withOpacity(0.05),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
