import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/fund.dart';
import '../../providers/fund_provider.dart';
import '../../providers/sector_provider.dart';

/// Fund detail page with info display, hold toggle, sector editing, and delete
class FundDetailPage extends ConsumerStatefulWidget {
  final String fundCode;

  const FundDetailPage({super.key, required this.fundCode});

  @override
  ConsumerState<FundDetailPage> createState() => _FundDetailPageState();
}

class _FundDetailPageState extends ConsumerState<FundDetailPage> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final fundState = ref.watch(fundListProvider);
    final fund = fundState.funds.firstWhere(
      (f) => f.code == widget.fundCode,
      orElse: () => Fund(code: widget.fundCode, name: '', fundKey: ''),
    );

    if (fund.name.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('基金详情')),
        body: const Center(child: Text('基金不存在')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('基金详情'),
        actions: [
          // Hold toggle button
          IconButton(
            icon: Icon(
              fund.isHold ? Icons.star : Icons.star_border,
              color: fund.isHold ? Colors.amber : null,
            ),
            onPressed: () => _toggleHoldStatus(fund),
            tooltip: fund.isHold ? '取消持有' : '标记持有',
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showDeleteConfirmation(context, fund),
            tooltip: '删除基金',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fund info card
            _buildFundInfoCard(context, fund),
            const SizedBox(height: 24),
            // Valuation section
            if (fund.valuation != null) ...[
              _buildValuationSection(context, fund.valuation!),
              const SizedBox(height: 24),
            ],
            // Sector tags section
            _buildSectorSection(context, fund),
            const SizedBox(height: 24),
            // Actions section
            _buildActionsSection(context, fund),
          ],
        ),
      ),
    );
  }

  Widget _buildFundInfoCard(BuildContext context, Fund fund) {
    final valuation = fund.valuation;
    final dayGrowth = valuation != null
        ? double.tryParse(
                valuation.dayGrowth.replaceAll('%', '').replaceAll('+', ''),) ??
            0
        : 0.0;
    final isUp = dayGrowth >= 0;
    final changeColor = isUp ? AppColors.stockUp : AppColors.stockDown;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with hold indicator
            Row(
              children: [
                if (fund.isHold)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '持有中',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.amber[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Text(
                  fund.code,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Fund name
            Text(
              fund.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            // Valuation display
            if (valuation != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    valuation.valuation,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: changeColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(width: 16),
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
                      valuation.dayGrowth,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: changeColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '估值时间: ${valuation.valuationTime}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildValuationSection(BuildContext context, FundValuation valuation) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '估值详情',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DetailItem(
                    label: valuation.consecutiveDays > 0 ? '连涨天数' : '连跌天数',
                    value: '${valuation.consecutiveDays.abs()}天',
                    valueColor: valuation.consecutiveDays > 0
                        ? AppColors.stockUp
                        : AppColors.stockDown,
                  ),
                ),
                Expanded(
                  child: _DetailItem(
                    label: '累计涨跌',
                    value: valuation.consecutiveGrowth,
                    valueColor: valuation.consecutiveGrowth.startsWith('-')
                        ? AppColors.stockDown
                        : AppColors.stockUp,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DetailItem(
                    label: '近30天涨跌',
                    value: valuation.monthlyStats,
                    valueColor: Colors.grey[700]!,
                  ),
                ),
                Expanded(
                  child: _DetailItem(
                    label: '月涨幅',
                    value: valuation.monthlyGrowth,
                    valueColor: valuation.monthlyGrowth.startsWith('-')
                        ? AppColors.stockDown
                        : AppColors.stockUp,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectorSection(BuildContext context, Fund fund) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '板块标签',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton.icon(
                  onPressed: () => _showSectorEditor(context, fund),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('编辑'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (fund.sectors.isEmpty)
              Text(
                '暂无板块标签，点击编辑添加',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: fund.sectors.map((sector) {
                  return Chip(
                    label: Text(sector),
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    labelStyle: const TextStyle(color: AppColors.primary),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeSector(fund, sector),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context, Fund fund) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toggle hold status button
        OutlinedButton.icon(
          onPressed: () => _toggleHoldStatus(fund),
          icon: Icon(
            fund.isHold ? Icons.star_border : Icons.star,
            color: fund.isHold ? Colors.grey : Colors.amber,
          ),
          label: Text(fund.isHold ? '取消持有标记' : '标记为持有'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Delete button
        OutlinedButton.icon(
          onPressed: _isDeleting
              ? null
              : () => _showDeleteConfirmation(context, fund),
          icon: _isDeleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline, color: AppColors.error),
          label: Text(
            '删除基金',
            style: TextStyle(color: _isDeleting ? Colors.grey : AppColors.error),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(
              color: _isDeleting ? Colors.grey : AppColors.error,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleHoldStatus(Fund fund) async {
    final success = await ref
        .read(fundListProvider.notifier)
        .updateHoldStatus(fund.code, !fund.isHold);

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(fund.isHold ? '已取消持有标记' : '已标记为持有'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _removeSector(Fund fund, String sector) async {
    final newSectors = fund.sectors.where((s) => s != sector).toList();
    await ref
        .read(fundListProvider.notifier)
        .updateSectors(fund.code, newSectors);
  }

  void _showSectorEditor(BuildContext context, Fund fund) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SectorEditorSheet(
        fund: fund,
        onSave: (sectors) async {
          await ref
              .read(fundListProvider.notifier)
              .updateSectors(fund.code, sectors);
          if (mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Fund fund) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要从自选列表中删除 ${fund.name} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteFund(fund);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFund(Fund fund) async {
    setState(() {
      _isDeleting = true;
    });

    final success =
        await ref.read(fundListProvider.notifier).deleteFund(fund.code);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('基金已删除'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      } else {
        setState(() {
          _isDeleting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('删除失败，请重试'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

/// Detail item widget
class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _DetailItem({
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
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

/// Sector editor bottom sheet
class _SectorEditorSheet extends ConsumerStatefulWidget {
  final Fund fund;
  final Function(List<String>) onSave;

  const _SectorEditorSheet({
    required this.fund,
    required this.onSave,
  });

  @override
  ConsumerState<_SectorEditorSheet> createState() => _SectorEditorSheetState();
}

class _SectorEditorSheetState extends ConsumerState<_SectorEditorSheet> {
  late List<String> _selectedSectors;

  @override
  void initState() {
    super.initState();
    _selectedSectors = List.from(widget.fund.sectors);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(sectorCategoriesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '选择板块',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton(
                    onPressed: () => widget.onSave(_selectedSectors),
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
            // Selected sectors
            if (_selectedSectors.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedSectors.map((sector) {
                    return Chip(
                      label: Text(sector),
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      labelStyle: const TextStyle(color: AppColors.primary),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        setState(() {
                          _selectedSectors.remove(sector);
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            const Divider(),
            // Available sectors
            Expanded(
              child: categoriesAsync.when(
                data: (categories) => _buildCategoryList(
                  context,
                  scrollController,
                  categories,
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('加载失败')),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    ScrollController scrollController,
    Map<String, List<String>> categories,
  ) {
    if (categories.isEmpty) {
      // Fallback to predefined sectors
      return _buildPredefinedSectors(context, scrollController);
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories.keys.elementAt(index);
        final sectors = categories[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sectors.map((sector) {
                final isSelected = _selectedSectors.contains(sector);
                return FilterChip(
                  label: Text(sector),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSectors.add(sector);
                      } else {
                        _selectedSectors.remove(sector);
                      }
                    });
                  },
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  checkmarkColor: AppColors.primary,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildPredefinedSectors(
    BuildContext context,
    ScrollController scrollController,
  ) {
    const predefinedSectors = [
      '科技',
      '医药',
      '消费',
      '金融',
      '新能源',
      '半导体',
      '白酒',
      '军工',
      '光伏',
      '锂电池',
      '芯片',
      '人工智能',
      '医疗器械',
      '创新药',
      '银行',
      '证券',
      '保险',
      '房地产',
      '汽车',
      '家电',
    ];

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: predefinedSectors.map((sector) {
          final isSelected = _selectedSectors.contains(sector);
          return FilterChip(
            label: Text(sector),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _selectedSectors.add(sector);
                } else {
                  _selectedSectors.remove(sector);
                }
              });
            },
            selectedColor: AppColors.primary.withOpacity(0.2),
            checkmarkColor: AppColors.primary,
          );
        }).toList(),
      ),
    );
  }
}
