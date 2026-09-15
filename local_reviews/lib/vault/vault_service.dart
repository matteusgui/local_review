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
      db.close();
    }
  }
}
