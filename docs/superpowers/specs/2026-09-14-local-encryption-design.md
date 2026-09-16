# Local Encryption (Database + Poster Files) — Design

Date: 2026-09-14

## Context

Per `CLAUDE.md`'s product vision, local data encryption is the first phase of the encryption roadmap (remote/synced data encryption comes later, once remote sync exists). This spec covers that first phase: encrypting the on-device Drift/SQLite database and the poster image files copied to app storage by `PosterStorageService`.

The scheme mirrors Anytype's local key-management model: a BIP-39 mnemonic recovery phrase is generated from local random entropy, deterministically expanded into a seed, and that seed is used to derive every encryption key the app needs. The seed itself is held only in the platform's secure enclave-backed storage (iOS/macOS Keychain, Android Keystore) — never written to disk in plaintext, never transmitted anywhere (there is no remote sync yet).

The prior spec (`2026-08-09-manual-film-entry-design.md`) shipped the database and poster storage unencrypted, and noted that Drift's current recommended encryption path is SQLite3MultipleCiphers via `NativeDatabase`, with a `PRAGMA rekey` migration for databases that were created unencrypted. This spec supersedes that migration note: because the app has no released users yet, this feature treats any pre-existing local database as discardable (see "Fresh start / no migration" below) rather than implementing a `PRAGMA rekey` path.

## Scope

In scope:
- BIP-39 mnemonic generation (128 bits of entropy → 12 words), validation, and mnemonic→seed derivation.
- Storing the seed in Keychain/Keystore via `flutter_secure_storage`.
- Deriving independent subkeys from the seed via HKDF-SHA256 (domain-separated by an `info` string): one for the database, one for poster files.
- Encrypting the Drift/SQLite database via SQLite3MultipleCiphers (`sqlite3mc`), keyed with the derived database subkey.
- Encrypting poster files on disk with AES-256-GCM, keyed with the derived poster subkey.
- App startup flow: onboarding (first run — generate + confirm the recovery phrase), restore (recovery phrase entry when a database file exists but no seed is in secure storage), and silent auto-unlock (seed already in secure storage).
- A "start fresh" escape hatch on the restore screen that discards any existing local database/poster files and routes to onboarding.

Out of scope (explicitly deferred):
- Encryption of remote/synced data — no remote sync exists yet (later roadmap phase per `CLAUDE.md`).
- `PRAGMA rekey`-style migration of a previously-unencrypted database — not needed since there are no released users; superseded by the "start fresh" flow described here.
- An additional app-level lock screen / biometric prompt on every launch — the design relies on the OS's own Keychain/Keystore protection at read time (see "Unlock flow" below). Could be added later as a separate feature.
- Web platform — target platforms for this feature are Android, iOS, Linux, macOS, Windows, matching the existing manual-film-entry feature's scope.
- Any UI for viewing/exporting the recovery phrase again after onboarding (e.g., a settings-screen "show recovery phrase" action) — not needed until a restore or account-recovery flow calls for it beyond what's specced here.
- Bundling or depending on a Linux Secret Service provider (e.g. packaging GNOME Keyring as an app dependency) to guarantee a keyring is available out of the box on Linux — deferred; see "Secure seed storage across platforms" below for how this case is handled for now. Worth revisiting as a dedicated follow-up once real Linux usage shows how often this actually comes up.

## Key derivation

```
128 bits CSPRNG entropy
        │
        ▼
  BIP-39 mnemonic (12 words) — shown once during onboarding for the user to back up
        │
        ▼  mnemonicToSeed (PBKDF2-HMAC-SHA512 per BIP-39 spec, no extra passphrase)
      seed (64 bytes) ────────────────────► stored in Keychain/Keystore
        │
        ▼  HKDF-SHA256(ikm = seed, salt = fixed app-specific constant)
   ┌────┴─────┐
   ▼          ▼
info=         info=
"local_reviews/db-key/v1"   "local_reviews/poster-key/v1"
   ▼          ▼
 dbKey (32B)  posterKey (32B)
```

`dbKey` and `posterKey` are independent — compromising one does not expose the other, and neither can be used to reconstruct the seed. The `info` strings are versioned (`/v1`) so future key rotation or additional derived keys (e.g., a future sync key) can be added without colliding with these.

## Components (`lib/vault/`)

| File | Responsibility |
|---|---|
| `mnemonic_service.dart` | Wraps the `bip39` package: `generateMnemonic()`, `validateMnemonic(phrase)`, `mnemonicToSeed(phrase)` |
| `seed_key_derivation.dart` | HKDF(seed) → `dbKey` / `posterKey`, via `package:cryptography`'s `Hkdf` |
| `secure_seed_storage.dart` | Wraps `flutter_secure_storage`: `read()` / `write(seed)` / `delete()`, seed stored base64-encoded under a fixed key (`vault_seed_v1`) |
| `vault_state.dart` | `sealed class VaultState { NeedsOnboarding, NeedsRestore, Unlocked(seed) }` |
| `vault_service.dart` | Orchestrates the above; resolves the initial `VaultState`, exposes `createVault()` (onboarding) and `restoreVault(phrase)` (restore) |

