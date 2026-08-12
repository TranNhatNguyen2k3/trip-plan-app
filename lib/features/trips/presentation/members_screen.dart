import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/trip_repository.dart';
import '../domain/trip.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  bool _inviting = false;

  Future<void> _inviteFriends() async {
    setState(() => _inviting = true);
    try {
      final repo = ref.read(tripRepositoryProvider);
      final trip = await repo.getTrip(widget.tripId);
      final invitation = await repo.createInvitation(widget.tripId);
      await repo.shareInvitation(invitation, trip.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation ready to share')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapErrorToMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(tripMembersProvider(widget.tripId));
    final tripAsync = ref.watch(tripProvider(widget.tripId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/trips/${widget.tripId}');
            }
          },
        ),
      ),
      body: membersAsync.when(
        loading: () => const AppLoading(message: 'Loading members…'),
        error: (e, _) => AppErrorState(
          error: e,
          onRetry: () => ref.invalidate(tripMembersProvider(widget.tripId)),
        ),
        data: (members) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                  AppSpacing.screenPadding,
                  AppSpacing.lg,
                ),
                child: AppButton(
                  label: 'Invite Friends',
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: _inviteFriends,
                  isLoading: _inviting,
                ),
              ),
              if (tripAsync.asData?.value != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${members.length} traveler${members.length == 1 ? '' : 's'} on ${tripAsync.asData!.value.name}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: members.isEmpty
                    ? AppEmptyState(
                        title: 'No members yet',
                        message: 'Invite friends to split costs and share memories.',
                        icon: Icons.group_outlined,
                        actionLabel: 'Invite Friends',
                        onAction: _inviteFriends,
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(tripMembersProvider(widget.tripId));
                          await ref.read(
                            tripMembersProvider(widget.tripId).future,
                          );
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenPadding,
                            AppSpacing.sm,
                            AppSpacing.screenPadding,
                            AppSpacing.xxl,
                          ),
                          itemCount: members.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.md),
                          itemBuilder: (context, index) {
                            return _MemberTile(member: members[index]);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final TripMember member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = member.profile?.displayName ?? 'Traveler';
    final isOwner = member.role == TripMemberRole.owner;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          AppAvatar(
            url: member.profile?.avatarUrl,
            name: name,
            size: 48,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.titleMedium),
                Text(
                  isOwner ? 'Owner' : 'Member',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isOwner ? AppColors.primaryDark : null,
                    fontWeight: isOwner ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
          if (isOwner)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                'Owner',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
