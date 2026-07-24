import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../themes/domain/presets.dart';
import '../../themes/presentation/widgets/theme_preview.dart';

/// 3-page promise (doc §8.3): volume anywhere → notification slider →
/// make it yours. Hand-built animations, no asset dependencies.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final controller = PageController();
  int page = 0;
  int themeIndex = 2;
  Timer? themeCycler;

  @override
  void initState() {
    super.initState();
    // Page 3's theme carousel auto-cycles (doc §8.3).
    themeCycler = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (page == 2 && mounted) {
        setState(() => themeIndex = (themeIndex + 1) % kBuiltInThemes.length);
      }
    });
  }

  @override
  void dispose() {
    themeCycler?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _finish() => context.go('/permissions');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _finish, child: const Text('Skip')),
            ),
            Expanded(
              child: PageView(
                controller: controller,
                onPageChanged: (i) => setState(() => page = i),
                children: [
                  _Page(
                    title: 'Volume, anywhere',
                    body:
                        'A floating button that lives above every app. Long-press '
                        'and slide to adjust volume — smooth as butter.',
                    child: ThemePreview(
                        theme: kBuiltInThemes[2], expanded: true, size: 220),
                  ),
                  const _Page(
                    title: 'Also in your notifications',
                    body:
                        'Prefer the shade? A persistent notification puts mute, '
                        'steppers and quick presets one swipe away.',
                    child: _NotificationMock(),
                  ),
                  _Page(
                    title: 'Make it yours',
                    body:
                        'Ten hand-crafted themes, or build your own — size, shape, '
                        'color, glow. Your button, your rules.',
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: ThemePreview(
                        key: ValueKey(themeIndex),
                        theme: kBuiltInThemes[themeIndex],
                        size: 220,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == page
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (page < 2) {
                      controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.fastOutSlowIn,
                      );
                    } else {
                      _finish();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(page < 2 ? 'Continue' : 'Get started'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.body, required this.child});

  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 240, child: Center(child: child)),
          const SizedBox(height: 32),
          Text(title,
              style: textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(body,
              style: textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Mock of the slider notification (doc §8.3 page 2).
class _NotificationMock extends StatelessWidget {
  const _NotificationMock();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 300,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.volume_off_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Icon(Icons.remove_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: 0.65, minHeight: 6, color: scheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.add_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Text('65%', style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final p in const ['0%', '25%', '50%', '75%', '100%'])
                Text(p,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: scheme.primary)),
            ],
          ),
        ],
      ),
    );
  }
}
