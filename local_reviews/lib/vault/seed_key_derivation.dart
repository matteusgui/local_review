import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class SeedKeyDerivation {
  SeedKeyDerivation() : _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  final Hkdf _hkdf;

  static final List<int> _salt = utf8.encode('local_reviews/vault/v1/salt');

  Future<Uint8List> deriveDatabaseKey(Uint8List seed) =>
      _derive(seed, 'local_reviews/db-key/v1');

  Future<Uint8List> derivePosterKey(Uint8List seed) =>
      _derive(seed, 'local_reviews/poster-key/v1');

  Future<Uint8List> _derive(Uint8List seed, String info) async {
    final key = await _hkdf.deriveKey(
      secretKey: SecretKey(seed),
      nonce: _salt,
      info: utf8.encode(info),
    );
    return Uint8List.fromList(await key.extractBytes());
  }
}
