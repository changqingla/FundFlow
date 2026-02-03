import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/sector.dart';
import '../../../providers/sector_provider.dart';
import '../../sector/sector_funds_page.dart';

/// Sector tab showing industry sectors with sorting and filtering
class SectorTab extends ConsumerWidget {
  const SectorTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectorState = ref.watch(sectorListProvider);
    final categoriesAsync = ref.watch(sectorCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('行业板块'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(sectorListProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter chips
          categoriesAsync.when(
            data: (categories) => _buildCategoryFilter(context, ref, categories, sectorState.selectedCategory),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Sort options
          _buildSortOptions(context, ref, sectorState),
          // Sector list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(sectorListProvider.notifier).refresh();
              },
              child: sectorState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : sectorState.error != null
                      ? _buildErrorWidget(context, ref, sectorState.error!)
                      : _buildSectorList(context, sectorState.filteredSectors),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(
    BuildContext context,
    WidgetRef ref,
    Map<String, List<String>> categories,
    String? selectedCategory,
  ) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final categoryNames = ['全部', ...categories.keys];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categoryNames.length,
        itemBuilder: (context, index) {
          final category = categoryNames[index];
          final isSelected = (category == '全部' && selectedCategory == null) ||
              category == selectedCategory;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                ref.read(sectorListProvider.notifier).filterByCategory(
                      category == '全部' ? null : category,
                      categories,
                    );
              },
              selectedColor: AppColors.primary.withOpacity(0.2),
              checkmarkColor: AppColors.primary,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortOptions(
    BuildContext context,
    WidgetRef ref,
    SectorListState state,
  ) {
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
      child: Row(
        children: [
          _SortButton(
            label: '涨跌幅',
            isSelected: state.sortField == SectorSortField.changeRate,
            isDescending: state.sortOrder == SortOrder.descending,
            onTap: () {
              ref.read(sectorListProvider.notifier).setSortField(SectorSortField.changeRate);
            },
          ),
          const SizedBox(width: 16),
          _SortButton(
            label: '主力净流入',
            isSelected: state.sortField == SectorSortField.mainNetInflow,
            isDescending: state.sortOrder == SortOrder.descending,
            onTap: () {
              ref.read(sectorListProvider.notifier).setSortField(SectorSortField.mainNetInflow);
            },
          ),
          const SizedBox(width: 16),
          _SortButton(
            label: '流入占比',
            isSelected: state.sortField == SectorSortField.mainInflowRatio,
            isDescending: state.sortOrder == SortOrder.descending,
            onTap: () {
              ref.read(sectorListProvider.notifier).setSortField(SectorSortField.mainInflowRatio);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectorList(BuildContext context, List<Sector> sectors) {
    if (sectors.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sectors.length,
      itemBuilder: (context, index) {
        return _SectorCard(sector: sectors[index]);
      },
    );
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
              ref.read(sectorListProvider.notifier).refresh();
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

/// Sort button widget
class _SortButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDescending;
  final VoidCallback onTap;

  const _SortButton({
    required this.label,
    required this.isSelected,
    required this.isDescending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                size: 14,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sector card widget
class _SectorCard extends StatelessWidget {
  final Sector sector;

  const _SectorCard({required this.sector});

  @override
  Widget build(BuildContext context) {
    final changeRate = double.tryParse(
          sector.changeRate.replaceAll('%', '').replaceAll('+', ''),
        ) ??
        0;
    final isUp = changeRate >= 0;
    final changeColor = isUp ? AppColors.stockUp : AppColors.stockDown;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SectorFundsPage(
                sectorId: sector.id,
                sectorName: sector.name,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Sector name
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sector.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _InfoTag(
                          label: '主力',
                          value: sector.mainNetInflow,
                          color: _getInflowColor(sector.mainNetInflow),
                        ),
                        const SizedBox(width: 8),
                        _InfoTag(
                          label: '散户',
                          value: sector.smallNetInflow,
                          color: _getInflowColor(sector.smallNetInflow),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Change rate
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: changeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        sector.changeRate,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: changeColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '流入占比: ${sector.mainInflowRatio}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              // Arrow
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getInflowColor(String value) {
    if (value.startsWith('-')) {
      return AppColors.stockDown;
    } else if (value.startsWith('+') || !value.startsWith('0')) {
      return AppColors.stockUp;
    }
    return Colors.grey;
  }
}

/// Info tag widget
class _InfoTag extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoTag({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
