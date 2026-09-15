import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/services/poster_cipher_service.dart';

void main() {
  late PosterCipherService cipher;

  setUp(() {
    cipher = PosterCipherService(SecretKey(List.generate(32, (i) => i)));
  });

  test('encrypt then decrypt returns the original bytes', () async {
    final plain = Uint8List.fromList([1, 2, 3, 4, 5]);
    final cipherBytes = await cipher.encrypt(plain);
    final decrypted = await cipher.decrypt(cipherBytes);
    expect(decrypted, plain);
  });

  test('tampering with the ciphertext makes decryption fail', () async {
    final plain = Uint8List.fromList([1, 2, 3, 4, 5]);
    final cipherBytes = await cipher.encrypt(plain);
    cipherBytes[cipherBytes.length - 1] ^= 0xFF;

    expect(cipher.decrypt(cipherBytes), throwsA(anything));
  });
}
