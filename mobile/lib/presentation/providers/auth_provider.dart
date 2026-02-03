import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/local_storage_provider.dart';
import '../../data/local/local_storage_service.dart';
import '../../data/models/user.dart';
import '../../data/network/api_client.dart';
import '../../data/network/token_manager.dart';
import '../../data/network/token_manager_provider.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_provider.dart';

/// Authentication status enum
///
/// Represents the current authentication state of the user
enum AuthStatus {
  /// Initial state - checking authentication status
  initial,

  /// User is authenticated and has valid tokens
  authenticated,

  /// User is not authenticated (no tokens or expired)
  unauthenticated,

  /// Authentication operation in progress
  loading,
}

/// Authentication state class
///
/// Holds the current authentication status, user information, and any errors
class AuthState {
  /// Current authentication status
  final AuthStatus status;

  /// Current authenticated user (null if not authenticated)
  final User? user;

  /// Error message (null if no error)
  final String? error;

  /// Whether a specific operation is in progress
  final bool isLoading;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.isLoading = false,
  });

  /// Create a copy with updated fields
  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
    bool? isLoading,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Check if user is authenticated
  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Check if there's an error
  bool get hasError => error != null && error!.isNotEmpty;

  @override
  String toString() {
    return 'AuthState(status: $status, user: ${user?.email}, error: $error, isLoading: $isLoading)';
  }
}

/// Authentication provider
///
/// Provides the authentication state notifier to the widget tree
///
/// Usage:
/// ```dart
/// final authState = ref.watch(authProvider);
/// final authNotifier = ref.read(authProvider.notifier);
/// ```
///
/// Requirements: 24.4, 25.3
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final tokenManager = ref.watch(tokenManagerProvider);
  final storage = ref.watch(localStorageServiceProvider);

  return AuthNotifier(
    authRepository: authRepository,
    tokenManager: tokenManager,
    storage: storage,
  );
});

/// Convenience provider for checking if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isAuthenticated;
});

/// Convenience provider for getting the current user
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.user;
});

