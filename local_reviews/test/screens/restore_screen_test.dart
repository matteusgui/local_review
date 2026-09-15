import 'dart:io';
import 'dart:typed_data';

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

    // The setup below performs real async I/O (a real background isolate via
    // NativeDatabase.createInBackground, plus real file/crypto operations),
    // and the widget interaction below drives a service that also performs
    // real (non-fake-clock) async I/O. Flutter's FakeAsync-driven test
    // binding stalls on such work unless it runs inside tester.runAsync().
    VaultUnlocked? unlocked;
    Uint8List? createdDbKey;
    await tester.runAsync(() async {
      final creator = VaultService(
        secureSeedStorage: SecureSeedStorage(store: FakeSeedKeyValueStore()),
        databaseFileResolver: () async => dbFile,
        documentsDirectory: () async => tempDir,
      );
      final mnemonic = creator.generateMnemonic();
      final created = await creator.completeOnboarding(mnemonic);
      createdDbKey = created.dbKey;
      final creatorDb = AppDatabase(
          openEncryptedExecutor(file: dbFile, key: created.dbKey));
      await creatorDb.close();

      final restoringService = VaultService(
        secureSeedStorage: SecureSeedStorage(store: FakeSeedKeyValueStore()),
        databaseFileResolver: () async => dbFile,
        documentsDirectory: () async => tempDir,
      );

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
      await tester.pump();
      // restoreVault() performs real (non-fake-clock) async I/O; give it a
      // real wall-clock turn to complete before pumping the settled frame.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });

    expect(unlocked, isNotNull);
    expect(unlocked!.dbKey, createdDbKey);
  });

  testWidgets('shows an error for a phrase that does not match',
      (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('restore_screen_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    // A 1-byte file (as in the plan's literal test text) is too small for
    // sqlite3 to distinguish from a fresh/empty database: VaultService's own
    // suite (vault_service_test.dart) documents that a trial-open with any
    // key trivially "succeeds" against a near-empty file. Use a page-sized
    // block of non-database bytes so the trial-open genuinely fails, which
    // is what this test is meant to exercise.
    final dbFile = File(p.join(tempDir.path, 'test.sqlite'))
      ..writeAsBytesSync(List.filled(4096, 7));

    final service = VaultService(
      secureSeedStorage: SecureSeedStorage(store: FakeSeedKeyValueStore()),
      databaseFileResolver: () async => dbFile,
      documentsDirectory: () async => tempDir,
    );

    // restoreVault() performs real (non-fake-clock) async I/O (dart:io file
    // checks + synchronous FFI sqlite3 calls); run the interaction inside
    // tester.runAsync() and give it a real wall-clock turn to complete.
    await tester.runAsync(() async {
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
    });

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

    // startFresh() performs real (non-fake-clock) dart:io file deletion; run
    // the interaction inside tester.runAsync() and give it a real wall-clock
    // turn to complete.
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: RestoreScreen(
          vaultService: service,
          onUnlocked: (_) {},
          onStartFresh: () => startFreshCalled = true,
        ),
      ));

      await tester.tap(find.text("I don't have the phrase — start fresh"));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });

    expect(dbFile.existsSync(), isFalse);
    expect(startFreshCalled, isTrue);
  });
}
