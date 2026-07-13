import 'package:intl/intl.dart';

import '../shared/app_models.dart';

final _ruNumber = NumberFormat.decimalPattern('ru');
final _enNumber = NumberFormat.decimalPattern('en');

/// SweetTime uses whole Kyrgyzstani soms. Russian and Kyrgyz use the local
/// currency name; English uses the ISO code so the amount stays unambiguous.
String formatSom(num value, AppLanguage language) {
  final amount = value.round();
  final formatted = _numberFor(language).format(amount);
  return switch (language) {
    AppLanguage.ru || AppLanguage.ky => '$formatted сом',
    AppLanguage.en => 'KGS $formatted',
  };
}

String formatPoints(num value, AppLanguage language) {
  final amount = value.round();
  final formatted = _numberFor(language).format(amount);
  return switch (language) {
    AppLanguage.ru => '$formatted ${_russianPointsWord(amount)}',
    AppLanguage.ky => '$formatted упай',
    AppLanguage.en => '$formatted ${amount.abs() == 1 ? 'point' : 'points'}',
  };
}

NumberFormat _numberFor(AppLanguage language) =>
    language == AppLanguage.en ? _enNumber : _ruNumber;

String _russianPointsWord(int value) {
  final absolute = value.abs();
  final lastTwo = absolute % 100;
  if (lastTwo >= 11 && lastTwo <= 14) return 'баллов';
  return switch (absolute % 10) {
    1 => 'балл',
    2 || 3 || 4 => 'балла',
    _ => 'баллов',
  };
}

/// Личный код пользователя: «512347» → «512 347».
String formatUserCode(String code) =>
    code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;
