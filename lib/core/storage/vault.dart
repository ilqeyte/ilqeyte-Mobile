import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores API keys outside of SQLite, in the Android Keystore / iOS Keychain.
/// Keys are never logged, serialized to disk, or sent anywhere except the
/// provider they belong to (over TLS, as a bearer header).
class SecureVault {
  SecureVault();

  static const String _prefix = 'provider_key::';
  static const AndroidOptions _androidOptions =
      AndroidOptions(encryptedSharedPreferences: true);

  final FlutterSecureStorage _storage =
      const FlutterSecureStorage(aOptions: _androidOptions);

  Future<void> write(String providerId, String apiKey) =>
      _storage.write(key: '$_prefix$providerId', value: apiKey);

  Future<String?> read(String providerId) =>
      _storage.read(key: '$_prefix$providerId');

  Future<void> delete(String providerId) =>
      _storage.delete(key: '$_prefix$providerId');
}
