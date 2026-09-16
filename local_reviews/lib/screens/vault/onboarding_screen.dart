import 'package:flutter/material.dart';

import '../../vault/vault_service.dart';
import '../../vault/vault_state.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.vaultService,
    required this.onUnlocked,
  });

  final VaultService vaultService;
  final ValueChanged<VaultUnlocked> onUnlocked;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { showPhrase, confirmWords }

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final String _mnemonic = widget.vaultService.generateMnemonic();
  late final List<String> _words = _mnemonic.split(' ');
  late final List<int> _confirmIndices =
      widget.vaultService.pickConfirmationIndices(_words.length);
  final Map<int, TextEditingController> _controllers = {};
  _Step _step = _Step.showPhrase;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final index in _confirmIndices) {
      _controllers[index] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _checkWords() {
    for (final index in _confirmIndices) {
      final input = _controllers[index]!.text.trim().toLowerCase();
      if (input != _words[index]) {
        setState(() {
          _error =
              "That doesn't match your recovery phrase. Check word ${index + 1} and try again.";
        });
        return;
      }
    }
    _complete();
  }

  Future<void> _complete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final unlocked = await widget.vaultService.completeOnboarding(_mnemonic);
      widget.onUnlocked(unlocked);
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Something went wrong saving your recovery phrase. '
            'Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up local encryption')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _step == _Step.showPhrase
            ? _buildShowPhrase()
            : _buildConfirmWords(context),
      ),
    );
  }

  Widget _buildShowPhrase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Write down these 12 words in order and keep them somewhere safe. '
          "They're the only way to recover your data if you lose this device.",
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _words.length; i++)
              Chip(label: Text('${i + 1}. ${_words[i]}')),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => _step = _Step.confirmWords),
          child: const Text("I've written it down"),
        ),
      ],
    );
  }

  Widget _buildConfirmWords(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Confirm your recovery phrase by typing the requested words.'),
        const SizedBox(height: 16),
        for (final index in _confirmIndices)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              key: Key('confirm-word-$index'),
              controller: _controllers[index],
              decoration: InputDecoration(labelText: 'Word #${index + 1}'),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton(
          onPressed: _busy ? null : _checkWords,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
