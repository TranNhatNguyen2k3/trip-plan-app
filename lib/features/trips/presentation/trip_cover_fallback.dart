import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';

class TripCoverFallback extends StatelessWidget {
  const TripCoverFallback({super.key, this.height = 160});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
            Color(0xFF004AAD),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.landscape_outlined, color: Colors.white70, size: 48),
      ),
    );
  }
}
