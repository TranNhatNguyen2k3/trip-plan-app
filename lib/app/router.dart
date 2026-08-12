import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/profile_screen.dart';
import '../features/auth/presentation/settings_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/community/presentation/creator_profile_screen.dart';
import '../features/community/presentation/explore_screen.dart';
import '../features/community/presentation/explore_search_screen.dart';
import '../features/community/presentation/plan_detail_screen.dart';
import '../features/community/presentation/publish_plan_screen.dart';
import '../features/community/presentation/saved_plans_screen.dart';
import '../features/book/presentation/trip_book_screen.dart';
import '../core/constants/feature_flags.dart';
import '../features/budget/presentation/budget_screen.dart';
import '../features/expenses/presentation/expense_detail_screen.dart';
import '../features/expenses/presentation/expense_form_screen.dart';
import '../features/expenses/presentation/expenses_screen.dart';
import '../features/journal/presentation/journal_form_screen.dart';
import '../features/journal/presentation/journal_detail_screen.dart';
import '../features/journal/presentation/journal_screen.dart';
import '../features/journal/presentation/photo_viewer_screen.dart';
import '../features/map/presentation/trip_map_screen.dart';
import '../features/recap/presentation/trip_recap_screen.dart';
import '../features/settlements/presentation/settlements_screen.dart';
import '../features/statistics/presentation/statistics_screen.dart';
import '../features/trips/presentation/create_trip_screen.dart';
import '../features/trips/presentation/home_screen.dart';
import '../features/trips/presentation/join_trip_screen.dart';
import '../features/trips/presentation/members_screen.dart';
import '../features/trips/presentation/shell_scaffold.dart';
import '../features/trips/presentation/trip_overview_screen.dart';
import '../features/trips/presentation/trips_screen.dart';
import '../features/trips/presentation/trip_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, _) {
    authRefresh.value++;
  });

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final session = ref.read(supabaseSession);
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/splash';
      final joining = state.matchedLocation.startsWith('/join/');

      if (state.matchedLocation == '/splash') return null;
      if (session == null && !loggingIn && !joining) return '/login';
      if (session != null && (state.matchedLocation == '/login' || state.matchedLocation == '/register')) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/join/:token', builder: (_, state) {
        return JoinTripScreen(token: state.pathParameters['token']!);
      }),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          ]),
          if (FeatureFlags.communityTripPlans)
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/explore',
                builder: (_, _) => const ExploreScreen(),
                routes: [
                  GoRoute(
                    path: 'search',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, state) => ExploreSearchScreen(
                      initialQuery: state.uri.queryParameters['q'] ??
                          (state.extra is String ? state.extra as String : null),
                    ),
                  ),
                  GoRoute(
                    path: 'plans/:tripId',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, state) => PlanDetailScreen(
                      tripId: state.pathParameters['tripId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'creators/:userId',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, state) => CreatorProfileScreen(
                      creatorId: state.pathParameters['userId']!,
                    ),
                  ),
                ],
              ),
            ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/trips',
              builder: (_, _) => const TripsScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (_, _) => const CreateTripScreen(),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, _) => const ProfileScreen(),
              routes: [
                if (FeatureFlags.communityTripPlans)
                  GoRoute(
                    path: 'saved',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const SavedPlansScreen(),
                  ),
              ],
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const SettingsScreen(),
      ),
      if (FeatureFlags.communityTripPlans)
        GoRoute(
          path: '/trips/:tripId/publish',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, state) => PublishPlanScreen(
            tripId: state.pathParameters['tripId']!,
          ),
        ),
      GoRoute(
        path: '/trips/:tripId',
        parentNavigatorKey: _rootNavigatorKey,
        routes: [
          ShellRoute(
            builder: (context, state, child) {
              final tripId = state.pathParameters['tripId']!;
              return TripShell(tripId: tripId, child: child);
            },
            routes: [
              GoRoute(
                path: '',
                builder: (_, state) => TripOverviewScreen(
                  tripId: state.pathParameters['tripId']!,
                ),
              ),
              GoRoute(
                path: 'expenses',
                builder: (_, state) => ExpensesScreen(
                  tripId: state.pathParameters['tripId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (_, state) => ExpenseFormScreen(
                      tripId: state.pathParameters['tripId']!,
                    ),
                  ),
                  GoRoute(
                    path: ':expenseId',
                    builder: (_, state) => ExpenseDetailScreen(
                      tripId: state.pathParameters['tripId']!,
                      expenseId: state.pathParameters['expenseId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (_, state) => ExpenseFormScreen(
                          tripId: state.pathParameters['tripId']!,
                          expenseId: state.pathParameters['expenseId'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'journal',
                builder: (_, state) => JournalScreen(
                  tripId: state.pathParameters['tripId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (_, state) => JournalFormScreen(
                      tripId: state.pathParameters['tripId']!,
                    ),
                  ),
                  GoRoute(
                    path: ':entryId',
                    builder: (_, state) => JournalDetailScreen(
                      tripId: state.pathParameters['tripId']!,
                      entryId: state.pathParameters['entryId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (_, state) => JournalFormScreen(
                          tripId: state.pathParameters['tripId']!,
                          entryId: state.pathParameters['entryId'],
                        ),
                      ),
                      GoRoute(
                        path: 'photos',
                        builder: (_, state) {
                          final index =
                              int.tryParse(state.uri.queryParameters['i'] ?? '0') ?? 0;
                          return PhotoViewerScreen(
                            tripId: state.pathParameters['tripId']!,
                            entryId: state.pathParameters['entryId']!,
                            initialIndex: index,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'settlements',
                builder: (_, state) => SettlementsScreen(
                  tripId: state.pathParameters['tripId']!,
                ),
              ),
              GoRoute(
                path: 'map',
                builder: (_, state) => TripMapScreen(
                  tripId: state.pathParameters['tripId']!,
                ),
              ),
              GoRoute(
                path: 'statistics',
                builder: (_, state) => StatisticsScreen(
                  tripId: state.pathParameters['tripId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'members',
            builder: (_, state) => MembersScreen(tripId: state.pathParameters['tripId']!),
          ),
          GoRoute(
            path: 'budget',
            builder: (_, state) => BudgetScreen(tripId: state.pathParameters['tripId']!),
          ),
          GoRoute(
            path: 'recap',
            builder: (_, state) => TripRecapScreen(tripId: state.pathParameters['tripId']!),
          ),
          GoRoute(
            path: 'book',
            builder: (_, state) => TripBookScreen(tripId: state.pathParameters['tripId']!),
          ),
        ],
      ),
    ],
  );
});

/// Session for redirect — uses live Supabase session after auth refresh.
final supabaseSession = Provider<Session?>((ref) {
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentSession;
});
