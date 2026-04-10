
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../providers/app_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.print_rounded, color: Color(0xFF6366F1), size: 32),
                    const SizedBox(width: 12),
                    Text(
                      l10n.appTitle,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.windowsPosPrinting,
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
                const SizedBox(height: 32),
                
                // Language Selection
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
                
                // API URL
                Text(l10n.apiEndpoint, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(text: settings.apiUrl),
                  onSubmitted: (val) => provider.updateSettings(apiUrl: val),
                  decoration: const InputDecoration(
                    hintText: 'https://api.example.com/print-queue',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 24),

                // Printer Selection
                Text(l10n.selectPrinter, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: provider.availablePrinters.any((p) => p.name == settings.selectedPrinter) 
                          ? settings.selectedPrinter 
                          : null,
                      hint: Text(l10n.choosePrinter),
                      isExpanded: true,
                      onChanged: (val) => provider.updateSettings(selectedPrinter: val),
                      items: provider.availablePrinters.map((p) {
                        return DropdownMenuItem(
                          value: p.name,
                          child: Text(p.name),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Interval
                Text('${l10n.pollingInterval}: ${settings.pollingInterval}s', style: const TextStyle(fontWeight: FontWeight.w600)),
                Slider(
                  value: settings.pollingInterval.toDouble(),
                  min: 5,
                  max: 60,
                  divisions: 11,
                  activeColor: const Color(0xFF6366F1),
                  onChanged: (val) => provider.updateSettings(pollingInterval: val.toInt()),
                ),
                
                const SizedBox(height: 12),

                // Start on Boot Toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(l10n.startAtBoot, style: const TextStyle(fontSize: 13))),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: settings.startAtBoot,
                          onChanged: (val) => provider.updateSettings(startAtBoot: val),
                          activeColor: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Auto Print Toggle
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: settings.autoPrintEnabled 
                        ? const Color(0xFF6366F1).withOpacity(0.1)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: settings.autoPrintEnabled 
                          ? const Color(0xFF6366F1)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.automaticPrinting, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            settings.autoPrintEnabled ? l10n.serviceActive : l10n.servicePaused,
                            style: TextStyle(
                              fontSize: 12, 
                              color: settings.autoPrintEnabled ? const Color(0xFF6366F1) : Colors.white54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: settings.autoPrintEnabled,
                        onChanged: (val) => provider.updateSettings(autoPrintEnabled: val),
                        activeColor: const Color(0xFF6366F1),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Update Banner
                if (provider.updateData != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.update_rounded, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${l10n.newVersion}: v${provider.updateData!['version']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (provider.isDownloading)
                          Column(
                            children: [
                              LinearProgressIndicator(
                                value: provider.downloadProgress,
                                backgroundColor: Colors.white10,
                                color: Colors.amber,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(provider.downloadProgress * 100).toInt()}% ${l10n.downloading}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          )
                        else
                          ElevatedButton(
                            onPressed: provider.startUpdate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(double.infinity, 40),
                            ),
                            child: Text(l10n.update),
                          ),
                      ],
                    ),
                  ),
              ],
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

  Widget _langBtn(BuildContext context, AppProvider provider, String flag, String code) {
    final active = provider.settings.locale == code;
    return InkWell(
      onTap: () => provider.updateSettings(locale: code),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6366F1).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? const Color(0xFF6366F1) : Colors.white10),
        ),
        child: Text(flag, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}
