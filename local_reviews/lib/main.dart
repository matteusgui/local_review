import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';

import 'app_repositories.dart';
import 'data/database.dart';
import 'screens/navigation_shell.dart';
import 'services/poster_cipher_service.dart';
import 'services/poster_storage_service.dart';

void main() {
  runApp(LocalReviewsApp(
    database: AppDatabase(),
    // TODO(Task 11): replace with the vault-derived poster key once
    // VaultGate wires PosterStorageService with the real encryption key.
    posterStorageService: PosterStorageService(
      cipherService: PosterCipherService(SecretKey(List.generate(32, (i) => i))),
    ),
  ));
}

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
