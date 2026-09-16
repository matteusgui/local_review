import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class PosterCipherService {
  PosterCipherService(this._key) : _algorithm = AesGcm.with256bits();

  final SecretKey _key;
  final AesGcm _algorithm;

  static const _macLength = 16;

  Future<Uint8List> encrypt(Uint8List plainBytes) async {
    final box = await _algorithm.encrypt(plainBytes, secretKey: _key);
    return box.concatenation();
  }

  Future<Uint8List> decrypt(Uint8List cipherBytes) async {
    final box = SecretBox.fromConcatenation(
      cipherBytes,
      nonceLength: _algorithm.nonceLength,
      macLength: _macLength,
    );
    final clear = await _algorithm.decrypt(box, secretKey: _key);
    return Uint8List.fromList(clear);
  }
}
