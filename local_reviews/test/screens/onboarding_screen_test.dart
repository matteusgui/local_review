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
