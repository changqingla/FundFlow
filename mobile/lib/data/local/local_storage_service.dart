import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hive_adapters.dart';

/// Box names for Hive storage
class HiveBoxNames {
  static const String funds = 'funds';
  static const String settings = 'settings';
  static const String cache = 'cache';
}

/// SharedPreferences keys
class PrefsKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String tokenExpiresAt = 'token_expires_at';
  static const String userId = 'user_id';
  static const String userEmail = 'user_email';
  static const String isLoggedIn = 'is_logged_in';
}

/// Local storage service for managing Hive boxes and SharedPreferences
class LocalStorageService {
  static LocalStorageService? _instance;
  static LocalStorageService get instance {
    _instance ??= LocalStorageService._();
    return _instance!;
  }

  LocalStorageService._();

  Box<FundLocalHive>? _fundsBox;
  Box<UserSettingsHive>? _settingsBox;
  Box<String>? _cacheBox;
  SharedPreferences? _prefs;

  bool _isInitialized = false;

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the local storage service
  /// Must be called before using any storage operations
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Register Hive adapters
    if (!Hive.isAdapterRegistered(HiveTypeIds.fundLocal)) {
      Hive.registerAdapter(FundLocalHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.userSettings)) {
      Hive.registerAdapter(UserSettingsHiveAdapter());
    }

    // Open Hive boxes
    _fundsBox = await Hive.openBox<FundLocalHive>(HiveBoxNames.funds);
    _settingsBox = await Hive.openBox<UserSettingsHive>(HiveBoxNames.settings);
    _cacheBox = await Hive.openBox<String>(HiveBoxNames.cache);

    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();

