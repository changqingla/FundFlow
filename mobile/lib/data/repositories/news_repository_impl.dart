import '../models/news.dart';
import '../network/api_client.dart';
import '../../core/config/api_endpoints.dart';
import 'news_repository.dart';

/// Implementation of NewsRepository using API client
class NewsRepositoryImpl implements NewsRepository {
  final ApiClient _apiClient;

  NewsRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<List<NewsItem>> getNews({int count = 50}) async {
    final response = await _apiClient.get(
      ApiEndpoints.news,
      queryParameters: {'count': count},
    );
    return _apiClient.parseListResponse(response, NewsItem.fromJson);
  }
}
