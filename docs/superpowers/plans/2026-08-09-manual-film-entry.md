# Manual Film Entry & Reviews Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users manually create films and write reviews against them, entirely on-device, with no external API dependency — the local-first MVP described in `docs/superpowers/specs/2026-08-09-manual-film-entry-design.md`.

**Architecture:** A Drift (SQLite) database with `Films`/`Genres`/`FilmGenres`/`Reviews` tables, wrapped by thin `FilmRepository`/`ReviewRepository` classes exposing reactive `Stream`s for reads. A single `AppDatabase` instance is created in `main.dart` and handed to the widget tree via an `AppRepositories` `InheritedWidget`. Screens consume repository streams directly through `StreamBuilder` — no separate state-management package.

**Tech Stack:** Flutter (Dart SDK ^3.12.2), `drift` + `drift_flutter` (SQLite), `image_picker` + `path_provider` (poster images), `flutter_test` (widget tests and repository tests — see amendment below), `drift`'s in-memory `NativeDatabase` (repository tests).

## Global Constraints

- All commands in this plan run from the `local_reviews/` directory (the Flutter project root), not the repo root — see `CLAUDE.md`.
- Target platforms: Android, iOS, Linux, macOS, Windows. No web support in this feature (per spec Scope).
- Pin these dependency versions (current as of plan authoring — verified against pub.dev/Drift docs):
  - `drift: ^2.34.2`, `drift_flutter: ^0.3.1`, `path_provider: ^2.1.6`, `path: ^1.9.0`, `image_picker: ^1.2.3`
  - dev: `drift_dev: ^2.34.5`, `build_runner: ^2.15.1` (amended during Task 1 — see below)
- **Amendment (post-Task 1, human-approved):** `build_runner: ^2.15.2` does not resolve on this Flutter SDK (3.44.6) — it needs `analyzer >=13.3.0` → `meta ^1.18.3`, but this SDK pins `meta` to exactly `1.18.0`. Use `build_runner: ^2.15.1` instead (same minor line, `flutter pub get` confirmed this is the resolvable version). Separately, `package:test` (specified above for repository tests) does not resolve alongside `drift_dev`'s analyzer requirement and this SDK's exact `test_api` pin — no version of `test` satisfies both. Use `package:flutter_test/flutter_test.dart` for repository tests instead (ships with the SDK, equivalent `test`/`group`/`setUp`/`expect` API); if a repository test needs `DatabaseConnection` from `package:drift/native.dart`, add `import 'package:drift/drift.dart' hide isNull;` to avoid an ambiguous import against `flutter_test`'s `isNull` matcher.
- Year validation range: 1888 through `DateTime.now().year + 1` (per spec).
- Rating range: 0.5–5.0 in 0.5 increments (per spec).
- Genre seed list (exact, fixed order): Action, Comedy, Drama, Horror, Sci-Fi, Documentary, Animation, Thriller, Romance, Fantasy.
- Cascade delete (film → its reviews and film-genre links) is enforced via SQLite `ON DELETE CASCADE` foreign keys, which requires `PRAGMA foreign_keys = ON` to be set on every connection (SQLite does not enable FK enforcement by default) — done in `AppDatabase`'s `beforeOpen` migration hook.
- Poster picking uses `ImageSource.gallery` only. `image_picker`'s desktop implementations (Linux/macOS/Windows) don't support `ImageSource.camera` without a custom capture delegate — out of scope for this MVP; gallery picking works uniformly on all five target platforms.
- The Add/Edit Review film picker (`Autocomplete<Film>`) filters an already-loaded, `StreamBuilder`-provided film list client-side, because `Autocomplete`'s `optionsBuilder` must return results synchronously. `FilmRepository.searchFilmsByTitle` (a real SQL `LIKE` query) still exists as part of the repository's public API per the spec and is covered by its own repository test — the UI just doesn't need it while the film list is small enough to filter in memory.
- No comments in code except where a non-obvious constraint (like the two above) needs explaining. Don't add doc comments describing what a function obviously does.

---

### Task 1: Dependencies + Films/Genres/FilmGenres schema

**Files:**
- Modify: `local_reviews/pubspec.yaml`
- Create: `local_reviews/lib/data/database.dart`
- Test: `local_reviews/test/data/database_test.dart`

**Interfaces:**
- Produces: `AppDatabase` class (Drift `@DriftDatabase`), tables `films`, `genres`, `filmGenres` accessible as `AppDatabase` getters; generated row classes `Film`, `Genre`, `FilmGenre`; generated companion classes `FilmsCompanion`, `GenresCompanion`, `FilmGenresCompanion`; top-level `const seedGenreNames` (`List<String>`, the 10 names from Global Constraints).

- [ ] **Step 1: Add dependencies to pubspec.yaml**

Edit `local_reviews/pubspec.yaml`, in the `dependencies:` block (after the existing `cupertino_icons` entry):

```yaml
  drift: ^2.34.2
  drift_flutter: ^0.3.1
  path_provider: ^2.1.6
  path: ^1.9.0
```

In the `dev_dependencies:` block (after `flutter_lints`):

```yaml
  drift_dev: ^2.34.5
  build_runner: ^2.15.2
```

Run: `cd local_reviews && flutter pub get`
Expected: Resolves and writes `pubspec.lock` with no errors.

- [ ] **Step 2: Write the database schema**

Create `local_reviews/lib/data/database.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Films extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  IntColumn get year => integer()();
  TextColumn get director => text().nullable()();
  TextColumn get posterPath => text().nullable()();
}

class Genres extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class FilmGenres extends Table {
  IntColumn get filmId =>
      integer().references(Films, #id, onDelete: KeyAction.cascade)();
  IntColumn get genreId =>
      integer().references(Genres, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {filmId, genreId};
}

const seedGenreNames = [
  'Action',
  'Comedy',
  'Drama',
  'Horror',
  'Sci-Fi',
  'Documentary',
  'Animation',
  'Thriller',
  'Romance',
  'Fantasy',
];

@DriftDatabase(tables: [Films, Genres, FilmGenres])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await batch((batch) {
            batch.insertAll(
              genres,
              seedGenreNames.map((name) => GenresCompanion.insert(name: name)),
            );
          });
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'local_reviews',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
```

- [ ] **Step 3: Generate Drift code**

Run: `cd local_reviews && dart run build_runner build --delete-conflicting-outputs`
Expected: Creates `local_reviews/lib/data/database.g.dart` with no errors.

- [ ] **Step 4: Write the failing test**

