import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/sector.dart';
import '../../providers/sector_provider.dart';

/// Sort field for sector funds
enum FundSortField {
  week1,
  month1,
  month3,
  month6,
  year1,
}

/// Sector funds page showing funds in a specific sector
class SectorFundsPage extends ConsumerStatefulWidget {
  final String sectorId;
  final String sectorName;

  const SectorFundsPage({
    super.key,
    required this.sectorId,
    required this.sectorName,
  });

  @override
  ConsumerState<SectorFundsPage> createState() => _SectorFundsPageState();
}

class _SectorFundsPageState extends ConsumerState<SectorFundsPage> {
  FundSortField _sortField = FundSortField.month1;
  bool _isDescending = true;

  @override
  Widget build(BuildContext context) {
    final fundsAsync = ref.watch(sectorFundsProvider(widget.sectorId));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.sectorName}基金'),
      ),
      body: Column(
        children: [
          // Sort options
          _buildSortOptions(context),
          // Fund list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(sectorFundsProvider(widget.sectorId));
              },
              child: fundsAsync.when(
                data: (funds) => _buildFundList(context, funds),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _buildErrorWidget(context, error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortOptions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _SortChip(
              label: '近1周',
              isSelected: _sortField == FundSortField.week1,
              isDescending: _isDescending,
              onTap: () => _setSortField(FundSortField.week1),
            ),
            const SizedBox(width: 8),
            _SortChip(
              label: '近1月',
              isSelected: _sortField == FundSortField.month1,
              isDescending: _isDescending,
              onTap: () => _setSortField(FundSortField.month1),
            ),
            const SizedBox(width: 8),
            _SortChip(
              label: '近3月',
              isSelected: _sortField == FundSortField.month3,
              isDescending: _isDescending,
              onTap: () => _setSortField(FundSortField.month3),
            ),
            const SizedBox(width: 8),
            _SortChip(
              label: '近6月',
              isSelected: _sortField == FundSortField.month6,
              isDescending: _isDescending,
              onTap: () => _setSortField(FundSortField.month6),
            ),
            const SizedBox(width: 8),
            _SortChip(
              label: '近1年',
              isSelected: _sortField == FundSortField.year1,
              isDescending: _isDescending,
              onTap: () => _setSortField(FundSortField.year1),
            ),
          ],
        ),
      ),
    );
  }

  void _setSortField(FundSortField field) {
    setState(() {
      if (_sortField == field) {
        _isDescending = !_isDescending;
      } else {
        _sortField = field;
        _isDescending = true;
      }
    });
  }

  Widget _buildFundList(BuildContext context, List<SectorFund> funds) {
    if (funds.isEmpty) {
      return const Center(child: Text('暂无基金数据'));
    }

    // Sort funds
    final sortedFunds = _sortFunds(funds);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedFunds.length,
      itemBuilder: (context, index) {
        return _SectorFundCard(
          fund: sortedFunds[index],
          sortField: _sortField,
        );
      },
    );
  }

  List<SectorFund> _sortFunds(List<SectorFund> funds) {
    final sorted = List<SectorFund>.from(funds);

    sorted.sort((a, b) {
      final valueA = _getSortValue(a);
      final valueB = _getSortValue(b);
      final comparison = valueA.compareTo(valueB);
      return _isDescending ? -comparison : comparison;
    });

    return sorted;
  }

  double _getSortValue(SectorFund fund) {
    String value;
    switch (_sortField) {
      case FundSortField.week1:
        value = fund.week1;
        break;
      case FundSortField.month1:
        value = fund.month1;
        break;
      case FundSortField.month3:
        value = fund.month3;
        break;
      case FundSortField.month6:
        value = fund.month6;
        break;
      case FundSortField.year1:
        value = fund.year1;
        break;
    }
    return double.tryParse(value.replaceAll('%', '').replaceAll('+', '')) ?? 0;
  }

  Widget _buildErrorWidget(BuildContext context, Object error) {
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
              ref.invalidate(sectorFundsProvider(widget.sectorId));
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

/// Sort chip widget
class _SortChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDescending;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.isSelected,
    required this.isDescending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected ? AppColors.primary : Colors.grey[600],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                isDescending ? Icons.arrow_downward : Icons.arrow_upward,
                size: 12,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sector fund card widget
class _SectorFundCard extends StatelessWidget {
  final SectorFund fund;
  final FundSortField sortField;

  const _SectorFundCard({
    required this.fund,
    required this.sortField,
  });

  String _getHighlightedValue() {
    switch (sortField) {
      case FundSortField.week1:
        return fund.week1;
      case FundSortField.month1:
        return fund.month1;
      case FundSortField.month3:
        return fund.month3;
      case FundSortField.month6:
        return fund.month6;
      case FundSortField.year1:
        return fund.year1;
    }
  }

  Color _getValueColor(String value) {
    final numValue =
        double.tryParse(value.replaceAll('%', '').replaceAll('+', '')) ?? 0;
    if (numValue > 0) return AppColors.stockUp;
    if (numValue < 0) return AppColors.stockDown;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final highlightedValue = _getHighlightedValue();
    final highlightColor = _getValueColor(highlightedValue);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      Row(
                        children: [
                          Text(
                            fund.code,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              fund.type,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.primary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Highlighted return
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: highlightColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    highlightedValue,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: highlightColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Historical returns
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ReturnItem(
                  label: '近1周',
                  value: fund.week1,
                  isHighlighted: sortField == FundSortField.week1,
                ),
                _ReturnItem(
                  label: '近1月',
                  value: fund.month1,
                  isHighlighted: sortField == FundSortField.month1,
                ),
                _ReturnItem(
                  label: '近3月',
                  value: fund.month3,
                  isHighlighted: sortField == FundSortField.month3,
                ),
                _ReturnItem(
                  label: '近6月',
                  value: fund.month6,
                  isHighlighted: sortField == FundSortField.month6,
                ),
                _ReturnItem(
                  label: '近1年',
                  value: fund.year1,
                  isHighlighted: sortField == FundSortField.year1,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Additional info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '净值: ${fund.netValue}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                Text(
                  '更新: ${fund.date}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey[600],
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

/// Return item widget
class _ReturnItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;

  const _ReturnItem({
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  Color _getValueColor() {
    final numValue =
        double.tryParse(value.replaceAll('%', '').replaceAll('+', '')) ?? 0;
    if (numValue > 0) return AppColors.stockUp;
    if (numValue < 0) return AppColors.stockDown;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isHighlighted ? AppColors.primary : Colors.grey[600],
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _getValueColor(),
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              ),
        ),
      ],
    );
  }
}
