import 'package:drift/drift.dart';

import '../database.dart';

class ReviewWithFilm {
  const ReviewWithFilm({required this.review, required this.film});

  final Review review;
  final Film film;
}

class ReviewRepository {
  ReviewRepository(this._db);

  final AppDatabase _db;

  Stream<List<ReviewWithFilm>> watchAllReviews() {
    final query = _db.select(_db.reviews).join([
      innerJoin(_db.films, _db.films.id.equalsExp(_db.reviews.filmId)),
    ])
      ..orderBy([
        OrderingTerm(expression: _db.reviews.watchDate, mode: OrderingMode.desc),
        OrderingTerm(expression: _db.reviews.createdAt, mode: OrderingMode.desc),
      ]);
    return query.watch().map((rows) => rows
        .map((row) => ReviewWithFilm(
              review: row.readTable(_db.reviews),
              film: row.readTable(_db.films),
            ))
        .toList());
  }

  Stream<List<Review>> watchReviewsForFilm(int filmId) {
    final query = _db.select(_db.reviews)
      ..where((r) => r.filmId.equals(filmId))
      ..orderBy([(r) => OrderingTerm(expression: r.watchDate, mode: OrderingMode.desc)]);
    return query.watch();
  }

  Future<int> createReview({
    required int filmId,
    required double rating,
    required String reviewText,
    required DateTime watchDate,
  }) {
    return _db.into(_db.reviews).insert(ReviewsCompanion.insert(
          filmId: filmId,
          rating: rating,
          reviewText: reviewText,
          watchDate: watchDate,
        ));
  }

  Future<void> updateReview({
    required int id,
    required double rating,
    required String reviewText,
    required DateTime watchDate,
  }) {
    return (_db.update(_db.reviews)..where((r) => r.id.equals(id))).write(
      ReviewsCompanion(
        rating: Value(rating),
        reviewText: Value(reviewText),
        watchDate: Value(watchDate),
      ),
    );
  }

  Future<void> deleteReview(int id) =>
      (_db.delete(_db.reviews)..where((r) => r.id.equals(id))).go();
}
