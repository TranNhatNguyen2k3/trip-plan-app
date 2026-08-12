import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/community_repository.dart';
import '../domain/public_trip_plan.dart';
import 'plan_card.dart';

class ExploreSearchScreen extends ConsumerStatefulWidget {
  const ExploreSearchScreen({super.key, this.initialQuery});

  /// From GoRouter `extra` or constructed from `?q=`.
  final String? initialQuery;

  @override
  ConsumerState<ExploreSearchScreen> createState() =>
      _ExploreSearchScreenState();
}

class _ExploreSearchScreenState extends ConsumerState<ExploreSearchScreen> {
  late final TextEditingController _controller;
  String? _tripType;
  String _sort = 'popular';
  String _destination = '';
  bool _seeded = false;

  static const _sortOptions = [
    ('popular', 'Popular'),
    ('recent', 'Recent'),
    ('trending', 'Trending'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final fromExtra = widget.initialQuery?.trim();
    final fromQuery =
        GoRouterState.of(context).uri.queryParameters['q']?.trim();
    final initial = (fromExtra != null && fromExtra.isNotEmpty)
        ? fromExtra
        : (fromQuery ?? '');
    _controller.text = initial;
    _destination = initial;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applySearch([String? value]) {
    setState(() {
      _destination = (value ?? _controller.text).trim();
    });
  }

  ({String? destination, String? tripType, String sort}) get _query => (
        destination: _destination.isEmpty ? null : _destination,
        tripType: _tripType,
        sort: _sort,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plansAsync = ref.watch(publicPlansProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Search plans',
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppColors.primaryDark,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.sm,
              AppSpacing.screenPadding,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: _controller,
                  hint: 'Destination or city',
                  prefixIcon: const Icon(Icons.search_rounded),
                  textInputAction: TextInputAction.search,
                  onChanged: (v) {
                    if (v.trim().isEmpty && _destination.isNotEmpty) {
                      _applySearch('');
                    }
                  },
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded),
                    tooltip: 'Search',
                    onPressed: () => _applySearch(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Trip type', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: AppSpacing.touchTarget + 4,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: AppChip(
                          label: 'All',
                          selected: _tripType == null,
                          onTap: () => setState(() {
                            _tripType = null;
                            _destination = _controller.text.trim();
                          }),
                        ),
                      ),
                      ...tripTypeOptions.map(
                        (type) => Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: AppChip(
                            label: tripTypeLabel(type),
                            selected: _tripType == type,
                            onTap: () => setState(() {
                              _tripType = _tripType == type ? null : type;
                              _destination = _controller.text.trim();
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Sort', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: AppSpacing.touchTarget + 4,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _sortOptions
                        .map(
                          (opt) => Padding(
                            padding:
                                const EdgeInsets.only(right: AppSpacing.sm),
                            child: AppChip(
                              label: opt.$2,
                              selected: _sort == opt.$1,
                              onTap: () => setState(() {
                                _sort = opt.$1;
                                _destination = _controller.text.trim();
                              }),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: plansAsync.when(
              loading: () => const AppLoading(message: 'Searching…'),
              error: (e, _) => AppErrorState(
                error: e,
                onRetry: () => ref.invalidate(publicPlansProvider(_query)),
              ),
              data: (plans) {
                if (plans.isEmpty) {
                  final q = _destination.isEmpty
                      ? 'your filters'
                      : '"$_destination"';
                  return AppEmptyState(
                    title: 'No plans found',
                    message:
                        'No plans found for $q. Try another destination.',
                    icon: Icons.search_off_rounded,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(publicPlansProvider(_query));
                    await ref.read(publicPlansProvider(_query).future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      AppSpacing.sm,
                      AppSpacing.screenPadding,
                      AppSpacing.xxxl,
                    ),
                    itemCount: plans.length + 1,
                    separatorBuilder: (_, index) {
                      if (index == 0) {
                        return const SizedBox(height: AppSpacing.lg);
                      }
                      return const SizedBox(height: AppSpacing.xl);
                    },
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Text(
                          '${plans.length} plan${plans.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodyMedium,
                        );
                      }
                      final plan = plans[index - 1];
                      return PlanCard(
                        plan: plan,
                        onTap: () =>
                            context.push('/explore/plans/${plan.tripId}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
