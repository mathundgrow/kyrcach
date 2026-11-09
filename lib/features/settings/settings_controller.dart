import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_settings.dart';

/// Настройки ИИ, сохранённые в SharedPreferences.
class SettingsController extends ChangeNotifier {
  SettingsController(this._preferences);

  static const _baseUrlKey = 'ai.base_url';
  static const _modelKey = 'ai.model';
  static const _timeoutKey = 'ai.timeout_seconds';

  final SharedPreferences _preferences;

  AiSettings _settings = AiSettings.defaults;
  bool _isSaving = false;

  AiSettings get settings => _settings;

  bool get isSaving => _isSaving;

  Future<void> load() async {
    _settings = AiSettings(
      baseUrl:
          _preferences.getString(_baseUrlKey) ?? AiSettings.defaults.baseUrl,
      model: _preferences.getString(_modelKey) ?? AiSettings.defaults.model,
      timeout: Duration(
        seconds:
            _preferences.getInt(_timeoutKey) ??
            AiSettings.defaults.timeout.inSeconds,
      ),
    );
    notifyListeners();
  }

  Future<void> save(AiSettings value) async {
    if (value == _settings) return;
    _isSaving = true;
    notifyListeners();
    try {
      await _preferences.setString(_baseUrlKey, value.baseUrl);
      await _preferences.setString(_modelKey, value.model);
      await _preferences.setInt(_timeoutKey, value.timeout.inSeconds);
      _settings = value;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> reset() => save(AiSettings.defaults);
}
