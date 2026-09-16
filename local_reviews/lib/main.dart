import 'package:flutter/material.dart';

import 'screens/vault_gate.dart';
import 'vault/vault_service.dart';

void main() {
  runApp(VaultGate(vaultService: VaultService()));
}
