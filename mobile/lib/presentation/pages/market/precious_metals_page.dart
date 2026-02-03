import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/market.dart';
import '../../providers/market_provider.dart';

/// Precious metals page showing real-time prices and gold history chart
class PreciousMetalsPage extends ConsumerWidget {
  const PreciousMetalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metalsAsync = ref.watch(preciousMetalsProvider);
    final goldHistoryAsync = ref.watch(goldHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('贵金属'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(preciousMetalsProvider.notifier).refresh();
              ref.read(goldHistoryProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(preciousMetalsProvider.notifier).refresh(),
            ref.read(goldHistoryProvider.notifier).refresh(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Real-time prices section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '实时价格',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              metalsAsync.when(
                data: (metals) => _buildMetalsList(context, metals),
                loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _buildErrorWidget(context, error),
              ),
              const SizedBox(height: 24),
              // Gold history chart section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '历史金价',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              goldHistoryAsync.when(
                data: (history) => _buildGoldHistoryChart(context, history),
                loading: () => const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _buildErrorWidget(context, error),
              ),
              const SizedBox(height: 16),
              // Gold history table
              goldHistoryAsync.when(
                data: (history) => _buildGoldHistoryTable(context, history),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetalsList(BuildContext context, List<PreciousMetal> metals) {
    if (metals.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text('暂无数据')),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: metals.length,
      itemBuilder: (context, index) {
        return _PreciousMetalCard(metal: metals[index]);
      },
    );
  }

  Widget _buildGoldHistoryChart(BuildContext context, List<GoldPrice> history) {
    if (history.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('暂无历史数据')),
      );
    }

    // Parse China gold prices for chart
    final spots = <FlSpot>[];
    for (var i = 0; i < history.length; i++) {
      final price = double.tryParse(
        history[i].chinaGoldPrice.replaceAll(RegExp(r'[^\d.]'), ''),
      );
      if (price != null) {
        spots.add(FlSpot(i.toDouble(), price));
      }
    }

    if (spots.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('无法解析价格数据')),
      );
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 5;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 5;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (history.length / 5).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < history.length) {
                    final date = history[index].date;
                    // Show only month-day
                    final parts = date.split('-');
                    if (parts.length >= 2) {
                      return Text(
                        '${parts[parts.length - 2]}/${parts.last}',
                        style: const TextStyle(fontSize: 10),
                      );
                    }
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  final date =
                      index < history.length ? history[index].date : '';
                  return LineTooltipItem(
                    '$date\n¥${spot.y.toStringAsFixed(2)}',
                    const TextStyle(color: Colors.white),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoldHistoryTable(BuildContext context, List<GoldPrice> history) {
    if (history.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    '日期',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '中国黄金',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '周大福',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Table rows
          ...history.take(10).map((price) => _GoldPriceRow(price: price)),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, Object error) {
    return SizedBox(
      height: 100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(height: 8),
            Text(
              '加载失败: ${error.toString()}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Precious metal card widget
class _PreciousMetalCard extends StatelessWidget {
  final PreciousMetal metal;

  const _PreciousMetalCard({required this.metal});

  @override
  Widget build(BuildContext context) {
    final isUp = metal.change >= 0;
    final changeColor = isUp ? AppColors.stockUp : AppColors.stockDown;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name and price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  metal.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${metal.price.toStringAsFixed(2)} ${metal.unit}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: changeColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Change info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '涨跌额: ${isUp ? "+" : ""}${metal.change.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: changeColor,
                      ),
                ),
                Text(
                  '涨跌幅: ${metal.changeRate}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: changeColor,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // OHLC info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InfoChip(label: '开', value: metal.open.toStringAsFixed(2)),
                _InfoChip(label: '高', value: metal.high.toStringAsFixed(2)),
                _InfoChip(label: '低', value: metal.low.toStringAsFixed(2)),
                _InfoChip(label: '收', value: metal.close.toStringAsFixed(2)),
              ],
            ),
            const SizedBox(height: 8),
            // Update time
            Text(
              '更新时间: ${metal.updatedAt}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Info chip for OHLC display
class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Gold price table row
class _GoldPriceRow extends StatelessWidget {
  final GoldPrice price;

  const _GoldPriceRow({required this.price});

  Color _getChangeColor(String change) {
    if (change.contains('+') || change.contains('涨')) {
      return AppColors.stockUp;
    } else if (change.contains('-') || change.contains('跌')) {
      return AppColors.stockDown;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              price.date,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price.chinaGoldPrice,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  price.chinaChange,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _getChangeColor(price.chinaChange),
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price.chowTaiFook,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  price.chowChange,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _getChangeColor(price.chowChange),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
