# Local Encryption (Database + Poster Files) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Encrypt the on-device Drift/SQLite database and poster image files using keys derived from a BIP-39 recovery phrase, with the seed held only in Keychain/Keystore, and an onboarding/restore/auto-unlock flow gating app startup.

**Architecture:** A new `lib/vault/` layer generates and validates the BIP-39 mnemonic, derives independent HKDF subkeys for the database and posters, and stores the seed via `flutter_secure_storage`. A `VaultGate` root widget resolves which of three states applies (needs onboarding, needs restore, already unlocked) and only then constructs the encrypted `AppDatabase` (via SQLite3MultipleCiphers) and an encryption-aware `PosterStorageService`, handing off to the existing `LocalReviewsApp`.

**Tech Stack:** Flutter/Dart, `drift` + `sqlite3` (SQLite3MultipleCiphers build hook) for the encrypted database, `bip39` for mnemonic generation/validation, `package:cryptography` for HKDF and AES-256-GCM, `flutter_secure_storage` for Keychain/Keystore/Credential Manager/libsecret access.

**Spec:** `docs/superpowers/specs/2026-09-14-local-encryption-design.md`

## Global Constraints

- Dart SDK stays `^3.12.2`; no new state-management package is introduced — the existing `InheritedWidget`/`StatefulWidget` patterns (`AppRepositories`, and now `VaultGate`) are the only DI/state mechanism.
- SQLite3MultipleCiphers keys are delivered in **raw key mode** (`PRAGMA key = "x'<hex>'"`), never passphrase mode.
- Every derived key comes from HKDF-SHA256 over the BIP-39 seed with a versioned `info` string (`local_reviews/db-key/v1`, `local_reviews/poster-key/v1`) — no key is ever reused across purposes.
- No insecure fallback store is introduced for the Linux "no Secret Service running" case — it surfaces a specific, actionable error instead (see Task 4 and Task 11).
- Target platforms: Android, iOS, Linux, macOS, Windows. Web is explicitly out of scope.
- Treat any pre-existing local database as discardable — there's no `PRAGMA rekey` migration path in this plan (see Task 11's "start fresh" action).

---

## Task 1: MnemonicService

**Files:**
- Modify: `local_reviews/pubspec.yaml` (add `bip39: ^1.0.6`)
- Create: `local_reviews/lib/vault/mnemonic_service.dart`
- Test: `local_reviews/test/vault/mnemonic_service_test.dart`

**Interfaces:**
- Produces: `MnemonicService` with `String generateMnemonic()`, `bool validateMnemonic(String mnemonic)`, `Uint8List mnemonicToSeed(String mnemonic, {String passphrase = ''})`, `List<int> pickConfirmationIndices(int wordCount, {int count = 3, Random? random})`.

- [ ] **Step 1: Add the `bip39` dependency**

Add to `local_reviews/pubspec.yaml` under `dependencies:`:

```yaml
  bip39: ^1.0.6
```

Run: `cd local_reviews && flutter pub get`

- [ ] **Step 2: Write the failing tests**

Create `local_reviews/test/vault/mnemonic_service_test.dart`:

```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/vault/mnemonic_service.dart';

void main() {
  late MnemonicService service;

  setUp(() => service = MnemonicService());

  test('generateMnemonic produces 12 valid words', () {
    final mnemonic = service.generateMnemonic();
    expect(mnemonic.split(' '), hasLength(12));
    expect(service.validateMnemonic(mnemonic), isTrue);
  });

  test('validateMnemonic rejects a tampered phrase', () {
    final mnemonic = service.generateMnemonic();
    final tampered = '${mnemonic.substring(0, mnemonic.length - 1)}x';
    expect(service.validateMnemonic(tampered), isFalse);
  });

  test('mnemonicToSeed matches the official BIP-39 test vector', () {
    const mnemonic = 'abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon abandon abandon about';
    const expectedSeedHex =
        'c55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e53495531f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04';

    final seed = service.mnemonicToSeed(mnemonic, passphrase: 'TREZOR');
    final seedHex =
        seed.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    expect(seedHex, expectedSeedHex);
  });

  test('pickConfirmationIndices returns 3 distinct in-range indices', () {
    final indices = service.pickConfirmationIndices(12, random: Random(1));
    expect(indices.toSet(), hasLength(3));
    expect(indices.every((i) => i >= 0 && i < 12), isTrue);
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `cd local_reviews && flutter test test/vault/mnemonic_service_test.dart`
Expected: FAIL — `package:local_reviews/vault/mnemonic_service.dart` does not exist.

- [ ] **Step 4: Implement `MnemonicService`**

Create `local_reviews/lib/vault/mnemonic_service.dart`:

```dart
import 'dart:math';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;

class MnemonicService {
  String generateMnemonic() => bip39.generateMnemonic(strength: 128);

  bool validateMnemonic(String mnemonic) => bip39.validateMnemonic(mnemonic);

  Uint8List mnemonicToSeed(String mnemonic, {String passphrase = ''}) =>
      bip39.mnemonicToSeed(mnemonic, passphrase: passphrase);

