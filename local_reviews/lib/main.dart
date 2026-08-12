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
