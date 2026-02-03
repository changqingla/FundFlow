import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client_provider.dart';
import 'news_repository.dart';
import 'news_repository_impl.dart';

/// Provider for NewsRepository
final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NewsRepositoryImpl(apiClient: apiClient);
});
