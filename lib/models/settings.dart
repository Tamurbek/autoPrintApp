
class AppSettings {
  final String apiUrl;
  final String? selectedPrinter;
  final bool autoPrintEnabled;
  final bool startAtBoot;
  final String locale;
  final int pollingInterval; // in seconds

  AppSettings({
    required this.apiUrl,
    this.selectedPrinter,
    this.autoPrintEnabled = false,
    this.startAtBoot = true,
    this.locale = 'uz',
    this.pollingInterval = 10,
  });

  AppSettings copyWith({
    String? apiUrl,
    String? selectedPrinter,
    bool? autoPrintEnabled,
    bool? startAtBoot,
    String? locale,
    int? pollingInterval,
  }) {
    return AppSettings(
      apiUrl: apiUrl ?? this.apiUrl,
      selectedPrinter: selectedPrinter ?? this.selectedPrinter,
      autoPrintEnabled: autoPrintEnabled ?? this.autoPrintEnabled,
      startAtBoot: startAtBoot ?? this.startAtBoot,
      locale: locale ?? this.locale,
      pollingInterval: pollingInterval ?? this.pollingInterval,
    );
  }
}
