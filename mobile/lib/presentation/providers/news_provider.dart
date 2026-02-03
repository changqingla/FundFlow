import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/news.dart';
import '../../data/repositories/news_repository_provider.dart';

/// News list provider with refresh support
final newsListProvider =
    AutoDisposeAsyncNotifierProvider<NewsListNotifier, List<NewsItem>>(
  NewsListNotifier.new,
);

/// News list notifier
class NewsListNotifier extends AutoDisposeAsyncNotifier<List<NewsItem>> {
  @override
  Future<List<NewsItem>> build() async {
    return _fetchNews();
  }

  Future<List<NewsItem>> _fetchNews({int count = 50}) async {
    final repository = ref.read(newsRepositoryProvider);
    return repository.getNews(count: count);
  }

  /// Refresh the news list
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchNews());
  }

  /// Load more news
  Future<void> loadMore() async {
    final currentNews = state.valueOrNull ?? [];
    final newCount = currentNews.length + 20;
    state = await AsyncValue.guard(() => _fetchNews(count: newCount));
  }
}
