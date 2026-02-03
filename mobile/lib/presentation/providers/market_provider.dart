import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/market.dart';
import '../../data/repositories/market_repository_provider.dart';

/// Auto-refresh interval for market data (30 seconds)
const _autoRefreshInterval = Duration(seconds: 30);

/// Market indices provider with auto-refresh
final marketIndicesProvider =
    AutoDisposeAsyncNotifierProvider<MarketIndicesNotifier, List<MarketIndex>>(
  MarketIndicesNotifier.new,
);

/// Market indices notifier with auto-refresh support
class MarketIndicesNotifier extends AutoDisposeAsyncNotifier<List<MarketIndex>> {
  Timer? _refreshTimer;

  @override
  Future<List<MarketIndex>> build() async {
    // Setup auto-refresh
    _setupAutoRefresh();

    // Cancel timer when provider is disposed
    ref.onDispose(() {
      _refreshTimer?.cancel();
    });

    return _fetchIndices();
  }

  void _setupAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      refresh();
    });
  }

  Future<List<MarketIndex>> _fetchIndices() async {
    final repository = ref.read(marketRepositoryProvider);
    return repository.getIndices();
  }

  /// Manually refresh the data
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchIndices());
  }
}

/// Precious metals provider with auto-refresh
final preciousMetalsProvider =
    AutoDisposeAsyncNotifierProvider<PreciousMetalsNotifier, List<PreciousMetal>>(
  PreciousMetalsNotifier.new,
);

/// Precious metals notifier with auto-refresh support
class PreciousMetalsNotifier
    extends AutoDisposeAsyncNotifier<List<PreciousMetal>> {
  Timer? _refreshTimer;

  @override
  Future<List<PreciousMetal>> build() async {
    _setupAutoRefresh();
    ref.onDispose(() {
      _refreshTimer?.cancel();
    });
    return _fetchPreciousMetals();
  }

  void _setupAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      refresh();
    });
  }

  Future<List<PreciousMetal>> _fetchPreciousMetals() async {
    final repository = ref.read(marketRepositoryProvider);
    return repository.getPreciousMetals();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchPreciousMetals());
  }
}

/// Gold history provider
final goldHistoryProvider =
    AutoDisposeAsyncNotifierProvider<GoldHistoryNotifier, List<GoldPrice>>(
  GoldHistoryNotifier.new,
);

/// Gold history notifier
class GoldHistoryNotifier extends AutoDisposeAsyncNotifier<List<GoldPrice>> {
  @override
  Future<List<GoldPrice>> build() async {
    return _fetchGoldHistory();
  }

  Future<List<GoldPrice>> _fetchGoldHistory() async {
    final repository = ref.read(marketRepositoryProvider);
    return repository.getGoldHistory();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchGoldHistory());
  }
}

/// Volume trend provider
final volumeTrendProvider =
    AutoDisposeAsyncNotifierProvider<VolumeTrendNotifier, List<VolumeTrend>>(
  VolumeTrendNotifier.new,
);

/// Volume trend notifier
class VolumeTrendNotifier extends AutoDisposeAsyncNotifier<List<VolumeTrend>> {
  @override
  Future<List<VolumeTrend>> build() async {
    return _fetchVolumeTrend();
  }

  Future<List<VolumeTrend>> _fetchVolumeTrend() async {
    final repository = ref.read(marketRepositoryProvider);
    return repository.getVolumeTrend();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchVolumeTrend());
  }
}

/// Minute data provider with auto-refresh
final minuteDataProvider =
    AutoDisposeAsyncNotifierProvider<MinuteDataNotifier, List<MinuteData>>(
  MinuteDataNotifier.new,
);

/// Minute data notifier with auto-refresh support
class MinuteDataNotifier extends AutoDisposeAsyncNotifier<List<MinuteData>> {
  Timer? _refreshTimer;

  @override
  Future<List<MinuteData>> build() async {
    // Minute data refreshes more frequently (every 60 seconds)
    _setupAutoRefresh();
    ref.onDispose(() {
      _refreshTimer?.cancel();
    });
    return _fetchMinuteData();
  }

  void _setupAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      refresh();
    });
  }

  Future<List<MinuteData>> _fetchMinuteData() async {
    final repository = ref.read(marketRepositoryProvider);
    return repository.getMinuteData();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchMinuteData());
  }
}
