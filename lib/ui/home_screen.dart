
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final settings = provider.settings;

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
                const Row(
                  children: [
                    Icon(Icons.print_rounded, color: Color(0xFF6366F1), size: 32),
                    SizedBox(width: 12),
                    Text(
                      'AutoPrint Agent',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Windows POS Printing Service',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
                const SizedBox(height: 48),
                
                // API URL
                const Text('API Endpoint', style: TextStyle(fontWeight: FontWeight.w600)),
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
                const Text('Select Printer', style: TextStyle(fontWeight: FontWeight.w600)),
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
                      hint: const Text('Choose a printer'),
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
                Text('Polling Interval: ${settings.pollingInterval}s', style: const TextStyle(fontWeight: FontWeight.w600)),
                Slider(
                  value: settings.pollingInterval.toDouble(),
                  min: 5,
                  max: 60,
                  divisions: 11,
                  activeColor: const Color(0xFF6366F1),
                  onChanged: (val) => provider.updateSettings(pollingInterval: val.toInt()),
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
                          const Text('Automatic Printing', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            settings.autoPrintEnabled ? 'SERVICE ACTIVE' : 'SERVICE PAUSED',
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
                      const Text(
                        'Activity Logs',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: provider.clearLogs,
                        icon: const Icon(Icons.delete_sweep_rounded),
                        label: const Text('Clear Logs'),
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
                                    'No activity yet',
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
}
