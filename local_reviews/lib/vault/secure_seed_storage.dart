import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _seedStorageKey = 'vault_seed_v1';

abstract class SeedKeyValueStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class PlatformSeedKeyValueStore implements SeedKeyValueStore {
  PlatformSeedKeyValueStore() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _seedStorageKey);

  @override
  Future<void> write(String value) =>
      _storage.write(key: _seedStorageKey, value: value);

  @override
  Future<void> delete() => _storage.delete(key: _seedStorageKey);
}

/// Thrown on Linux when no Secret Service provider (GNOME Keyring, KWallet,
/// etc.) is reachable. There is no insecure fallback store for this case —
/// see the local-encryption design spec's "Secure seed storage across
/// platforms" section.
class NoSecureKeyringException implements Exception {
  const NoSecureKeyringException(this.cause);
  final Object cause;
}

class SecureStorageException implements Exception {
  const SecureStorageException(this.cause);
  final Object cause;
}

class SecureSeedStorage {
  SecureSeedStorage({SeedKeyValueStore? store, bool Function()? isLinux})
      : _store = store ?? PlatformSeedKeyValueStore(),
        _isLinux = isLinux ?? (() => Platform.isLinux);

  final SeedKeyValueStore _store;
  final bool Function() _isLinux;

  Future<Uint8List?> readSeed() async {
    final encoded = await _guard(() => _store.read());
    if (encoded == null) return null;
    return base64Decode(encoded);
  }

  Future<void> writeSeed(Uint8List seed) {
    return _guard(() => _store.write(base64Encode(seed)));
  }

  Future<void> deleteSeed() => _guard(() => _store.delete());

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      if (_isLinux()) {
        throw NoSecureKeyringException(error);
      }
      throw SecureStorageException(error);
    }
  }
}
