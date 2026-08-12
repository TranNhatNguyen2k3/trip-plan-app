import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_currency_text.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../expenses/domain/expense.dart';
import '../data/statistics_repository.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key, required this.tripId});

  final String tripId;

  static const _chartColors = [
    AppColors.primary,
    AppColors.travelAccent,
    Color(0xFF2563EB),
    Color(0xFFDB2777),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFF65A30D),
    Color(0xFFEA580C),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(tripStatisticsProvider(tripId));

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: statsAsync.when(
        loading: () => const AppLoading(message: 'Crunching numbers…'),
        error: (error, _) => AppErrorState(
          error: error,
          onRetry: () => ref.invalidate(tripStatisticsProvider(tripId)),
        ),
        data: (stats) {
          if (stats.totalSpent == 0) {
            return AppEmptyState(
              title: 'No spending yet',
              message: 'Add expenses to see charts and totals.',
              icon: Icons.pie_chart_outline,
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(tripStatisticsProvider(tripId)),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total spent',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppCurrencyText(stats.totalSpent, fontSize: 34),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'By category',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: SizedBox(
                    height: 220,
                    child: stats.byCategory.isEmpty
                        ? const Center(child: Text('No category data'))
                        : Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 36,
                                    sections: [
                                      for (var i = 0;
                                          i < stats.byCategory.length;
                                          i++)
                                        PieChartSectionData(
                                          color: _chartColors[
                                              i % _chartColors.length],
                                          value: stats.byCategory[i].amount
                                              .toDouble(),
                                          title: '',
                                          radius: 48,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (var i = 0;
                                        i < stats.byCategory.length;
                                        i++)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: AppSpacing.xs,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: _chartColors[
                                                    i % _chartColors.length],
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _categoryLabel(
                                                  stats.byCategory[i].category,
                                                ),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'By member',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: SizedBox(
                    height: 220,
                    child: stats.byMember.isEmpty
                        ? const Center(child: Text('No member data'))
                        : BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: _maxAmount(
                                    stats.byMember.map((e) => e.amount),
                                  ) *
                                  1.2,
                              barTouchData: BarTouchData(
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipItem: (group, _, rod, _) {
                                    final member = stats.byMember[group.x];
                                    return BarTooltipItem(
                                      '${member.displayName ?? 'Traveler'}\n'
                                      '${formatCurrency(member.amount)}',
                                      const TextStyle(color: Colors.white),
                                    );
                                  },
                                ),
                              ),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 44,
                                    getTitlesWidget: (value, _) => Text(
                                      formatCompactCurrency(value.toInt()),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, _) {
                                      final i = value.toInt();
                                      if (i < 0 || i >= stats.byMember.length) {
                                        return const SizedBox.shrink();
                                      }
                                      final name =
                                          stats.byMember[i].displayName ?? '?';
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          name.length > 8
                                              ? '${name.substring(0, 7)}…'
                                              : name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              barGroups: [
                                for (var i = 0; i < stats.byMember.length; i++)
                                  BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: stats.byMember[i].amount
                                            .toDouble(),
                                        color: _chartColors[
                                            i % _chartColors.length],
                                        width: 18,
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(6),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Daily spending',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: SizedBox(
                    height: 220,
                    child: stats.byDate.isEmpty
                        ? const Center(child: Text('No daily data'))
                        : LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: _maxAmount(
                                    stats.byDate.map((e) => e.amount),
                                  ) *
                                  1.2,
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipItems: (spots) {
                                    return spots.map((spot) {
                                      final day = stats.byDate[spot.x.toInt()];
                                      return LineTooltipItem(
                                        '${formatDate(day.date)}\n'
                                        '${formatCurrency(day.amount)}',
                                        const TextStyle(color: Colors.white),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 44,
                                    getTitlesWidget: (value, _) => Text(
                                      formatCompactCurrency(value.toInt()),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 1,
                                    getTitlesWidget: (value, _) {
                                      final i = value.toInt();
                                      if (i < 0 ||
                                          i >= stats.byDate.length ||
                                          (stats.byDate.length > 6 &&
                                              i %
                                                      ((stats.byDate.length / 4)
                                                          .ceil()) !=
                                                  0)) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          DateFormat('M/d')
                                              .format(stats.byDate[i].date),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.4),
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  isCurved: true,
                                  color: AppColors.primary,
                                  barWidth: 3,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: AppColors.primary
                                        .withValues(alpha: 0.12),
                                  ),
                                  spots: [
                                    for (var i = 0;
                                        i < stats.byDate.length;
                                        i++)
                                      FlSpot(
                                        i.toDouble(),
                                        stats.byDate[i].amount.toDouble(),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }

  static double _maxAmount(Iterable<int> amounts) {
    var max = 0;
    for (final a in amounts) {
      if (a > max) max = a;
    }
    return max == 0 ? 1 : max.toDouble();
  }

  static String _categoryLabel(String raw) {
    return ExpenseCategory.fromString(raw).label;
  }
}
