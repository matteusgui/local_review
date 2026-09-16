import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_reviews/vault/mnemonic_service.dart';

void main() {
  late MnemonicService service;

  setUp(() => service = MnemonicService());

  test('generateMnemonic produces 12 valid words', () {
    final mnemonic = service.generateMnemonic();
    expect(mnemonic.split(' '), hasLength(12));
    expect(service.validateMnemonic(mnemonic), isTrue);
  });

  test('validateMnemonic rejects a tampered phrase', () {
    final mnemonic = service.generateMnemonic();
    final tampered = '${mnemonic.substring(0, mnemonic.length - 1)}x';
    expect(service.validateMnemonic(tampered), isFalse);
  });

  test('mnemonicToSeed matches the official BIP-39 test vector', () {
    const mnemonic = 'abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon abandon abandon about';
    const expectedSeedHex =
        'c55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e53495531f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04';

    final seed = service.mnemonicToSeed(mnemonic, passphrase: 'TREZOR');
    final seedHex =
        seed.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    expect(seedHex, expectedSeedHex);
  });

  test('pickConfirmationIndices returns 3 distinct in-range indices', () {
    final indices = service.pickConfirmationIndices(12, random: Random(1));
    expect(indices.toSet(), hasLength(3));
    expect(indices.every((i) => i >= 0 && i < 12), isTrue);
  });
}
