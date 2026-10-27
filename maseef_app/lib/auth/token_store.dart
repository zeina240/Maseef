import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Storage key for the opaque session token. The role and user id are not stored.
const sessionTokenKey = 'maseef.session.token';

abstract class SessionTokenStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}

/// In-memory store used by widget tests. The production entrypoint in main.dart
/// uses [SecureSessionTokenStore].
class MemoryTokenStore implements SessionTokenStore {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async {
    _token = token;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}

/// Platform token storage.
///
/// Android stores the token with AES-GCM, wrapped by a key in the Android
/// Keystore. This needs Android 6 or newer. A rooted device can still extract it.
///
/// iOS and macOS use the Keychain. The item stays on this device
/// (`first_unlock_this_device`) and is not synced through iCloud.
///
/// Windows uses DPAPI for the current Windows user. Any program running as
/// that user can decrypt the token.
///
/// Linux uses the desktop secret service (libsecret). If no keyring is
/// running, saving the token fails and the account screen says sign-in could
/// not be kept.
///
/// Web encrypts the value in browser storage, but the wrapping key also lives
/// in that browser. Any script running on this site can read the token. That
/// is weaker than the mobile keychain. The app does not put the token in a
/// cookie, so other websites cannot attach it to their own requests.
class SecureSessionTokenStore implements SessionTokenStore {
  const SecureSessionTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? _defaultStorage;

  static const _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      preferencesKeyPrefix: 'maseef',
      storageNamespace: 'maseef_auth',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
    webOptions: WebOptions(dbName: 'maseef_auth', publicKey: 'maseef_session'),
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: sessionTokenKey);

  @override
  Future<void> write(String token) {
    return _storage.write(key: sessionTokenKey, value: token);
  }

  @override
  Future<void> clear() => _storage.delete(key: sessionTokenKey);
}
