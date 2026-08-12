import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/app_repositories.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/data/repositories/film_repository.dart';
import 'package:local_reviews/data/repositories/review_repository.dart';
import 'package:local_reviews/screens/reviews/reviews_screen.dart';

void main() {
  testWidgets('shows an empty state, then lists reviews most-recent-watch-date first',
      (tester) async {
    final database = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(database.close);
    final filmRepository = FilmRepository(database);
    final reviewRepository = ReviewRepository(database);

    await tester.pumpWidget(
      AppRepositories(
        database: database,
        child: const MaterialApp(home: ReviewsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No reviews yet'), findsOneWidget);

    final filmId = await filmRepository.createFilm(title: 'Aftersun', year: 2022);
    final olderReviewId = await reviewRepository.createReview(
        filmId: filmId, rating: 3, reviewText: 'Old watch.', watchDate: DateTime(2026, 1, 1));
    final recentReviewId = await reviewRepository.createReview(
        filmId: filmId, rating: 5, reviewText: 'Recent watch.', watchDate: DateTime(2026, 5, 1));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNWidgets(2));
    final orderedKeys = find
        .byType(ListTile)
        .evaluate()
        .map((element) => (element.widget.key! as ValueKey).value)
        .toList();
    expect(orderedKeys, ['review_tile_$recentReviewId', 'review_tile_$olderReviewId']);
  });

  testWidgets('tapping the FAB opens Add review', (tester) async {
    final database = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(database.close);

    await tester.pumpWidget(
      AppRepositories(
        database: database,
        child: const MaterialApp(home: ReviewsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_review_fab')));
    await tester.pumpAndSettle();

    expect(find.text('Add review'), findsOneWidget);
  });
}