  List<int> pickConfirmationIndices(
    int wordCount, {
    int count = 3,
    Random? random,
  }) {
    final rng = random ?? Random.secure();
    final indices = <int>{};
    while (indices.length < count) {
      indices.add(rng.nextInt(wordCount));
    }
    return indices.toList()..sort();
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd local_reviews && flutter test test/vault/mnemonic_service_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 6: Commit**

```bash
git add local_reviews/pubspec.yaml local_reviews/pubspec.lock local_reviews/lib/vault/mnemonic_service.dart local_reviews/test/vault/mnemonic_service_test.dart
git commit -m "Add MnemonicService wrapping BIP-39 generation/validation/seed derivation"
```

---

## Task 2: SeedKeyDerivation

**Files:**
- Modify: `local_reviews/pubspec.yaml` (add `cryptography: ^2.9.0`)
- Create: `local_reviews/lib/vault/seed_key_derivation.dart`
- Test: `local_reviews/test/vault/seed_key_derivation_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `SeedKeyDerivation` with `Future<Uint8List> deriveDatabaseKey(Uint8List seed)` and `Future<Uint8List> derivePosterKey(Uint8List seed)`, each returning 32 bytes.

- [ ] **Step 1: Add the `cryptography` dependency**

Add to `local_reviews/pubspec.yaml` under `dependencies:`:

```yaml
  cryptography: ^2.9.0
```

Run: `cd local_reviews && flutter pub get`

- [ ] **Step 2: Write the failing tests**

Create `local_reviews/test/vault/seed_key_derivation_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/vault/seed_key_derivation.dart';

void main() {
  late SeedKeyDerivation derivation;
  late Uint8List seed;

  setUp(() {
    derivation = SeedKeyDerivation();
    seed = Uint8List.fromList(List.generate(64, (i) => i));
  });

  test('deriveDatabaseKey is deterministic and 32 bytes', () async {
    final keyA = await derivation.deriveDatabaseKey(seed);
    final keyB = await derivation.deriveDatabaseKey(seed);
    expect(keyA, hasLength(32));
    expect(keyA, keyB);
  });

  test('database and poster keys differ for the same seed', () async {
    final dbKey = await derivation.deriveDatabaseKey(seed);
    final posterKey = await derivation.derivePosterKey(seed);
    expect(dbKey, isNot(posterKey));
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `cd local_reviews && flutter test test/vault/seed_key_derivation_test.dart`
Expected: FAIL — `package:local_reviews/vault/seed_key_derivation.dart` does not exist.

- [ ] **Step 4: Implement `SeedKeyDerivation`**

Create `local_reviews/lib/vault/seed_key_derivation.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class SeedKeyDerivation {
  SeedKeyDerivation() : _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  final Hkdf _hkdf;

  static final List<int> _salt = utf8.encode('local_reviews/vault/v1/salt');

  Future<Uint8List> deriveDatabaseKey(Uint8List seed) =>
      _derive(seed, 'local_reviews/db-key/v1');

  Future<Uint8List> derivePosterKey(Uint8List seed) =>
      _derive(seed, 'local_reviews/poster-key/v1');

  Future<Uint8List> _derive(Uint8List seed, String info) async {
    final key = await _hkdf.deriveKey(
      secretKey: SecretKey(seed),
      nonce: _salt,
      info: utf8.encode(info),
    );
    return Uint8List.fromList(await key.extractBytes());
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd local_reviews && flutter test test/vault/seed_key_derivation_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 6: Commit**

```bash
git add local_reviews/pubspec.yaml local_reviews/pubspec.lock local_reviews/lib/vault/seed_key_derivation.dart local_reviews/test/vault/seed_key_derivation_test.dart
git commit -m "Add SeedKeyDerivation deriving domain-separated HKDF subkeys from the seed"
```

---

## Task 3: PosterCipherService

**Files:**
- Create: `local_reviews/lib/services/poster_cipher_service.dart`
- Test: `local_reviews/test/services/poster_cipher_service_test.dart`

**Interfaces:**
- Consumes: `package:cryptography`'s `SecretKey`, `AesGcm`, `SecretBox` (already a dependency as of Task 2).
- Produces: `PosterCipherService(SecretKey key)` with `Future<Uint8List> encrypt(Uint8List plainBytes)` and `Future<Uint8List> decrypt(Uint8List cipherBytes)`.

- [ ] **Step 1: Write the failing tests**

Create `local_reviews/test/services/poster_cipher_service_test.dart`:

```dart
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/services/poster_cipher_service.dart';

void main() {
  late PosterCipherService cipher;

  setUp(() {
    cipher = PosterCipherService(SecretKey(List.generate(32, (i) => i)));
  });

  test('encrypt then decrypt returns the original bytes', () async {
    final plain = Uint8List.fromList([1, 2, 3, 4, 5]);
    final cipherBytes = await cipher.encrypt(plain);
    final decrypted = await cipher.decrypt(cipherBytes);
    expect(decrypted, plain);
  });

  test('tampering with the ciphertext makes decryption fail', () async {
    final plain = Uint8List.fromList([1, 2, 3, 4, 5]);
    final cipherBytes = await cipher.encrypt(plain);
    cipherBytes[cipherBytes.length - 1] ^= 0xFF;

    expect(cipher.decrypt(cipherBytes), throwsA(anything));
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd local_reviews && flutter test test/services/poster_cipher_service_test.dart`
Expected: FAIL — `package:local_reviews/services/poster_cipher_service.dart` does not exist.

- [ ] **Step 3: Implement `PosterCipherService`**

Create `local_reviews/lib/services/poster_cipher_service.dart`:

```dart
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class PosterCipherService {
  PosterCipherService(this._key) : _algorithm = AesGcm.with256bits();

  final SecretKey _key;
  final AesGcm _algorithm;

  static const _macLength = 16;

  Future<Uint8List> encrypt(Uint8List plainBytes) async {
    final box = await _algorithm.encrypt(plainBytes, secretKey: _key);
    return box.concatenation();
  }

  Future<Uint8List> decrypt(Uint8List cipherBytes) async {
    final box = SecretBox.fromConcatenation(
      cipherBytes,
      nonceLength: _algorithm.nonceLength,
      macLength: _macLength,
    );
    final clear = await _algorithm.decrypt(box, secretKey: _key);
    return Uint8List.fromList(clear);
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd local_reviews && flutter test test/services/poster_cipher_service_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/services/poster_cipher_service.dart local_reviews/test/services/poster_cipher_service_test.dart
git commit -m "Add PosterCipherService for AES-256-GCM poster file encryption"
```

---

## Task 4: SecureSeedStorage

**Files:**
- Modify: `local_reviews/pubspec.yaml` (add `flutter_secure_storage: ^11.1.1`)
- Create: `local_reviews/lib/vault/secure_seed_storage.dart`
- Create: `local_reviews/test/vault/fakes.dart`
- Test: `local_reviews/test/vault/secure_seed_storage_test.dart`

**Interfaces:**
- Produces: `SeedKeyValueStore` (abstract: `read()`/`write(String)`/`delete()`), `PlatformSeedKeyValueStore` (real `flutter_secure_storage`-backed implementation), `NoSecureKeyringException`, `SecureStorageException`, and `SecureSeedStorage` with `Future<Uint8List?> readSeed()`, `Future<void> writeSeed(Uint8List seed)`, `Future<void> deleteSeed()`. Also produces the shared test double `FakeSeedKeyValueStore` in `test/vault/fakes.dart`, reused by Tasks 6, 9, 10, 11.

- [ ] **Step 1: Add the `flutter_secure_storage` dependency**

Add to `local_reviews/pubspec.yaml` under `dependencies:`:

```yaml
  flutter_secure_storage: ^11.1.1
```

Run: `cd local_reviews && flutter pub get`

- [ ] **Step 2: Write the shared test fake**

Create `local_reviews/test/vault/fakes.dart`:

```dart
import 'package:local_reviews/vault/secure_seed_storage.dart';

class FakeSeedKeyValueStore implements SeedKeyValueStore {
  FakeSeedKeyValueStore({this.failWith});

  final Object? failWith;
  String? value;

  @override
  Future<String?> read() async {
    if (failWith != null) throw failWith!;
    return value;
  }

  @override
  Future<void> write(String newValue) async {
    if (failWith != null) throw failWith!;
    value = newValue;
  }

  @override
  Future<void> delete() async {
    if (failWith != null) throw failWith!;
    value = null;
  }
}
```

- [ ] **Step 3: Write the failing tests**

Create `local_reviews/test/vault/secure_seed_storage_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/vault/secure_seed_storage.dart';

import 'fakes.dart';

void main() {
  test('round-trips a seed through the underlying store', () async {
    final storage = SecureSeedStorage(store: FakeSeedKeyValueStore());
    final seed = Uint8List.fromList(List.generate(64, (i) => i));

    await storage.writeSeed(seed);
    final readBack = await storage.readSeed();

    expect(readBack, seed);
  });

  test('returns null when nothing has been written', () async {
    final storage = SecureSeedStorage(store: FakeSeedKeyValueStore());
    expect(await storage.readSeed(), isNull);
  });

  test('maps a store failure to NoSecureKeyringException on Linux', () async {
    final storage = SecureSeedStorage(
      store: FakeSeedKeyValueStore(failWith: Exception('no secret service')),
      isLinux: () => true,
    );

    expect(storage.readSeed(), throwsA(isA<NoSecureKeyringException>()));
  });

  test('maps a store failure to SecureStorageException off Linux', () async {
    final storage = SecureSeedStorage(
      store: FakeSeedKeyValueStore(failWith: Exception('keychain denied')),
      isLinux: () => false,
    );

    expect(storage.readSeed(), throwsA(isA<SecureStorageException>()));
  });
}
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `cd local_reviews && flutter test test/vault/secure_seed_storage_test.dart`
Expected: FAIL — `package:local_reviews/vault/secure_seed_storage.dart` does not exist.

- [ ] **Step 5: Implement `SecureSeedStorage`**

Create `local_reviews/lib/vault/secure_seed_storage.dart`:

```dart
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
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd local_reviews && flutter test test/vault/secure_seed_storage_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 7: Commit**

```bash
git add local_reviews/pubspec.yaml local_reviews/pubspec.lock local_reviews/lib/vault/secure_seed_storage.dart local_reviews/test/vault/fakes.dart local_reviews/test/vault/secure_seed_storage_test.dart
git commit -m "Add SecureSeedStorage wrapping Keychain/Keystore with Linux keyring error mapping"
```

---

## Task 5: Database encryption helpers

**Files:**
- Modify: `local_reviews/pubspec.yaml` (add `hooks.user_defines.sqlite3.source: sqlite3mc`; bump `drift` and `drift_dev` to `^2.35.0`)
- Modify: `local_reviews/lib/data/database.dart` (add `resolveDatabaseFile()` and `openEncryptedExecutor()`; existing `AppDatabase` constructor and `_openConnection()` are untouched in this task)
- Modify: `local_reviews/test/data/database_test.dart` (add one new test)

**Interfaces:**
- Produces: `Future<File> resolveDatabaseFile()` and `QueryExecutor openEncryptedExecutor({required File file, required Uint8List key})`, both top-level in `lib/data/database.dart`.

- [ ] **Step 1: Update `pubspec.yaml`**

Bump the existing `drift` and `drift_dev` lines under `dependencies:`/`dev_dependencies:` to:

```yaml
  drift: ^2.35.0
```
```yaml
  drift_dev: ^2.35.0
```

Add a new **root-level** key (a sibling of `dependencies:`, `dev_dependencies:`, `flutter:` — not nested inside any of them):

```yaml
hooks:
  user_defines:
    sqlite3:
      source: sqlite3mc
```

Run: `cd local_reviews && flutter pub get`

- [ ] **Step 2: Write the failing test**

In `local_reviews/test/data/database_test.dart`, add these imports alongside the existing ones:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
```

Add this test inside `main()`, after the existing tests:

```dart
  test('opens an encrypted database file and rejects the wrong key', () async {
    final tempDir = Directory.systemTemp.createTempSync('db_encryption_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final dbFile = File(p.join(tempDir.path, 'test.sqlite'));
    final keyA = Uint8List.fromList(List.generate(32, (i) => i));
    final keyB = Uint8List.fromList(List.generate(32, (i) => 255 - i));

    final dbA = AppDatabase(openEncryptedExecutor(file: dbFile, key: keyA));
    await dbA
        .into(dbA.films)
        .insert(FilmsCompanion.insert(title: 'Paprika', year: 2006));
    await dbA.close();

    final dbAReopened =
        AppDatabase(openEncryptedExecutor(file: dbFile, key: keyA));
    final films = await dbAReopened.select(dbAReopened.films).get();
    expect(films.map((f) => f.title), contains('Paprika'));
    await dbAReopened.close();

    final dbWrongKey =
        AppDatabase(openEncryptedExecutor(file: dbFile, key: keyB));
    await expectLater(
      dbWrongKey.select(dbWrongKey.films).get(),
      throwsA(anything),
    );
    await dbWrongKey.close();
  });
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd local_reviews && flutter test test/data/database_test.dart`
Expected: FAIL — `openEncryptedExecutor` is not defined.

- [ ] **Step 4: Implement the helpers**

In `local_reviews/lib/data/database.dart`, add these imports at the top, alongside the existing ones:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
```

Add these two top-level functions (e.g. after the `seedGenreNames` constant, before the `AppDatabase` class):

```dart
Future<File> resolveDatabaseFile() async {
  final dir = await getApplicationSupportDirectory();
  return File(p.join(dir.path, 'local_reviews.sqlite'));
}

QueryExecutor openEncryptedExecutor({required File file, required Uint8List key}) {
  final keyHex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return NativeDatabase.createInBackground(
    file,
    setup: (rawDb) {
      rawDb.execute("PRAGMA key = \"x'$keyHex'\";");
      assert(rawDb.select('PRAGMA cipher;').isNotEmpty);
    },
  );
}
```

Do **not** touch `AppDatabase`'s constructor, `_openConnection()`, or the `drift_flutter` import yet — that happens in Task 11, once `VaultGate` exists to replace the only remaining caller of the unencrypted default connection.

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd local_reviews && flutter test test/data/database_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 6: Run the full test suite to confirm nothing else broke**

Run: `cd local_reviews && flutter test`
Expected: PASS (all existing tests still pass — this task was additive only)

- [ ] **Step 7: Commit**

```bash
git add local_reviews/pubspec.yaml local_reviews/pubspec.lock local_reviews/lib/data/database.dart local_reviews/test/data/database_test.dart
git commit -m "Add SQLite3MultipleCiphers-backed encrypted executor for the Drift database"
```

---

## Task 6: VaultService

**Files:**
- Modify: `local_reviews/pubspec.yaml` (add `sqlite3: ^3.6.0`)
- Create: `local_reviews/lib/vault/vault_state.dart`
- Create: `local_reviews/lib/vault/vault_service.dart`
- Test: `local_reviews/test/vault/vault_service_test.dart`

**Interfaces:**
- Consumes: `MnemonicService` (Task 1), `SeedKeyDerivation` (Task 2), `SecureSeedStorage`/`SeedKeyValueStore` (Task 4), `resolveDatabaseFile()`/`openEncryptedExecutor()` (Task 5), `FakeSeedKeyValueStore` (Task 4, test-only).
- Produces: `sealed class VaultState` with `VaultNeedsOnboarding`, `VaultNeedsRestore`, `VaultUnlocked(dbKey, posterKey)`; `WrongRecoveryPhraseException`; `VaultService` with `Future<VaultState> resolveInitialState()`, `String generateMnemonic()`, `List<int> pickConfirmationIndices(int wordCount)`, `Future<VaultUnlocked> completeOnboarding(String mnemonic)`, `Future<VaultUnlocked> restoreVault(String phrase)`, `Future<void> startFresh()`. These are consumed by Tasks 9, 10, 11.

- [ ] **Step 1: Add the `sqlite3` dependency**

Add to `local_reviews/pubspec.yaml` under `dependencies:`:

```yaml
  sqlite3: ^3.6.0
```

Run: `cd local_reviews && flutter pub get`

- [ ] **Step 2: Define `VaultState`**

Create `local_reviews/lib/vault/vault_state.dart`:

```dart
import 'dart:typed_data';

sealed class VaultState {
  const VaultState();
}

class VaultNeedsOnboarding extends VaultState {
  const VaultNeedsOnboarding();
}

class VaultNeedsRestore extends VaultState {
  const VaultNeedsRestore();
}

class VaultUnlocked extends VaultState {
  const VaultUnlocked({required this.dbKey, required this.posterKey});

  final Uint8List dbKey;
  final Uint8List posterKey;
}
```

- [ ] **Step 3: Write the failing tests**

Create `local_reviews/test/vault/vault_service_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/vault/secure_seed_storage.dart';
import 'package:local_reviews/vault/vault_service.dart';
import 'package:local_reviews/vault/vault_state.dart';
import 'package:path/path.dart' as p;

import 'fakes.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('vault_service_test');
    dbFile = File(p.join(tempDir.path, 'test.sqlite'));
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  VaultService buildService({FakeSeedKeyValueStore? store}) {
    return VaultService(
      secureSeedStorage:
          SecureSeedStorage(store: store ?? FakeSeedKeyValueStore()),
      databaseFileResolver: () async => dbFile,
      documentsDirectory: () async => tempDir,
    );
  }

  test('resolveInitialState returns NeedsOnboarding when nothing exists',
      () async {
    final service = buildService();
    expect(await service.resolveInitialState(), isA<VaultNeedsOnboarding>());
  });

  test(
      'resolveInitialState returns NeedsRestore when a db file exists but no seed',
      () async {
    dbFile.writeAsBytesSync([0]);
    final service = buildService();
    expect(await service.resolveInitialState(), isA<VaultNeedsRestore>());
  });

  test('resolveInitialState returns Unlocked when a seed is already stored',
      () async {
    final store = FakeSeedKeyValueStore();
    final onboarding = buildService(store: store);
    final mnemonic = onboarding.generateMnemonic();
    await onboarding.completeOnboarding(mnemonic);

    final relaunch = buildService(store: store);
    expect(await relaunch.resolveInitialState(), isA<VaultUnlocked>());
  });

  test('restoreVault succeeds with the phrase that created the database',
      () async {
    final creator = buildService();
    final mnemonic = creator.generateMnemonic();
    final created = await creator.completeOnboarding(mnemonic);
    final creatorDb =
        AppDatabase(openEncryptedExecutor(file: dbFile, key: created.dbKey));
    await creatorDb.close();

    final restorer = buildService();
    final unlocked = await restorer.restoreVault(mnemonic);
    expect(unlocked.dbKey, created.dbKey);
  });

  test('restoreVault rejects a phrase that does not match the database',
      () async {
    final creator = buildService();
    final mnemonic = creator.generateMnemonic();
    final created = await creator.completeOnboarding(mnemonic);
    final creatorDb =
        AppDatabase(openEncryptedExecutor(file: dbFile, key: created.dbKey));
    await creatorDb.close();

    final restorer = buildService();
    final otherMnemonic = restorer.generateMnemonic();

    expect(
      () => restorer.restoreVault(otherMnemonic),
      throwsA(isA<WrongRecoveryPhraseException>()),
    );
  });

  test('startFresh deletes the database file and posters directory',
      () async {
    dbFile.writeAsBytesSync([0]);
    final postersDir = Directory(p.join(tempDir.path, 'posters'))
      ..createSync();
    File(p.join(postersDir.path, 'poster.enc')).writeAsBytesSync([1]);

    final service = buildService();
    await service.startFresh();

    expect(dbFile.existsSync(), isFalse);
    expect(postersDir.existsSync(), isFalse);
  });
}
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `cd local_reviews && flutter test test/vault/vault_service_test.dart`
Expected: FAIL — `package:local_reviews/vault/vault_service.dart` does not exist.

- [ ] **Step 5: Implement `VaultService`**

Create `local_reviews/lib/vault/vault_service.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../data/database.dart';
import 'mnemonic_service.dart';
import 'secure_seed_storage.dart';
import 'seed_key_derivation.dart';
import 'vault_state.dart';

class WrongRecoveryPhraseException implements Exception {
  const WrongRecoveryPhraseException();
}

class VaultService {
  VaultService({
    MnemonicService? mnemonicService,
    SeedKeyDerivation? keyDerivation,
    SecureSeedStorage? secureSeedStorage,
    Future<File> Function()? databaseFileResolver,
    Future<Directory> Function()? documentsDirectory,
  })  : _mnemonicService = mnemonicService ?? MnemonicService(),
        _keyDerivation = keyDerivation ?? SeedKeyDerivation(),
        _secureSeedStorage = secureSeedStorage ?? SecureSeedStorage(),
        _databaseFileResolver = databaseFileResolver ?? resolveDatabaseFile,
        _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  final MnemonicService _mnemonicService;
  final SeedKeyDerivation _keyDerivation;
  final SecureSeedStorage _secureSeedStorage;
  final Future<File> Function() _databaseFileResolver;
  final Future<Directory> Function() _documentsDirectory;

  Future<VaultState> resolveInitialState() async {
    final seed = await _secureSeedStorage.readSeed();
    if (seed != null) {
      return _unlockedFrom(seed);
    }
    final dbFile = await _databaseFileResolver();
    if (await dbFile.exists()) {
      return const VaultNeedsRestore();
    }
    return const VaultNeedsOnboarding();
  }

  String generateMnemonic() => _mnemonicService.generateMnemonic();

  List<int> pickConfirmationIndices(int wordCount) =>
      _mnemonicService.pickConfirmationIndices(wordCount);

  Future<VaultUnlocked> completeOnboarding(String mnemonic) async {
    final seed = _mnemonicService.mnemonicToSeed(mnemonic);
    await _secureSeedStorage.writeSeed(seed);
    return _unlockedFrom(seed);
  }

  Future<VaultUnlocked> restoreVault(String phrase) async {
    if (!_mnemonicService.validateMnemonic(phrase)) {
      throw const WrongRecoveryPhraseException();
    }
    final seed = _mnemonicService.mnemonicToSeed(phrase);
    final dbKey = await _keyDerivation.deriveDatabaseKey(seed);
    final dbFile = await _databaseFileResolver();
    if (!await _canOpenWithKey(dbFile, dbKey)) {
      throw const WrongRecoveryPhraseException();
    }
    await _secureSeedStorage.writeSeed(seed);
    return _unlockedFrom(seed);
  }

  Future<void> startFresh() async {
    final dbFile = await _databaseFileResolver();
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
    final documentsDir = await _documentsDirectory();
    final postersDir = Directory(p.join(documentsDir.path, 'posters'));
    if (await postersDir.exists()) {
      await postersDir.delete(recursive: true);
    }
  }

  Future<VaultUnlocked> _unlockedFrom(Uint8List seed) async {
    final dbKey = await _keyDerivation.deriveDatabaseKey(seed);
    final posterKey = await _keyDerivation.derivePosterKey(seed);
    return VaultUnlocked(dbKey: dbKey, posterKey: posterKey);
  }

  Future<bool> _canOpenWithKey(File dbFile, Uint8List key) async {
    final keyHex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final db = sqlite3.open(dbFile.path);
    try {
      db.execute("PRAGMA key = \"x'$keyHex'\";");
      db.select('SELECT count(*) FROM sqlite_master');
      return true;
    } on SqliteException {
      return false;
    } finally {
      db.dispose();
    }
  }
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd local_reviews && flutter test test/vault/vault_service_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 7: Commit**

```bash
git add local_reviews/pubspec.yaml local_reviews/pubspec.lock local_reviews/lib/vault/vault_state.dart local_reviews/lib/vault/vault_service.dart local_reviews/test/vault/vault_service_test.dart
git commit -m "Add VaultService resolving onboarding/restore/unlocked state"
```

---

## Task 7: PosterStorageService encryption integration

**Files:**
- Modify: `local_reviews/lib/services/poster_storage_service.dart`
- Modify: `local_reviews/lib/data/repositories/film_repository.dart`
- Modify: `local_reviews/lib/app_repositories.dart`
- Modify: `local_reviews/test/services/poster_storage_service_test.dart`
- Modify: `local_reviews/test/data/film_repository_test.dart`
- Modify: `local_reviews/test/app_repositories_test.dart`

**Interfaces:**
- Consumes: `PosterCipherService` (Task 3).
- Produces: `PosterStorageService({required PosterCipherService cipherService, Future<Directory> Function()? documentsDirectory})` with `Future<String> savePoster(File sourceFile)`, `Future<Uint8List> loadDecrypted(String posterPath)`, `Future<void> deletePoster(String posterPath)`. `FilmRepository`'s `posterStorageService` parameter becomes required (was optional). `AppRepositories({required AppDatabase database, required PosterStorageService posterStorageService, required Widget child})` — `posterStorageService` becomes required too (was optional with a silent default that no longer compiles once `PosterStorageService` requires a cipher). Consumed by Task 8 and Task 11.

**Note on ordering:** `AppRepositories`'s current factory has a fallback `posterStorageService ?? PosterStorageService()`. The moment `PosterStorageService`'s `cipherService` becomes required (this task's first half), that fallback stops compiling — so the `AppRepositories` fix (this task's second half) must land in the *same* task, not a later one, or every other test in the suite breaks in between (`app_repositories.dart` is on the import path of nearly everything).

- [ ] **Step 1: Write the failing tests for `PosterStorageService`**

Replace the contents of `local_reviews/test/services/poster_storage_service_test.dart`:

```dart
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/services/poster_cipher_service.dart';
import 'package:local_reviews/services/poster_storage_service.dart';
import 'package:path/path.dart' as p;

PosterCipherService _testCipherService() =>
    PosterCipherService(SecretKey(List.generate(32, (i) => i)));

void main() {
  late Directory tempDir;
  late PosterStorageService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('poster_storage_test');
    service = PosterStorageService(
      documentsDirectory: () async => tempDir,
      cipherService: _testCipherService(),
    );
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  test('savePoster writes an encrypted file into a posters subdirectory',
      () async {
    final source = File(p.join(tempDir.path, 'source.jpg'))
      ..writeAsBytesSync([1, 2, 3]);

    final savedPath = await service.savePoster(source);

    expect(savedPath, contains('${p.separator}posters${p.separator}'));
    expect(await File(savedPath).readAsBytes(), isNot([1, 2, 3]));
    expect(await service.loadDecrypted(savedPath), [1, 2, 3]);
  });

  test('two saved posters get different paths', () async {
    final source = File(p.join(tempDir.path, 'source.jpg'))
      ..writeAsBytesSync([1]);

    final firstPath = await service.savePoster(source);
    final secondPath = await service.savePoster(source);

    expect(firstPath, isNot(secondPath));
  });

  test('deletePoster removes the file', () async {
    final source = File(p.join(tempDir.path, 'source.jpg'))
      ..writeAsBytesSync([1]);
    final savedPath = await service.savePoster(source);

    await service.deletePoster(savedPath);

    expect(File(savedPath).existsSync(), isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd local_reviews && flutter test test/services/poster_storage_service_test.dart`
Expected: FAIL — `PosterStorageService` has no `cipherService` parameter / no `loadDecrypted` method.

- [ ] **Step 3: Update `PosterStorageService`**

Replace the contents of `local_reviews/lib/services/poster_storage_service.dart`:

```dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'poster_cipher_service.dart';

class PosterStorageService {
  PosterStorageService({
    required PosterCipherService cipherService,
    Future<Directory> Function()? documentsDirectory,
  })  : _cipherService = cipherService,
        _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  final PosterCipherService _cipherService;
  final Future<Directory> Function() _documentsDirectory;

  Future<String> savePoster(File sourceFile) async {
    final documentsDir = await _documentsDirectory();
    final postersDir = Directory(p.join(documentsDir.path, 'posters'));
    if (!await postersDir.exists()) {
      await postersDir.create(recursive: true);
    }
    final destinationPath = p.join(postersDir.path, '${_uniqueFileName()}.enc');
    final plainBytes = await sourceFile.readAsBytes();
    final cipherBytes = await _cipherService.encrypt(plainBytes);
    await File(destinationPath).writeAsBytes(cipherBytes);
    return destinationPath;
  }

  Future<Uint8List> loadDecrypted(String posterPath) async {
    final cipherBytes = await File(posterPath).readAsBytes();
    return _cipherService.decrypt(cipherBytes);
  }

  Future<void> deletePoster(String posterPath) async {
    final file = File(posterPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _uniqueFileName() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomSuffix = Random().nextInt(1 << 32);
    return '$timestamp-$randomSuffix';
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd local_reviews && flutter test test/services/poster_storage_service_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Update `FilmRepository` to require a `PosterStorageService`**

In `local_reviews/lib/data/repositories/film_repository.dart`, change:

```dart
  FilmRepository(this._db, {PosterStorageService? posterStorageService})
    : _posterStorageService = posterStorageService ?? PosterStorageService();
```

to:

```dart
  FilmRepository(this._db, {required PosterStorageService posterStorageService})
    : _posterStorageService = posterStorageService;
```

- [ ] **Step 6: Update `film_repository_test.dart`'s default repository setup**

In `local_reviews/test/data/film_repository_test.dart`, add these imports alongside the existing ones:

```dart
import 'package:cryptography/cryptography.dart';
import 'package:local_reviews/services/poster_cipher_service.dart';
```

Change the `setUp`:

```dart
  setUp(() {
    database = openTestDatabase();
    repository = FilmRepository(
      database,
      posterStorageService: PosterStorageService(
        cipherService: PosterCipherService(SecretKey(List.generate(32, (i) => i))),
      ),
    );
  });
```

The other test in this file (`'deleteFilm also deletes its poster file from disk'`) already constructs its own `PosterStorageService(documentsDirectory: ...)` explicitly — add `cipherService: PosterCipherService(SecretKey(List.generate(32, (i) => i)))` to that constructor call too.

- [ ] **Step 7: Update `app_repositories_test.dart`**

In `local_reviews/test/app_repositories_test.dart`, add these imports alongside the existing ones:

```dart
import 'package:cryptography/cryptography.dart';
import 'package:local_reviews/services/poster_cipher_service.dart';
import 'package:local_reviews/services/poster_storage_service.dart';
```

Update the test body to pass `posterStorageService` explicitly:

```dart
void main() {
  testWidgets('AppRepositories.of exposes the repositories to descendants',
      (tester) async {
    final database = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(database.close);
    final posterStorageService = PosterStorageService(
      cipherService: PosterCipherService(SecretKey(List.generate(32, (i) => i))),
    );

    late BuildContext capturedContext;
    await tester.pumpWidget(
      AppRepositories(
        database: database,
        posterStorageService: posterStorageService,
        child: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final repos = AppRepositories.of(capturedContext);
    expect(repos.database, database);
    expect(repos.filmRepository, isNotNull);
    expect(repos.reviewRepository, isNotNull);
    expect(repos.posterStorageService, posterStorageService);
  });
}
```

- [ ] **Step 8: Run `app_repositories_test.dart` to verify it fails**

Run: `cd local_reviews && flutter test test/app_repositories_test.dart`
Expected: FAIL — `AppRepositories`'s `posterStorageService` is still optional, and its internal fallback (`posterStorageService ?? PosterStorageService()`) no longer compiles now that `PosterStorageService` requires a `cipherService`.

- [ ] **Step 9: Update `AppRepositories`**

In `local_reviews/lib/app_repositories.dart`, change the factory:

```dart
  factory AppRepositories({
    Key? key,
    required AppDatabase database,
    required Widget child,
    PosterStorageService? posterStorageService,
  }) {
    final resolvedPosterStorageService =
        posterStorageService ?? PosterStorageService();
    return AppRepositories._(
      key: key,
      database: database,
      posterStorageService: resolvedPosterStorageService,
      filmRepository: FilmRepository(
        database,
        posterStorageService: resolvedPosterStorageService,
      ),
      reviewRepository: ReviewRepository(database),
      child: child,
    );
  }
```

to:

```dart
  factory AppRepositories({
    Key? key,
    required AppDatabase database,
    required PosterStorageService posterStorageService,
    required Widget child,
  }) {
    return AppRepositories._(
      key: key,
      database: database,
      posterStorageService: posterStorageService,
      filmRepository: FilmRepository(
        database,
        posterStorageService: posterStorageService,
      ),
      reviewRepository: ReviewRepository(database),
      child: child,
    );
  }
```

- [ ] **Step 10: Run `app_repositories_test.dart` to verify it passes**

Run: `cd local_reviews && flutter test test/app_repositories_test.dart`
Expected: PASS

- [ ] **Step 11: Run the full test suite**

Run: `cd local_reviews && flutter test`
Expected: PASS (all tests, including `film_repository_test.dart`, `poster_storage_service_test.dart`, and `app_repositories_test.dart`)

- [ ] **Step 12: Commit**

```bash
git add local_reviews/lib/services/poster_storage_service.dart local_reviews/lib/data/repositories/film_repository.dart local_reviews/lib/app_repositories.dart local_reviews/test/services/poster_storage_service_test.dart local_reviews/test/data/film_repository_test.dart local_reviews/test/app_repositories_test.dart
git commit -m "Encrypt poster files at rest and require an explicit PosterStorageService throughout"
```

---

## Task 8: PosterThumbnail async decryption

**Files:**
- Modify: `local_reviews/lib/widgets/poster_thumbnail.dart`
- Modify: `local_reviews/test/widgets/poster_thumbnail_test.dart`

**Interfaces:**
- Consumes: `AppRepositories.of(context).posterStorageService` (the `AppRepositories` API from Task 7, where `posterStorageService` became a required constructor parameter).

- [ ] **Step 1: Write the failing test**

Replace the contents of `local_reviews/test/widgets/poster_thumbnail_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/app_repositories.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/services/poster_cipher_service.dart';
import 'package:local_reviews/services/poster_storage_service.dart';
import 'package:local_reviews/widgets/poster_thumbnail.dart';
import 'package:path/path.dart' as p;

// A minimal valid 1x1 transparent PNG, used so Image.memory can decode it.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);

void main() {
  testWidgets('shows a placeholder icon when posterPath is null',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PosterThumbnail()));
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
  });

  testWidgets('shows a placeholder icon when the file does not exist',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PosterThumbnail(posterPath: '/nonexistent/path/poster.jpg'),
    ));
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
  });

  testWidgets('shows the decrypted image once the poster loads',
      (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('poster_thumbnail_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final posterStorageService = PosterStorageService(
      documentsDirectory: () async => tempDir,
      cipherService: PosterCipherService(SecretKey(List.generate(32, (i) => i))),
    );
    final sourceFile = File(p.join(tempDir.path, 'source.png'))
      ..writeAsBytesSync(_onePixelPng);
    final posterPath = await posterStorageService.savePoster(sourceFile);

    final database = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(database.close);

    await tester.pumpWidget(
      AppRepositories(
        database: database,
        posterStorageService: posterStorageService,
        child: MaterialApp(home: PosterThumbnail(posterPath: posterPath)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.movie_outlined), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd local_reviews && flutter test test/widgets/poster_thumbnail_test.dart`
Expected: FAIL — `AppRepositories` does not yet accept a required `posterStorageService`, and `PosterThumbnail` doesn't render an `Image` for a valid path yet.

`AppRepositories` already requires `posterStorageService` as of Task 7, so this call compiles — the remaining failure is that `PosterThumbnail` doesn't yet render the decrypted image. Proceed to Step 3.

- [ ] **Step 3: Update `PosterThumbnail`**

Replace the contents of `local_reviews/lib/widgets/poster_thumbnail.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_repositories.dart';

class PosterThumbnail extends StatelessWidget {
  const PosterThumbnail({super.key, this.posterPath, this.size = 56});

  final String? posterPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = posterPath;
    if (path == null || !File(path).existsSync()) {
      return _placeholder(context);
    }
    final posterStorageService = AppRepositories.of(context).posterStorageService;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: FutureBuilder<Uint8List>(
        future: posterStorageService.loadDecrypted(path),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _placeholder(context);
          }
          return Image.memory(
            snapshot.data!,
            width: size,
            height: size * 1.5,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _placeholder(context),
          );
        },
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: size,
      height: size * 1.5,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.movie_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd local_reviews && flutter test test/widgets/poster_thumbnail_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/widgets/poster_thumbnail.dart local_reviews/test/widgets/poster_thumbnail_test.dart
git commit -m "Decrypt poster thumbnails asynchronously via PosterStorageService"
```

---

## Task 9: OnboardingScreen

**Files:**
- Create: `local_reviews/lib/screens/vault/onboarding_screen.dart`
- Test: `local_reviews/test/screens/onboarding_screen_test.dart`

**Interfaces:**
- Consumes: `VaultService` (Task 6: `generateMnemonic()`, `pickConfirmationIndices(int)`, `completeOnboarding(String)`), `FakeSeedKeyValueStore`/`SecureSeedStorage` (Task 4, test-only).
- Produces: `OnboardingScreen({required VaultService vaultService, required ValueChanged<VaultUnlocked> onUnlocked})`. Consumed by Task 11.

- [ ] **Step 1: Write the failing tests**

Create `local_reviews/test/screens/onboarding_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/screens/vault/onboarding_screen.dart';
import 'package:local_reviews/vault/secure_seed_storage.dart';
import 'package:local_reviews/vault/vault_service.dart';
import 'package:local_reviews/vault/vault_state.dart';

import '../vault/fakes.dart';

void main() {
  testWidgets('completes onboarding once the confirmation words match',
      (tester) async {
    final service = VaultService(
      secureSeedStorage: SecureSeedStorage(store: FakeSeedKeyValueStore()),
    );
    VaultUnlocked? unlocked;

    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(
        vaultService: service,
        onUnlocked: (result) => unlocked = result,
      ),
    ));

    final chipTexts = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(Chip),
          matching: find.byType(Text),
        ))
        .map((t) => t.data!)
        .toList();
    final words = {
      for (final entry in chipTexts)
        int.parse(entry.split('.').first) - 1: entry.split(' ').last,
    };

    await tester.tap(find.text("I've written it down"));
    await tester.pumpAndSettle();

    for (final element in find.byType(TextField).evaluate()) {
      final key = element.widget.key as ValueKey<String>;
      final index = int.parse(key.value.split('-').last);
      await tester.enterText(find.byKey(key), words[index]!);
    }
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(unlocked, isNotNull);
  });

  testWidgets('shows an error and does not unlock on a wrong confirmation word',
      (tester) async {
    final service = VaultService(
      secureSeedStorage: SecureSeedStorage(store: FakeSeedKeyValueStore()),
    );
    var unlockedCalls = 0;

    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(
        vaultService: service,
        onUnlocked: (_) => unlockedCalls++,
      ),
    ));

    await tester.tap(find.text("I've written it down"));
    await tester.pumpAndSettle();

    for (final element in find.byType(TextField).evaluate()) {
      await tester.enterText(find.byWidget(element.widget), 'wrongword');
    }
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(unlockedCalls, 0);
    expect(find.textContaining("doesn't match"), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd local_reviews && flutter test test/screens/onboarding_screen_test.dart`
Expected: FAIL — `package:local_reviews/screens/vault/onboarding_screen.dart` does not exist.

- [ ] **Step 3: Implement `OnboardingScreen`**

Create `local_reviews/lib/screens/vault/onboarding_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../vault/vault_service.dart';
import '../../vault/vault_state.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.vaultService,
    required this.onUnlocked,
  });

  final VaultService vaultService;
  final ValueChanged<VaultUnlocked> onUnlocked;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { showPhrase, confirmWords }

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final String _mnemonic = widget.vaultService.generateMnemonic();
  late final List<String> _words = _mnemonic.split(' ');
  late final List<int> _confirmIndices =
      widget.vaultService.pickConfirmationIndices(_words.length);
  final Map<int, TextEditingController> _controllers = {};
  _Step _step = _Step.showPhrase;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final index in _confirmIndices) {
      _controllers[index] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _checkWords() {
    for (final index in _confirmIndices) {
      final input = _controllers[index]!.text.trim().toLowerCase();
      if (input != _words[index]) {
        setState(() {
          _error =
              "That doesn't match your recovery phrase. Check word ${index + 1} and try again.";
        });
        return;
      }
    }
    _complete();
  }

  Future<void> _complete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final unlocked = await widget.vaultService.completeOnboarding(_mnemonic);
    widget.onUnlocked(unlocked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up local encryption')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _step == _Step.showPhrase
            ? _buildShowPhrase()
            : _buildConfirmWords(context),
      ),
    );
  }

  Widget _buildShowPhrase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Write down these 12 words in order and keep them somewhere safe. '
          "They're the only way to recover your data if you lose this device.",
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _words.length; i++)
              Chip(label: Text('${i + 1}. ${_words[i]}')),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => _step = _Step.confirmWords),
          child: const Text("I've written it down"),
        ),
      ],
    );
  }

  Widget _buildConfirmWords(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Confirm your recovery phrase by typing the requested words.'),
        const SizedBox(height: 16),
        for (final index in _confirmIndices)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              key: Key('confirm-word-$index'),
              controller: _controllers[index],
              decoration: InputDecoration(labelText: 'Word #${index + 1}'),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton(
          onPressed: _busy ? null : _checkWords,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd local_reviews && flutter test test/screens/onboarding_screen_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/screens/vault/onboarding_screen.dart local_reviews/test/screens/onboarding_screen_test.dart
git commit -m "Add OnboardingScreen: generate, display, and confirm the recovery phrase"
```

---

## Task 10: RestoreScreen

**Files:**
- Create: `local_reviews/lib/screens/vault/restore_screen.dart`
- Test: `local_reviews/test/screens/restore_screen_test.dart`

**Interfaces:**
- Consumes: `VaultService` (Task 6: `generateMnemonic()`, `completeOnboarding(String)`, `restoreVault(String)`, `startFresh()`, `WrongRecoveryPhraseException`), `openEncryptedExecutor()`/`AppDatabase` (Task 5, test-only), `FakeSeedKeyValueStore`/`SecureSeedStorage` (Task 4, test-only).
- Produces: `RestoreScreen({required VaultService vaultService, required ValueChanged<VaultUnlocked> onUnlocked, required VoidCallback onStartFresh})`. Consumed by Task 11.

- [ ] **Step 1: Write the failing tests**

Create `local_reviews/test/screens/restore_screen_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/screens/vault/restore_screen.dart';
import 'package:local_reviews/vault/secure_seed_storage.dart';
import 'package:local_reviews/vault/vault_service.dart';
import 'package:local_reviews/vault/vault_state.dart';
import 'package:path/path.dart' as p;

import '../vault/fakes.dart';

void main() {
  testWidgets('unlocks with the phrase that created the database',
      (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('restore_screen_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final dbFile = File(p.join(tempDir.path, 'test.sqlite'));

    final creator = VaultService(
      secureSeedStorage: SecureSeedStorage(store: FakeSeedKeyValueStore()),
      databaseFileResolver: () async => dbFile,
      documentsDirectory: () async => tempDir,
    );
    final mnemonic = creator.generateMnemonic();
    final created = await creator.completeOnboarding(mnemonic);
    final creatorDb =
        AppDatabase(openEncryptedExecutor(file: dbFile, key: created.dbKey));
    await creatorDb.close();

    final restoringService = VaultService(
      secureSeedStorage: SecureSeedStorage(store: FakeSeedKeyValueStore()),
      databaseFileResolver: () async => dbFile,
      documentsDirectory: () async => tempDir,
    );
    VaultUnlocked? unlocked;

    await tester.pumpWidget(MaterialApp(
      home: RestoreScreen(
        vaultService: restoringService,
        onUnlocked: (result) => unlocked = result,
        onStartFresh: () {},
      ),
    ));

    await tester.enterText(
      find.byKey(const Key('recovery-phrase-field')),
      mnemonic,
    );
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(unlocked, isNotNull);
    expect(unlocked!.dbKey, created.dbKey);
  });

  testWidgets('shows an error for a phrase that does not match',
      (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('restore_screen_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final dbFile = File(p.join(tempDir.path, 'test.sqlite'))
      ..writeAsBytesSync([0]);

    final service = VaultService(
      secureSeedStorage: SecureSeedStorage(store: FakeSeedKeyValueStore()),
      databaseFileResolver: () async => dbFile,
      documentsDirectory: () async => tempDir,
    );

    await tester.pumpWidget(MaterialApp(
      home: RestoreScreen(
        vaultService: service,
        onUnlocked: (_) {},
        onStartFresh: () {},
      ),
    ));

    await tester.enterText(
      find.byKey(const Key('recovery-phrase-field')),
      'abandon abandon abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon about',
    );
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(find.textContaining("doesn't match"), findsOneWidget);
  });

  testWidgets('start fresh deletes the database file and calls onStartFresh',
      (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('restore_screen_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final dbFile = File(p.join(tempDir.path, 'test.sqlite'))
      ..writeAsBytesSync([0]);

    final service = VaultService(
      secureSeedStorage: SecureSeedStorage(store: FakeSeedKeyValueStore()),
      databaseFileResolver: () async => dbFile,
      documentsDirectory: () async => tempDir,
    );
    var startFreshCalled = false;

    await tester.pumpWidget(MaterialApp(
      home: RestoreScreen(
        vaultService: service,
        onUnlocked: (_) {},
        onStartFresh: () => startFreshCalled = true,
      ),
    ));

    await tester.tap(find.text("I don't have the phrase — start fresh"));
    await tester.pumpAndSettle();

    expect(dbFile.existsSync(), isFalse);
    expect(startFreshCalled, isTrue);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd local_reviews && flutter test test/screens/restore_screen_test.dart`
Expected: FAIL — `package:local_reviews/screens/vault/restore_screen.dart` does not exist.

- [ ] **Step 3: Implement `RestoreScreen`**

Create `local_reviews/lib/screens/vault/restore_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../vault/vault_service.dart';
import '../../vault/vault_state.dart';

class RestoreScreen extends StatefulWidget {
  const RestoreScreen({
    super.key,
    required this.vaultService,
    required this.onUnlocked,
    required this.onStartFresh,
  });

  final VaultService vaultService;
  final ValueChanged<VaultUnlocked> onUnlocked;
  final VoidCallback onStartFresh;

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final unlocked =
          await widget.vaultService.restoreVault(_controller.text.trim());
      widget.onUnlocked(unlocked);
    } on WrongRecoveryPhraseException {
      setState(() {
        _busy = false;
        _error = "This phrase doesn't match the data on this device.";
      });
    }
  }

  Future<void> _startFresh() async {
    await widget.vaultService.startFresh();
    widget.onStartFresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restore from recovery phrase')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your 12-word recovery phrase to unlock the data on this device.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('recovery-phrase-field'),
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Recovery phrase'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Restore'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _startFresh,
              child: const Text("I don't have the phrase — start fresh"),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd local_reviews && flutter test test/screens/restore_screen_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/screens/vault/restore_screen.dart local_reviews/test/screens/restore_screen_test.dart
git commit -m "Add RestoreScreen: recovery-phrase restore with a start-fresh escape hatch"
```

---

## Task 11: VaultGate, main.dart wiring, and cleanup

**Files:**
- Create: `local_reviews/lib/app.dart` (moves `LocalReviewsApp` out of `main.dart`)
- Create: `local_reviews/lib/screens/vault_gate.dart`
- Modify: `local_reviews/lib/main.dart`
- Modify: `local_reviews/lib/data/database.dart` (require the executor; remove `_openConnection()` and the `drift_flutter` import)
- Modify: `local_reviews/pubspec.yaml` (remove `drift_flutter`)
- Modify: `local_reviews/test/widget_test.dart`
- Test: `local_reviews/test/screens/vault_gate_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1–10 (`VaultService`, `VaultState`/`VaultUnlocked`, `OnboardingScreen`, `RestoreScreen`, `resolveDatabaseFile()`/`openEncryptedExecutor()`, `AppRepositories`, `PosterStorageService`, `PosterCipherService`, `NoSecureKeyringException`).
- Produces: `LocalReviewsApp({required AppDatabase database, required PosterStorageService posterStorageService})` (moved to `lib/app.dart`, now takes `posterStorageService`), `VaultGate({required VaultService vaultService})`. This is the final task — nothing downstream depends on it.

- [ ] **Step 1: Move `LocalReviewsApp` into `lib/app.dart`**

Create `local_reviews/lib/app.dart`:

```dart
import 'package:flutter/material.dart';

import 'app_repositories.dart';
import 'data/database.dart';
import 'screens/navigation_shell.dart';
import 'services/poster_storage_service.dart';

class LocalReviewsApp extends StatelessWidget {
  const LocalReviewsApp({
    super.key,
    required this.database,
    required this.posterStorageService,
  });

  final AppDatabase database;
  final PosterStorageService posterStorageService;

  @override
  Widget build(BuildContext context) {
    return AppRepositories(
      database: database,
      posterStorageService: posterStorageService,
      child: MaterialApp(
        title: 'Local Reviews',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
        home: const NavigationShell(),
      ),
    );
  }
}
```

- [ ] **Step 2: Finalize `AppDatabase`'s constructor and remove `drift_flutter`**

In `local_reviews/lib/data/database.dart`, change:

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
```

to:

```dart
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
```

Change:

```dart
@DriftDatabase(tables: [Films, Genres, FilmGenres, Reviews])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());
```

to:

```dart
@DriftDatabase(tables: [Films, Genres, FilmGenres, Reviews])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor executor) : super(executor);
```

Delete the now-unused `_openConnection()` static method entirely (the closing brace of the class moves up to follow `beforeOpen`'s `MigrationStrategy`).

In `local_reviews/pubspec.yaml`, remove the line:

```yaml
  drift_flutter: ^0.3.1
```

Run: `cd local_reviews && flutter pub get`

- [ ] **Step 3: Write the failing `VaultGate` test**

Create `local_reviews/test/screens/vault_gate_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/screens/vault_gate.dart';
import 'package:local_reviews/vault/secure_seed_storage.dart';
import 'package:local_reviews/vault/vault_service.dart';
import 'package:path/path.dart' as p;

import '../vault/fakes.dart';

void main() {
  testWidgets('shows onboarding when nothing has been set up yet',
      (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('vault_gate_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final service = VaultService(
      secureSeedStorage: SecureSeedStorage(store: FakeSeedKeyValueStore()),
      databaseFileResolver: () async => File(p.join(tempDir.path, 'test.sqlite')),
      documentsDirectory: () async => tempDir,
    );

    await tester.pumpWidget(VaultGate(vaultService: service));
    await tester.pumpAndSettle();

    expect(find.text('Set up local encryption'), findsOneWidget);
  });

  testWidgets('shows restore when a database file exists but no seed is stored',
      (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('vault_gate_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final dbFile = File(p.join(tempDir.path, 'test.sqlite'))
      ..writeAsBytesSync([0]);
    final service = VaultService(
      secureSeedStorage: SecureSeedStorage(store: FakeSeedKeyValueStore()),
      databaseFileResolver: () async => dbFile,
      documentsDirectory: () async => tempDir,
    );

    await tester.pumpWidget(VaultGate(vaultService: service));
    await tester.pumpAndSettle();

    expect(find.text('Restore from recovery phrase'), findsOneWidget);
  });

  testWidgets('goes straight to the app when a seed is already stored',
      (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('vault_gate_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final store = FakeSeedKeyValueStore();
    final dbFile = File(p.join(tempDir.path, 'test.sqlite'));
    final onboarding = VaultService(
      secureSeedStorage: SecureSeedStorage(store: store),
      databaseFileResolver: () async => dbFile,
      documentsDirectory: () async => tempDir,
    );
    await onboarding.completeOnboarding(onboarding.generateMnemonic());

    final service = VaultService(
      secureSeedStorage: SecureSeedStorage(store: store),
      databaseFileResolver: () async => dbFile,
      documentsDirectory: () async => tempDir,
    );

    await tester.pumpWidget(VaultGate(vaultService: service));
    await tester.pumpAndSettle();

    expect(find.text('No reviews yet'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `cd local_reviews && flutter test test/screens/vault_gate_test.dart`
Expected: FAIL — `package:local_reviews/screens/vault_gate.dart` does not exist.

- [ ] **Step 5: Implement `VaultGate`**

Create `local_reviews/lib/screens/vault_gate.dart`:

```dart
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../data/database.dart';
import '../services/poster_cipher_service.dart';
import '../services/poster_storage_service.dart';
import '../vault/secure_seed_storage.dart';
import '../vault/vault_service.dart';
import '../vault/vault_state.dart';
import 'vault/onboarding_screen.dart';
import 'vault/restore_screen.dart';

class VaultGate extends StatefulWidget {
  const VaultGate({super.key, required this.vaultService});

  final VaultService vaultService;

  @override
  State<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends State<VaultGate> {
  late Future<VaultState> _stateFuture;

  @override
  void initState() {
    super.initState();
    _stateFuture = widget.vaultService.resolveInitialState();
  }

  void _onUnlocked(VaultUnlocked unlocked) {
    setState(() => _stateFuture = Future.value(unlocked));
  }

  void _onStartFresh() {
    setState(() => _stateFuture = Future.value(const VaultNeedsOnboarding()));
  }

  void _retry() {
    setState(() => _stateFuture = widget.vaultService.resolveInitialState());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VaultState>(
      future: _stateFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorApp(error: snapshot.error!, onRetry: _retry);
        }
        final state = snapshot.data;
        if (state == null) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        return switch (state) {
          VaultNeedsOnboarding() => MaterialApp(
              home: OnboardingScreen(
                vaultService: widget.vaultService,
                onUnlocked: _onUnlocked,
              ),
            ),
          VaultNeedsRestore() => MaterialApp(
              home: RestoreScreen(
                vaultService: widget.vaultService,
                onUnlocked: _onUnlocked,
                onStartFresh: _onStartFresh,
              ),
            ),
          VaultUnlocked() => _UnlockedApp(state: state),
        };
      },
    );
  }
}

class _UnlockedApp extends StatelessWidget {
  const _UnlockedApp({required this.state});

  final VaultUnlocked state;

  Future<AppDatabase> _openDatabase() async {
    final file = await resolveDatabaseFile();
    return AppDatabase(openEncryptedExecutor(file: file, key: state.dbKey));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppDatabase>(
      future: _openDatabase(),
      builder: (context, snapshot) {
        final database = snapshot.data;
        if (database == null) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        return LocalReviewsApp(
          database: database,
          posterStorageService: PosterStorageService(
            cipherService: PosterCipherService(SecretKey(state.posterKey)),
          ),
        );
      },
    );
  }
}

class _ErrorApp extends StatelessWidget {
  const _ErrorApp({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is NoSecureKeyringException
        ? 'No secure keyring service found — install and start GNOME '
            'Keyring, KWallet, or another Secret Service-compatible '
            'provider, then try again.'
        : 'Could not access secure storage on this device.';
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Wire `main.dart`**

Replace the contents of `local_reviews/lib/main.dart`:

```dart
import 'package:flutter/material.dart';

import 'screens/vault_gate.dart';
import 'vault/vault_service.dart';

void main() {
  runApp(VaultGate(vaultService: VaultService()));
}
```

- [ ] **Step 7: Update `widget_test.dart`**

Replace the contents of `local_reviews/test/widget_test.dart`:

```dart
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/app.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/services/poster_cipher_service.dart';
import 'package:local_reviews/services/poster_storage_service.dart';

void main() {
  testWidgets('the app launches to an empty Reviews screen', (tester) async {
    final database = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(database.close);

    await tester.pumpWidget(LocalReviewsApp(
      database: database,
      posterStorageService: PosterStorageService(
        cipherService: PosterCipherService(SecretKey(List.generate(32, (i) => i))),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No reviews yet'), findsOneWidget);
  });
}
```

- [ ] **Step 8: Run the new and updated tests**

Run: `cd local_reviews && flutter test test/screens/vault_gate_test.dart test/widget_test.dart`
Expected: PASS (4 tests total)

- [ ] **Step 9: Run the full test suite and static analysis**

Run: `cd local_reviews && flutter test`
Expected: PASS (every test in the suite)

Run: `cd local_reviews && flutter analyze`
Expected: No issues found.

- [ ] **Step 10: Commit**

```bash
git add local_reviews/lib/app.dart local_reviews/lib/screens/vault_gate.dart local_reviews/lib/main.dart local_reviews/lib/data/database.dart local_reviews/pubspec.yaml local_reviews/pubspec.lock local_reviews/test/widget_test.dart local_reviews/test/screens/vault_gate_test.dart
git commit -m "Wire VaultGate as the app root: onboarding/restore/auto-unlock"
```

- [ ] **Step 11: Manual smoke test**

Run: `cd local_reviews && flutter run -d linux` (or another available desktop/emulator target).

Confirm: the app shows the onboarding screen on first launch, the 12-word phrase and confirmation step work, and after confirming you land on the normal empty Reviews screen. Stop and relaunch the app (`flutter run` again) — it should skip straight to the Reviews screen (auto-unlock), with no onboarding/restore prompt.