Create `local_reviews/test/data/database_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:local_reviews/data/database.dart';
import 'package:test/test.dart';

AppDatabase openTestDatabase() => AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

void main() {
  late AppDatabase database;

  setUp(() => database = openTestDatabase());
  tearDown(() => database.close());

  test('genres are seeded on creation', () async {
    final genres = await database.select(database.genres).get();
    expect(genres.map((g) => g.name).toList(), seedGenreNames);
  });

  test('a film can be inserted and read back', () async {
    final id = await database.into(database.films).insert(
          FilmsCompanion.insert(title: 'Paprika', year: 2006),
        );
    final film = await (database.select(database.films)
          ..where((f) => f.id.equals(id)))
        .getSingle();
    expect(film.title, 'Paprika');
    expect(film.year, 2006);
    expect(film.director, isNull);
  });
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd local_reviews && flutter test test/data/database_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 6: Commit**

```bash
git add local_reviews/pubspec.yaml local_reviews/pubspec.lock local_reviews/lib/data/database.dart local_reviews/lib/data/database.g.dart local_reviews/test/data/database_test.dart
git commit -m "Add Drift schema for films and genres"
```

---

### Task 2: Reviews table + cascade delete

**Files:**
- Modify: `local_reviews/lib/data/database.dart`
- Modify: `local_reviews/test/data/database_test.dart`

**Interfaces:**
- Consumes: `Films`, `Genres`, `FilmGenres` tables, `seedGenreNames` (Task 1).
- Produces: `Reviews` table; generated row class `Review`; generated companion `ReviewsCompanion`.

- [ ] **Step 1: Write the failing test**

Add to `local_reviews/test/data/database_test.dart` (inside `main()`, after the existing tests):

```dart
  test('deleting a film cascades to delete its reviews', () async {
    final filmId = await database.into(database.films).insert(
          FilmsCompanion.insert(title: 'Perfect Blue', year: 1997),
        );
    await database.into(database.reviews).insert(
          ReviewsCompanion.insert(
            filmId: filmId,
            rating: 4.5,
            text: 'Tense and beautifully animated.',
            watchDate: DateTime(2026, 1, 5),
          ),
        );

    await (database.delete(database.films)..where((f) => f.id.equals(filmId)))
        .go();

    final remainingReviews = await database.select(database.reviews).get();
    expect(remainingReviews, isEmpty);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd local_reviews && flutter test test/data/database_test.dart`
Expected: FAIL — `Reviews`/`ReviewsCompanion` undefined (table doesn't exist yet).

- [ ] **Step 3: Add the Reviews table**

In `local_reviews/lib/data/database.dart`, add after the `FilmGenres` class:

```dart
class Reviews extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get filmId =>
      integer().references(Films, #id, onDelete: KeyAction.cascade)();
  RealColumn get rating => real()();
  TextColumn get text => text()();
  DateTimeColumn get watchDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

Change the `@DriftDatabase` annotation to include it:

```dart
@DriftDatabase(tables: [Films, Genres, FilmGenres, Reviews])
```

- [ ] **Step 4: Regenerate Drift code**

Run: `cd local_reviews && dart run build_runner build --delete-conflicting-outputs`
Expected: Regenerates `database.g.dart` with no errors.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd local_reviews && flutter test test/data/database_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 6: Commit**

```bash
git add local_reviews/lib/data/database.dart local_reviews/lib/data/database.g.dart local_reviews/test/data/database_test.dart
git commit -m "Add Reviews table with cascade delete from Films"
```

---

### Task 3: FilmRepository

**Files:**
- Create: `local_reviews/lib/data/repositories/film_repository.dart`
- Test: `local_reviews/test/data/film_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `Films`, `Genres`, `FilmGenres`, `Film`, `Genre`, `FilmsCompanion`, `FilmGenresCompanion` (Task 1).
- Produces: `FilmWithGenres` class (`film: Film`, `genres: List<Genre>`); `FilmRepository` class with:
  - `FilmRepository(AppDatabase db)`
  - `Stream<List<FilmWithGenres>> watchAllFilms()`
  - `Stream<List<Genre>> watchAllGenres()`
  - `Future<FilmWithGenres?> getFilmById(int id)`
  - `Future<int> createFilm({required String title, required int year, String? director, String? posterPath, List<int> genreIds = const []})`
  - `Future<void> updateFilm({required int id, required String title, required int year, String? director, String? posterPath, List<int> genreIds = const []})`
  - `Future<void> deleteFilm(int id)`
  - `Future<int> reviewCountForFilm(int filmId)` (defined here so Task 12's delete-confirmation dialog doesn't need `ReviewRepository`)
  - `Future<List<Film>> searchFilmsByTitle(String query)`

- [ ] **Step 1: Write the failing test**

Create `local_reviews/test/data/film_repository_test.dart`:

```dart
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/data/repositories/film_repository.dart';
import 'package:test/test.dart';

import 'database_test.dart' show openTestDatabase;

void main() {
  late AppDatabase database;
  late FilmRepository repository;

  setUp(() {
    database = openTestDatabase();
    repository = FilmRepository(database);
  });
  tearDown(() => database.close());

  test('createFilm stores the film and its genres', () async {
    final allGenres = await repository.watchAllGenres().first;
    final action = allGenres.firstWhere((g) => g.name == 'Action');
    final scifi = allGenres.firstWhere((g) => g.name == 'Sci-Fi');

    final id = await repository.createFilm(
      title: 'Akira',
      year: 1988,
      director: 'Katsuhiro Otomo',
      genreIds: [action.id, scifi.id],
    );

    final result = await repository.getFilmById(id);
    expect(result, isNotNull);
    expect(result!.film.title, 'Akira');
    expect(result.genres.map((g) => g.name).toSet(), {'Action', 'Sci-Fi'});
  });

  test('updateFilm replaces fields and genre associations', () async {
    final allGenres = await repository.watchAllGenres().first;
    final drama = allGenres.firstWhere((g) => g.name == 'Drama');
    final comedy = allGenres.firstWhere((g) => g.name == 'Comedy');

    final id = await repository.createFilm(
      title: 'Working Title',
      year: 2000,
      genreIds: [drama.id],
    );

    await repository.updateFilm(
      id: id,
      title: 'Final Title',
      year: 2001,
      genreIds: [comedy.id],
    );

    final result = await repository.getFilmById(id);
    expect(result!.film.title, 'Final Title');
    expect(result.film.year, 2001);
    expect(result.genres.map((g) => g.name).toList(), ['Comedy']);
  });

  test('deleteFilm removes the film', () async {
    final id = await repository.createFilm(title: 'Throwaway', year: 2020);
    await repository.deleteFilm(id);
    expect(await repository.getFilmById(id), isNull);
  });

  test('reviewCountForFilm counts reviews for that film only', () async {
    final filmId = await repository.createFilm(title: 'Counted', year: 2010);
    final otherFilmId = await repository.createFilm(title: 'Other', year: 2011);
    await database.into(database.reviews).insert(
          ReviewsCompanion.insert(
            filmId: filmId,
            rating: 3,
            text: 'Fine.',
            watchDate: DateTime(2026, 1, 1),
          ),
        );
    await database.into(database.reviews).insert(
          ReviewsCompanion.insert(
            filmId: otherFilmId,
            rating: 5,
            text: 'Great.',
            watchDate: DateTime(2026, 1, 2),
          ),
        );

    expect(await repository.reviewCountForFilm(filmId), 1);
  });

  test('searchFilmsByTitle matches a case-insensitive substring', () async {
    await repository.createFilm(title: 'Spirited Away', year: 2001);
    await repository.createFilm(title: 'Princess Mononoke', year: 1997);

    final results = await repository.searchFilmsByTitle('spirit');
    expect(results.map((f) => f.title).toList(), ['Spirited Away']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd local_reviews && flutter test test/data/film_repository_test.dart`
Expected: FAIL — `package:local_reviews/data/repositories/film_repository.dart` doesn't exist.

- [ ] **Step 3: Implement FilmRepository**

Create `local_reviews/lib/data/repositories/film_repository.dart`:

```dart
import 'package:drift/drift.dart';

import '../database.dart';

class FilmWithGenres {
  const FilmWithGenres({required this.film, required this.genres});

  final Film film;
  final List<Genre> genres;
}

class FilmRepository {
  FilmRepository(this._db);

  final AppDatabase _db;

  Stream<List<Genre>> watchAllGenres() => _db.select(_db.genres).watch();

  Stream<List<FilmWithGenres>> watchAllFilms() {
    final query = _db.select(_db.films)
      ..orderBy([(f) => OrderingTerm(expression: f.title)]);
    return query.watch().asyncMap((films) async {
      final result = <FilmWithGenres>[];
      for (final film in films) {
        result.add(FilmWithGenres(film: film, genres: await _genresForFilm(film.id)));
      }
      return result;
    });
  }

  Future<FilmWithGenres?> getFilmById(int id) async {
    final film = await (_db.select(_db.films)..where((f) => f.id.equals(id)))
        .getSingleOrNull();
    if (film == null) return null;
    return FilmWithGenres(film: film, genres: await _genresForFilm(id));
  }

  Future<List<Genre>> _genresForFilm(int filmId) async {
    final query = _db.select(_db.filmGenres).join([
      innerJoin(_db.genres, _db.genres.id.equalsExp(_db.filmGenres.genreId)),
    ])
      ..where(_db.filmGenres.filmId.equals(filmId));
    final rows = await query.get();
    return rows.map((row) => row.readTable(_db.genres)).toList();
  }

  Future<int> createFilm({
    required String title,
    required int year,
    String? director,
    String? posterPath,
    List<int> genreIds = const [],
  }) {
    return _db.transaction(() async {
      final id = await _db.into(_db.films).insert(FilmsCompanion.insert(
            title: title,
            year: year,
            director: Value(director),
            posterPath: Value(posterPath),
          ));
      await _linkGenres(id, genreIds);
      return id;
    });
  }

  Future<void> updateFilm({
    required int id,
    required String title,
    required int year,
    String? director,
    String? posterPath,
    List<int> genreIds = const [],
  }) {
    return _db.transaction(() async {
      await (_db.update(_db.films)..where((f) => f.id.equals(id))).write(
        FilmsCompanion(
          title: Value(title),
          year: Value(year),
          director: Value(director),
          posterPath: Value(posterPath),
        ),
      );
      await (_db.delete(_db.filmGenres)..where((fg) => fg.filmId.equals(id))).go();
      await _linkGenres(id, genreIds);
    });
  }

  Future<void> _linkGenres(int filmId, List<int> genreIds) {
    if (genreIds.isEmpty) return Future.value();
    return _db.batch((batch) {
      batch.insertAll(
        _db.filmGenres,
        genreIds.map((genreId) =>
            FilmGenresCompanion.insert(filmId: filmId, genreId: genreId)),
      );
    });
  }

  Future<void> deleteFilm(int id) =>
      (_db.delete(_db.films)..where((f) => f.id.equals(id))).go();

  Future<int> reviewCountForFilm(int filmId) async {
    final reviews = await (_db.select(_db.reviews)
          ..where((r) => r.filmId.equals(filmId)))
        .get();
    return reviews.length;
  }

  Future<List<Film>> searchFilmsByTitle(String query) {
    final likePattern = '%$query%';
    return (_db.select(_db.films)
          ..where((f) => f.title.like(likePattern)))
        .get();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd local_reviews && flutter test test/data/film_repository_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/data/repositories/film_repository.dart local_reviews/test/data/film_repository_test.dart
git commit -m "Add FilmRepository"
```

---

### Task 4: ReviewRepository

**Files:**
- Create: `local_reviews/lib/data/repositories/review_repository.dart`
- Test: `local_reviews/test/data/review_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `Films`, `Reviews`, `Film`, `Review`, `ReviewsCompanion` (Task 1/2).
- Produces: `ReviewWithFilm` class (`review: Review`, `film: Film`); `ReviewRepository` class with:
  - `ReviewRepository(AppDatabase db)`
  - `Stream<List<ReviewWithFilm>> watchAllReviews()` (sorted by `watchDate` desc, then `createdAt` desc)
  - `Stream<List<Review>> watchReviewsForFilm(int filmId)`
  - `Future<int> createReview({required int filmId, required double rating, required String text, required DateTime watchDate})`
  - `Future<void> updateReview({required int id, required double rating, required String text, required DateTime watchDate})`
  - `Future<void> deleteReview(int id)`

- [ ] **Step 1: Write the failing test**

Create `local_reviews/test/data/review_repository_test.dart`:

```dart
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/data/repositories/film_repository.dart';
import 'package:local_reviews/data/repositories/review_repository.dart';
import 'package:test/test.dart';

import 'database_test.dart' show openTestDatabase;

void main() {
  late AppDatabase database;
  late FilmRepository filmRepository;
  late ReviewRepository reviewRepository;

  setUp(() {
    database = openTestDatabase();
    filmRepository = FilmRepository(database);
    reviewRepository = ReviewRepository(database);
  });
  tearDown(() => database.close());

  test('watchAllReviews sorts by watch date, most recent first', () async {
    final filmId = await filmRepository.createFilm(title: 'A Film', year: 2020);
    await reviewRepository.createReview(
      filmId: filmId,
      rating: 3,
      text: 'First watch.',
      watchDate: DateTime(2026, 1, 1),
    );
    await reviewRepository.createReview(
      filmId: filmId,
      rating: 4.5,
      text: 'Rewatch, liked it more.',
      watchDate: DateTime(2026, 3, 1),
    );

    final reviews = await reviewRepository.watchAllReviews().first;
    expect(reviews.map((r) => r.review.text).toList(),
        ['Rewatch, liked it more.', 'First watch.']);
    expect(reviews.every((r) => r.film.title == 'A Film'), isTrue);
  });

  test('a film can have multiple reviews (rewatches)', () async {
    final filmId = await filmRepository.createFilm(title: 'Rewatched', year: 2015);
    await reviewRepository.createReview(
        filmId: filmId, rating: 3, text: 'Ok.', watchDate: DateTime(2026, 1, 1));
    await reviewRepository.createReview(
        filmId: filmId, rating: 5, text: 'Loved it this time.', watchDate: DateTime(2026, 2, 1));

    final reviews = await reviewRepository.watchReviewsForFilm(filmId).first;
    expect(reviews, hasLength(2));
  });

  test('updateReview changes rating, text, and watch date', () async {
    final filmId = await filmRepository.createFilm(title: 'Edit Me', year: 2018);
    final reviewId = await reviewRepository.createReview(
        filmId: filmId, rating: 2, text: 'Meh.', watchDate: DateTime(2026, 1, 1));

    await reviewRepository.updateReview(
      id: reviewId,
      rating: 4,
      text: 'Grew on me.',
      watchDate: DateTime(2026, 1, 2),
    );

    final reviews = await reviewRepository.watchReviewsForFilm(filmId).first;
    expect(reviews.single.rating, 4);
    expect(reviews.single.text, 'Grew on me.');
  });

  test('deleteReview removes only that review', () async {
    final filmId = await filmRepository.createFilm(title: 'Two Reviews', year: 2019);
    final keepId = await reviewRepository.createReview(
        filmId: filmId, rating: 3, text: 'Keep.', watchDate: DateTime(2026, 1, 1));
    final removeId = await reviewRepository.createReview(
        filmId: filmId, rating: 1, text: 'Remove.', watchDate: DateTime(2026, 1, 2));

    await reviewRepository.deleteReview(removeId);

    final reviews = await reviewRepository.watchReviewsForFilm(filmId).first;
    expect(reviews.map((r) => r.id).toList(), [keepId]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd local_reviews && flutter test test/data/review_repository_test.dart`
Expected: FAIL — `package:local_reviews/data/repositories/review_repository.dart` doesn't exist.

- [ ] **Step 3: Implement ReviewRepository**

Create `local_reviews/lib/data/repositories/review_repository.dart`:

```dart
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
    required String text,
    required DateTime watchDate,
  }) {
    return _db.into(_db.reviews).insert(ReviewsCompanion.insert(
          filmId: filmId,
          rating: rating,
          text: text,
          watchDate: watchDate,
        ));
  }

  Future<void> updateReview({
    required int id,
    required double rating,
    required String text,
    required DateTime watchDate,
  }) {
    return (_db.update(_db.reviews)..where((r) => r.id.equals(id))).write(
      ReviewsCompanion(
        rating: Value(rating),
        text: Value(text),
        watchDate: Value(watchDate),
      ),
    );
  }

  Future<void> deleteReview(int id) =>
      (_db.delete(_db.reviews)..where((r) => r.id.equals(id))).go();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd local_reviews && flutter test test/data/review_repository_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/data/repositories/review_repository.dart local_reviews/test/data/review_repository_test.dart
git commit -m "Add ReviewRepository"
```

---

### Task 5: PosterStorageService

**Files:**
- Create: `local_reviews/lib/services/poster_storage_service.dart`
- Test: `local_reviews/test/services/poster_storage_service_test.dart`

**Interfaces:**
- Produces: `PosterStorageService` class with:
  - `PosterStorageService({Future<Directory> Function()? documentsDirectory})`
  - `Future<String> savePoster(File sourceFile)` — copies the file into `<documents dir>/posters/<unique name>`, returns the new path.
  - `Future<void> deletePoster(String posterPath)`

- [ ] **Step 1: Write the failing test**

Create `local_reviews/test/services/poster_storage_service_test.dart`:

```dart
import 'dart:io';

import 'package:local_reviews/services/poster_storage_service.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late PosterStorageService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('poster_storage_test');
    service = PosterStorageService(documentsDirectory: () async => tempDir);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  test('savePoster copies the file into a posters subdirectory', () async {
    final source = File(p.join(tempDir.path, 'source.jpg'))
      ..writeAsBytesSync([1, 2, 3]);

    final savedPath = await service.savePoster(source);

    expect(savedPath, contains('${p.separator}posters${p.separator}'));
    expect(File(savedPath).readAsBytesSync(), [1, 2, 3]);
  });

  test('two saved posters get different paths', () async {
    final source = File(p.join(tempDir.path, 'source.jpg'))
      ..writeAsBytesSync([1]);

    final firstPath = await service.savePoster(source);
    final secondPath = await service.savePoster(source);

    expect(firstPath, isNot(secondPath));
  });

  test('deletePoster removes the file', () async {
    final source = File(p.join(tempDir.path, 'source.jpg'))
      ..writeAsBytesSync([1]);
    final savedPath = await service.savePoster(source);

    await service.deletePoster(savedPath);

    expect(File(savedPath).existsSync(), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd local_reviews && flutter test test/services/poster_storage_service_test.dart`
Expected: FAIL — `package:local_reviews/services/poster_storage_service.dart` doesn't exist.

- [ ] **Step 3: Implement PosterStorageService**

Create `local_reviews/lib/services/poster_storage_service.dart`:

```dart
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PosterStorageService {
  PosterStorageService({Future<Directory> Function()? documentsDirectory})
      : _documentsDirectory = documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  Future<String> savePoster(File sourceFile) async {
    final documentsDir = await _documentsDirectory();
    final postersDir = Directory(p.join(documentsDir.path, 'posters'));
    if (!await postersDir.exists()) {
      await postersDir.create(recursive: true);
    }
    final destinationPath =
        p.join(postersDir.path, '${_uniqueFileName()}${p.extension(sourceFile.path)}');
    final savedFile = await sourceFile.copy(destinationPath);
    return savedFile.path;
  }

  Future<void> deletePoster(String posterPath) async {
    final file = File(posterPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _uniqueFileName() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomSuffix = Random().nextInt(1 << 32);
    return '$timestamp-$randomSuffix';
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd local_reviews && flutter test test/services/poster_storage_service_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/services/poster_storage_service.dart local_reviews/test/services/poster_storage_service_test.dart
git commit -m "Add PosterStorageService"
```

---

### Task 6: StarRatingInput widget

**Files:**
- Create: `local_reviews/lib/widgets/star_rating_input.dart`
- Test: `local_reviews/test/widgets/star_rating_input_test.dart`

**Interfaces:**
- Produces: `StarRatingInput` widget with constructor `StarRatingInput({Key? key, required double rating, ValueChanged<double>? onChanged, double size = 32})`. When `onChanged` is null it renders read-only (used for display in list rows); when non-null, tapping the left/right half of star `N` (1-indexed) calls `onChanged` with `N - 0.5` or `N`.

- [ ] **Step 1: Write the failing test**

Create `local_reviews/test/widgets/star_rating_input_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/widgets/star_rating_input.dart';

void main() {
  testWidgets('shows full, half, and empty stars for a 2.5 rating',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: StarRatingInput(rating: 2.5),
    ));

    expect(find.byIcon(Icons.star), findsNWidgets(2));
    expect(find.byIcon(Icons.star_half), findsNWidgets(1));
    expect(find.byIcon(Icons.star_border), findsNWidgets(2));
  });

  testWidgets('tapping the left half of a star reports a half value',
      (tester) async {
    double? reportedRating;
    await tester.pumpWidget(MaterialApp(
      home: StarRatingInput(
        rating: 0,
        onChanged: (value) => reportedRating = value,
      ),
    ));

    final thirdStar = find.byKey(const ValueKey('star_2'));
    final topLeft = tester.getTopLeft(thirdStar);
    await tester.tapAt(topLeft + const Offset(2, 16));
    await tester.pump();

    expect(reportedRating, 2.5);
  });

  testWidgets('tapping the right half of a star reports a whole value',
      (tester) async {
    double? reportedRating;
    await tester.pumpWidget(MaterialApp(
      home: StarRatingInput(
        rating: 0,
        onChanged: (value) => reportedRating = value,
      ),
    ));

    final thirdStar = find.byKey(const ValueKey('star_2'));
    final topRight = tester.getTopRight(thirdStar);
    await tester.tapAt(topRight - const Offset(2, -16));
    await tester.pump();

    expect(reportedRating, 3.0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd local_reviews && flutter test test/widgets/star_rating_input_test.dart`
Expected: FAIL — `package:local_reviews/widgets/star_rating_input.dart` doesn't exist.

- [ ] **Step 3: Implement StarRatingInput**

Create `local_reviews/lib/widgets/star_rating_input.dart`:

```dart
import 'package:flutter/material.dart';

class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 32,
  });

  final double rating;
  final ValueChanged<double>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) => _buildStar(context, index)),
    );
  }

  Widget _buildStar(BuildContext context, int index) {
    final starValue = index + 1;
    final IconData icon;
    if (rating >= starValue) {
      icon = Icons.star;
    } else if (rating >= starValue - 0.5) {
      icon = Icons.star_half;
    } else {
      icon = Icons.star_border;
    }

    final star = Icon(icon, size: size, color: Theme.of(context).colorScheme.primary);
    final handler = onChanged;
    if (handler == null) {
      return star;
    }

    return GestureDetector(
      key: ValueKey('star_$index'),
      onTapUp: (details) {
        final isLeftHalf = details.localPosition.dx < size / 2;
        handler(isLeftHalf ? index + 0.5 : index + 1.0);
      },
      child: SizedBox(width: size, height: size, child: star),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd local_reviews && flutter test test/widgets/star_rating_input_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/widgets/star_rating_input.dart local_reviews/test/widgets/star_rating_input_test.dart
git commit -m "Add StarRatingInput widget"
```

---

### Task 7: PosterThumbnail widget

**Files:**
- Create: `local_reviews/lib/widgets/poster_thumbnail.dart`
- Test: `local_reviews/test/widgets/poster_thumbnail_test.dart`

**Interfaces:**
- Produces: `PosterThumbnail` widget, constructor `PosterThumbnail({Key? key, String? posterPath, double size = 56})`. Shows the image at `posterPath` if it's non-null and the file exists; otherwise shows a placeholder `Icon(Icons.movie_outlined)`.

- [ ] **Step 1: Write the failing test**

Create `local_reviews/test/widgets/poster_thumbnail_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/widgets/poster_thumbnail.dart';

void main() {
  testWidgets('shows a placeholder icon when posterPath is null',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PosterThumbnail()));
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
  });

  testWidgets('shows a placeholder icon when the file does not exist',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PosterThumbnail(posterPath: '/nonexistent/path/poster.jpg'),
    ));
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd local_reviews && flutter test test/widgets/poster_thumbnail_test.dart`
Expected: FAIL — `package:local_reviews/widgets/poster_thumbnail.dart` doesn't exist.

- [ ] **Step 3: Implement PosterThumbnail**

Create `local_reviews/lib/widgets/poster_thumbnail.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';

class PosterThumbnail extends StatelessWidget {
  const PosterThumbnail({super.key, this.posterPath, this.size = 56});

  final String? posterPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = posterPath;
    if (path == null || !File(path).existsSync()) {
      return _placeholder(context);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.file(
        File(path),
        width: size,
        height: size * 1.5,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: size,
      height: size * 1.5,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.movie_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd local_reviews && flutter test test/widgets/poster_thumbnail_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/widgets/poster_thumbnail.dart local_reviews/test/widgets/poster_thumbnail_test.dart
git commit -m "Add PosterThumbnail widget"
```

---

### Task 8: GenreMultiSelect widget

**Files:**
- Create: `local_reviews/lib/widgets/genre_multi_select.dart`
- Test: `local_reviews/test/widgets/genre_multi_select_test.dart`

**Interfaces:**
- Consumes: `Genre` (Task 1).
- Produces: `GenreMultiSelect` widget, constructor `GenreMultiSelect({Key? key, required List<Genre> allGenres, required Set<int> selectedGenreIds, required ValueChanged<Set<int>> onChanged})`. Renders one `FilterChip` per genre; tapping toggles that genre's id in/out of the reported set.

- [ ] **Step 1: Write the failing test**

Create `local_reviews/test/widgets/genre_multi_select_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/widgets/genre_multi_select.dart';

void main() {
  testWidgets('selecting a chip adds its id to the reported set',
      (tester) async {
    Set<int>? reported;
    final genres = [
      Genre(id: 1, name: 'Action'),
      Genre(id: 2, name: 'Comedy'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GenreMultiSelect(
          allGenres: genres,
          selectedGenreIds: const {},
          onChanged: (updated) => reported = updated,
        ),
      ),
    ));

    await tester.tap(find.widgetWithText(FilterChip, 'Action'));
    await tester.pump();

    expect(reported, {1});
  });

  testWidgets('deselecting a chip removes its id', (tester) async {
    Set<int>? reported;
    final genres = [Genre(id: 1, name: 'Action')];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GenreMultiSelect(
          allGenres: genres,
          selectedGenreIds: const {1},
          onChanged: (updated) => reported = updated,
        ),
      ),
    ));

    await tester.tap(find.widgetWithText(FilterChip, 'Action'));
    await tester.pump();

    expect(reported, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd local_reviews && flutter test test/widgets/genre_multi_select_test.dart`
Expected: FAIL — `package:local_reviews/widgets/genre_multi_select.dart` doesn't exist.

- [ ] **Step 3: Implement GenreMultiSelect**

Create `local_reviews/lib/widgets/genre_multi_select.dart`:

```dart
import 'package:flutter/material.dart';

import '../data/database.dart';

class GenreMultiSelect extends StatelessWidget {
  const GenreMultiSelect({
    super.key,
    required this.allGenres,
    required this.selectedGenreIds,
    required this.onChanged,
  });

  final List<Genre> allGenres;
  final Set<int> selectedGenreIds;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: allGenres.map((genre) {
        final selected = selectedGenreIds.contains(genre.id);
        return FilterChip(
          label: Text(genre.name),
          selected: selected,
          onSelected: (isSelected) {
            final updated = Set<int>.from(selectedGenreIds);
            if (isSelected) {
              updated.add(genre.id);
            } else {
              updated.remove(genre.id);
            }
            onChanged(updated);
          },
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd local_reviews && flutter test test/widgets/genre_multi_select_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/widgets/genre_multi_select.dart local_reviews/test/widgets/genre_multi_select_test.dart
git commit -m "Add GenreMultiSelect widget"
```

---

### Task 9: AppRepositories InheritedWidget

**Files:**
- Create: `local_reviews/lib/app_repositories.dart`
- Test: `local_reviews/test/app_repositories_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (Task 1), `FilmRepository` (Task 3), `ReviewRepository` (Task 4), `PosterStorageService` (Task 5).
- Produces: `AppRepositories` (`InheritedWidget`), constructor `AppRepositories({Key? key, required AppDatabase database, required Widget child})`, exposing `database`, `filmRepository`, `reviewRepository`, `posterStorageService` fields and a static `AppRepositories.of(BuildContext context)` accessor. This is how every screen from Task 11 onward reaches the repositories — no repository is passed as a constructor parameter to any screen.

- [ ] **Step 1: Write the failing test**

Create `local_reviews/test/app_repositories_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/app_repositories.dart';
import 'package:local_reviews/data/database.dart';

void main() {
  testWidgets('AppRepositories.of exposes the repositories to descendants',
      (tester) async {
    final database = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(database.close);

    late BuildContext capturedContext;
    await tester.pumpWidget(
      AppRepositories(
        database: database,
        child: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final repos = AppRepositories.of(capturedContext);
    expect(repos.database, database);
    expect(repos.filmRepository, isNotNull);
    expect(repos.reviewRepository, isNotNull);
    expect(repos.posterStorageService, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd local_reviews && flutter test test/app_repositories_test.dart`
Expected: FAIL — `package:local_reviews/app_repositories.dart` doesn't exist.

- [ ] **Step 3: Implement AppRepositories**

Create `local_reviews/lib/app_repositories.dart`:

```dart
import 'package:flutter/widgets.dart';

import 'data/database.dart';
import 'data/repositories/film_repository.dart';
import 'data/repositories/review_repository.dart';
import 'services/poster_storage_service.dart';

class AppRepositories extends InheritedWidget {
  AppRepositories({super.key, required this.database, required super.child})
      : filmRepository = FilmRepository(database),
        reviewRepository = ReviewRepository(database),
        posterStorageService = PosterStorageService();

  final AppDatabase database;
  final FilmRepository filmRepository;
  final ReviewRepository reviewRepository;
  final PosterStorageService posterStorageService;

  static AppRepositories of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<AppRepositories>();
    assert(result != null, 'No AppRepositories found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(AppRepositories oldWidget) => database != oldWidget.database;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd local_reviews && flutter test test/app_repositories_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/app_repositories.dart local_reviews/test/app_repositories_test.dart
git commit -m "Add AppRepositories InheritedWidget"
```

---

### Task 10: FilmFieldsController + FilmFieldsForm

**Files:**
- Create: `local_reviews/lib/widgets/film_fields_form.dart`
- Test: `local_reviews/test/widgets/film_fields_form_test.dart`

**Interfaces:**
- Consumes: `Genre` (Task 1), `PosterStorageService` (Task 5), `GenreMultiSelect` (Task 8), `PosterThumbnail` (Task 7).
- Produces:
  - `FilmFieldsController` — holds `titleController`/`yearController`/`directorController` (`TextEditingController`), `posterPath`/`selectedGenreIds` (`ValueNotifier`), computed getters `title`/`year`/`director`, static validators `validateTitle`/`validateYear`, and `dispose()`. Constructor takes optional `initialTitle`, `initialYear`, `initialDirector`, `initialPosterPath`, `initialGenreIds`.
  - `FilmFieldsForm` widget — constructor `FilmFieldsForm({Key? key, required FilmFieldsController controller, required List<Genre> allGenres, required PosterStorageService posterStorageService})`. Renders the poster picker, title/year/director fields, and genre chips. Used by both Task 11 (`AddEditFilmScreen`) and Task 14 (`AddEditReviewScreen`'s inline new-film form) — this is the DRY point for film-field UI, per the spec's shared-form design.

- [ ] **Step 1: Write the failing test**

Create `local_reviews/test/widgets/film_fields_form_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/services/poster_storage_service.dart';
import 'package:local_reviews/widgets/film_fields_form.dart';

void main() {
  testWidgets('validateTitle rejects empty and accepts non-empty', (tester) async {
    expect(FilmFieldsController.validateTitle(''), isNotNull);
    expect(FilmFieldsController.validateTitle('Alien'), isNull);
  });

  testWidgets('validateYear rejects out-of-range and non-numeric years',
      (tester) async {
    expect(FilmFieldsController.validateYear('1887'), isNotNull);
    expect(FilmFieldsController.validateYear('not a year'), isNotNull);
    expect(FilmFieldsController.validateYear('1979'), isNull);
  });

  testWidgets('typing into the title field updates the controller', (tester) async {
    final controller = FilmFieldsController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FilmFieldsForm(
          controller: controller,
          allGenres: const [],
          posterStorageService: PosterStorageService(),
        ),
      ),
    ));

    await tester.enterText(find.byKey(const Key('film_title_field')), 'Alien');
    expect(controller.title, 'Alien');
  });

  testWidgets('tapping a genre chip updates selectedGenreIds', (tester) async {
    final controller = FilmFieldsController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FilmFieldsForm(
          controller: controller,
          allGenres: [Genre(id: 1, name: 'Horror')],
          posterStorageService: PosterStorageService(),
        ),
      ),
    ));

    await tester.tap(find.widgetWithText(FilterChip, 'Horror'));
    await tester.pump();

    expect(controller.selectedGenreIds.value, {1});
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd local_reviews && flutter test test/widgets/film_fields_form_test.dart`
Expected: FAIL — `package:local_reviews/widgets/film_fields_form.dart` doesn't exist.

- [ ] **Step 3: Implement FilmFieldsController and FilmFieldsForm**

Create `local_reviews/lib/widgets/film_fields_form.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/database.dart';
import '../services/poster_storage_service.dart';
import 'genre_multi_select.dart';
import 'poster_thumbnail.dart';

class FilmFieldsController {
  FilmFieldsController({
    String? initialTitle,
    int? initialYear,
    String? initialDirector,
    String? initialPosterPath,
    Set<int> initialGenreIds = const {},
  })  : titleController = TextEditingController(text: initialTitle ?? ''),
        yearController = TextEditingController(text: initialYear?.toString() ?? ''),
        directorController = TextEditingController(text: initialDirector ?? ''),
        posterPath = ValueNotifier<String?>(initialPosterPath),
        selectedGenreIds = ValueNotifier<Set<int>>(Set<int>.from(initialGenreIds));

  final TextEditingController titleController;
  final TextEditingController yearController;
  final TextEditingController directorController;
  final ValueNotifier<String?> posterPath;
  final ValueNotifier<Set<int>> selectedGenreIds;

  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) return 'Title is required';
    return null;
  }

  static String? validateYear(String? value) {
    if (value == null || value.trim().isEmpty) return 'Year is required';
    final year = int.tryParse(value.trim());
    final maxYear = DateTime.now().year + 1;
    if (year == null || year < 1888 || year > maxYear) {
      return 'Enter a year between 1888 and $maxYear';
    }
    return null;
  }

  String get title => titleController.text.trim();
  int get year => int.parse(yearController.text.trim());
  String? get director =>
      directorController.text.trim().isEmpty ? null : directorController.text.trim();

  void dispose() {
    titleController.dispose();
    yearController.dispose();
    directorController.dispose();
    posterPath.dispose();
    selectedGenreIds.dispose();
  }
}

class FilmFieldsForm extends StatelessWidget {
  const FilmFieldsForm({
    super.key,
    required this.controller,
    required this.allGenres,
    required this.posterStorageService,
  });

  final FilmFieldsController controller;
  final List<Genre> allGenres;
  final PosterStorageService posterStorageService;

  Future<void> _pickPoster() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    controller.posterPath.value = await posterStorageService.savePoster(File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<String?>(
          valueListenable: controller.posterPath,
          builder: (context, posterPath, _) => GestureDetector(
            onTap: _pickPoster,
            child: PosterThumbnail(posterPath: posterPath, size: 96),
          ),
        ),
        TextFormField(
          key: const Key('film_title_field'),
          controller: controller.titleController,
          decoration: const InputDecoration(labelText: 'Title'),
          validator: FilmFieldsController.validateTitle,
        ),
        TextFormField(
          key: const Key('film_year_field'),
          controller: controller.yearController,
          decoration: const InputDecoration(labelText: 'Year'),
          keyboardType: TextInputType.number,
          validator: FilmFieldsController.validateYear,
        ),
        TextFormField(
          key: const Key('film_director_field'),
          controller: controller.directorController,
          decoration: const InputDecoration(labelText: 'Director (optional)'),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<Set<int>>(
          valueListenable: controller.selectedGenreIds,
          builder: (context, selected, _) => GenreMultiSelect(
            allGenres: allGenres,
            selectedGenreIds: selected,
            onChanged: (updated) => controller.selectedGenreIds.value = updated,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd local_reviews && flutter test test/widgets/film_fields_form_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/widgets/film_fields_form.dart local_reviews/test/widgets/film_fields_form_test.dart
git commit -m "Add FilmFieldsController and FilmFieldsForm"
```

---

### Task 11: AddEditFilmScreen

**Files:**
- Create: `local_reviews/lib/screens/films/add_edit_film_screen.dart`
- Test: `local_reviews/test/screens/add_edit_film_screen_test.dart`

**Interfaces:**
- Consumes: `AppRepositories` (Task 9), `FilmFieldsController`/`FilmFieldsForm` (Task 10), `Film`, `Genre` (Task 1).
- Produces: `AddEditFilmScreen` widget, constructor `AddEditFilmScreen({Key? key, Film? existingFilm, Set<int> existingGenreIds = const {}})`. Omitting `existingFilm` means "create"; passing it means "edit". Saving pops the screen.

- [ ] **Step 1: Write the failing test**

Create `local_reviews/test/screens/add_edit_film_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/app_repositories.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/screens/films/add_edit_film_screen.dart';

Future<AppDatabase> pumpScreen(WidgetTester tester, {Widget? screen}) async {
  final database = AppDatabase(
    DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
  );
  addTearDown(database.close);

  await tester.pumpWidget(
    AppRepositories(
      database: database,
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd local_reviews && flutter test test/screens/add_edit_film_screen_test.dart`
Expected: FAIL — `package:local_reviews/screens/films/add_edit_film_screen.dart` doesn't exist.

- [ ] **Step 3: Implement AddEditFilmScreen**

Create `local_reviews/lib/screens/films/add_edit_film_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../app_repositories.dart';
import '../../data/database.dart';
import '../../widgets/film_fields_form.dart';

class AddEditFilmScreen extends StatefulWidget {
  const AddEditFilmScreen({super.key, this.existingFilm, this.existingGenreIds = const {}});

  final Film? existingFilm;
  final Set<int> existingGenreIds;

  @override
  State<AddEditFilmScreen> createState() => AddEditFilmScreenState();
}

class AddEditFilmScreenState extends State<AddEditFilmScreen> {
  final formKey = GlobalKey<FormState>();
  late final FilmFieldsController fieldsController;

  @override
  void initState() {
    super.initState();
    fieldsController = FilmFieldsController(
      initialTitle: widget.existingFilm?.title,
      initialYear: widget.existingFilm?.year,
      initialDirector: widget.existingFilm?.director,
      initialPosterPath: widget.existingFilm?.posterPath,
      initialGenreIds: widget.existingGenreIds,
    );
  }

  @override
  void dispose() {
    fieldsController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    final repos = AppRepositories.of(context);
    if (widget.existingFilm == null) {
      await repos.filmRepository.createFilm(
        title: fieldsController.title,
        year: fieldsController.year,
        director: fieldsController.director,
        posterPath: fieldsController.posterPath.value,
        genreIds: fieldsController.selectedGenreIds.value.toList(),
      );
    } else {
      await repos.filmRepository.updateFilm(
        id: widget.existingFilm!.id,
        title: fieldsController.title,
        year: fieldsController.year,
        director: fieldsController.director,
        posterPath: fieldsController.posterPath.value,
        genreIds: fieldsController.selectedGenreIds.value.toList(),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final repos = AppRepositories.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.existingFilm == null ? 'Add film' : 'Edit film')),
      body: StreamBuilder<List<Genre>>(
        stream: repos.filmRepository.watchAllGenres(),
        builder: (context, snapshot) {
          final allGenres = snapshot.data ?? const <Genre>[];
          return Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilmFieldsForm(
                  controller: fieldsController,
                  allGenres: allGenres,
                  posterStorageService: repos.posterStorageService,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const Key('save_film_button'),
                  onPressed: save,
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd local_reviews && flutter test test/screens/add_edit_film_screen_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/screens/films/add_edit_film_screen.dart local_reviews/test/screens/add_edit_film_screen_test.dart
git commit -m "Add AddEditFilmScreen"
```

---

### Task 12: FilmDetailScreen

**Files:**
- Create: `local_reviews/lib/screens/films/film_detail_screen.dart`
- Test: `local_reviews/test/screens/film_detail_screen_test.dart`

**Interfaces:**
- Consumes: `AppRepositories` (Task 9), `AddEditFilmScreen` (Task 11), `PosterThumbnail` (Task 7), `StarRatingInput` (Task 6).
- Produces: `FilmDetailScreen` widget, constructor `FilmDetailScreen({Key? key, required int filmId})`. Shows film info, its reviews, an edit FAB (opens `AddEditFilmScreen` pre-filled), and a delete button that confirms via dialog (stating cascade review count) before calling `deleteFilm` and popping.

- [ ] **Step 1: Write the failing test**

Create `local_reviews/test/screens/film_detail_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/app_repositories.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/data/repositories/film_repository.dart';
import 'package:local_reviews/data/repositories/review_repository.dart';
import 'package:local_reviews/screens/films/film_detail_screen.dart';

void main() {
  testWidgets('delete confirmation states how many reviews will be removed',
      (tester) async {
    final database = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(database.close);
    final filmRepository = FilmRepository(database);
    final reviewRepository = ReviewRepository(database);

    final filmId = await filmRepository.createFilm(title: 'Deletable', year: 2005);
    await reviewRepository.createReview(
        filmId: filmId, rating: 3, text: 'Fine.', watchDate: DateTime(2026, 1, 1));
    await reviewRepository.createReview(
        filmId: filmId, rating: 4, text: 'Rewatch.', watchDate: DateTime(2026, 2, 1));

    await tester.pumpWidget(
      AppRepositories(
        database: database,
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd local_reviews && flutter test test/screens/film_detail_screen_test.dart`
Expected: FAIL — `package:local_reviews/screens/films/film_detail_screen.dart` doesn't exist.

- [ ] **Step 3: Implement FilmDetailScreen**

Create `local_reviews/lib/screens/films/film_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../app_repositories.dart';
import '../../data/database.dart';
import '../../data/repositories/film_repository.dart';
import '../../widgets/poster_thumbnail.dart';
import '../../widgets/star_rating_input.dart';
import 'add_edit_film_screen.dart';

class FilmDetailScreen extends StatelessWidget {
  const FilmDetailScreen({super.key, required this.filmId});

  final int filmId;

  Future<void> _confirmDelete(BuildContext context) async {
    final repos = AppRepositories.of(context);
    final reviewCount = await repos.filmRepository.reviewCountForFilm(filmId);
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete film?'),
        content: Text(reviewCount == 0
            ? 'This film has no reviews.'
            : 'This will also delete $reviewCount review${reviewCount == 1 ? '' : 's'} for this film.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('confirm_delete_film_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await repos.filmRepository.deleteFilm(filmId);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _editFilm(BuildContext context) async {
    final repos = AppRepositories.of(context);
    final entry = await repos.filmRepository.getFilmById(filmId);
    if (entry == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddEditFilmScreen(
        existingFilm: entry.film,
        existingGenreIds: entry.genres.map((g) => g.id).toSet(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final repos = AppRepositories.of(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            key: const Key('delete_film_button'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: StreamBuilder<List<FilmWithGenres>>(
        stream: repos.filmRepository.watchAllFilms(),
        builder: (context, snapshot) {
          final films = snapshot.data ?? const <FilmWithGenres>[];
          final matches = films.where((f) => f.film.id == filmId);
          if (matches.isEmpty) return const SizedBox.shrink();
          final entry = matches.first;
          return Column(
            children: [
              PosterThumbnail(posterPath: entry.film.posterPath, size: 96),
              Text('${entry.film.title} (${entry.film.year})',
                  style: Theme.of(context).textTheme.headlineSmall),
              if (entry.film.director != null) Text(entry.film.director!),
              Wrap(
                spacing: 4,
                children: entry.genres.map((g) => Chip(label: Text(g.name))).toList(),
              ),
              Expanded(
                child: StreamBuilder<List<Review>>(
                  stream: repos.reviewRepository.watchReviewsForFilm(filmId),
                  builder: (context, reviewSnapshot) {
                    final reviews = reviewSnapshot.data ?? const <Review>[];
                    return ListView.builder(
                      itemCount: reviews.length,
                      itemBuilder: (context, index) {
                        final review = reviews[index];
                        return ListTile(
                          key: ValueKey('review_tile_${review.id}'),
                          title: StarRatingInput(rating: review.rating, size: 16),
                          subtitle: Text(review.text),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('edit_film_fab'),
        onPressed: () => _editFilm(context),
        child: const Icon(Icons.edit),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd local_reviews && flutter test test/screens/film_detail_screen_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/screens/films/film_detail_screen.dart local_reviews/test/screens/film_detail_screen_test.dart
git commit -m "Add FilmDetailScreen"
```

---

### Task 13: FilmsScreen

**Files:**
- Create: `local_reviews/lib/screens/films/films_screen.dart`
- Test: `local_reviews/test/screens/films_screen_test.dart`

**Interfaces:**
- Consumes: `AppRepositories` (Task 9), `AddEditFilmScreen` (Task 11), `FilmDetailScreen` (Task 12), `PosterThumbnail` (Task 7).
- Produces: `FilmsScreen` widget (no constructor params beyond `key`) — the Films library screen: list of all films, FAB to add a new one, tap to open detail.

- [ ] **Step 1: Write the failing test**

Create `local_reviews/test/screens/films_screen_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd local_reviews && flutter test test/screens/films_screen_test.dart`
Expected: FAIL — `package:local_reviews/screens/films/films_screen.dart` doesn't exist.

- [ ] **Step 3: Implement FilmsScreen**

Create `local_reviews/lib/screens/films/films_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../app_repositories.dart';
import '../../data/repositories/film_repository.dart';
import '../../widgets/poster_thumbnail.dart';
import 'add_edit_film_screen.dart';
import 'film_detail_screen.dart';

class FilmsScreen extends StatelessWidget {
  const FilmsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repos = AppRepositories.of(context);
    return Scaffold(
      body: StreamBuilder<List<FilmWithGenres>>(
        stream: repos.filmRepository.watchAllFilms(),
        builder: (context, snapshot) {
          final films = snapshot.data ?? const <FilmWithGenres>[];
          if (films.isEmpty) {
            return const Center(child: Text('No films yet'));
          }
          return ListView.builder(
            itemCount: films.length,
            itemBuilder: (context, index) {
              final entry = films[index];
              return ListTile(
                key: ValueKey('film_tile_${entry.film.id}'),
                leading: PosterThumbnail(posterPath: entry.film.posterPath, size: 40),
                title: Text('${entry.film.title} (${entry.film.year})'),
                subtitle: entry.film.director != null ? Text(entry.film.director!) : null,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FilmDetailScreen(filmId: entry.film.id),
                )),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add_film_fab'),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AddEditFilmScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd local_reviews && flutter test test/screens/films_screen_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/screens/films/films_screen.dart local_reviews/test/screens/films_screen_test.dart
git commit -m "Add FilmsScreen"
```

---

### Task 14: AddEditReviewScreen

**Files:**
- Create: `local_reviews/lib/screens/reviews/add_edit_review_screen.dart`
- Test: `local_reviews/test/screens/add_edit_review_screen_test.dart`

**Interfaces:**
- Consumes: `AppRepositories` (Task 9), `FilmFieldsController`/`FilmFieldsForm` (Task 10), `StarRatingInput` (Task 6), `Film`, `Review`, `FilmWithGenres`, `Genre` (Tasks 1/3).
- Produces: `AddEditReviewScreen` widget, constructor `AddEditReviewScreen({Key? key, Review? existingReview, Film? preselectedFilm})`. Create mode (`existingReview` null) shows the film `Autocomplete` picker plus a "+ New film" toggle revealing `FilmFieldsForm`; edit mode shows the review fields only, against `preselectedFilm`. Saving pops the screen.

- [ ] **Step 1: Write the failing test**

Create `local_reviews/test/screens/add_edit_review_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/app_repositories.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/data/repositories/film_repository.dart';
import 'package:local_reviews/screens/reviews/add_edit_review_screen.dart';
import 'package:local_reviews/widgets/star_rating_input.dart';

Future<AppDatabase> pumpScreen(WidgetTester tester) async {
  final database = AppDatabase(
    DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
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
    await tester.enterText(find.byKey(const Key('film_title_field')), 'Ponyo');
    await tester.enterText(find.byKey(const Key('film_year_field')), '2008');

    await tester.tap(find.byKey(const ValueKey('star_3')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save_review_button')));
    await tester.pumpAndSettle();

    expect(find.text('Review text is required'), findsOneWidget);
    expect(await database.select(database.reviews).get(), isEmpty);
  });

  testWidgets('creates a new film inline and a review against it', (tester) async {
    final database = await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('toggle_new_film_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('film_title_field')), 'Ponyo');
    await tester.enterText(find.byKey(const Key('film_year_field')), '2008');
    await tester.enterText(find.byKey(const Key('review_text_field')), 'Charming.');

    final fifthStar = find.byKey(const ValueKey('star_4'));
    await tester.tapAt(tester.getTopRight(fifthStar) - const Offset(2, -16));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save_review_button')));
    await tester.pumpAndSettle();

    final films = await database.select(database.films).get();
    final reviews = await database.select(database.reviews).get();
    expect(films.single.title, 'Ponyo');
    expect(reviews.single.text, 'Charming.');
    expect(reviews.single.rating, 5.0);
    expect(find.byType(AddEditReviewScreen), findsNothing);
  });

  testWidgets('selecting an existing film via the picker attaches the review to it',
      (tester) async {
    final database = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(database.close);
    final filmId =
        await FilmRepository(database).createFilm(title: 'Nausicaä', year: 1984);

    await tester.pumpWidget(
      AppRepositories(
        database: database,
        child: const MaterialApp(home: AddEditReviewScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('film_search_field')), 'Naus');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nausicaä (1984)').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('review_text_field')), 'A classic.');
    await tester.tap(find.byKey(const ValueKey('star_2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_review_button')));
    await tester.pumpAndSettle();

    final reviews = await database.select(database.reviews).get();
    expect(reviews.single.filmId, filmId);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd local_reviews && flutter test test/screens/add_edit_review_screen_test.dart`
Expected: FAIL — `package:local_reviews/screens/reviews/add_edit_review_screen.dart` doesn't exist.

- [ ] **Step 3: Implement AddEditReviewScreen**

Create `local_reviews/lib/screens/reviews/add_edit_review_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../app_repositories.dart';
import '../../data/database.dart';
import '../../data/repositories/film_repository.dart';
import '../../widgets/film_fields_form.dart';
import '../../widgets/star_rating_input.dart';

class AddEditReviewScreen extends StatefulWidget {
  const AddEditReviewScreen({super.key, this.existingReview, this.preselectedFilm});

  final Review? existingReview;
  final Film? preselectedFilm;

  @override
  State<AddEditReviewScreen> createState() => AddEditReviewScreenState();
}

class AddEditReviewScreenState extends State<AddEditReviewScreen> {
  final formKey = GlobalKey<FormState>();
  final textController = TextEditingController();
  late final FilmFieldsController newFilmController;
  double rating = 0;
  DateTime watchDate = DateTime.now();
  Film? selectedFilm;
  bool creatingNewFilm = false;

  @override
  void initState() {
    super.initState();
    selectedFilm = widget.preselectedFilm;
    textController.text = widget.existingReview?.text ?? '';
    rating = widget.existingReview?.rating ?? 0;
    watchDate = widget.existingReview?.watchDate ?? DateTime.now();
    newFilmController = FilmFieldsController();
  }

  @override
  void dispose() {
    textController.dispose();
    newFilmController.dispose();
    super.dispose();
  }

  String? _validateReviewText(String? value) {
    if (value == null || value.trim().isEmpty) return 'Review text is required';
    return null;
  }

  Future<void> _save() async {
    final formValid = formKey.currentState!.validate();
    if (!formValid || rating <= 0) return;
    final repos = AppRepositories.of(context);

    final int filmId;
    if (creatingNewFilm) {
      filmId = await repos.filmRepository.createFilm(
        title: newFilmController.title,
        year: newFilmController.year,
        director: newFilmController.director,
        posterPath: newFilmController.posterPath.value,
        genreIds: newFilmController.selectedGenreIds.value.toList(),
      );
    } else if (selectedFilm != null) {
      filmId = selectedFilm!.id;
    } else {
      return;
    }

    if (widget.existingReview == null) {
      await repos.reviewRepository.createReview(
        filmId: filmId,
        rating: rating,
        text: textController.text.trim(),
        watchDate: watchDate,
      );
    } else {
      await repos.reviewRepository.updateReview(
        id: widget.existingReview!.id,
        rating: rating,
        text: textController.text.trim(),
        watchDate: watchDate,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final repos = AppRepositories.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.existingReview == null ? 'Add review' : 'Edit review')),
      body: StreamBuilder<List<FilmWithGenres>>(
        stream: repos.filmRepository.watchAllFilms(),
        builder: (context, filmsSnapshot) {
          final allFilms =
              (filmsSnapshot.data ?? const <FilmWithGenres>[]).map((e) => e.film).toList();
          return StreamBuilder<List<Genre>>(
            stream: repos.filmRepository.watchAllGenres(),
            builder: (context, genresSnapshot) {
              final allGenres = genresSnapshot.data ?? const <Genre>[];
              return Form(
                key: formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (widget.existingReview == null) ...[
                      Autocomplete<Film>(
                        displayStringForOption: (film) => '${film.title} (${film.year})',
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) return const Iterable<Film>.empty();
                          final query = textEditingValue.text.toLowerCase();
                          return allFilms.where((film) => film.title.toLowerCase().contains(query));
                        },
                        onSelected: (film) => setState(() {
                          selectedFilm = film;
                          creatingNewFilm = false;
                        }),
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            key: const Key('film_search_field'),
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(labelText: 'Search films'),
                          );
                        },
                      ),
                      if (selectedFilm != null)
                        Text('Selected: ${selectedFilm!.title} (${selectedFilm!.year})'),
                      TextButton(
                        key: const Key('toggle_new_film_button'),
                        onPressed: () => setState(() {
                          creatingNewFilm = !creatingNewFilm;
                          if (creatingNewFilm) selectedFilm = null;
                        }),
                        child: Text(creatingNewFilm ? 'Cancel new film' : '+ New film'),
                      ),
                      if (creatingNewFilm)
                        FilmFieldsForm(
                          controller: newFilmController,
                          allGenres: allGenres,
                          posterStorageService: repos.posterStorageService,
                        ),
                    ] else
                      Text('${widget.preselectedFilm?.title} (${widget.preselectedFilm?.year})'),
                    const SizedBox(height: 16),
                    StarRatingInput(
                      rating: rating,
                      onChanged: (value) => setState(() => rating = value),
                    ),
                    TextFormField(
                      key: const Key('review_text_field'),
                      controller: textController,
                      decoration: const InputDecoration(labelText: 'Review'),
                      validator: _validateReviewText,
                      maxLines: 4,
                    ),
                    ListTile(
                      key: const Key('watch_date_field'),
                      title: Text('Watched on ${watchDate.toLocal().toString().split(' ').first}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: watchDate,
                          firstDate: DateTime(1888),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => watchDate = picked);
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      key: const Key('save_review_button'),
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd local_reviews && flutter test test/screens/add_edit_review_screen_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/screens/reviews/add_edit_review_screen.dart local_reviews/test/screens/add_edit_review_screen_test.dart
git commit -m "Add AddEditReviewScreen"
```

---

### Task 15: ReviewDetailScreen

**Files:**
- Create: `local_reviews/lib/screens/reviews/review_detail_screen.dart`
- Test: `local_reviews/test/screens/review_detail_screen_test.dart`

**Interfaces:**
- Consumes: `AppRepositories` (Task 9), `AddEditReviewScreen` (Task 14), `StarRatingInput` (Task 6), `ReviewWithFilm` (Task 4).
- Produces: `ReviewDetailScreen` widget, constructor `ReviewDetailScreen({Key? key, required int reviewId})`. Shows the review's film/rating/text/date, an edit FAB (opens `AddEditReviewScreen` pre-filled), and a delete button with confirmation dialog.

- [ ] **Step 1: Write the failing test**

Create `local_reviews/test/screens/review_detail_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/app_repositories.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/data/repositories/film_repository.dart';
import 'package:local_reviews/data/repositories/review_repository.dart';
import 'package:local_reviews/screens/reviews/review_detail_screen.dart';

void main() {
  testWidgets('shows review details and deletes on confirmation', (tester) async {
    final database = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(database.close);
    final filmRepository = FilmRepository(database);
    final reviewRepository = ReviewRepository(database);

    final filmId = await filmRepository.createFilm(title: 'Paterson', year: 2016);
    final reviewId = await reviewRepository.createReview(
      filmId: filmId,
      rating: 4,
      text: 'Quietly lovely.',
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

    final remaining = await reviewRepository.watchReviewsForFilm(filmId).first;
    expect(remaining, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd local_reviews && flutter test test/screens/review_detail_screen_test.dart`
Expected: FAIL — `package:local_reviews/screens/reviews/review_detail_screen.dart` doesn't exist.

- [ ] **Step 3: Implement ReviewDetailScreen**

Create `local_reviews/lib/screens/reviews/review_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../app_repositories.dart';
import '../../data/repositories/review_repository.dart';
import '../../widgets/star_rating_input.dart';
import 'add_edit_review_screen.dart';

class ReviewDetailScreen extends StatelessWidget {
  const ReviewDetailScreen({super.key, required this.reviewId});

  final int reviewId;

  Future<void> _confirmDelete(BuildContext context) async {
    final repos = AppRepositories.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('confirm_delete_review_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repos.reviewRepository.deleteReview(reviewId);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _editReview(BuildContext context) async {
    final repos = AppRepositories.of(context);
    final entry = (await repos.reviewRepository.watchAllReviews().first)
        .where((r) => r.review.id == reviewId);
    if (entry.isEmpty || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddEditReviewScreen(
        existingReview: entry.first.review,
        preselectedFilm: entry.first.film,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final repos = AppRepositories.of(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            key: const Key('delete_review_button'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: StreamBuilder<List<ReviewWithFilm>>(
        stream: repos.reviewRepository.watchAllReviews(),
        builder: (context, snapshot) {
          final matches =
              (snapshot.data ?? const <ReviewWithFilm>[]).where((r) => r.review.id == reviewId);
          if (matches.isEmpty) return const SizedBox.shrink();
          final entry = matches.first;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${entry.film.title} (${entry.film.year})',
                    style: Theme.of(context).textTheme.headlineSmall),
                StarRatingInput(rating: entry.review.rating),
                Text('Watched: ${entry.review.watchDate.toLocal().toString().split(' ').first}'),
                const SizedBox(height: 8),
                Text(entry.review.text),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('edit_review_fab'),
        onPressed: () => _editReview(context),
        child: const Icon(Icons.edit),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd local_reviews && flutter test test/screens/review_detail_screen_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/screens/reviews/review_detail_screen.dart local_reviews/test/screens/review_detail_screen_test.dart
git commit -m "Add ReviewDetailScreen"
```

---

### Task 16: ReviewsScreen

**Files:**
- Create: `local_reviews/lib/screens/reviews/reviews_screen.dart`
- Test: `local_reviews/test/screens/reviews_screen_test.dart`

**Interfaces:**
- Consumes: `AppRepositories` (Task 9), `AddEditReviewScreen` (Task 14), `ReviewDetailScreen` (Task 15), `PosterThumbnail` (Task 7), `StarRatingInput` (Task 6).
- Produces: `ReviewsScreen` widget (no constructor params beyond `key`) — the app's home screen: reverse-chronological review list, FAB to add a review, tap to open detail.

- [ ] **Step 1: Write the failing test**

Create `local_reviews/test/screens/reviews_screen_test.dart`:

```dart
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
        filmId: filmId, rating: 3, text: 'Old watch.', watchDate: DateTime(2026, 1, 1));
    final recentReviewId = await reviewRepository.createReview(
        filmId: filmId, rating: 5, text: 'Recent watch.', watchDate: DateTime(2026, 5, 1));
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd local_reviews && flutter test test/screens/reviews_screen_test.dart`
Expected: FAIL — `package:local_reviews/screens/reviews/reviews_screen.dart` doesn't exist.

- [ ] **Step 3: Implement ReviewsScreen**

Create `local_reviews/lib/screens/reviews/reviews_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../app_repositories.dart';
import '../../data/repositories/review_repository.dart';
import '../../widgets/poster_thumbnail.dart';
import '../../widgets/star_rating_input.dart';
import 'add_edit_review_screen.dart';
import 'review_detail_screen.dart';

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repos = AppRepositories.of(context);
    return Scaffold(
      body: StreamBuilder<List<ReviewWithFilm>>(
        stream: repos.reviewRepository.watchAllReviews(),
        builder: (context, snapshot) {
          final reviews = snapshot.data ?? const <ReviewWithFilm>[];
          if (reviews.isEmpty) {
            return const Center(child: Text('No reviews yet'));
          }
          return ListView.builder(
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final entry = reviews[index];
              return ListTile(
                key: ValueKey('review_tile_${entry.review.id}'),
                leading: PosterThumbnail(posterPath: entry.film.posterPath, size: 40),
                title: Text('${entry.film.title} (${entry.film.year})'),
                subtitle: StarRatingInput(rating: entry.review.rating, size: 16),
                trailing: Text(entry.review.watchDate.toLocal().toString().split(' ').first),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ReviewDetailScreen(reviewId: entry.review.id),
                )),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add_review_fab'),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AddEditReviewScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd local_reviews && flutter test test/screens/reviews_screen_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/screens/reviews/reviews_screen.dart local_reviews/test/screens/reviews_screen_test.dart
git commit -m "Add ReviewsScreen"
```

---

### Task 17: NavigationShell

**Files:**
- Create: `local_reviews/lib/screens/navigation_shell.dart`
- Test: `local_reviews/test/screens/navigation_shell_test.dart`

**Interfaces:**
- Consumes: `ReviewsScreen` (Task 16), `FilmsScreen` (Task 13).
- Produces: `NavigationShell` widget (no constructor params beyond `key`) — the app's root layout: bottom `NavigationBar` (with a `Key('bottom_nav_bar')`) below 600 logical pixels wide, `NavigationRail` at or above it, switching between the Reviews and Films screens.

- [ ] **Step 1: Write the failing test**

Create `local_reviews/test/screens/navigation_shell_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd local_reviews && flutter test test/screens/navigation_shell_test.dart`
Expected: FAIL — `package:local_reviews/screens/navigation_shell.dart` doesn't exist.

- [ ] **Step 3: Implement NavigationShell**

Create `local_reviews/lib/screens/navigation_shell.dart`:

```dart
import 'package:flutter/material.dart';

import 'films/films_screen.dart';
import 'reviews/reviews_screen.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => NavigationShellState();
}

class NavigationShellState extends State<NavigationShell> {
  static const wideLayoutBreakpoint = 600.0;

  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    const screens = [ReviewsScreen(), FilmsScreen()];
    final isWide = MediaQuery.of(context).size.width >= wideLayoutBreakpoint;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => setState(() => selectedIndex = index),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.movie_outlined),
                  selectedIcon: Icon(Icons.movie),
                  label: Text('Reviews'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.local_movies_outlined),
                  selectedIcon: Icon(Icons.local_movies),
                  label: Text('Films'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: screens[selectedIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      body: screens[selectedIndex],
      bottomNavigationBar: NavigationBar(
        key: const Key('bottom_nav_bar'),
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => setState(() => selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.movie_outlined),
            selectedIcon: Icon(Icons.movie),
            label: 'Reviews',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_movies_outlined),
            selectedIcon: Icon(Icons.local_movies),
            label: 'Films',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd local_reviews && flutter test test/screens/navigation_shell_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add local_reviews/lib/screens/navigation_shell.dart local_reviews/test/screens/navigation_shell_test.dart
git commit -m "Add responsive NavigationShell"
```

---

### Task 18: Wire main.dart, replace the placeholder test, final verification

**Files:**
- Modify: `local_reviews/lib/main.dart`
- Modify: `local_reviews/test/widget_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (Task 1), `AppRepositories` (Task 9), `NavigationShell` (Task 17).
- Produces: `LocalReviewsApp` widget, constructor `LocalReviewsApp({Key? key, required AppDatabase database})` — the app's root, wiring `AppRepositories` around `MaterialApp(home: NavigationShell())`. `main()` calls `runApp(LocalReviewsApp(database: AppDatabase()))`.

- [ ] **Step 1: Write the failing test**

Replace the entire contents of `local_reviews/test/widget_test.dart` (currently the default counter-app smoke test) with:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/main.dart';

void main() {
  testWidgets('the app launches to an empty Reviews screen', (tester) async {
    final database = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(database.close);

    await tester.pumpWidget(LocalReviewsApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('No reviews yet'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd local_reviews && flutter test test/widget_test.dart`
Expected: FAIL — `LocalReviewsApp` doesn't take a `database` parameter yet (current `main.dart` is still the counter-app template).

- [ ] **Step 3: Rewrite main.dart**

Replace the entire contents of `local_reviews/lib/main.dart` with:

```dart
import 'package:flutter/material.dart';

import 'app_repositories.dart';
import 'data/database.dart';
import 'screens/navigation_shell.dart';

void main() {
  runApp(LocalReviewsApp(database: AppDatabase()));
}

class LocalReviewsApp extends StatelessWidget {
  const LocalReviewsApp({super.key, required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return AppRepositories(
      database: database,
      child: MaterialApp(
        title: 'Local Reviews',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
        home: const NavigationShell(),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd local_reviews && flutter test test/widget_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Run the full test suite and static analysis**

Run: `cd local_reviews && flutter analyze`
Expected: "No issues found!"

Run: `cd local_reviews && flutter test`
Expected: All tests pass (every test file created in Tasks 1–18).

- [ ] **Step 6: Commit**

```bash
git add local_reviews/lib/main.dart local_reviews/test/widget_test.dart
git commit -m "Wire main.dart to the manual film entry feature"
```

---

## Self-Review Notes

- **Spec coverage:** Data model (Tasks 1–2), architecture/repositories (Tasks 3–5, 9), all six screens plus shared widgets (Tasks 6–8, 10–17), main wiring (Task 18), validation rules (Tasks 10 test, 14 test), delete confirmations with cascade count (Task 12 test), testing approach — repository tests (Tasks 1–4) and widget tests replacing the placeholder (Tasks 6–18) — all covered. The "Future: encryption" spec section intentionally has no task: it's explicitly out of scope for this plan (see spec).
- **Placeholder scan:** No TBD/TODO markers; every step has real, complete code.
- **Type consistency:** `FilmWithGenres`, `ReviewWithFilm`, `FilmRepository`, `ReviewRepository`, `AppRepositories`, `FilmFieldsController`/`FilmFieldsForm`, and all widget key names (`film_title_field`, `save_film_button`, `add_review_fab`, etc.) are defined once (in the task that produces them) and reused with matching names/signatures in every later task that consumes them.
