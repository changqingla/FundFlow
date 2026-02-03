import '../../core/config/api_endpoints.dart';
import '../local/local_storage_service.dart';
import '../models/user.dart';
import '../network/api_client.dart';
import '../network/token_manager.dart';

/// Authentication repository interface
abstract class AuthRepository {
  /// Register a new user
  Future<void> register(RegisterRequest request);

  /// Send verification code to email
  Future<void> sendVerificationCode(String email);

  /// Verify email with code
  Future<User> verifyEmail(VerifyEmailRequest request);

  /// Login with email and password
  Future<TokenPair> login(LoginRequest request);

  /// Logout current user
  Future<void> logout();

  /// Refresh access token
  Future<TokenPair> refreshToken(String refreshToken);

  /// Request password reset
  Future<void> forgotPassword(String email);

  /// Reset password with verification code
  Future<void> resetPassword(ResetPasswordRequest request);

  /// Get current user info
  Future<User> getCurrentUser();
}

/// Implementation of AuthRepository using ApiClient
///
/// This repository handles all authentication-related API calls including:
/// - User registration with email verification
/// - Login/logout with JWT token management
/// - Password reset flow
/// - Token refresh
///
/// Requirements: 23.1-23.8, 24.1-24.7, 26.1-26.5
class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _apiClient;
  final LocalStorageService _storage;
  final TokenManager _tokenManager;

  AuthRepositoryImpl({
    required ApiClient apiClient,
    required LocalStorageService storage,
    required TokenManager tokenManager,
  })  : _apiClient = apiClient,
        _storage = storage,
        _tokenManager = tokenManager;

  /// Register a new user
  ///
  /// Sends registration request to the server. After successful registration,
  /// a verification code will be sent to the user's email.
  ///
  /// Throws [ApiException] if:
  /// - Email format is invalid (Requirement 23.1)
  /// - Email is already registered (Requirement 23.6)
  ///
  /// Requirements: 23.1, 23.2, 23.5, 23.6, 23.8
  @override
  Future<void> register(RegisterRequest request) async {
    final response = await _apiClient.post(
      ApiEndpoints.register,
      data: request.toJson(),
    );
    _apiClient.parseEmptyResponse(response);
  }

  /// Send verification code to email
  ///
  /// Requests the server to send a 6-digit verification code to the specified
  /// email address. The code is valid for 10 minutes.
  ///
  /// This is used for:
  /// - Email verification during registration
  /// - Re-sending verification code if expired
  ///
  /// Requirements: 23.2, 23.3
  @override
  Future<void> sendVerificationCode(String email) async {
    final response = await _apiClient.post(
      ApiEndpoints.register,
      data: {'email': email},
    );
    _apiClient.parseEmptyResponse(response);
  }

  /// Verify email with code
  ///
  /// Verifies the user's email using the 6-digit code sent to their email.
  /// On successful verification, the user account is created and activated.
  ///
  /// Returns the created [User] object.
  ///
  /// Throws [ApiException] if:
  /// - Verification code is incorrect (Requirement 23.7)
  /// - Verification code has expired (Requirement 23.7)
  ///
  /// Requirements: 23.3, 23.4, 23.7
  @override
  Future<User> verifyEmail(VerifyEmailRequest request) async {
    final response = await _apiClient.post(
      ApiEndpoints.verifyEmail,
      data: request.toJson(),
    );
    return _apiClient.parseResponse(response, User.fromJson);
  }

  /// Login with email and password
  ///
  /// Authenticates the user and returns a token pair containing:
  /// - Access token (valid for 7 days)
  /// - Refresh token
  ///
  /// On successful login:
  /// - Tokens are saved to local storage
  /// - User is marked as logged in
  ///
  /// Throws [ApiException] if:
  /// - Email doesn't exist (Requirement 24.5)
  /// - Password is incorrect (Requirement 24.6)
  /// - Account is locked due to too many failed attempts (Requirement 24.7)
  ///
  /// Requirements: 24.1, 24.2, 24.3, 24.4, 24.5, 24.6, 24.7
  @override
  Future<TokenPair> login(LoginRequest request) async {
    final response = await _apiClient.post(
      ApiEndpoints.login,
      data: request.toJson(),
    );

    final tokenPair = _apiClient.parseResponse(response, TokenPair.fromJson);

    // Save tokens to local storage
    await _tokenManager.saveTokens(tokenPair);

    // Mark user as logged in
    await _storage.setLoggedIn(true);

    return tokenPair;
  }

  /// Logout current user
  ///
  /// Logs out the user by:
  /// - Calling the logout API to invalidate the token on server
  /// - Clearing all local auth data (tokens, user info)
  ///
  /// Requirements: 25.4, 27.5
  @override
  Future<void> logout() async {
    try {
      // Call logout API to invalidate token on server
      final response = await _apiClient.post(ApiEndpoints.logout);
      _apiClient.parseEmptyResponse(response);
    } catch (e) {
      // Even if API call fails, we should still clear local data
      // This handles cases where token is already invalid
    } finally {
      // Clear all local auth data
      await _tokenManager.clearTokens();
      await _storage.clearUserData();
    }
  }

  /// Refresh access token
  ///
  /// Uses the refresh token to obtain a new access token.
  /// This is typically called automatically by TokenManager when
  /// the access token is about to expire.
  ///
  /// Returns a new [TokenPair] with fresh tokens.
  ///
  /// Throws [ApiException] if:
  /// - Refresh token is invalid or expired
  /// - Refresh token has been blacklisted
  ///
  /// Requirements: 25.3, 25.5
  @override
  Future<TokenPair> refreshToken(String refreshToken) async {
    final response = await _apiClient.post(
      ApiEndpoints.refreshToken,
      data: {'refreshToken': refreshToken},
    );

    final tokenPair = _apiClient.parseResponse(response, TokenPair.fromJson);

    // Save new tokens
    await _tokenManager.saveTokens(tokenPair);

    return tokenPair;
  }

  /// Request password reset
  ///
  /// Sends a password reset verification code to the user's registered email.
  /// The code is valid for 10 minutes.
  ///
  /// Throws [ApiException] if:
  /// - Email is not registered
  ///
  /// Requirements: 26.1, 26.2
  @override
  Future<void> forgotPassword(String email) async {
    final response = await _apiClient.post(
      ApiEndpoints.forgotPassword,
      data: {'email': email},
    );
    _apiClient.parseEmptyResponse(response);
  }

  /// Reset password with verification code
  ///
  /// Resets the user's password using the verification code sent to their email.
  /// The new password must meet strength requirements:
  /// - At least 8 characters
  /// - Contains both letters and numbers
  ///
  /// Throws [ApiException] if:
  /// - Verification code is incorrect or expired (Requirement 26.5)
  /// - New password doesn't meet strength requirements (Requirement 26.4)
  ///
  /// Requirements: 26.3, 26.4, 26.5
  @override
  Future<void> resetPassword(ResetPasswordRequest request) async {
    final response = await _apiClient.post(
      ApiEndpoints.resetPassword,
      data: request.toJson(),
    );
    _apiClient.parseEmptyResponse(response);
  }

  /// Get current user info
  ///
  /// Retrieves the currently authenticated user's information.
  /// Requires a valid access token.
  ///
  /// Returns the [User] object with user details.
  ///
  /// Throws [NetworkException] with type [NetworkErrorType.unauthorized]
  /// if the token is invalid or expired.
  ///
  /// Requirements: 25.1, 25.2
  @override
  Future<User> getCurrentUser() async {
    final response = await _apiClient.get(ApiEndpoints.currentUser);
    return _apiClient.parseResponse(response, User.fromJson);
  }
}
