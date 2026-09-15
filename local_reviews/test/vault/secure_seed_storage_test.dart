import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/vault/secure_seed_storage.dart';

import 'fakes.dart';

void main() {
  test('round-trips a seed through the underlying store', () async {
    final storage = SecureSeedStorage(store: FakeSeedKeyValueStore());
    final seed = Uint8List.fromList(List.generate(64, (i) => i));

    await storage.writeSeed(seed);
    final readBack = await storage.readSeed();

    expect(readBack, seed);
  });

  test('returns null when nothing has been written', () async {
    final storage = SecureSeedStorage(store: FakeSeedKeyValueStore());
    expect(await storage.readSeed(), isNull);
  });

  test('maps a store failure to NoSecureKeyringException on Linux', () async {
    final storage = SecureSeedStorage(
      store: FakeSeedKeyValueStore(failWith: Exception('no secret service')),
      isLinux: () => true,
    );

    expect(storage.readSeed(), throwsA(isA<NoSecureKeyringException>()));
  });

  test('maps a store failure to SecureStorageException off Linux', () async {
    final storage = SecureSeedStorage(
      store: FakeSeedKeyValueStore(failWith: Exception('keychain denied')),
      isLinux: () => false,
    );

    expect(storage.readSeed(), throwsA(isA<SecureStorageException>()));
  });
}
