import 'package:flutter/material.dart';

import '../../vault/vault_service.dart';
import '../../vault/vault_state.dart';

class RestoreScreen extends StatefulWidget {
  const RestoreScreen({
    super.key,
    required this.vaultService,
    required this.onUnlocked,
    required this.onStartFresh,
  });

  final VaultService vaultService;
  final ValueChanged<VaultUnlocked> onUnlocked;
  final VoidCallback onStartFresh;

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final unlocked =
          await widget.vaultService.restoreVault(_controller.text.trim());
      widget.onUnlocked(unlocked);
    } on WrongRecoveryPhraseException {
      setState(() {
        _busy = false;
        _error = "This phrase doesn't match the data on this device.";
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _startFresh() async {
    await widget.vaultService.startFresh();
    widget.onStartFresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restore from recovery phrase')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your 12-word recovery phrase to unlock the data on this device.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('recovery-phrase-field'),
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Recovery phrase'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Restore'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _startFresh,
              child: const Text("I don't have the phrase — start fresh"),
            ),
          ],
        ),
      ),
    );
  }
}
