import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/data/repositories/film_repository.dart';
import 'package:local_reviews/data/repositories/review_repository.dart';
import 'package:local_reviews/services/poster_cipher_service.dart';
import 'package:local_reviews/services/poster_storage_service.dart';

import 'database_test.dart' show openTestDatabase;

void main() {
  late AppDatabase database;
  late FilmRepository filmRepository;
  late ReviewRepository reviewRepository;

  setUp(() {
    database = openTestDatabase();
    filmRepository = FilmRepository(
      database,
      posterStorageService: PosterStorageService(
        cipherService: PosterCipherService(SecretKey(List.generate(32, (i) => i))),
      ),
    );
    reviewRepository = ReviewRepository(database);
  });
  tearDown(() => database.close());

  test('watchAllReviews sorts by watch date, most recent first', () async {
    final filmId = await filmRepository.createFilm(title: 'A Film', year: 2020);
    await reviewRepository.createReview(
      filmId: filmId,
      rating: 3,
      reviewText: 'First watch.',
      watchDate: DateTime(2026, 1, 1),
    );
    await reviewRepository.createReview(
      filmId: filmId,
      rating: 4.5,
      reviewText: 'Rewatch, liked it more.',
      watchDate: DateTime(2026, 3, 1),
    );

    final reviews = await reviewRepository.watchAllReviews().first;
    expect(reviews.map((r) => r.review.reviewText).toList(),
        ['Rewatch, liked it more.', 'First watch.']);
    expect(reviews.every((r) => r.film.title == 'A Film'), isTrue);
  });

  test('a film can have multiple reviews (rewatches)', () async {
    final filmId = await filmRepository.createFilm(title: 'Rewatched', year: 2015);
    await reviewRepository.createReview(
        filmId: filmId, rating: 3, reviewText: 'Ok.', watchDate: DateTime(2026, 1, 1));
    await reviewRepository.createReview(
        filmId: filmId, rating: 5, reviewText: 'Loved it this time.', watchDate: DateTime(2026, 2, 1));

    final reviews = await reviewRepository.watchReviewsForFilm(filmId).first;
    expect(reviews, hasLength(2));
  });

  test('updateReview changes rating, text, and watch date', () async {
    final filmId = await filmRepository.createFilm(title: 'Edit Me', year: 2018);
    final reviewId = await reviewRepository.createReview(
        filmId: filmId, rating: 2, reviewText: 'Meh.', watchDate: DateTime(2026, 1, 1));

    await reviewRepository.updateReview(
      id: reviewId,
      rating: 4,
      reviewText: 'Grew on me.',
      watchDate: DateTime(2026, 1, 2),
    );

    final reviews = await reviewRepository.watchReviewsForFilm(filmId).first;
    expect(reviews.single.rating, 4);
    expect(reviews.single.reviewText, 'Grew on me.');
  });

  test('deleteReview removes only that review', () async {
    final filmId = await filmRepository.createFilm(title: 'Two Reviews', year: 2019);
    final keepId = await reviewRepository.createReview(
        filmId: filmId, rating: 3, reviewText: 'Keep.', watchDate: DateTime(2026, 1, 1));
    final removeId = await reviewRepository.createReview(
        filmId: filmId, rating: 1, reviewText: 'Remove.', watchDate: DateTime(2026, 1, 2));

    await reviewRepository.deleteReview(removeId);

    final reviews = await reviewRepository.watchReviewsForFilm(filmId).first;
    expect(reviews.map((r) => r.id).toList(), [keepId]);
  });
}
