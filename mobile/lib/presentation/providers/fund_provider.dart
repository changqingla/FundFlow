import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/hive_adapters.dart';
import '../../data/local/local_storage_provider.dart';
import '../../data/models/fund.dart';
import '../../data/repositories/fund_repository_provider.dart';

/// Fund list state
class FundListState {
  final List<Fund> funds;
  final bool isLoading;
  final String? error;
  final bool isAddingFund;

  const FundListState({
    this.funds = const [],
    this.isLoading = false,
    this.error,
    this.isAddingFund = false,
  });

  FundListState copyWith({
    List<Fund>? funds,
    bool? isLoading,
    String? error,
    bool? isAddingFund,
  }) {
    return FundListState(
      funds: funds ?? this.funds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAddingFund: isAddingFund ?? this.isAddingFund,
    );
  }
}

/// Fund list provider
final fundListProvider = StateNotifierProvider<FundListNotifier, FundListState>(
  (ref) => FundListNotifier(ref),
);

/// Fund list state notifier
class FundListNotifier extends StateNotifier<FundListState> {
  final Ref _ref;

  FundListNotifier(this._ref) : super(const FundListState()) {
    loadFunds();
  }

  /// Load funds from repository and sync with local cache
  Future<void> loadFunds() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repository = _ref.read(fundRepositoryProvider);
      final funds = await repository.getFunds();
      
      // Sync to local storage
      await _syncToLocalStorage(funds);
      
      state = state.copyWith(funds: funds, isLoading: false);
    } catch (e) {
      // Try to load from local cache on error
      final localFunds = _loadFromLocalStorage();
      if (localFunds.isNotEmpty) {
        state = state.copyWith(
          funds: localFunds,
          isLoading: false,
          error: '使用缓存数据: ${e.toString()}',
        );
      } else {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  /// Refresh funds
  Future<void> refresh() async {
    await loadFunds();
  }

  /// Add a fund
  Future<bool> addFund(String code) async {
    state = state.copyWith(isAddingFund: true, error: null);
    try {
      final repository = _ref.read(fundRepositoryProvider);
      final fund = await repository.addFund(code);
      
      // Add to local storage
      await _saveFundToLocal(fund);
      
      // Update state
      state = state.copyWith(
        funds: [...state.funds, fund],
        isAddingFund: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isAddingFund: false, error: e.toString());
      return false;
    }
  }

  /// Delete a fund
  Future<bool> deleteFund(String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repository = _ref.read(fundRepositoryProvider);
      await repository.deleteFund(code);
      
      // Remove from local storage
      await _deleteFundFromLocal(code);
      
      state = state.copyWith(
        funds: state.funds.where((f) => f.code != code).toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Update hold status
  Future<bool> updateHoldStatus(String code, bool isHold) async {
    try {
      final repository = _ref.read(fundRepositoryProvider);
      await repository.updateHoldStatus(code, isHold);
      
      // Update local storage
      await _updateLocalHoldStatus(code, isHold);
      
      state = state.copyWith(
        funds: state.funds.map((f) {
          if (f.code == code) {
            return f.copyWith(isHold: isHold);
          }
          return f;
        }).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Update sectors
  Future<bool> updateSectors(String code, List<String> sectors) async {
    try {
      final repository = _ref.read(fundRepositoryProvider);
      await repository.updateSectors(code, sectors);
      
      // Update local storage
      await _updateLocalSectors(code, sectors);
      
      state = state.copyWith(
        funds: state.funds.map((f) {
          if (f.code == code) {
            return f.copyWith(sectors: sectors);
          }
          return f;
        }).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Get fund by code
  Fund? getFundByCode(String code) {
    try {
      return state.funds.firstWhere((f) => f.code == code);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // Local Storage Operations
  // ============================================================

  Future<void> _syncToLocalStorage(List<Fund> funds) async {
    try {
      final storage = _ref.read(localStorageProvider);
      final localFunds = funds.map((f) => FundLocalHive()
        ..code = f.code
        ..name = f.name
        ..fundKey = f.fundKey
        ..isHold = f.isHold
        ..sectors = f.sectors
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now()).toList();
      await storage.saveFunds(localFunds);
    } catch (_) {
      // Ignore local storage errors
    }
  }

  List<Fund> _loadFromLocalStorage() {
    try {
      final storage = _ref.read(localStorageProvider);
      final localFunds = storage.getAllFunds();
      return localFunds.map((f) => Fund(
        code: f.code,
        name: f.name,
        fundKey: f.fundKey,
        isHold: f.isHold,
        sectors: f.sectors,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveFundToLocal(Fund fund) async {
    try {
      final storage = _ref.read(localStorageProvider);
      await storage.saveFund(FundLocalHive()
        ..code = fund.code
        ..name = fund.name
        ..fundKey = fund.fundKey
        ..isHold = fund.isHold
        ..sectors = fund.sectors
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now());
    } catch (_) {
      // Ignore local storage errors
    }
  }

  Future<void> _deleteFundFromLocal(String code) async {
    try {
      final storage = _ref.read(localStorageProvider);
      await storage.deleteFund(code);
    } catch (_) {
      // Ignore local storage errors
    }
  }

  Future<void> _updateLocalHoldStatus(String code, bool isHold) async {
    try {
      final storage = _ref.read(localStorageProvider);
      await storage.updateHoldStatus(code, isHold);
    } catch (_) {
      // Ignore local storage errors
    }
  }

  Future<void> _updateLocalSectors(String code, List<String> sectors) async {
    try {
      final storage = _ref.read(localStorageProvider);
      await storage.updateSectors(code, sectors);
    } catch (_) {
      // Ignore local storage errors
    }
  }
}

/// Fund valuation provider
final fundValuationProvider =
    FutureProvider.family<FundValuation, String>((ref, code) async {
  final repository = ref.read(fundRepositoryProvider);
  return repository.getValuation(code);
});

/// Fund history provider
final fundHistoryProvider =
    FutureProvider.family<List<FundPoint>, ({String code, String interval})>(
        (ref, params) async {
  final repository = ref.read(fundRepositoryProvider);
  return repository.getFundHistory(params.code, params.interval);
});
