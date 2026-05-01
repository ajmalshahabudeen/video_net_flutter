import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Service for persisting and retrieving saved credentials.
class CredentialStorageService {
  static const _key = 'saved_credentials';

  /// Save credentials for a specific host.
  Future<void> saveCredentials(
      String host, SmbCredentials credentials) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAllCredentials();
    all[host] = credentials;

    final encoded = jsonEncode(
      all.map((k, v) => MapEntry(k, v.toJson())),
    );
    await prefs.setString(_key, encoded);
  }

  /// Get saved credentials for a specific host.
  Future<SmbCredentials?> getCredentials(String host) async {
    final all = await getAllCredentials();
    return all[host];
  }

  /// Get all saved credentials.
  Future<Map<String, SmbCredentials>> getAllCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, SmbCredentials.fromJson(v as Map<String, dynamic>)),
      );
    } catch (_) {
      return {};
    }
  }

  /// Remove credentials for a specific host.
  Future<void> removeCredentials(String host) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAllCredentials();
    all.remove(host);

    final encoded = jsonEncode(
      all.map((k, v) => MapEntry(k, v.toJson())),
    );
    await prefs.setString(_key, encoded);
  }

  /// Check if credentials exist for a host.
  Future<bool> hasCredentials(String host) async {
    final all = await getAllCredentials();
    return all.containsKey(host);
  }
}
