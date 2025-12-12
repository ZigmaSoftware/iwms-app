import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../localization/app_localizations.dart';

const String _localePreferenceKey = 'profile_language_code';

class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(AppLocalizations.supportedLocales.first) {
    _loadPreferredLocale();
  }

  Future<void> setLocale(Locale locale) async {
    if (!_isSupported(locale) || locale == state) return;
    emit(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePreferenceKey, locale.languageCode);
  }

  Future<void> _loadPreferredLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localePreferenceKey);
    if (code == null) return;
    final matchedLocale = AppLocalizations.supportedLocales.firstWhere(
      (supportedLocale) => supportedLocale.languageCode == code,
      orElse: () => state,
    );
    if (matchedLocale != state) {
      emit(matchedLocale);
    }
  }

  bool _isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((supported) => supported.languageCode == locale.languageCode);
}
