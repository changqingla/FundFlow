import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/market.dart';
import '../../providers/market_provider.dart';

/// Volume trend page showing A-share market volume data
class VolumeTrendPage extends ConsumerWidget {
  const VolumeTrendPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumeAsync = ref.watch(volumeTrendProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('成交量趋势'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(volumeTrendProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(volumeTrendProvider.notifier).refresh();
        },
        child: volumeAsync.when(
          data: (volumes) => _buildContent(context, volumes),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _buildErrorWidget(context, ref, error),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<VolumeTrend> volumes) {
    if (volumes.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '近7日A股成交量',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          _buildVolumeChart(context, volumes),
          const SizedBox(height: 24),
          // Legend
          _buildLegend(context),
          const SizedBox(height: 24),
          // Detail list
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '详细数据',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          _buildVolumeList(context, volumes),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildVolumeChart(BuildContext context, List<VolumeTrend> volumes) {
    // Parse volume data for chart
    final shanghaiData = <BarChartGroupData>[];
    final shenzhenData = <BarChartGroupData>[];
    final beijingData = <BarChartGroupData>[];

    double maxY = 0;

    for (var i = 0; i < volumes.length; i++) {
      final shanghai = _parseVolume(volumes[i].shanghai);
      final shenzhen = _parseVolume(volumes[i].shenzhen);
      final beijing = _parseVolume(volumes[i].beijing);

      final total = shanghai + shenzhen + beijing;
      if (total > maxY) maxY = total;

      shanghaiData.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: shanghai,
            color: AppColors.primary,
            width: 20,
          ),
        ],
      ),);
    }

    // Build stacked bar chart data
    final barGroups = <BarChartGroupData>[];
    for (var i = 0; i < volumes.length; i++) {
      final shanghai = _parseVolume(volumes[i].shanghai);
      final shenzhen = _parseVolume(volumes[i].shenzhen);
      final beijing = _parseVolume(volumes[i].beijing);

      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: shanghai + shenzhen + beijing,
            rodStackItems: [
              BarChartRodStackItem(0, shanghai, AppColors.primary),
              BarChartRodStackItem(
                  shanghai, shanghai + shenzhen, AppColors.secondary,),
              BarChartRodStackItem(shanghai + shenzhen,
                  shanghai + shenzhen + beijing, AppColors.warning,),
            ],
            width: 24,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      ),);
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.1,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final volume = volumes[group.x];
                return BarTooltipItem(
                  '${volume.date}\n'
                  '总计: ${volume.totalVolume}\n'
                  '上交所: ${volume.shanghai}\n'
                  '深交所: ${volume.shenzhen}\n'
                  '北交所: ${volume.beijing}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < volumes.length) {
                    final date = volumes[index].date;
                    // Show only month-day
                    final parts = date.split('-');
                    if (parts.length >= 2) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${parts[parts.length - 2]}/${parts.last}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    }
                  }
                  return const Text('');
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _formatVolume(value),
                    style: const TextStyle(fontSize: 10),
                  );
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
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LegendItem(color: AppColors.primary, label: '上交所'),
          SizedBox(width: 24),
          _LegendItem(color: AppColors.secondary, label: '深交所'),
          SizedBox(width: 24),
          _LegendItem(color: AppColors.warning, label: '北交所'),
        ],
      ),
    );
  }

  Widget _buildVolumeList(BuildContext context, List<VolumeTrend> volumes) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: volumes.length,
      itemBuilder: (context, index) {
        return _VolumeCard(volume: volumes[index]);
      },
    );
  }

  Widget _buildErrorWidget(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.read(volumeTrendProvider.notifier).refresh();
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  double _parseVolume(String volumeStr) {
    // Parse volume string like "1.23万亿" or "12345亿"
    final cleanStr = volumeStr.replaceAll(RegExp(r'[^\d.]'), '');
    final value = double.tryParse(cleanStr) ?? 0;

    if (volumeStr.contains('万亿')) {
      return value * 10000; // Convert to 亿
    }
    return value;
  }

  String _formatVolume(double value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万亿';
    }
    return '${value.toStringAsFixed(0)}亿';
  }
}

/// Legend item widget
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Volume card widget
class _VolumeCard extends StatelessWidget {
  final VolumeTrend volume;

  const _VolumeCard({required this.volume});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  volume.date,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '总计: ${volume.totalVolume}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Exchange breakdown
            Row(
              children: [
                Expanded(
                  child: _ExchangeInfo(
                    label: '上交所',
                    value: volume.shanghai,
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _ExchangeInfo(
                    label: '深交所',
                    value: volume.shenzhen,
                    color: AppColors.secondary,
                  ),
                ),
                Expanded(
                  child: _ExchangeInfo(
                    label: '北交所',
                    value: volume.beijing,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Exchange info widget
class _ExchangeInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ExchangeInfo({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
