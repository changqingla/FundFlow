import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/market.dart';
import '../../providers/market_provider.dart';

/// Minute chart page showing Shanghai index intraday data
class MinuteChartPage extends ConsumerWidget {
  const MinuteChartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minuteAsync = ref.watch(minuteDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('上证分时'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(minuteDataProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(minuteDataProvider.notifier).refresh();
        },
        child: minuteAsync.when(
          data: (data) => _buildContent(context, data),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _buildErrorWidget(context, ref, error),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<MinuteData> data) {
    if (data.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current price header
          _buildPriceHeader(context, data.last),
          const SizedBox(height: 16),
          // Price chart
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '分时走势',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          _buildPriceChart(context, data),
          const SizedBox(height: 24),
          // Volume chart
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '成交量',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          _buildVolumeChart(context, data),
          const SizedBox(height: 24),
          // Detail list
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '分时明细',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          _buildMinuteList(context, data),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPriceHeader(BuildContext context, MinuteData latest) {
    final changeRate = latest.changeRate;
    final isUp = !changeRate.startsWith('-');
    final changeColor = isUp ? AppColors.stockUp : AppColors.stockDown;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            changeColor.withOpacity(0.1),
            changeColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: changeColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '上证指数',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                latest.price,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: changeColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isUp ? "+" : ""}${latest.change}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: changeColor,
                        ),
                  ),
                  Text(
                    latest.changeRate,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: changeColor,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoItem(label: '成交量', value: latest.volume),
              const SizedBox(width: 24),
              _InfoItem(label: '成交额', value: latest.amount),
              const SizedBox(width: 24),
              _InfoItem(label: '时间', value: latest.time),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceChart(BuildContext context, List<MinuteData> data) {
    // Parse price data for chart
    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      final price = double.tryParse(data[i].price.replaceAll(',', ''));
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

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;
    final padding = range * 0.1;

    // Determine line color based on overall trend
    final firstPrice = spots.first.y;
    final lastPrice = spots.last.y;
    final lineColor = lastPrice >= firstPrice ? AppColors.stockUp : AppColors.stockDown;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: range / 4,
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
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (data.length / 5).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < data.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        data[index].time,
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
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
          minY: minY - padding,
          maxY: maxY + padding,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: lineColor,
              barWidth: 1.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index < data.length) {
                    final minute = data[index];
                    return LineTooltipItem(
                      '${minute.time}\n'
                      '价格: ${minute.price}\n'
                      '涨跌: ${minute.change} (${minute.changeRate})',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  }
                  return null;
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeChart(BuildContext context, List<MinuteData> data) {
    // Parse volume data for chart
    final barGroups = <BarChartGroupData>[];
    double maxY = 0;

    for (var i = 0; i < data.length; i++) {
      final volume = _parseVolume(data[i].volume);
      if (volume > maxY) maxY = volume;

      // Determine bar color based on price change
      final isUp = !data[i].changeRate.startsWith('-');
      final barColor = isUp ? AppColors.stockUp : AppColors.stockDown;

      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: volume,
            color: barColor.withOpacity(0.7),
            width: 3,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
        ],
      ));
    }

    if (barGroups.isEmpty) {
      return const SizedBox(
        height: 150,
        child: Center(child: Text('无法解析成交量数据')),
      );
    }

    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.1,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                if (group.x < data.length) {
                  final minute = data[group.x];
                  return BarTooltipItem(
                    '${minute.time}\n成交量: ${minute.volume}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  );
                }
                return null;
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
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
            horizontalInterval: maxY / 3,
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

  Widget _buildMinuteList(BuildContext context, List<MinuteData> data) {
    // Show latest 20 entries in reverse order
    final displayData = data.reversed.take(20).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: displayData.length,
      itemBuilder: (context, index) {
        return _MinuteDataRow(data: displayData[index]);
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
              ref.read(minuteDataProvider.notifier).refresh();
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  double _parseVolume(String volumeStr) {
    final cleanStr = volumeStr.replaceAll(RegExp(r'[^\d.]'), '');
    final value = double.tryParse(cleanStr) ?? 0;

    if (volumeStr.contains('亿')) {
      return value * 10000;
    } else if (volumeStr.contains('万')) {
      return value;
    }
    return value / 10000; // Convert to 万
  }

  String _formatVolume(double value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}亿';
    }
    return '${value.toStringAsFixed(0)}万';
  }
}

/// Info item widget
class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// Minute data row widget
class _MinuteDataRow extends StatelessWidget {
  final MinuteData data;

  const _MinuteDataRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final isUp = !data.changeRate.startsWith('-');
    final changeColor = isUp ? AppColors.stockUp : AppColors.stockDown;

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
          // Time
          SizedBox(
            width: 50,
            child: Text(
              data.time,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          // Price
          Expanded(
            child: Text(
              data.price,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: changeColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          // Change
          SizedBox(
            width: 70,
            child: Text(
              data.change,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: changeColor,
                  ),
              textAlign: TextAlign.right,
            ),
          ),
          // Change rate
          SizedBox(
            width: 60,
            child: Text(
              data.changeRate,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: changeColor,
                  ),
              textAlign: TextAlign.right,
            ),
          ),
          // Volume
          SizedBox(
            width: 60,
            child: Text(
              data.volume,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
