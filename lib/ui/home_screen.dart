
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/gen_l10n/app_localizations.dart';
import '../providers/app_provider.dart';
import 'dialogs/pdf_preview_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLocked = true;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final settings = provider.settings;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar / Settings
          Container(
            width: 350,
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.print_rounded, color: Color(0xFF6366F1), size: 28),
                          const SizedBox(width: 8),
                          Text(
                            l10n.appTitle,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => setState(() => _isLocked = !_isLocked),
                        icon: Icon(
                          _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                          size: 20,
                          color: _isLocked ? Colors.white24 : const Color(0xFF6366F1),
                        ),
                        tooltip: _isLocked ? "Sozlamalarni ochish" : "Sozlamalarni qulflash",
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.windowsPosPrinting,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  
                  // Connection Status Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: provider.isWsConnected 
                        ? Colors.green.withOpacity(0.1) 
                        : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: provider.isWsConnected 
                          ? Colors.green.withOpacity(0.3) 
                          : Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: provider.isWsConnected ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (provider.isWsConnected ? Colors.green : Colors.red).withOpacity(0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          provider.isWsConnected ? "Server bilan aloqa bor" : "Server bilan aloqa yo'q",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: provider.isWsConnected ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Language Selection (Always visible)
                  Row(
                    children: [
                      _langBtn(context, provider, '🇺🇿', 'uz'),
                      const SizedBox(width: 8),
                      _langBtn(context, provider, '🇷🇺', 'ru'),
                      const SizedBox(width: 8),
                      _langBtn(context, provider, '🇺🇸', 'en'),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  if (!_isLocked) ...[
                    // --- SERVER SETTINGS --- (Hidden by default)
                    _sectionHeader(l10n.apiEndpoint, Icons.dns_rounded),
                    const SizedBox(height: 12),
                    _settingsCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _textField(
                                  label: "API URL",
                                  initialValue: settings.apiUrl,
                                  hint: 'https://api.example.com',
                                  icon: Icons.link_rounded,
                                  onChanged: (val) => provider.updateSettings(apiUrl: val),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 22),
                                child: _actionBtn(
                                  label: "Ping",
                                  icon: Icons.sensors_rounded,
                                  color: Colors.green,
                                  onPressed: provider.manualPing,
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(color: Colors.white10, height: 1),
                          ),
                          _textField(
                            label: l10n.apiKey,
                            initialValue: settings.apiKey,
                            hint: 'cd8d7cd62ea6...',
                            icon: Icons.key_rounded,
                            isPassword: true,
                            onChanged: (val) => provider.updateSettings(apiKey: val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // --- PRINTER SETTINGS --- (Always visible for printer switching)
                  _sectionHeader(l10n.selectPrinter, Icons.print_rounded),
                  const SizedBox(height: 12),
                  _settingsCard(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: provider.availablePrinters.any((p) => p.name == settings.selectedPrinter) 
                                  ? settings.selectedPrinter 
                                  : null,
                              hint: Text(l10n.choosePrinter, style: const TextStyle(fontSize: 13)),
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1E293B),
                              onChanged: (val) => provider.updateSettings(selectedPrinter: val),
                              items: provider.availablePrinters.map((p) {
                                return DropdownMenuItem(
                                  value: p.name,
                                  child: Text(p.name, style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _actionBtn(
                                label: l10n.testPrint,
                                icon: Icons.playlist_add_check_rounded,
                                color: const Color(0xFF6366F1),
                                onPressed: provider.testPrint,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _actionBtn(
                                label: "JSON",
                                icon: Icons.code_rounded,
                                color: Colors.white24,
                                onPressed: provider.testJsonPrint,
                              ),
                            ),
                          ],
                        ),
                        if (provider.lastPdfBytes != null) ...[
                          const SizedBox(height: 8),
                          _actionBtn(
                            label: "Ko'rish",
                            icon: Icons.visibility_rounded,
                            color: Colors.teal.withOpacity(0.5),
                            onPressed: () => PdfPreviewDialog.show(context, provider.lastPdfBytes!),
                            isFullWidth: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (!_isLocked) ...[
                    // --- APP SETTINGS --- (Hidden by default)
                    _sectionHeader("Ilova sozlamalari", Icons.settings_suggest_rounded),
                    const SizedBox(height: 12),
                    _settingsCard(
                      child: Column(
                        children: [
                          _settingRow(
                            label: "${l10n.pollingInterval}: ${settings.pollingInterval}s",
                            child: SizedBox(
                              width: 120,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                ),
                                child: Slider(
                                  value: settings.pollingInterval.toDouble(),
                                  min: 5,
                                  max: 60,
                                  divisions: 11,
                                  activeColor: const Color(0xFF6366F1),
                                  onChanged: (val) => provider.updateSettings(pollingInterval: val.toInt()),
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(color: Colors.white10, height: 1),
                          ),
                          _settingToggle(
                            label: l10n.startAtBoot,
                            value: settings.startAtBoot,
                            onChanged: (val) => provider.updateSettings(startAtBoot: val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Auto Print Toggle (Always visible)
                  _settingToggle(
                    label: l10n.automaticPrinting,
                    value: settings.autoPrintEnabled,
                    subtitle: settings.autoPrintEnabled ? l10n.serviceActive : l10n.servicePaused,
                    onChanged: (val) => provider.updateSettings(autoPrintEnabled: val),
                    activeColor: const Color(0xFF6366F1),
                  ),

                  const SizedBox(height: 24),

                  // Update & Version
                  if (provider.updateData != null) _updateBanner(context, provider, l10n),
                  
                  const SizedBox(height: 12),
                  _actionBtn(
                    label: l10n.checkUpdate,
                    icon: Icons.sync_rounded,
                    color: Colors.white10,
                    onPressed: provider.manualCheckUpdate,
                    isFullWidth: true,
                  ),

                ],
              ),
            ),
          ),


          // Logs / Main Area
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.background,
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.activityLogs,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: provider.clearLogs,
                        icon: const Icon(Icons.delete_sweep_rounded),
                        label: Text(l10n.clearLogs),
                        style: TextButton.styleFrom(foregroundColor: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: provider.logs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
                                  const SizedBox(height: 16),
                                  Text(
                                    l10n.noActivity,
                                    style: TextStyle(color: Colors.white.withOpacity(0.2)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: provider.logs.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
                              itemBuilder: (context, index) {
                                final log = provider.logs[index];
                                final isError = log.contains('Error');
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    log,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      color: isError ? Colors.redAccent : Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _settingsCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }

  Widget _textField({
    required String label,
    required String initialValue,
    required String hint,
    required IconData icon,
    required Function(String) onChanged,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: initialValue)
            ..selection = TextSelection.fromPosition(TextPosition(offset: initialValue.length)),
          onChanged: onChanged,
          obscureText: isPassword,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF6366F1).withOpacity(0.7)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
          ),
        ),
      ],
    );
  }

  Widget _settingRow({required String label, required Widget child}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.white)),
        child,
      ],
    );
  }

  Widget _settingToggle({
    required String label,
    required bool value,
    required Function(bool) onChanged,
    String? subtitle,
    Color? activeColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
              if (subtitle != null)
                Text(subtitle, style: TextStyle(fontSize: 10, color: activeColor ?? Colors.white54, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: activeColor ?? const Color(0xFF6366F1),
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isFullWidth = false,
  }) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: 40,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: TextButton.styleFrom(
          foregroundColor: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          backgroundColor: color.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: color.withOpacity(0.3)),
          ),
        ),
      ),
    );
  }

  Widget _updateBanner(BuildContext context, AppProvider provider, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Text(
                'v${provider.updateData!['version']} tayyor!',
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (provider.isDownloading)
            LinearProgressIndicator(value: provider.downloadProgress, color: Colors.amber, backgroundColor: Colors.white10)
          else
            _actionBtn(
              label: l10n.update,
              icon: Icons.download_rounded,
              color: Colors.amber,
              onPressed: provider.startUpdate,
              isFullWidth: true,
            ),
        ],
      ),
    );
  }

  Widget _langBtn(BuildContext context, AppProvider provider, String flag, String code) {
    final active = provider.settings.locale == code;
    return InkWell(
      onTap: () => provider.updateSettings(locale: code),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6366F1).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? const Color(0xFF6366F1).withOpacity(0.5) : Colors.white10),
        ),
        child: Text(flag, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

