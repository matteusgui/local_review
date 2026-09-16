import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/app.dart';
import 'package:local_reviews/data/database.dart';
import 'package:local_reviews/services/poster_cipher_service.dart';
import 'package:local_reviews/services/poster_storage_service.dart';

void main() {
  testWidgets('the app launches to an empty Reviews screen', (tester) async {
    final database = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    addTearDown(database.close);

    await tester.pumpWidget(LocalReviewsApp(
      database: database,
      posterStorageService: PosterStorageService(
        cipherService: PosterCipherService(SecretKey(List.generate(32, (i) => i))),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No reviews yet'), findsOneWidget);
  });
}
