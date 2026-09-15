import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/vault/seed_key_derivation.dart';

void main() {
  late SeedKeyDerivation derivation;
  late Uint8List seed;

  setUp(() {
    derivation = SeedKeyDerivation();
    seed = Uint8List.fromList(List.generate(64, (i) => i));
  });

  test('deriveDatabaseKey is deterministic and 32 bytes', () async {
    final keyA = await derivation.deriveDatabaseKey(seed);
    final keyB = await derivation.deriveDatabaseKey(seed);
    expect(keyA, hasLength(32));
    expect(keyA, keyB);
  });

  test('database and poster keys differ for the same seed', () async {
    final dbKey = await derivation.deriveDatabaseKey(seed);
    final posterKey = await derivation.derivePosterKey(seed);
    expect(dbKey, isNot(posterKey));
  });
}
