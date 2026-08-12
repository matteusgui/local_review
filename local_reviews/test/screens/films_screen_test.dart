import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/app_repositories.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/data/repositories/film_repository.dart';
import 'package:local_reviews/screens/films/films_screen.dart';

void main() {
  testWidgets('shows an empty state with no films, then lists a seeded film',
      (tester) async {
    final database = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(database.close);

    await tester.pumpWidget(
      AppRepositories(
        database: database,
        child: const MaterialApp(home: FilmsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No films yet'), findsOneWidget);

    await FilmRepository(database).createFilm(title: 'Whisper of the Heart', year: 1995);
    await tester.pumpAndSettle();

    expect(find.text('Whisper of the Heart (1995)'), findsOneWidget);
  });

  testWidgets('tapping the FAB opens Add film', (tester) async {
    final database = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(database.close);

    await tester.pumpWidget(
      AppRepositories(
        database: database,
        child: const MaterialApp(home: FilmsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_film_fab')));
    await tester.pumpAndSettle();

    expect(find.text('Add film'), findsOneWidget);
  });
}