    _isInitialized = true;
  }

  /// Ensure the service is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'LocalStorageService is not initialized. Call initialize() first.',
      );
    }
  }

  // ============================================================
  // Fund Storage Operations
  // ============================================================

  /// Get all saved funds
  List<FundLocalHive> getAllFunds() {
    _ensureInitialized();
    return _fundsBox!.values.toList();
  }

  /// Get a fund by code
  FundLocalHive? getFund(String code) {
    _ensureInitialized();
    return _fundsBox!.get(code);
  }

  /// Save a fund (create or update)
  Future<void> saveFund(FundLocalHive fund) async {
    _ensureInitialized();
    await _fundsBox!.put(fund.code, fund);
  }

  /// Save multiple funds
  Future<void> saveFunds(List<FundLocalHive> funds) async {
    _ensureInitialized();
    final Map<String, FundLocalHive> fundMap = {
      for (final fund in funds) fund.code: fund,
    };
    await _fundsBox!.putAll(fundMap);
  }

  /// Delete a fund by code
  Future<void> deleteFund(String code) async {
    _ensureInitialized();
    await _fundsBox!.delete(code);
  }

  /// Delete all funds
  Future<void> deleteAllFunds() async {
    _ensureInitialized();
    await _fundsBox!.clear();
  }

  /// Update hold status for a fund
  Future<void> updateHoldStatus(String code, bool isHold) async {
    _ensureInitialized();
    final fund = _fundsBox!.get(code);
    if (fund != null) {
      fund.isHold = isHold;
      fund.updatedAt = DateTime.now();
      await fund.save();
    }
  }

  /// Update sectors for a fund
  Future<void> updateSectors(String code, List<String> sectors) async {
    _ensureInitialized();
    final fund = _fundsBox!.get(code);
    if (fund != null) {
      fund.sectors = List.from(sectors);
      fund.updatedAt = DateTime.now();
      await fund.save();
    }
  }

  /// Check if a fund exists
  bool hasFund(String code) {
    _ensureInitialized();
    return _fundsBox!.containsKey(code);
  }

  /// Get the count of saved funds
  int get fundCount {
    _ensureInitialized();
    return _fundsBox!.length;
  }

  // ============================================================
  // User Settings Operations
  // ============================================================

  /// Get user settings
  UserSettingsHive getSettings() {
    _ensureInitialized();
    return _settingsBox!.get('default') ?? UserSettingsHive();
  }

  /// Save user settings
  Future<void> saveSettings(UserSettingsHive settings) async {
    _ensureInitialized();
    await _settingsBox!.put('default', settings);
  }

  /// Update theme mode
  Future<void> updateThemeMode(String themeMode) async {
    _ensureInitialized();
    final settings = getSettings();
    final updated = settings.copyWith(themeMode: themeMode);
    await saveSettings(updated);
  }

  /// Update language
  Future<void> updateLanguage(String language) async {
    _ensureInitialized();
    final settings = getSettings();
    final updated = settings.copyWith(language: language);
    await saveSettings(updated);
  }

  /// Update notifications enabled
  Future<void> updateNotificationsEnabled(bool enabled) async {
    _ensureInitialized();
    final settings = getSettings();
    final updated = settings.copyWith(notificationsEnabled: enabled);
    await saveSettings(updated);
  }

  /// Update last sync time
  Future<void> updateLastSyncTime(DateTime time) async {
    _ensureInitialized();
    final settings = getSettings();
    final updated = settings.copyWith(lastSyncTime: time);
    await saveSettings(updated);
  }

  // ============================================================
  // Cache Operations
  // ============================================================

  /// Get cached data by key
  String? getCache(String key) {
    _ensureInitialized();
    return _cacheBox!.get(key);
  }

  /// Set cached data
  Future<void> setCache(String key, String value) async {
    _ensureInitialized();
    await _cacheBox!.put(key, value);
  }

  /// Delete cached data by key
  Future<void> deleteCache(String key) async {
    _ensureInitialized();
    await _cacheBox!.delete(key);
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    _ensureInitialized();
    await _cacheBox!.clear();
  }

  // ============================================================
  // Token/Auth Operations (SharedPreferences)
  // ============================================================

  /// Save access token
  Future<void> saveAccessToken(String token) async {
    _ensureInitialized();
    await _prefs!.setString(PrefsKeys.accessToken, token);
  }

  /// Get access token
  String? getAccessToken() {
    _ensureInitialized();
    return _prefs!.getString(PrefsKeys.accessToken);
  }

  /// Save refresh token
  Future<void> saveRefreshToken(String token) async {
    _ensureInitialized();
    await _prefs!.setString(PrefsKeys.refreshToken, token);
  }

  /// Get refresh token
  String? getRefreshToken() {
    _ensureInitialized();
    return _prefs!.getString(PrefsKeys.refreshToken);
  }

  /// Save token expiration time
  Future<void> saveTokenExpiresAt(DateTime expiresAt) async {
    _ensureInitialized();
    await _prefs!.setString(
      PrefsKeys.tokenExpiresAt,
      expiresAt.toIso8601String(),
    );
  }

  /// Get token expiration time
  DateTime? getTokenExpiresAt() {
    _ensureInitialized();
    final str = _prefs!.getString(PrefsKeys.tokenExpiresAt);
    return str != null ? DateTime.parse(str) : null;
  }

  /// Check if token is expired
  bool isTokenExpired() {
    final expiresAt = getTokenExpiresAt();
    if (expiresAt == null) return true;
    return DateTime.now().isAfter(expiresAt);
  }

  /// Save user ID
  Future<void> saveUserId(String id) async {
    _ensureInitialized();
    await _prefs!.setString(PrefsKeys.userId, id);
  }

  /// Get user ID
  String? getUserId() {
    _ensureInitialized();
    return _prefs!.getString(PrefsKeys.userId);
  }

  /// Save user email
  Future<void> saveUserEmail(String email) async {
    _ensureInitialized();
    await _prefs!.setString(PrefsKeys.userEmail, email);
  }

  /// Get user email
  String? getUserEmail() {
    _ensureInitialized();
    return _prefs!.getString(PrefsKeys.userEmail);
  }

  /// Set logged in status
  Future<void> setLoggedIn(bool isLoggedIn) async {
    _ensureInitialized();
    await _prefs!.setBool(PrefsKeys.isLoggedIn, isLoggedIn);
  }

  /// Check if user is logged in
  bool isLoggedIn() {
    _ensureInitialized();
    return _prefs!.getBool(PrefsKeys.isLoggedIn) ?? false;
  }

  // ============================================================
  // Logout/Clear Operations
  // ============================================================

  /// Clear all auth data (on logout)
  Future<void> clearAuthData() async {
    _ensureInitialized();
    await _prefs!.remove(PrefsKeys.accessToken);
    await _prefs!.remove(PrefsKeys.refreshToken);
    await _prefs!.remove(PrefsKeys.tokenExpiresAt);
    await _prefs!.remove(PrefsKeys.userId);
    await _prefs!.remove(PrefsKeys.userEmail);
    await _prefs!.setBool(PrefsKeys.isLoggedIn, false);
  }

  /// Clear all user data (funds, cache) on logout
  Future<void> clearUserData() async {
    _ensureInitialized();
    await deleteAllFunds();
    await clearCache();
    await clearAuthData();
  }

  /// Close all Hive boxes
  Future<void> close() async {
    await _fundsBox?.close();
    await _settingsBox?.close();
    await _cacheBox?.close();
    _isInitialized = false;
  }
}
