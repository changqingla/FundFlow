import '../models/market.dart';
import '../network/api_client.dart';
import '../../core/config/api_endpoints.dart';
import 'market_repository.dart';

/// Implementation of MarketRepository using API client
class MarketRepositoryImpl implements MarketRepository {
  final ApiClient _apiClient;

  MarketRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<List<MarketIndex>> getIndices() async {
    final response = await _apiClient.get(ApiEndpoints.marketIndices);
    return _apiClient.parseListResponse(response, MarketIndex.fromJson);
  }

  @override
  Future<List<PreciousMetal>> getPreciousMetals() async {
    final response = await _apiClient.get(ApiEndpoints.preciousMetals);
    return _apiClient.parseListResponse(response, PreciousMetal.fromJson);
  }

  @override
  Future<List<GoldPrice>> getGoldHistory() async {
    final response = await _apiClient.get(ApiEndpoints.goldHistory);
    return _apiClient.parseListResponse(response, GoldPrice.fromJson);
  }

  @override
  Future<List<VolumeTrend>> getVolumeTrend() async {
    final response = await _apiClient.get(ApiEndpoints.volumeTrend);
    return _apiClient.parseListResponse(response, VolumeTrend.fromJson);
  }

  @override
  Future<List<MinuteData>> getMinuteData() async {
    final response = await _apiClient.get(ApiEndpoints.minuteData);
    return _apiClient.parseListResponse(response, MinuteData.fromJson);
  }
}
