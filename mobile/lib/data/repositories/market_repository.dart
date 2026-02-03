import '../models/market.dart';

/// Market data repository interface
abstract class MarketRepository {
  /// Get global market indices
  Future<List<MarketIndex>> getIndices();

  /// Get precious metals data
  Future<List<PreciousMetal>> getPreciousMetals();

  /// Get gold price history
  Future<List<GoldPrice>> getGoldHistory();

  /// Get volume trend data
  Future<List<VolumeTrend>> getVolumeTrend();

  /// Get minute data for Shanghai index
  Future<List<MinuteData>> getMinuteData();
}
