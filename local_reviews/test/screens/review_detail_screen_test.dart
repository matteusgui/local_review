import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/app_repositories.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/data/repositories/film_repository.dart';
import 'package:local_reviews/data/repositories/review_repository.dart';
import 'package:local_reviews/screens/reviews/review_detail_screen.dart';

void main() {
  testWidgets('shows review details and deletes on confirmation', (
    tester,
  ) async {
    final database = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(database.close);
    final filmRepository = FilmRepository(database);
    final reviewRepository = ReviewRepository(database);

    final filmId = await filmRepository.createFilm(
      title: 'Paterson',
      year: 2016,
    );
    final reviewId = await reviewRepository.createReview(
      filmId: filmId,
      rating: 4,
      reviewText: 'Quietly lovely.',
      watchDate: DateTime(2026, 4, 1),
    );

    await tester.pumpWidget(
      AppRepositories(
        database: database,
        child: MaterialApp(home: ReviewDetailScreen(reviewId: reviewId)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paterson (2016)'), findsOneWidget);
    expect(find.text('Quietly lovely.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete_review_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete_review_button')));
    await tester.pumpAndSettle();

    // A plain one-shot get() is used here rather than
    // reviewRepository.watchReviewsForFilm(filmId).first: opening a *new*
    // watch() stream while ReviewDetailScreen's own StreamBuilder still has
    // an active watch() subscription on the same connection deadlocks the
    // addTearDown(database.close) call above under flutter_test's widget
    // test environment (reproduced independently of this test's delete
    // flow — even a bare `mount, then watch().first` hangs the same way).
    // This does not change what's being verified: the review row is gone.
    final remaining = await (database.select(
      database.reviews,
    )..where((r) => r.filmId.equals(filmId))).get();
    expect(remaining, isEmpty);
  });
}
