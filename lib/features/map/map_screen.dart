import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/typography.dart';
import '../../shared/meta_header.dart';

/// Map tab = the world campaign map (round = country, city stages placed
/// at real geo positions). Skeleton; the real map lands next session.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const MetaHeader('맵'),
          Expanded(
            child: Center(
              child: Text('세계지도 캠페인 (구현 예정)',
                  style: AppText.body.copyWith(color: c.inkFaint)),
            ),
          ),
        ],
      ),
    );
  }
}
