// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'AutoPrint Agent';

  @override
  String get windowsPosPrinting => 'Служба печати POS для Windows';

  @override
  String get apiEndpoint => 'API Endpoint';

  @override
  String get selectPrinter => 'Выберите принтер';

  @override
  String get pollingInterval => 'Интервал опроса';

  @override
  String get automaticPrinting => 'Автоматическая печать';

  @override
  String get serviceActive => 'СЛУЖБА АКТИВНА';

  @override
  String get servicePaused => 'СЛУЖБА ПРИОСТАНОВЛЕНА';

  @override
  String get activityLogs => 'Журналы активности';

  @override
  String get clearLogs => 'Очистить логи';

  @override
  String get noActivity => 'Активности пока нет';

  @override
  String get newVersion => 'Доступна новая версия';

  @override
  String get update => 'Обновить';

  @override
  String get startAtBoot => 'Запускать при старте Windows';

  @override
  String get choosePrinter => 'Выберите принтер';

  @override
  String get downloading => 'Загрузка...';

  @override
  String get testPrint => 'Пробная печать';

  @override
  String get testJsonPrint => 'Тест JSON печати';

  @override
  String get checkUpdate => 'Проверить обновления';

  @override
  String get noUpdate => 'Нет доступных обновлений';

  @override
  String get updateAvailable => 'Доступно обновление!';

  @override
  String get apiKey => 'API Ключ';

  @override
  String get open => 'Открыть';

  @override
  String get exit => 'Выйти';
}
