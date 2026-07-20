import 'package:flutter/material.dart';

import '../app/tokens/colors.dart';
import '../app/tokens/typography.dart';
import 'theme_toggle_button.dart';

/// Centered screen title used by the map / shop / settings tabs, with the
/// light/dark toggle pinned to the right.
class MetaHeader extends StatelessWidget {
  const MetaHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: AppText.title.copyWith(color: c.ink)),
          const Align(
            alignment: Alignment.centerRight,
            child: ThemeToggleButton(),
          ),
        ],
      ),
    );
  }
}
