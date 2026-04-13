// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AutoPrint Agent';

  @override
  String get windowsPosPrinting => 'Windows POS Printing Service';

  @override
  String get apiEndpoint => 'API Endpoint';

  @override
  String get selectPrinter => 'Select Printer';

  @override
  String get pollingInterval => 'Polling Interval';

  @override
  String get automaticPrinting => 'Automatic Printing';

  @override
  String get serviceActive => 'SERVICE ACTIVE';

  @override
  String get servicePaused => 'SERVICE PAUSED';

  @override
  String get activityLogs => 'Activity Logs';

  @override
  String get clearLogs => 'Clear Logs';

  @override
  String get noActivity => 'No activity yet';

  @override
  String get newVersion => 'New Version Available';

  @override
  String get update => 'Update';

  @override
  String get startAtBoot => 'Start on Windows Boot';

  @override
  String get choosePrinter => 'Choose a printer';

  @override
  String get downloading => 'Downloading...';

  @override
  String get testPrint => 'Test Print';

  @override
  String get testJsonPrint => 'Test JSON Print';

  @override
  String get checkUpdate => 'Check for Updates';

  @override
  String get noUpdate => 'No update available';

  @override
  String get updateAvailable => 'Update available!';

  @override
  String get apiKey => 'API Key';
}
