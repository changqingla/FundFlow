import '../models/news.dart';

/// News data repository interface
abstract class NewsRepository {
  /// Get news list
  Future<List<NewsItem>> getNews({int count = 50});
}