And in `lib/services/`: `poster_cipher_service.dart` — AES-256-GCM encrypt/decrypt of raw bytes given the poster key.

## Secure seed storage across platforms

`flutter_secure_storage` backs `secure_seed_storage.dart` with a different OS-native store per platform:

- **iOS / macOS**: Keychain — no gap, this is the mechanism the rest of this spec means by "Keychain".
- **Android**: Keystore-backed encrypted storage — no gap, this is the mechanism the rest of this spec means by "Keystore".
- **Windows**: Windows Credential Manager (DPAPI-backed) — no gap.
- **Linux**: `libsecret`, which itself depends on a *running* Secret Service provider (GNOME Keyring, KWallet, or another compatible implementation). This is an environment dependency, not just a library one — some Linux setups (minimal window managers, headless/server environments) may have no Secret Service running at all, and every read/write will fail.

For Linux specifically, when `SecureSeedStorage` detects that no Secret Service is available (the underlying `flutter_secure_storage` call fails for that reason), the blocking error screen described in "Error handling" shows an actionable message — e.g. "No secure keyring service found — install and start GNOME Keyring, KWallet, or another Secret Service-compatible provider" — instead of a generic failure message, so the user knows what to fix. No alternative, app-managed fallback store is introduced for this case: without a real OS-backed keyring, anything we build ourselves would be obfuscation rather than actual protection, which would undermine the point of this feature. See "Out of scope" above for a possible future follow-up (bundling/depending on a Linux keyring provider) once real Linux usage shows how often this matters in practice.

## Database encryption

- `pubspec.yaml` gains a root-level build hook:
  ```yaml
  hooks:
    user_defines:
      sqlite3:
        source: sqlite3mc
  ```
  This bundles SQLite3MultipleCiphers via Dart's native-assets build hooks — no platform-specific Gradle/pod/binary setup needed on Android, iOS, Linux, macOS, or Windows.
- `drift_flutter` is dropped as a dependency: its `driftDatabase()` helper doesn't expose a way to run a setup `PRAGMA key` statement, so `database.dart` constructs the connection directly:
  ```dart
  NativeDatabase.createInBackground(
    dbFile,
    setup: (rawDb) {
      rawDb.execute("PRAGMA key = \"x'$dbKeyHex'\";"); // raw 32-byte key, hex-encoded
      assert(rawDb.select('PRAGMA cipher;').isNotEmpty);
    },
  );
  ```
  Raw key mode (`x'<hex>'`) is used rather than passphrase mode: the input is already a cryptographically strong 256-bit key derived via BIP-39 + HKDF, so SQLCipher/sqlite3mc's own internal PBKDF2 stretching (meant for low-entropy human passwords) would only add latency on every app open with no security benefit.
- `AppDatabase` takes the resolved `File` and `dbKey` bytes as constructor parameters instead of resolving its own path internally. The path itself (e.g. `<applicationSupportDirectory>/local_reviews.sqlite`, via `path_provider`) is resolved once by a small shared helper (e.g. `resolveDatabaseFile()`) used both by whoever constructs `AppDatabase` and by `VaultService`'s "does a database file already exist" check, so the two never drift out of sync.
- `drift`/`drift_dev` are bumped to the minimum version that supports the `sqlite3mc` hook (≥2.35.0 as of this writing — confirm exact current version at implementation time).
- `PRAGMA foreign_keys = ON` continues to run in `beforeOpen`, unchanged from today.

## Poster file encryption

- `PosterCipherService.encrypt(bytes) → Uint8List` runs AES-256-GCM with a random 12-byte nonce per call, and serializes the result as `nonce ++ ciphertext ++ tag` using `cryptography`'s `SecretBox.concatenation()` / `SecretBox.fromConcatenation()`.
- `PosterStorageService.savePoster` encrypts the picked file's bytes before writing, and saves with a `.enc` extension (the file is no longer a valid image, so keeping the original extension would be misleading).
- `PosterStorageService` gains a corresponding decrypt path used by the UI.
- `PosterThumbnail` currently renders synchronously via `Image.file(File(path))`. Decryption is async, so it becomes a `FutureBuilder<Uint8List>` that calls into the cipher service (obtained via `AppRepositories.of(context)`, the same DI pattern already used for repositories) and renders with `Image.memory(bytes)`. A GCM authentication failure (corrupted/tampered file) falls through to the same placeholder the widget already shows for a missing file.

## App startup / unlock flow

