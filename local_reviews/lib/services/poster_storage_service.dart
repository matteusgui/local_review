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
