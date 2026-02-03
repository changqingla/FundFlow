import '../models/fund.dart';
import '../network/api_client.dart';
import '../../core/config/api_endpoints.dart';
import 'fund_repository.dart';

/// Implementation of FundRepository using API client
class FundRepositoryImpl implements FundRepository {
  final ApiClient _apiClient;

  FundRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<List<Fund>> getFunds() async {
    final response = await _apiClient.get(ApiEndpoints.funds);
    return _apiClient.parseListResponse(response, Fund.fromJson);
  }

  @override
  Future<Fund> addFund(String code) async {
    final response = await _apiClient.post(
      ApiEndpoints.funds,
      data: {'code': code},
    );
    return _apiClient.parseResponse(response, Fund.fromJson);
  }

  @override
  Future<void> deleteFund(String code) async {
    final response = await _apiClient.delete(ApiEndpoints.fundByCode(code));
    _apiClient.parseEmptyResponse(response);
  }

  @override
  Future<void> updateHoldStatus(String code, bool isHold) async {
    final response = await _apiClient.put(
      ApiEndpoints.fundHoldStatus(code),
      data: {'isHold': isHold},
    );
    _apiClient.parseEmptyResponse(response);
  }

  @override
  Future<void> updateSectors(String code, List<String> sectors) async {
    final response = await _apiClient.put(
      ApiEndpoints.fundSectors(code),
      data: {'sectors': sectors},
    );
    _apiClient.parseEmptyResponse(response);
  }

  @override
  Future<FundValuation> getValuation(String code) async {
    final response = await _apiClient.get(ApiEndpoints.fundValuation(code));
    return _apiClient.parseResponse(response, FundValuation.fromJson);
  }

  @override
  Future<List<FundPoint>> getFundHistory(String code, String interval) async {
    final response = await _apiClient.get(
      '${ApiEndpoints.fundByCode(code)}/history',
      queryParameters: {'interval': interval},
    );
    return _apiClient.parseListResponse(response, FundPoint.fromJson);
  }
}
