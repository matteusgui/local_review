import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../data/database.dart';
import '../services/poster_cipher_service.dart';
import '../services/poster_storage_service.dart';
import '../vault/secure_seed_storage.dart';
import '../vault/vault_service.dart';
import '../vault/vault_state.dart';
import 'vault/onboarding_screen.dart';
import 'vault/restore_screen.dart';

class VaultGate extends StatefulWidget {
  const VaultGate({super.key, required this.vaultService});

  final VaultService vaultService;

  @override
  State<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends State<VaultGate> {
  late Future<VaultState> _stateFuture;

  @override
  void initState() {
    super.initState();
    _stateFuture = widget.vaultService.resolveInitialState();
  }

  void _onUnlocked(VaultUnlocked unlocked) {
    setState(() => _stateFuture = Future.value(unlocked));
  }

  void _onStartFresh() {
    setState(() => _stateFuture = Future.value(const VaultNeedsOnboarding()));
  }

  void _retry() {
    setState(() => _stateFuture = widget.vaultService.resolveInitialState());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VaultState>(
      future: _stateFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorApp(error: snapshot.error!, onRetry: _retry);
        }
        final state = snapshot.data;
        if (state == null) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        return switch (state) {
          VaultNeedsOnboarding() => MaterialApp(
              home: OnboardingScreen(
                vaultService: widget.vaultService,
                onUnlocked: _onUnlocked,
              ),
            ),
          VaultNeedsRestore() => MaterialApp(
              home: RestoreScreen(
                vaultService: widget.vaultService,
                onUnlocked: _onUnlocked,
                onStartFresh: _onStartFresh,
              ),
            ),
          VaultUnlocked() => _UnlockedApp(state: state),
        };
      },
    );
  }
}

class _UnlockedApp extends StatelessWidget {
  const _UnlockedApp({required this.state});

  final VaultUnlocked state;

  Future<AppDatabase> _openDatabase() async {
    final file = await resolveDatabaseFile();
    return AppDatabase(openEncryptedExecutor(file: file, key: state.dbKey));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppDatabase>(
      future: _openDatabase(),
      builder: (context, snapshot) {
        final database = snapshot.data;
        if (database == null) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        return LocalReviewsApp(
          database: database,
          posterStorageService: PosterStorageService(
            cipherService: PosterCipherService(SecretKey(state.posterKey)),
          ),
        );
      },
    );
  }
}

class _ErrorApp extends StatelessWidget {
  const _ErrorApp({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is NoSecureKeyringException
        ? 'No secure keyring service found — install and start GNOME '
            'Keyring, KWallet, or another Secret Service-compatible '
            'provider, then try again.'
        : 'Could not access secure storage on this device.';
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