`main.dart` becomes minimal, wrapping the app in a `VaultGate` (a plain `StatefulWidget` at the root — no state-management package introduced, consistent with the existing `InheritedWidget`-based `AppRepositories`). On init, `VaultGate` asks `VaultService` to resolve the initial state:

1. **Seed present in Keychain/Keystore → `Unlocked`.** Derive `dbKey`/`posterKey`, open `AppDatabase`, build `AppRepositories`, show `NavigationShell`. No prompt — protection comes from the OS's own Keychain/Keystore gating (see "Error handling" for what happens if that read fails).
2. **No seed, no database file on disk → `NeedsOnboarding`.** Show `OnboardingScreen`:
   - Generate the mnemonic and display the 12 words.
   - Require the user to confirm 3 randomly-chosen word positions by typing them back, before proceeding (reduces the risk of a bad backup going unnoticed).
   - Only after confirmation: derive the seed, write it to secure storage, then create the encrypted database. The seed is written to secure storage *before* the database file is created — if the app is killed mid-onboarding, the next launch sees "seed present, no database file" and simply (re)creates the database with that same seed, rather than leaving an orphaned encrypted file with no matching key.
3. **No seed, database file exists on disk → `NeedsRestore`.** Show `RestoreScreen`:
   - User enters the 12-word phrase; validated locally via BIP-39 checksum before anything else.
   - Derive the candidate seed and subkeys, attempt to open the existing database file with the candidate `dbKey`, and run a trial query (`SELECT count(*) FROM sqlite_master`) inside a try/catch. SQLite3MultipleCiphers does not reject a wrong key at connection-open time — only a real read against the encrypted pages reveals a mismatch.
   - On trial-query failure: show an inline "this phrase doesn't match the data on this device" error; nothing is persisted, the user can retry.
   - On success: write the seed to secure storage, proceed as `Unlocked`.
   - A secondary "I don't have the phrase — start fresh" action deletes the existing database file and poster directory, then routes to onboarding. This is also the mechanism that resolves today's pre-existing unencrypted dev database: on first run under this feature, that file won't open under any key, so the natural path is this same "start fresh" action rather than bespoke migration code.

## Error handling

- Secure storage read/write failure: blocking error screen with a retry action — the app cannot function without the seed, by design. On Linux, a failure caused by no Secret Service running gets the specific actionable message described in "Secure seed storage across platforms" rather than a generic one; other platforms/causes get a generic message.
- Invalid recovery phrase (BIP-39 checksum failure): inline error before any database access is attempted.
- Valid phrase that doesn't match the existing database: inline error from the trial-query failure (see above); no partial writes.
- Corrupted/tampered poster file (GCM tag mismatch on decrypt): falls back to the existing placeholder in `PosterThumbnail`, does not crash the screen.

## Testing

- `mnemonic_service_test.dart`: valid mnemonic generation; `validateMnemonic` true/false cases; a pinned official BIP-39 test vector to confirm `mnemonicToSeed` is deterministic and spec-correct.
- `seed_key_derivation_test.dart`: same seed + same `info` → same key, deterministically; `dbKey != posterKey` for the same seed.
- `secure_seed_storage_test.dart`: a fake `flutter_secure_storage` backend that throws a "no Secret Service" style error maps to the Linux-specific actionable message; other failures map to the generic one.
- `vault_service_test.dart`: all three initial states, using fakes for secure storage and for the "database file exists" check; the restore flow's wrong-phrase path leaves no persisted state.
- `poster_cipher_service_test.dart`: encrypt/decrypt round-trip; a single flipped ciphertext byte causes decryption to throw (GCM authentication).
- `poster_storage_service_test.dart`: existing tests assert saved bytes equal the original source bytes — that assumption no longer holds once encryption is wired in. `PosterStorageService` gets a constructor-injectable cipher (mirroring the existing `documentsDirectory` injection point) so the current tests can keep verifying file-placement/naming behavior against a pass-through fake cipher, with new tests added specifically for the real-cipher round trip.
- `database_test.dart`: opening with a key and reopening with the same key succeeds; reopening with a different key fails on the trial query.
- Widget tests: `poster_thumbnail_test.dart` updated for the `FutureBuilder`-based async load; new tests for `OnboardingScreen` (word-confirmation gating), `RestoreScreen` (phrase validation, wrong-phrase error, "start fresh" action), and `VaultGate` (routes to the right screen per `VaultState`).

## Dependencies

Add: `bip39` (re-check maintenance status at implementation time; fall back to a maintained fork such as `bip39_plus` if `bip39` looks abandoned), `flutter_secure_storage`, `cryptography`.

Remove: `drift_flutter` (superseded by direct `NativeDatabase` construction, see "Database encryption").

Bump: `drift`, `drift_dev` to the minimum version supporting the `sqlite3mc` build hook.
