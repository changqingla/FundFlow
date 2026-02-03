import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/market.dart';

/// Market index card widget
class MarketCard extends StatelessWidget {
  final MarketIndex index;
  final VoidCallback? onTap;

  const MarketCard({
    super.key,
    required this.index,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final changeColor = index.isUp ? AppColors.stockUp : AppColors.stockDown;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                index.name,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                index.price,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: changeColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                index.change,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: changeColor,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
