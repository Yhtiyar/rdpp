import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LocalStore {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> data);
}

class PreferencesStore implements LocalStore {
  static const _key = 'littlewins.state.v1';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  @override
  Future<Map<String, dynamic>?> read() async {
    final raw = await _preferences.getString(_key);
    if (raw == null) {
      return null;
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> write(Map<String, dynamic> data) =>
      _preferences.setString(_key, jsonEncode(data));
}
