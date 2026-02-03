import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/news.dart';

/// News item widget
class NewsItemWidget extends StatelessWidget {
  final NewsItem news;
  final VoidCallback? onTap;

  const NewsItemWidget({
    super.key,
    required this.news,
    this.onTap,
  });

  Color _getEvaluateColor() {
    switch (news.evaluate) {
      case '利好':
        return AppColors.bullish;
      case '利空':
        return AppColors.bearish;
      default:
        return AppColors.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final publishTime = DateTime.fromMillisecondsSinceEpoch(news.publishTime);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with time and evaluate
              Row(
                children: [
                  Text(
                    Formatters.formatRelativeTime(publishTime),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const Spacer(),
                  if (news.evaluate.isNotEmpty && news.evaluate != '空')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getEvaluateColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        news.evaluate,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _getEvaluateColor(),
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Title
              Text(
                news.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Content
              Text(
                news.content,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              // Related entities
              if (news.entities.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: news.entities.take(5).map((entity) {
                    return Chip(
                      label: Text(
                        '${entity.name} ${entity.code}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
