import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/market.dart';
import '../../../providers/market_provider.dart';
import '../../../widgets/market_card.dart';

/// Market tab showing global market indices
class MarketTab extends ConsumerWidget {
  const MarketTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indicesAsync = ref.watch(marketIndicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('市场指数'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(marketIndicesProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(marketIndicesProvider.notifier).refresh();
        },
        child: indicesAsync.when(
          data: (indices) => _buildIndicesList(context, indices),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildErrorWidget(context, ref, error),
        ),
      ),
    );
  }

  Widget _buildIndicesList(BuildContext context, List<MarketIndex> indices) {
    if (indices.isEmpty) {
      return const Center(
        child: Text('暂无数据'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: indices.length,
      itemBuilder: (context, index) {
        final marketIndex = indices[index];
        return _MarketIndexCard(index: marketIndex);
      },
    );
  }

  Widget _buildErrorWidget(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.error,
          ),
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
              ref.read(marketIndicesProvider.notifier).refresh();
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

/// Market index card with up/down color display
class _MarketIndexCard extends StatelessWidget {
  final MarketIndex index;

  const _MarketIndexCard({required this.index});

  @override
  Widget build(BuildContext context) {
    // Determine color based on isUp flag
    final changeColor = index.isUp ? AppColors.stockUp : AppColors.stockDown;
    final changeIcon = index.isUp ? Icons.arrow_upward : Icons.arrow_downward;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Index name
            Text(
              index.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Price
            Text(
              index.price,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: changeColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            // Change with icon
            Row(
              children: [
                Icon(
                  changeIcon,
                  size: 16,
                  color: changeColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    index.change,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: changeColor,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
