import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/app_repositories.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/data/repositories/film_repository.dart';
import 'package:local_reviews/screens/reviews/add_edit_review_screen.dart';

// The review form (film picker + inline new-film fields + rating + review
// text + watch date) is taller than the default 800x600 test viewport, which
// would leave the bottom of the form outside the hit-testable area and
// unbuilt inside the lazily-rendered ListView. Enlarge the surface so every
// field is on-screen and tappable without needing to scroll mid-test.
void _growTestViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<AppDatabase> pumpScreen(WidgetTester tester) async {
  _growTestViewport(tester);
  final database = AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  addTearDown(database.close);
  await tester.pumpWidget(
    AppRepositories(
      database: database,
      child: const MaterialApp(home: AddEditReviewScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return database;
}

void main() {
  testWidgets(
    'does not save when review text is empty even with a rating and new film',
    (tester) async {
      final database = await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('toggle_new_film_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('film_title_field')),
        'Ponyo',
      );
      await tester.enterText(find.byKey(const Key('film_year_field')), '2008');

      await tester.tap(find.byKey(const ValueKey('star_3')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_review_button')));
      await tester.pumpAndSettle();

      expect(find.text('Review text is required'), findsOneWidget);
      expect(await database.select(database.reviews).get(), isEmpty);
    },
  );

  testWidgets('creates a new film inline and a review against it', (
    tester,
  ) async {
    final database = await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('toggle_new_film_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('film_title_field')), 'Ponyo');
    await tester.enterText(find.byKey(const Key('film_year_field')), '2008');
    await tester.enterText(
      find.byKey(const Key('review_text_field')),
      'Charming.',
    );

    final fifthStar = find.byKey(const ValueKey('star_4'));
    await tester.tapAt(tester.getTopRight(fifthStar) - const Offset(2, -16));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save_review_button')));
    await tester.pumpAndSettle();

    final films = await database.select(database.films).get();
    final reviews = await database.select(database.reviews).get();
    expect(films.single.title, 'Ponyo');
    expect(reviews.single.reviewText, 'Charming.');
    expect(reviews.single.rating, 5.0);
    expect(find.byType(AddEditReviewScreen), findsNothing);
  });

  testWidgets(
    'selecting an existing film via the picker attaches the review to it',
    (tester) async {
      _growTestViewport(tester);
      final database = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      addTearDown(database.close);
      final filmId = await FilmRepository(
        database,
      ).createFilm(title: 'Nausicaä', year: 1984);

      await tester.pumpWidget(
        AppRepositories(
          database: database,
          child: const MaterialApp(home: AddEditReviewScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('film_search_field')),
        'Naus',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nausicaä (1984)').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('review_text_field')),
        'A classic.',
      );
      await tester.tap(find.byKey(const ValueKey('star_2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save_review_button')));
      await tester.pumpAndSettle();

      final reviews = await database.select(database.reviews).get();
      expect(reviews.single.filmId, filmId);
    },
  );
}
