import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/sector.dart';
import '../../data/repositories/sector_repository_provider.dart';

/// Sort field for sectors
enum SectorSortField {
  changeRate,
  mainNetInflow,
  mainInflowRatio,
}

/// Sort order
enum SortOrder {
  ascending,
  descending,
}

/// Sector list state
class SectorListState {
  final List<Sector> sectors;
  final List<Sector> filteredSectors;
  final bool isLoading;
  final String? error;
  final String? selectedCategory;
  final SectorSortField sortField;
  final SortOrder sortOrder;

  const SectorListState({
    this.sectors = const [],
    this.filteredSectors = const [],
    this.isLoading = false,
    this.error,
    this.selectedCategory,
    this.sortField = SectorSortField.changeRate,
    this.sortOrder = SortOrder.descending,
  });

  SectorListState copyWith({
    List<Sector>? sectors,
    List<Sector>? filteredSectors,
    bool? isLoading,
    String? error,
    String? selectedCategory,
    SectorSortField? sortField,
    SortOrder? sortOrder,
  }) {
    return SectorListState(
      sectors: sectors ?? this.sectors,
      filteredSectors: filteredSectors ?? this.filteredSectors,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      sortField: sortField ?? this.sortField,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

/// Sector list provider
final sectorListProvider =
    StateNotifierProvider<SectorListNotifier, SectorListState>(
  (ref) => SectorListNotifier(ref),
);

/// Sector list notifier
class SectorListNotifier extends StateNotifier<SectorListState> {
  final Ref _ref;

  SectorListNotifier(this._ref) : super(const SectorListState()) {
    loadSectors();
  }

  /// Load sectors from repository
  Future<void> loadSectors() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repository = _ref.read(sectorRepositoryProvider);
      final sectors = await repository.getSectors();
      final sorted = _sortSectors(sectors, state.sortField, state.sortOrder);
      state = state.copyWith(
        sectors: sectors,
        filteredSectors: sorted,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh sectors
  Future<void> refresh() async {
    await loadSectors();
  }

  /// Set sort field and order
  void setSortField(SectorSortField field) {
    final newOrder = state.sortField == field && state.sortOrder == SortOrder.descending
        ? SortOrder.ascending
        : SortOrder.descending;
    
    final sorted = _sortSectors(state.sectors, field, newOrder);
    state = state.copyWith(
      sortField: field,
      sortOrder: newOrder,
      filteredSectors: sorted,
    );
  }

  /// Filter by category
  void filterByCategory(String? category, Map<String, List<String>> categories) {
    if (category == null || category.isEmpty) {
      // Show all sectors
      final sorted = _sortSectors(state.sectors, state.sortField, state.sortOrder);
      state = state.copyWith(
        selectedCategory: null,
        filteredSectors: sorted,
      );
      return;
    }

    final sectorNames = categories[category] ?? [];
    final filtered = state.sectors
        .where((s) => sectorNames.contains(s.name))
        .toList();
    final sorted = _sortSectors(filtered, state.sortField, state.sortOrder);
    
    state = state.copyWith(
      selectedCategory: category,
      filteredSectors: sorted,
    );
  }

  /// Sort sectors by field
  List<Sector> _sortSectors(
    List<Sector> sectors,
    SectorSortField field,
    SortOrder order,
  ) {
    final sorted = List<Sector>.from(sectors);
    
    sorted.sort((a, b) {
      double valueA, valueB;
      
      switch (field) {
        case SectorSortField.changeRate:
          valueA = _parsePercentage(a.changeRate);
          valueB = _parsePercentage(b.changeRate);
          break;
        case SectorSortField.mainNetInflow:
          valueA = _parseAmount(a.mainNetInflow);
          valueB = _parseAmount(b.mainNetInflow);
          break;
        case SectorSortField.mainInflowRatio:
          valueA = _parsePercentage(a.mainInflowRatio);
          valueB = _parsePercentage(b.mainInflowRatio);
          break;
      }
      
      final comparison = valueA.compareTo(valueB);
      return order == SortOrder.descending ? -comparison : comparison;
    });
    
    return sorted;
  }

  double _parsePercentage(String value) {
    final cleanValue = value.replaceAll('%', '').replaceAll('+', '');
    return double.tryParse(cleanValue) ?? 0;
  }

  double _parseAmount(String value) {
    final cleanValue = value.replaceAll(RegExp(r'[^\d.-]'), '');
    double amount = double.tryParse(cleanValue) ?? 0;
    
    if (value.contains('亿')) {
      amount *= 100000000;
    } else if (value.contains('万')) {
      amount *= 10000;
    }
    
    return amount;
  }
}

/// Sector categories provider
final sectorCategoriesProvider =
    FutureProvider<Map<String, List<String>>>((ref) async {
  final repository = ref.read(sectorRepositoryProvider);
  return repository.getCategories();
});

/// Sector funds provider
final sectorFundsProvider =
    FutureProvider.family<List<SectorFund>, String>((ref, sectorId) async {
  final repository = ref.read(sectorRepositoryProvider);
  return repository.getSectorFunds(sectorId);
});
