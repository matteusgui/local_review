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
    // Drift opens its executor lazily: without a real statement, the file
    // is never actually written, so a later trial-open with any key would
    // trivially "succeed" against an empty file. Force a real open/write.
    await creatorDb.customStatement('SELECT 1');
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
    // See note above: force a real open/write before closing.
    await creatorDb.customStatement('SELECT 1');
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
