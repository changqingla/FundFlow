import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/fund.dart';
import '../../../providers/fund_provider.dart';
import '../../fund/add_fund_page.dart';
import '../../fund/fund_detail_page.dart';

/// Fund tab showing user's watchlist funds
class FundTab extends ConsumerWidget {
  const FundTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fundState = ref.watch(fundListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('自选基金'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddFundPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(fundListProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(fundListProvider.notifier).refresh();
        },
        child: fundState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : fundState.error != null && fundState.funds.isEmpty
                ? _buildErrorWidget(context, ref, fundState.error!)
                : _buildFundList(context, ref, fundState.funds),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddFundPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFundList(
      BuildContext context, WidgetRef ref, List<Fund> funds) {
    if (funds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '暂无自选基金',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右上角 + 添加基金',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    // Sort funds: held funds first, then by valuation change
    final sortedFunds = List<Fund>.from(funds);
    sortedFunds.sort((a, b) {
      // Held funds first
      if (a.isHold && !b.isHold) return -1;
      if (!a.isHold && b.isHold) return 1;
      
      // Then by day growth
      final aGrowth = _parseDayGrowth(a.valuation?.dayGrowth);
      final bGrowth = _parseDayGrowth(b.valuation?.dayGrowth);
      return bGrowth.compareTo(aGrowth);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedFunds.length,
      itemBuilder: (context, index) {
        return _FundCard(fund: sortedFunds[index]);
      },
    );
  }

  double _parseDayGrowth(String? growth) {
    if (growth == null) return 0;
    return double.tryParse(growth.replaceAll('%', '').replaceAll('+', '')) ?? 0;
  }

  Widget _buildErrorWidget(BuildContext context, WidgetRef ref, String error) {
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
            error,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.read(fundListProvider.notifier).refresh();
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

/// Fund card widget with valuation display
class _FundCard extends ConsumerWidget {
  final Fund fund;

  const _FundCard({required this.fund});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valuation = fund.valuation;
    final dayGrowth = valuation != null
        ? double.tryParse(valuation.dayGrowth.replaceAll('%', '').replaceAll('+', '')) ?? 0
        : 0.0;
    final isUp = dayGrowth >= 0;
    final changeColor = isUp ? AppColors.stockUp : AppColors.stockDown;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FundDetailPage(fundCode: fund.code),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with hold indicator and sectors
              Row(
                children: [
                  // Hold indicator (star)
                  if (fund.isHold)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 20,
                      ),
                    ),
                  // Sector tags
                  ...fund.sectors.take(2).map(
                        (sector) => Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            sector,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.primary),
                          ),
                        ),
                      ),
                  const Spacer(),
                  // Update time
                  if (valuation != null)
                    Text(
                      valuation.valuationTime,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Fund name and code
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fund.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fund.code,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Valuation and change
                  if (valuation != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          valuation.valuation,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: changeColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: changeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            valuation.dayGrowth,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: changeColor,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              // Consecutive days and monthly stats
              if (valuation != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Consecutive days
                    _StatItem(
                      label: valuation.consecutiveDays > 0 ? '连涨' : '连跌',
                      value: '${valuation.consecutiveDays.abs()}天',
                      valueColor: valuation.consecutiveDays > 0
                          ? AppColors.stockUp
                          : AppColors.stockDown,
                    ),
                    const SizedBox(width: 16),
                    // Consecutive growth
                    _StatItem(
                      label: '累计',
                      value: valuation.consecutiveGrowth,
                      valueColor: valuation.consecutiveGrowth.startsWith('-')
                          ? AppColors.stockDown
                          : AppColors.stockUp,
                    ),
                    const SizedBox(width: 16),
                    // Monthly stats
                    _StatItem(
                      label: '近30天',
                      value: valuation.monthlyStats,
                      valueColor: Colors.grey[700]!,
                    ),
                    const SizedBox(width: 16),
                    // Monthly growth
                    _StatItem(
                      label: '月涨幅',
                      value: valuation.monthlyGrowth,
                      valueColor: valuation.monthlyGrowth.startsWith('-')
                          ? AppColors.stockDown
                          : AppColors.stockUp,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Stat item widget
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatItem({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
