import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/app_repositories.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/screens/navigation_shell.dart';

Future<AppDatabase> pumpShell(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final database = AppDatabase(
    DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
  );
  addTearDown(database.close);

  await tester.pumpWidget(
    AppRepositories(
      database: database,
      child: const MaterialApp(home: NavigationShell()),
    ),
  );
  await tester.pumpAndSettle();
  return database;
}

void main() {
  testWidgets('shows a bottom nav bar on a narrow (phone) layout', (tester) async {
    await pumpShell(tester, const Size(400, 800));
    expect(find.byKey(const Key('bottom_nav_bar')), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('shows a navigation rail on a wide (desktop) layout', (tester) async {
    await pumpShell(tester, const Size(1000, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byKey(const Key('bottom_nav_bar')), findsNothing);
  });

  testWidgets('tapping the Films destination switches screens', (tester) async {
    await pumpShell(tester, const Size(400, 800));
    expect(find.text('No reviews yet'), findsOneWidget);

    await tester.tap(find.text('Films'));
    await tester.pumpAndSettle();

    expect(find.text('No films yet'), findsOneWidget);
  });
}
