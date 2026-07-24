import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/api_client.dart';

/// Low-friction feedback → `POST /v1/feedback` (doc §8.13).
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

enum _SendState { idle, sending, sent }

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  String category = 'idea';
  bool attachDiagnostics = true;
  _SendState sendState = _SendState.idle;
  final textController = TextEditingController();

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (textController.text.trim().isEmpty) return;
    setState(() => sendState = _SendState.sending);

    Map<String, Object?>? diagnostics;
    if (attachDiagnostics) {
      final info = await PackageInfo.fromPlatform();
      diagnostics = {
        'os_version': Platform.operatingSystemVersion,
        'app_version': info.version,
        'locale': Platform.localeName,
      };
    }

    final ok = await ref.read(apiClientProvider).sendFeedback(
          category: category,
          message: textController.text.trim(),
          diagnostics: diagnostics,
        );

    if (!mounted) return;
    if (ok) {
      // Send button morphs → ring → check (doc §8.13).
      setState(() => sendState = _SendState.sent);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) context.pop();
    } else {
      setState(() => sendState = _SendState.idle);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't send right now — try again later.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final (id, label) in const [
                ('bug', 'Bug'),
                ('idea', 'Idea'),
                ('praise', 'Praise'),
                ('other', 'Other'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: category == id,
                  onSelected: (_) => setState(() => category = id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: textController,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'What\'s on your mind?',
              border: OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Attach diagnostics'),
            subtitle:
                const Text('Device model, Android version, app version'),
            value: attachDiagnostics,
            onChanged: (v) => setState(() => attachDiagnostics = v),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: sendState == _SendState.idle ? _send : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: switch (sendState) {
                  _SendState.idle => const Text('Send'),
                  _SendState.sending => const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  _SendState.sent =>
                    const Icon(Icons.check_rounded, key: ValueKey('check')),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
