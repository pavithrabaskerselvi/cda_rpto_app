import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';

class LanguageProvider extends ChangeNotifier {
  static const _key = 'rpto_language_code';
  String _code = 'en'; // 'en' | 'ta' | 'hi'
  String get code => _code;

  LanguageProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _code = prefs.getString(_key) ?? 'en';
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    _code = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }

  String get displayName {
    switch (_code) {
      case 'ta':
        return 'தமிழ் (Tamil)';
      case 'hi':
        return 'हिन्दी (Hindi)';
      default:
        return 'English (India)';
    }
  }

  /// Translate a key into the currently selected language.
  ///
  /// Usage:
  ///   languageProvider.t('profile_title')
  ///   languageProvider.t('copied_to_clipboard', {'label': 'Phone number'})
  String t(String key, [Map<String, String>? params]) {
    var text = AppStrings.get(key, _code);
    if (params != null) {
      params.forEach((paramKey, value) {
        text = text.replaceAll('{$paramKey}', value);
      });
    }
    return text;
  }
}