import 'dart:typed_data';

sealed class VaultState {
  const VaultState();
}

class VaultNeedsOnboarding extends VaultState {
  const VaultNeedsOnboarding();
}

class VaultNeedsRestore extends VaultState {
  const VaultNeedsRestore();
}

class VaultUnlocked extends VaultState {
  const VaultUnlocked({required this.dbKey, required this.posterKey});

  final Uint8List dbKey;
  final Uint8List posterKey;
}
