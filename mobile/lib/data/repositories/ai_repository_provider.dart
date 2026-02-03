import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client_provider.dart';
import 'ai_repository.dart';

/// Provider for the AI repository
///
/// This provider creates an AIRepositoryImpl instance with the API client
/// for making SSE streaming requests to the AI endpoints.
///
/// **Validates: Requirements 12.1, 13.1, 14.1, 15.1**
final aiRepositoryProvider = Provider<AIRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AIRepositoryImpl(apiClient: apiClient);
});
