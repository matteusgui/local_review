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
