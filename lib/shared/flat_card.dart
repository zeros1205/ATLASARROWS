import 'package:flutter/material.dart';

import '../app/tokens/colors.dart';
import '../app/tokens/dimens.dart';
import 'pressable.dart';

/// A flat surface card — hairline border, no shadow. Depth comes from the
/// border and whitespace, matching the paper+ink identity.
class FlatCard extends StatelessWidget {
  const FlatCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppGap.lg),
    this.radius = AppRadius.lg,
    this.color,
    this.border = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.card,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: c.line, width: 1) : null,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, scale: 0.97, child: card);
  }
}
