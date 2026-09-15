import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/app_repositories.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/data/repositories/film_repository.dart';
import 'package:local_reviews/data/repositories/review_repository.dart';
import 'package:local_reviews/screens/films/film_detail_screen.dart';
import 'package:local_reviews/services/poster_cipher_service.dart';
import 'package:local_reviews/services/poster_storage_service.dart';

PosterStorageService _testPosterStorageService() => PosterStorageService(
      cipherService: PosterCipherService(SecretKey(List.generate(32, (i) => i))),
    );

void main() {
  testWidgets('delete confirmation states how many reviews will be removed',
      (tester) async {
    final database = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(database.close);
    final filmRepository = FilmRepository(
      database,
      posterStorageService: _testPosterStorageService(),
    );
    final reviewRepository = ReviewRepository(database);

    final filmId = await filmRepository.createFilm(title: 'Deletable', year: 2005);
    await reviewRepository.createReview(
        filmId: filmId, rating: 3, reviewText: 'Fine.', watchDate: DateTime(2026, 1, 1));
    await reviewRepository.createReview(
        filmId: filmId, rating: 4, reviewText: 'Rewatch.', watchDate: DateTime(2026, 2, 1));

    await tester.pumpWidget(
      AppRepositories(
        database: database,
        posterStorageService: _testPosterStorageService(),
        child: MaterialApp(home: FilmDetailScreen(filmId: filmId)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('delete_film_button')));
    await tester.pumpAndSettle();

    expect(find.text('This will also delete 2 reviews for this film.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm_delete_film_button')));
    await tester.pumpAndSettle();

    expect(await filmRepository.getFilmById(filmId), isNull);
  });
}
