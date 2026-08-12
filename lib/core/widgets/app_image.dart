import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import 'app_loading.dart';

class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.url,
    this.cacheKey,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.memCacheWidth,
    this.heroTag,
  });

  final String? url;
  final String? cacheKey;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final int? memCacheWidth;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppSpacing.radiusMd);
    Widget child;
    if (url == null || url!.isEmpty) {
      child = _Fallback(width: width, height: height);
    } else {
      child = CachedNetworkImage(
        imageUrl: url!,
        cacheKey: cacheKey,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: memCacheWidth,
        placeholder: (_, _) => AppSkeleton(height: height ?? 120, width: width),
        errorWidget: (_, _, _) => _Fallback(width: width, height: height, failed: true),
      );
    }

    child = ClipRRect(borderRadius: radius, child: child);
    if (heroTag != null) {
      child = Hero(tag: heroTag!, child: child);
    }
    return child;
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({this.width, this.height, this.failed = false});

  final double? width;
  final double? height;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            failed ? Icons.broken_image_outlined : Icons.photo_outlined,
            color: scheme.onSurfaceVariant,
          ),
          if (failed) ...[
            const SizedBox(height: 4),
            Text('Unable to load', style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
