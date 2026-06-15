import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  LocalStorage._(this._preferences);

  final SharedPreferences? _preferences;
  final Map<String, Object?> _memory = {};

  static Future<LocalStorage> create() async {
    try {
      return LocalStorage._(await SharedPreferences.getInstance());
    } catch (_) {
      return LocalStorage._(null);
    }
  }

  T? read<T>(String key) {
    final value = _preferences?.get(key) ?? _memory[key];
    if (value is T) {
      return value;
    }

    if (value is String && T != String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map && T == Map<String, Object?>) {
          return decoded.map((key, item) => MapEntry(key.toString(), item))
              as T;
        }
        if (decoded is T) {
          return decoded;
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> write(String key, Object? value) async {
    _memory[key] = value;
    final preferences = _preferences;
    if (preferences == null) return;

    if (value == null) {
      await preferences.remove(key);
    } else if (value is String) {
      await preferences.setString(key, value);
    } else if (value is bool) {
      await preferences.setBool(key, value);
    } else if (value is int) {
      await preferences.setInt(key, value);
    } else if (value is double) {
      await preferences.setDouble(key, value);
    } else if (value is List<String>) {
      await preferences.setStringList(key, value);
    } else {
      await preferences.setString(key, jsonEncode(value));
    }
  }

  Future<void> remove(String key) async {
    _memory.remove(key);
    await _preferences?.remove(key);
  }
}
