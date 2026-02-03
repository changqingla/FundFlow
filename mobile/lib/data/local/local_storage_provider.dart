import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hive_adapters.dart';
import 'local_storage_service.dart';

/// Provider for the LocalStorageService singleton
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService.instance;
});

/// Provider for the list of local funds
final localFundsProvider =
    StateNotifierProvider<LocalFundsNotifier, List<FundLocalHive>>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return LocalFundsNotifier(storage);
});

/// Provider for user settings
final userSettingsProvider =
    StateNotifierProvider<UserSettingsNotifier, UserSettingsHive>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return UserSettingsNotifier(storage);
});

/// Notifier for managing local funds state
class LocalFundsNotifier extends StateNotifier<List<FundLocalHive>> {
  final LocalStorageService _storage;

  LocalFundsNotifier(this._storage) : super([]) {
    _loadFunds();
  }

  /// Load funds from local storage
  void _loadFunds() {
    if (_storage.isInitialized) {
      state = _storage.getAllFunds();
    }
  }

  /// Refresh funds from local storage
  void refresh() {
    _loadFunds();
  }

  /// Add a new fund
  Future<void> addFund({
    required String code,
    required String name,
    required String fundKey,
    bool isHold = false,
    List<String> sectors = const [],
  }) async {
    final now = DateTime.now();
    final fund = FundLocalHive(
      code: code,
      name: name,
      fundKey: fundKey,
      isHold: isHold,
      sectors: sectors,
      createdAt: now,
      updatedAt: now,
    );
    await _storage.saveFund(fund);
    _loadFunds();
  }

  /// Delete a fund by code
  Future<void> deleteFund(String code) async {
    await _storage.deleteFund(code);
    _loadFunds();
  }

  /// Update hold status for a fund
  Future<void> updateHoldStatus(String code, bool isHold) async {
    await _storage.updateHoldStatus(code, isHold);
    _loadFunds();
  }

  /// Update sectors for a fund
  Future<void> updateSectors(String code, List<String> sectors) async {
    await _storage.updateSectors(code, sectors);
    _loadFunds();
  }

  /// Save multiple funds (for syncing from server)
  Future<void> saveFunds(List<FundLocalHive> funds) async {
    await _storage.saveFunds(funds);
    _loadFunds();
  }

  /// Clear all funds (on logout)
  Future<void> clearAll() async {
    await _storage.deleteAllFunds();
    state = [];
  }

  /// Check if a fund exists
  bool hasFund(String code) {
    return _storage.hasFund(code);
  }

  /// Get a fund by code
  FundLocalHive? getFund(String code) {
    return _storage.getFund(code);
  }
}

/// Notifier for managing user settings state
class UserSettingsNotifier extends StateNotifier<UserSettingsHive> {
  final LocalStorageService _storage;

  UserSettingsNotifier(this._storage) : super(UserSettingsHive()) {
    _loadSettings();
  }

  /// Load settings from local storage
  void _loadSettings() {
    if (_storage.isInitialized) {
      state = _storage.getSettings();
    }
  }

  /// Update theme mode
  Future<void> setThemeMode(String themeMode) async {
    await _storage.updateThemeMode(themeMode);
    state = state.copyWith(themeMode: themeMode);
  }

  /// Update language
  Future<void> setLanguage(String language) async {
    await _storage.updateLanguage(language);
    state = state.copyWith(language: language);
  }

  /// Update notifications enabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _storage.updateNotificationsEnabled(enabled);
    state = state.copyWith(notificationsEnabled: enabled);
  }

  /// Update last sync time
  Future<void> setLastSyncTime(DateTime time) async {
    await _storage.updateLastSyncTime(time);
    state = state.copyWith(lastSyncTime: time);
  }
}

/// Provider for checking if user is logged in
final isLoggedInProvider = Provider<bool>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return storage.isInitialized && storage.isLoggedIn();
});

/// Provider for getting the access token
final accessTokenProvider = Provider<String?>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return storage.isInitialized ? storage.getAccessToken() : null;
});

/// Provider for theme mode
final themeModeProvider = Provider<String>((ref) {
  final settings = ref.watch(userSettingsProvider);
  return settings.themeMode;
});
