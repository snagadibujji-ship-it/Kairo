import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

/// Service responsible for managing encrypted storage on Android KeyStore and iOS Keychain.
class SecureStorageService extends GetxService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true, // Uses Android KeyStore for encrypting shared preferences
    ),
  );

  /// Write encrypted key-value pair.
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      print('[SecureStorageService] Write error for key "$key": $e');
    }
  }

  /// Read decrypted value by key.
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      print('[SecureStorageService] Read error for key "$key": $e');
      return null;
    }
  }

  /// Delete value by key.
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      print('[SecureStorageService] Delete error for key "$key": $e');
    }
  }

  /// Clear all keys.
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      print('[SecureStorageService] ClearAll error: $e');
    }
  }
}
