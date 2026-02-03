import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client_provider.dart';
import 'fund_repository.dart';
import 'fund_repository_impl.dart';

/// Provider for FundRepository
final fundRepositoryProvider = Provider<FundRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return FundRepositoryImpl(apiClient: apiClient);
});
