
class AppSettings {
  final String apiUrl;
  final String? selectedPrinter;
  final bool autoPrintEnabled;
  final int pollingInterval; // in seconds

  AppSettings({
    required this.apiUrl,
    this.selectedPrinter,
    this.autoPrintEnabled = false,
    this.pollingInterval = 10,
  });

  AppSettings copyWith({
    String? apiUrl,
    String? selectedPrinter,
    bool? autoPrintEnabled,
    int? pollingInterval,
  }) {
    return AppSettings(
      apiUrl: apiUrl ?? this.apiUrl,
      selectedPrinter: selectedPrinter ?? this.selectedPrinter,
      autoPrintEnabled: autoPrintEnabled ?? this.autoPrintEnabled,
      pollingInterval: pollingInterval ?? this.pollingInterval,
    );
  }
}
