import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../auth/data/auth_repository.dart';
import '../data/trip_repository.dart';

class JoinTripScreen extends ConsumerStatefulWidget {
  const JoinTripScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends ConsumerState<JoinTripScreen> {
  Object? _error;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _accept());
  }

  Future<void> _accept() async {
    if (_started) return;
    _started = true;

    final session = ref.read(authRepositoryProvider).currentSession;
    if (session == null) {
      if (!mounted) return;
      context.go('/login');
      return;
    }

    setState(() => _error = null);
    try {
      final tripId =
          await ref.read(tripRepositoryProvider).acceptInvitation(widget.token);
      ref.invalidate(tripsProvider);
      if (!mounted) return;
      context.go('/trips/$tripId');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                const Spacer(),
                AppErrorState(
                  error: _error!,
                  onRetry: () {
                    _started = false;
                    _accept();
                  },
                ),
                const Spacer(),
                AppButton(
                  label: 'Go home',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.go('/'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryTint,
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  size: 36,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Joining trip…',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Accepting your invitation',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxl),
              const AppLoading(),
            ],
          ),
        ),
      ),
    );
  }
}
