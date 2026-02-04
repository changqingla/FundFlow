import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/local_storage_provider.dart';
import 'api_client.dart';
import 'token_manager_provider.dart';

/// Provider for the API client singleton
///
/// The API client is configured with:
/// - LocalStorageService for token management
/// - TokenManager for automatic token refresh
/// - Automatic token injection via interceptors
/// - Error handling and transformation
///
/// Usage:
/// ```dart
/// final apiClient = ref.read(apiClientProvider);
/// final response = await apiClient.get('/endpoint');
/// ```
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  final tokenManager = ref.watch(tokenManagerProvider);
  
  final apiClient = ApiClient(
    storage: storage,
    onUnauthorized: () {
      // Handle unauthorized - this will be connected to auth provider
      // to trigger logout or token refresh
      debugPrintUnauthorized();
    },
  );
  
  // Connect TokenManager to ApiClient for automatic token refresh
  apiClient.setTokenManager(tokenManager);
  
  return apiClient;
});

/// Debug print for unauthorized callback
void debugPrintUnauthorized() {
  // This is a placeholder - in production, this would trigger
  // the auth provider to handle the unauthorized state
  // ignore: avoid_print
  print('[ApiClient] Unauthorized - token may be expired');
}

/// Provider for checking network connectivity status
/// This can be extended to use connectivity_plus package
final networkStatusProvider = StateProvider<NetworkStatus>((ref) {
  return NetworkStatus.connected;
});

/// Network connectivity status
enum NetworkStatus {
  connected,
  disconnected,
  unknown,
}

/// Extension on Ref for convenient API client access
extension ApiClientRefExtension on Ref {
  /// Get the API client instance
  ApiClient get apiClient => read(apiClientProvider);
}

/// Extension on WidgetRef for convenient API client access
extension ApiClientWidgetRefExtension on WidgetRef {
  /// Get the API client instance
  ApiClient get apiClient => read(apiClientProvider);
}
