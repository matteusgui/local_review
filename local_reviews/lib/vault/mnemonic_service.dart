import 'dart:math';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;

class MnemonicService {
  String generateMnemonic() => bip39.generateMnemonic(strength: 128);

  bool validateMnemonic(String mnemonic) => bip39.validateMnemonic(mnemonic);

  Uint8List mnemonicToSeed(String mnemonic, {String passphrase = ''}) =>
      bip39.mnemonicToSeed(mnemonic, passphrase: passphrase);

  List<int> pickConfirmationIndices(
    int wordCount, {
    int count = 3,
    Random? random,
  }) {
    final rng = random ?? Random.secure();
    final indices = <int>{};
    while (indices.length < count) {
      indices.add(rng.nextInt(wordCount));
    }
    return indices.toList()..sort();
  }
}
