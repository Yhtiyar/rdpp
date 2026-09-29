import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/local_store.dart';

/// Listening cannot grant coins or replace reading progress.
class ListeningPreferencesStore implements LocalStore {
  static const key = 'littlewins.listening.v1';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  @override
  Future<Map<String, dynamic>?> read() async {
    final value = await _preferences.getString(key);
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  @override
  Future<void> write(Map<String, dynamic> data) =>
      _preferences.setString(key, jsonEncode(data));
}