/// Authentication state notifier
///
/// Manages authentication state and provides methods for:
/// - Login with email and password
/// - Registration with email verification
/// - Password reset
/// - Logout
/// - Auto-login check on app startup
///
/// Requirements: 23.1-23.8, 24.1-24.7, 25.1-25.5, 26.1-26.5
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final TokenManager _tokenManager;
  final LocalStorageService _storage;

  AuthNotifier({
    required AuthRepository authRepository,
    required TokenManager tokenManager,
    required LocalStorageService storage,
  })  : _authRepository = authRepository,
        _tokenManager = tokenManager,
        _storage = storage,
        super(const AuthState()) {
    // Check authentication status on initialization
    _checkAuthStatus();
  }

  /// Check initial authentication status
  ///
  /// This method is called on app startup to determine if the user
  /// is already logged in with valid tokens.
  ///
  /// Requirements: 24.4, 25.3
  Future<void> _checkAuthStatus() async {
    _debugLog('Checking authentication status...');

    try {
      // Check if storage is initialized
      if (!_storage.isInitialized) {
        _debugLog('Storage not initialized, user is unauthenticated');
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      // Check if user has tokens
      if (!_tokenManager.hasTokens) {
        _debugLog('No tokens found, user is unauthenticated');
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      // Check if token is expired
      if (_tokenManager.isTokenExpired) {
        _debugLog('Token expired, attempting refresh...');

        // Try to refresh the token
        final refreshSuccess = await _tokenManager.ensureValidToken();
        if (!refreshSuccess) {
          _debugLog('Token refresh failed, user is unauthenticated');
          state = state.copyWith(status: AuthStatus.unauthenticated);
          return;
        }
      }

      // Token is valid, try to get user info
      _debugLog('Token valid, fetching user info...');
      try {
        final user = await _authRepository.getCurrentUser();
        _debugLog('User info fetched: ${user.email}');
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          clearError: true,
        );
      } catch (e) {
        // If we can't get user info, still consider authenticated
        // The user info can be fetched later
        _debugLog('Could not fetch user info, but token is valid');
        state = state.copyWith(
          status: AuthStatus.authenticated,
          clearError: true,
        );
      }
    } catch (e) {
      _debugLog('Error checking auth status: $e');
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// Register a new user
  ///
  /// Sends registration request to the server. After successful registration,
  /// a verification code will be sent to the user's email.
  ///
  /// [email] - User's email address
  /// [password] - User's password (must meet strength requirements)
  /// [nickname] - Optional nickname
  ///
  /// Throws error if:
  /// - Email format is invalid
  /// - Email is already registered
  /// - Password doesn't meet requirements
  ///
  /// Requirements: 23.1, 23.2, 23.5, 23.6
  Future<void> register({
    required String email,
    required String password,
    String? nickname,
  }) async {
    _debugLog('Registering user: $email');
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final request = RegisterRequest(
        email: email,
        password: password,
        nickname: nickname,
      );
      await _authRepository.register(request);
      _debugLog('Registration successful, verification code sent');
      state = state.copyWith(isLoading: false);
    } catch (e) {
      _debugLog('Registration failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
      );
      rethrow;
    }
  }

  /// Verify email with verification code
  ///
  /// Verifies the user's email using the 6-digit code sent to their email.
  /// On successful verification, the user account is created and activated.
  ///
  /// [email] - User's email address
  /// [code] - 6-digit verification code
  ///
  /// Returns the created [User] object.
  ///
  /// Throws error if:
  /// - Verification code is incorrect
  /// - Verification code has expired
  ///
  /// Requirements: 23.3, 23.4, 23.7
  Future<User> verifyEmail({
    required String email,
    required String code,
  }) async {
    _debugLog('Verifying email: $email');
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final request = VerifyEmailRequest(email: email, code: code);
      final user = await _authRepository.verifyEmail(request);
      _debugLog('Email verification successful');
      state = state.copyWith(isLoading: false);
      return user;
    } catch (e) {
      _debugLog('Email verification failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
      );
      rethrow;
    }
  }

  /// Login with email and password
  ///
  /// Authenticates the user and stores the tokens locally.
  /// On successful login, the user is marked as authenticated.
  ///
  /// [email] - User's email address
  /// [password] - User's password
  ///
  /// Throws error if:
  /// - Email doesn't exist
  /// - Password is incorrect
  /// - Account is locked
  ///
  /// Requirements: 24.1, 24.2, 24.3, 24.4, 24.5, 24.6, 24.7
  Future<void> login({
    required String email,
    required String password,
  }) async {
    _debugLog('Logging in user: $email');
    state = state.copyWith(
      status: AuthStatus.loading,
      isLoading: true,
      clearError: true,
    );

    try {
      final request = LoginRequest(email: email, password: password);
      await _authRepository.login(request);
      _debugLog('Login successful');

      // Fetch user info after login
      try {
        final user = await _authRepository.getCurrentUser();
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isLoading: false,
        );
      } catch (e) {
        // Login successful but couldn't fetch user info
        // Still mark as authenticated
        _debugLog('Could not fetch user info after login: $e');
        state = state.copyWith(
          status: AuthStatus.authenticated,
          isLoading: false,
        );
      }
    } catch (e) {
      _debugLog('Login failed: $e');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        error: _getErrorMessage(e),
      );
      rethrow;
    }
  }

  /// Logout current user
  ///
  /// Logs out the user by:
  /// - Calling the logout API to invalidate the token on server
  /// - Clearing all local auth data (tokens, user info)
  /// - Clearing local user data (funds, cache)
  ///
  /// Requirements: 25.4, 27.5
  Future<void> logout() async {
    _debugLog('Logging out user');
    state = state.copyWith(isLoading: true);

    try {
      await _authRepository.logout();
      _debugLog('Logout successful');
    } catch (e) {
      // Even if API call fails, we should still clear local data
      _debugLog('Logout API call failed, but clearing local data: $e');
    } finally {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Request password reset
  ///
  /// Sends a password reset verification code to the user's registered email.
  ///
  /// [email] - User's registered email address
  ///
  /// Throws error if:
  /// - Email is not registered
  ///
  /// Requirements: 26.1, 26.2
  Future<void> forgotPassword(String email) async {
    _debugLog('Requesting password reset for: $email');
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _authRepository.forgotPassword(email);
      _debugLog('Password reset code sent');
      state = state.copyWith(isLoading: false);
    } catch (e) {
      _debugLog('Password reset request failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
      );
      rethrow;
    }
  }

  /// Reset password with verification code
  ///
  /// Resets the user's password using the verification code sent to their email.
  ///
  /// [email] - User's email address
  /// [code] - 6-digit verification code
  /// [newPassword] - New password (must meet strength requirements)
  ///
  /// Throws error if:
  /// - Verification code is incorrect or expired
  /// - New password doesn't meet strength requirements
  ///
  /// Requirements: 26.3, 26.4, 26.5
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    _debugLog('Resetting password for: $email');
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final request = ResetPasswordRequest(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      await _authRepository.resetPassword(request);
      _debugLog('Password reset successful');
      state = state.copyWith(isLoading: false);
    } catch (e) {
      _debugLog('Password reset failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
      );
      rethrow;
    }
  }

  /// Refresh user information
  ///
  /// Fetches the latest user information from the server.
  Future<void> refreshUserInfo() async {
    if (!state.isAuthenticated) return;

    _debugLog('Refreshing user info');
    try {
      final user = await _authRepository.getCurrentUser();
      state = state.copyWith(user: user);
      _debugLog('User info refreshed');
    } catch (e) {
      _debugLog('Failed to refresh user info: $e');
      // Don't update error state for background refresh
    }
  }

  /// Clear any error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Force re-check authentication status
  ///
  /// Useful when returning to the app from background
  Future<void> recheckAuthStatus() async {
    await _checkAuthStatus();
  }

  /// Get user-friendly error message from exception
  String _getErrorMessage(dynamic error) {
    if (error is NetworkException) {
      return error.userMessage;
    }
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  /// Debug logging helper
  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[AuthNotifier] $message');
    }
  }
}
