import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/trip_realtime.dart';
import '../data/trip_repository.dart';

class TripShell extends ConsumerStatefulWidget {
  const TripShell({
    super.key,
    required this.tripId,
    required this.child,
  });

  final String tripId;
  final Widget child;

  @override
  ConsumerState<TripShell> createState() => _TripShellState();
}

class _TripShellState extends ConsumerState<TripShell>
    with SingleTickerProviderStateMixin {
  bool _fabOpen = false;
  late final AnimationController _fabController;
  late final Animation<double> _fabExpand;

  static const _tabs = [
    (label: 'Overview', icon: Icons.dashboard_outlined),
    (label: 'Expenses', icon: Icons.payments_outlined),
    (label: 'Journal', icon: Icons.photo_album_outlined),
    (label: 'Map', icon: Icons.map_outlined),
    (label: 'Settlements', icon: Icons.handshake_outlined),
    (label: 'More', icon: Icons.more_horiz),
  ];

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fabExpand = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  int _tabIndexForPath(String path) {
    if (path.contains('/expenses')) return 1;
    if (path.contains('/journal')) return 2;
    if (path.contains('/map')) return 3;
    if (path.contains('/settlements')) return 4;
    if (path.contains('/statistics') ||
        path.contains('/members') ||
        path.contains('/budget') ||
        path.contains('/recap') ||
        path.contains('/book')) {
      return 5;
    }
    return 0;
  }

  void _goTab(int index) {
    final base = '/trips/${widget.tripId}';
    switch (index) {
      case 0:
        context.go(base);
      case 1:
        context.go('$base/expenses');
      case 2:
        context.go('$base/journal');
      case 3:
        context.go('$base/map');
      case 4:
        context.go('$base/settlements');
      case 5:
        _showMoreMenu();
    }
  }

  Future<void> _showMoreMenu() async {
    final base = '/trips/${widget.tripId}';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.insights_outlined),
                title: const Text('Statistics'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('$base/statistics');
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Budget'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('$base/budget');
                },
              ),
              ListTile(
                leading: const Icon(Icons.public_outlined),
                title: const Text('Publish Trip Plan'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('$base/publish');
                },
              ),
              ListTile(
                leading: const Icon(Icons.movie_filter_outlined),
                title: const Text('Trip Recap'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('$base/recap');
                },
              ),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Trip Book'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('$base/book');
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('Members'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('$base/members');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleFab() {
    setState(() => _fabOpen = !_fabOpen);
    if (_fabOpen) {
      _fabController.forward();
    } else {
      _fabController.reverse();
    }
  }

  void _closeFab() {
    if (!_fabOpen) return;
    setState(() => _fabOpen = false);
    _fabController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(tripRealtimeProvider(widget.tripId));
    final tripAsync = ref.watch(tripProvider(widget.tripId));
    final location = GoRouterState.of(context).uri.path;
    final selected = _tabIndexForPath(location);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: tripAsync.when(
          loading: () => const Text('Trip'),
          error: (_, _) => const Text('Trip'),
          data: (trip) => Text(trip.name),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/trips');
            }
          },
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: _tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final active = selected == index;
                return FilterChip(
                  selected: active,
                  showCheckmark: false,
                  avatar: Icon(
                    tab.icon,
                    size: 18,
                    color: active ? AppColors.primaryDark : AppColors.textSecondary,
                  ),
                  label: Text(tab.label),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  backgroundColor: theme.colorScheme.surface,
                  side: BorderSide(
                    color: active ? AppColors.primary : AppColors.border,
                  ),
                  labelStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: active ? AppColors.primaryDark : AppColors.textSecondary,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                  onSelected: (_) => _goTab(index),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: tripAsync.when(
              loading: () => const AppLoading(),
              error: (e, _) => AppErrorState(
                error: e,
                onRetry: () => ref.invalidate(tripProvider(widget.tripId)),
              ),
              data: (_) => widget.child,
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FadeTransition(
            opacity: _fabExpand,
            child: ScaleTransition(
              scale: _fabExpand,
              alignment: Alignment.bottomRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _FabAction(
                    icon: Icons.payments_rounded,
                    label: 'Add Expense',
                    onTap: () {
                      _closeFab();
                      context.push('/trips/${widget.tripId}/expenses/create');
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _FabAction(
                    icon: Icons.photo_camera_rounded,
                    label: 'Add Memory',
                    onTap: () {
                      _closeFab();
                      context.push('/trips/${widget.tripId}/journal/create');
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
          FloatingActionButton(
            heroTag: 'trip-fab-${widget.tripId}',
            onPressed: _toggleFab,
            child: AnimatedRotation(
              turns: _fabOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 220),
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _FabAction extends StatelessWidget {
  const _FabAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(label, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}
