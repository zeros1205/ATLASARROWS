import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../shared/pressable.dart';

/// Home: wordmark + primary PLAY (resume) + a secondary map entry. No
/// hearts/gem in the header (hearts live in-play; gem is unused).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Z'),
                TextSpan(text: '·', style: TextStyle(color: c.accent)),
                const TextSpan(text: 'ARROWS'),
              ]),
              style: AppText.display.copyWith(
                  color: c.ink, fontSize: 40, letterSpacing: -1),
            ),
            const SizedBox(height: 6),
            Text('SHIFT THE ARROWS',
                style: AppText.caption
                    .copyWith(color: c.inkFaint, letterSpacing: 2.5)),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: Column(
                children: [
                  _PrimaryButton(
                    label: '플레이',
                    sub: '한국 · 서울 4/5',
                    onTap: () {},
                  ),
                  const SizedBox(height: AppGap.md),
                  _SecondaryButton(label: '세계지도', icon: Icons.public_outlined,
                      onTap: () {}),
                ],
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton(
      {required this.label, required this.sub, required this.onTap});
  final String label, sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          children: [
            Text(label,
                style: AppText.headline
                    .copyWith(color: c.onAccent, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(sub,
                style: AppText.caption.copyWith(
                    color: c.onAccent.withValues(alpha: 0.8),
                    letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: c.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: c.ink),
            const SizedBox(width: 8),
            Text(label,
                style: AppText.label
                    .copyWith(color: c.ink, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
