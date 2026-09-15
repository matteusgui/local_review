import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/app_repositories.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/screens/films/add_edit_film_screen.dart';
import 'package:local_reviews/services/poster_cipher_service.dart';
import 'package:local_reviews/services/poster_storage_service.dart';

Future<AppDatabase> pumpScreen(WidgetTester tester, {Widget? screen}) async {
  final database = AppDatabase(
    DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
  );
  addTearDown(database.close);

  await tester.pumpWidget(
    AppRepositories(
      database: database,
      posterStorageService: PosterStorageService(
        cipherService: PosterCipherService(SecretKey(List.generate(32, (i) => i))),
      ),
      child: MaterialApp(home: screen ?? const AddEditFilmScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return database;
}

void main() {
  testWidgets('shows a validation error and does not save when title is empty',
      (tester) async {
    final database = await pumpScreen(tester);

    await tester.enterText(find.byKey(const Key('film_year_field')), '2000');
    await tester.tap(find.byKey(const Key('save_film_button')));
    await tester.pumpAndSettle();

    expect(find.text('Title is required'), findsOneWidget);
    expect(await database.select(database.films).get(), isEmpty);
  });

  testWidgets('saves a valid film and pops the screen', (tester) async {
    final database = await pumpScreen(tester);

    await tester.enterText(find.byKey(const Key('film_title_field')), 'Arrival');
    await tester.enterText(find.byKey(const Key('film_year_field')), '2016');
    await tester.tap(find.byKey(const Key('save_film_button')));
    await tester.pumpAndSettle();

    final films = await database.select(database.films).get();
    expect(films.single.title, 'Arrival');
    expect(find.byType(AddEditFilmScreen), findsNothing);
  });
}
