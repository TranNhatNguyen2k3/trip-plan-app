import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_loading.dart';
import '../../journal/data/journal_repository.dart';
import '../data/trip_map_service.dart';
import '../domain/trip_map_point.dart';

class TripMapScreen extends ConsumerStatefulWidget {
  const TripMapScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends ConsumerState<TripMapScreen> {
  TripMapPoint? _selected;
  List<TripMapPoint>? _clusterGroup;

  @override
  Widget build(BuildContext context) {
    final pointsAsync = ref.watch(tripMapPointsProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Map')),
      body: pointsAsync.when(
        loading: () => const AppLoading(message: 'Loading map…'),
        error: (e, _) => AppErrorState(
          error: e,
          onRetry: () => ref.invalidate(tripMapPointsProvider(widget.tripId)),
        ),
        data: (points) {
          if (points.isEmpty) {
            return AppEmptyState(
              title: 'Your journey map is empty',
              message: 'Add locations to your memories to see your trip here.',
              icon: Icons.map_outlined,
              actionLabel: 'Add Memory',
              onAction: () => context.push('/trips/${widget.tripId}/journal/create'),
            );
          }

          final journey = sortJourney(points);
          final clusters = clusterMapPoints(journey, precision: 0.008);
          final center = LatLng(journey.first.latitude, journey.first.longitude);
          final placeNames = journey
              .map((p) => p.locationName)
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .toSet();

          return Column(
            children: [
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 12,
                    onTap: (_, _) => setState(() {
                      _selected = null;
                      _clusterGroup = null;
                    }),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.tripmate.tripmate',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: journey
                              .map((p) => LatLng(p.latitude, p.longitude))
                              .toList(),
                          color: AppColors.primary.withValues(alpha: 0.7),
                          strokeWidth: 3,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        for (final group in clusters)
                          Marker(
                            point: LatLng(
                              group.map((e) => e.latitude).reduce((a, b) => a + b) /
                                  group.length,
                              group.map((e) => e.longitude).reduce((a, b) => a + b) /
                                  group.length,
                            ),
                            width: 44,
                            height: 44,
                            child: GestureDetector(
                              onTap: () {
                                if (group.length == 1) {
                                  setState(() {
                                    _selected = group.first;
                                    _clusterGroup = null;
                                  });
                                } else {
                                  setState(() {
                                    _clusterGroup = group;
                                    _selected = null;
                                  });
                                }
                              },
                              child: _MarkerBubble(count: group.length),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                color: Theme.of(context).colorScheme.surface,
                child: Text(
                  '${placeNames.length} places · ${journey.length} memories',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (_clusterGroup != null)
                _ClusterSheet(
                  points: _clusterGroup!,
                  onSelect: (p) => setState(() {
                    _selected = p;
                    _clusterGroup = null;
                  }),
                ),
              if (_selected != null)
                _MarkerDetail(
                  tripId: widget.tripId,
                  point: _selected!,
                  onClose: () => setState(() => _selected = null),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MarkerBubble extends StatelessWidget {
  const _MarkerBubble({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        count > 1 ? '$count' : '📍',
        style: TextStyle(
          color: Colors.white,
          fontSize: count > 1 ? 12 : 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ClusterSheet extends StatelessWidget {
  const _ClusterSheet({required this.points, required this.onSelect});

  final List<TripMapPoint> points;
  final ValueChanged<TripMapPoint> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: SizedBox(
        height: 160,
        child: ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: points.length,
          itemBuilder: (context, i) {
            final p = points[i];
            return ListTile(
              title: Text(p.displayTitle),
              subtitle: Text(formatDate(p.visitedAt)),
              onTap: () => onSelect(p),
            );
          },
        ),
      ),
    );
  }
}

class _MarkerDetail extends ConsumerStatefulWidget {
  const _MarkerDetail({
    required this.tripId,
    required this.point,
    required this.onClose,
  });

  final String tripId;
  final TripMapPoint point;
  final VoidCallback onClose;

  @override
  ConsumerState<_MarkerDetail> createState() => _MarkerDetailState();
}

class _MarkerDetailState extends ConsumerState<_MarkerDetail> {
  String? _photoUrl;
  bool _loadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final path = widget.point.photoPath;
    if (path == null) return;
    setState(() => _loadingPhoto = true);
    final url = await ref.read(journalRepositoryProvider).signedUrl(path);
    if (!mounted) return;
    setState(() {
      _photoUrl = url;
      _loadingPhoto = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.point;
    return Material(
      elevation: 12,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      point.displayTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close)),
                ],
              ),
              if (_loadingPhoto)
                const AppSkeleton(height: 140)
              else if (_photoUrl != null)
                AppImage(
                  url: _photoUrl,
                  height: 140,
                  width: double.infinity,
                  memCacheWidth: 800,
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${formatDate(point.visitedAt)} · ${formatTime(point.visitedAt)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'View Memory',
                onPressed: () =>
                    context.push('/trips/${widget.tripId}/journal/${point.id}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
