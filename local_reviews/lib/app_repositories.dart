import 'package:flutter/widgets.dart';

import 'data/database.dart';
import 'data/repositories/film_repository.dart';
import 'data/repositories/review_repository.dart';
import 'services/poster_storage_service.dart';

class AppRepositories extends InheritedWidget {
  factory AppRepositories({
    Key? key,
    required AppDatabase database,
    required Widget child,
    PosterStorageService? posterStorageService,
  }) {
    final resolvedPosterStorageService =
        posterStorageService ?? PosterStorageService();
    return AppRepositories._(
      key: key,
      database: database,
      posterStorageService: resolvedPosterStorageService,
      filmRepository: FilmRepository(
        database,
        posterStorageService: resolvedPosterStorageService,
      ),
      reviewRepository: ReviewRepository(database),
      child: child,
    );
  }

  const AppRepositories._({
    super.key,
    required this.database,
    required this.posterStorageService,
    required this.filmRepository,
    required this.reviewRepository,
    required super.child,
  });

  final AppDatabase database;
  final FilmRepository filmRepository;
  final ReviewRepository reviewRepository;
  final PosterStorageService posterStorageService;

  static AppRepositories of(BuildContext context) {
    final result = context
        .dependOnInheritedWidgetOfExactType<AppRepositories>();
    assert(result != null, 'No AppRepositories found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(AppRepositories oldWidget) =>
      database != oldWidget.database;
}
