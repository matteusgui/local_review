import 'package:flutter/material.dart';

import 'app_repositories.dart';
import 'data/database.dart';
import 'screens/navigation_shell.dart';
import 'services/poster_storage_service.dart';

class LocalReviewsApp extends StatelessWidget {
  const LocalReviewsApp({
    super.key,
    required this.database,
    required this.posterStorageService,
  });

  final AppDatabase database;
  final PosterStorageService posterStorageService;

  @override
  Widget build(BuildContext context) {
    return AppRepositories(
      database: database,
      posterStorageService: posterStorageService,
      child: MaterialApp(
        title: 'Local Reviews',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
        home: const NavigationShell(),
      ),
    );
  }
}
