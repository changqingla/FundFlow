import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client_provider.dart';
import 'market_repository.dart';
import 'market_repository_impl.dart';

/// Provider for MarketRepository
final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MarketRepositoryImpl(apiClient: apiClient);
});
