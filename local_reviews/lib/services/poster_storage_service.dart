import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'poster_cipher_service.dart';

class PosterStorageService {
  PosterStorageService({
    required PosterCipherService cipherService,
    Future<Directory> Function()? documentsDirectory,
  })  : _cipherService = cipherService,
        _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  final PosterCipherService _cipherService;
  final Future<Directory> Function() _documentsDirectory;

  Future<String> savePoster(File sourceFile) async {
    final documentsDir = await _documentsDirectory();
    final postersDir = Directory(p.join(documentsDir.path, 'posters'));
    if (!await postersDir.exists()) {
      await postersDir.create(recursive: true);
    }
    final destinationPath = p.join(postersDir.path, '${_uniqueFileName()}.enc');
    final plainBytes = await sourceFile.readAsBytes();
    final cipherBytes = await _cipherService.encrypt(plainBytes);
    await File(destinationPath).writeAsBytes(cipherBytes);
    return destinationPath;
  }

  Future<Uint8List> loadDecrypted(String posterPath) async {
    final cipherBytes = await File(posterPath).readAsBytes();
    return await _cipherService.decrypt(cipherBytes);
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
