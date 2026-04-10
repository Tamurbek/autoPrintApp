// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appTitle => 'AutoPrint Agent';

  @override
  String get windowsPosPrinting => 'Windows POS chop etish xizmati';

  @override
  String get apiEndpoint => 'API Endpoint';

  @override
  String get selectPrinter => 'Printerni tanlang';

  @override
  String get pollingInterval => 'Tekshirish oralig\'i';

  @override
  String get automaticPrinting => 'Avtomatik chop etish';

  @override
  String get serviceActive => 'XIZMAT FAOL';

  @override
  String get servicePaused => 'XIZMAT TO\'XTATILGAN';

  @override
  String get activityLogs => 'Amallar jurnali';

  @override
  String get clearLogs => 'Loglarni tozalash';

  @override
  String get noActivity => 'Hozircha amallar yo\'q';

  @override
  String get newVersion => 'Yangi versiya mavjud';

  @override
  String get update => 'Yangilash';

  @override
  String get startAtBoot => 'Windows bilan birga yuklanish';

  @override
  String get choosePrinter => 'Printerni tanlang';

  @override
  String get downloading => 'Yuklanmoqda...';

  @override
  String get testPrint => 'Test chop etish';

  @override
  String get checkUpdate => 'Yangilanishni tekshirish';

  @override
  String get noUpdate => 'Yangilanish mavjud emas';

  @override
  String get updateAvailable => 'Yangilanish mavjud!';
}
