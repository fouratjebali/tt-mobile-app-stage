import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  english('en', 'English', 'English'),
  french('fr', 'French', 'Français');

  const AppLanguage(this.code, this.replyLanguage, this.nativeLabel);

  final String code;
  final String replyLanguage;
  final String nativeLabel;

  static AppLanguage fromCode(String? code) {
    return code == french.code ? french : english;
  }

  static AppLanguage fromReplyLanguage(String value) {
    return value.toLowerCase() == 'french' ? french : english;
  }
}

class AppLanguageController extends ChangeNotifier {
  AppLanguageController(this._prefs)
    : _language = AppLanguage.fromCode(_prefs.getString(_languageKey));

  static const _languageKey = 'appLanguage';
  static const _languageSelectedKey = 'appLanguageSelected';

  final SharedPreferences _prefs;
  AppLanguage _language;

  AppLanguage get language => _language;
  bool get isFrench => _language == AppLanguage.french;
  bool get hasSelectedLanguage => _prefs.getBool(_languageSelectedKey) ?? false;

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language && hasSelectedLanguage) return;
    _language = language;
    await _prefs.setString(_languageKey, language.code);
    await _prefs.setBool(_languageSelectedKey, true);
    notifyListeners();
  }
}
