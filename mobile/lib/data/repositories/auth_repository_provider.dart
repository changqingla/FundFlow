import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/local_storage_provider.dart';
import '../network/api_client_provider.dart';
import '../network/token_manager_provider.dart';
import 'auth_repository.dart';

/// Provider for the AuthRepository
///
/// This provider creates an instance of [AuthRepositoryImpl] with all
/// required dependencies:
/// - [ApiClient] for making HTTP requests
/// - [LocalStorageService] for storing user data
/// - [TokenManager] for managing authentication tokens
///
/// Usage:
/// ```dart
/// final authRepo = ref.read(authRepositoryProvider);
/// await authRepo.login(LoginRequest(email: 'user@example.com', password: 'password'));
/// ```
///
/// Requirements: 23.1-23.8, 24.1-24.7, 26.1-26.5
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(localStorageServiceProvider);
  final tokenManager = ref.watch(tokenManagerProvider);

  return AuthRepositoryImpl(
    apiClient: apiClient,
    storage: storage,
    tokenManager: tokenManager,
  );
});
