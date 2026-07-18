import 'package:flutter/material.dart';

import '../app/tokens/colors.dart';
import '../app/tokens/typography.dart';

/// Centered screen title used by the map / shop / settings tabs.
class MetaHeader extends StatelessWidget {
  const MetaHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
      child: Text(title,
          textAlign: TextAlign.center,
          style: AppText.title.copyWith(color: c.ink)),
    );
  }
}
