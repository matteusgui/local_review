import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/screens/vault_gate.dart';
import 'package:local_reviews/vault/secure_seed_storage.dart';
import 'package:local_reviews/vault/vault_service.dart';
import 'package:path/path.dart' as p;

import '../support/pump_until.dart';
import '../vault/fakes.dart';

// Unlike VaultService's own file/directory lookups (injected above via
// databaseFileResolver/documentsDirectory), _UnlockedApp inside VaultGate
// opens the real database through the production resolveDatabaseFile(),
// which calls path_provider's getApplicationSupportDirectory(). There is no
// platform plugin registered under `flutter test`, so that call throws
// MissingPluginException unless the method channel is mocked here.
const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

void _mockApplicationSupportPath(WidgetTester tester, String path) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _pathProviderChannel,
    (call) async => call.method == 'getApplicationSupportDirectory' ? path : null,
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathProviderChannel, null));
}

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

    // VaultGate's initState kicks off resolveInitialState(), which performs
    // real (non-fake-clock) dart:io file-existence checks. Flutter's
    // FakeAsync-driven test binding stalls on such work unless it runs
    // inside tester.runAsync() (see commits 378795d and eea833c for the same
    // pattern with real async I/O elsewhere in this app). While the state is
    // pending, VaultGate shows a CircularProgressIndicator, whose
    // indeterminate animation schedules frames forever — pumpAndSettle()
    // would never settle, so give the real future a wall-clock turn and use
    // a plain pump() instead.
    await tester.runAsync(() async {
      await tester.pumpWidget(VaultGate(vaultService: service));
      await tester.pump();
      await pumpUntil(tester, find.text('Set up local encryption'));
    });

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

    // See the previous test: resolveInitialState() performs real dart:io
    // file-existence checks and needs tester.runAsync(); pumpAndSettle()
    // can't be used while the pending CircularProgressIndicator is showing.
    await tester.runAsync(() async {
      await tester.pumpWidget(VaultGate(vaultService: service));
      await tester.pump();
      await pumpUntil(tester, find.text('Restore from recovery phrase'));
    });

    expect(find.text('Restore from recovery phrase'), findsOneWidget);
  });

  testWidgets('goes straight to the app when a seed is already stored',
      (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('vault_gate_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    _mockApplicationSupportPath(tester, tempDir.path);
    final store = FakeSeedKeyValueStore();
    final dbFile = File(p.join(tempDir.path, 'test.sqlite'));

    // Once unlocked, VaultGate opens the encrypted database via
    // resolveDatabaseFile() + openEncryptedExecutor(), which spins up a real
    // background isolate (NativeDatabase.createInBackground) plus real
    // dart:io/crypto work. All of the setup and interaction below needs to
    // run inside tester.runAsync() for the same reason as the other tests in
    // this file (and restore_screen_test.dart / database_test.dart).
    await tester.runAsync(() async {
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
      // Two nested FutureBuilders are involved here: VaultGate's own
      // _stateFuture (fast — fake seed storage + real key derivation), then
      // _UnlockedApp's _openDatabase() (a real background-isolate database
      // open — the slowest and most timing-sensitive step in this file).
      // Neither pending future's spinner lets pumpAndSettle() settle, so
      // wait for the final screen's content to appear instead of guessing a
      // fixed wall-clock budget for the isolate spawn.
      await tester.pump();
      await pumpUntil(tester, find.text('No reviews yet'));

      expect(find.text('No reviews yet'), findsOneWidget);

      // The rendered ReviewsScreen holds a live drift stream subscription
      // against the real encrypted database opened above. Unmounting it
      // (via the test framework's automatic teardown) schedules a
      // Timer.zero to close that stream; if that happens after this
      // runAsync() block exits, it becomes a FakeTimer that never fires and
      // fails the test's "no pending timers" invariant. Dispose the tree
      // here, inside runAsync, so the real Timer actually runs to
      // completion before the test ends. There's no widget/condition to
      // poll for here — this is just giving the already-scheduled real
      // Timer.zero a wall-clock turn to fire — so it keeps a short fixed
      // delay rather than pumpUntil.
      await tester.pumpWidget(Container());
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });

  testWidgets(
      'shows the Linux-specific keyring error message when secure storage '
      'is unavailable', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('vault_gate_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final service = VaultService(
      secureSeedStorage: SecureSeedStorage(
        store: FakeSeedKeyValueStore(failWith: Exception('no keyring')),
        isLinux: () => true,
      ),
      databaseFileResolver: () async =>
          File(p.join(tempDir.path, 'test.sqlite')),
      documentsDirectory: () async => tempDir,
    );

    // Reading the seed fails synchronously inside FakeSeedKeyValueStore
    // (no real I/O involved), so resolveInitialState()'s returned future
    // resolves with an error on a normal microtask turn — this doesn't
    // need tester.runAsync().
    await tester.pumpWidget(VaultGate(vaultService: service));
    await tester.pump();

    expect(
      find.textContaining('No secure keyring service found'),
      findsOneWidget,
    );
  });
}
