import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/services/poster_storage_service.dart';
import 'package:path/path.dart' as p;

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
