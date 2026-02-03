import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/fund.dart';

/// Fund list item widget
class FundListItem extends StatelessWidget {
  final Fund fund;
  final VoidCallback? onTap;
  final VoidCallback? onHoldToggle;

  const FundListItem({
    super.key,
    required this.fund,
    this.onTap,
    this.onHoldToggle,
  });

  @override
  Widget build(BuildContext context) {
    final valuation = fund.valuation;
    final dayGrowth = valuation != null
        ? double.tryParse(valuation.dayGrowth.replaceAll('%', '')) ?? 0
        : 0.0;
    final changeColor = dayGrowth >= 0 ? AppColors.stockUp : AppColors.stockDown;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Hold indicator
              if (fund.isHold)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
              // Fund info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
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
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fund.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fund.code,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // Valuation info
              if (valuation != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      valuation.valuation,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: changeColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      valuation.dayGrowth,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: changeColor,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '连${valuation.consecutiveDays > 0 ? "涨" : "跌"}${valuation.consecutiveDays.abs()}天',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: valuation.consecutiveDays > 0
                                ? AppColors.stockUp
                                : AppColors.stockDown,
                          ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
