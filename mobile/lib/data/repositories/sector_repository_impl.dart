import '../models/sector.dart';
import '../network/api_client.dart';
import '../../core/config/api_endpoints.dart';
import 'sector_repository.dart';

/// Implementation of SectorRepository using API client
class SectorRepositoryImpl implements SectorRepository {
  final ApiClient _apiClient;

  SectorRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<List<Sector>> getSectors() async {
    final response = await _apiClient.get(ApiEndpoints.sectors);
    return _apiClient.parseListResponse(response, Sector.fromJson);
  }

  @override
  Future<List<SectorFund>> getSectorFunds(String sectorId) async {
    final response = await _apiClient.get(ApiEndpoints.sectorFunds(sectorId));
    return _apiClient.parseListResponse(response, SectorFund.fromJson);
  }

  @override
  Future<Map<String, List<String>>> getCategories() async {
    final response = await _apiClient.get(ApiEndpoints.sectorCategories);
    final data = response.data;
    
    if (data is! Map<String, dynamic>) {
      return {};
    }

    final code = data['code'] as int? ?? -1;
    if (code != 0) {
      return {};
    }

    final responseData = data['data'];
    if (responseData == null || responseData is! Map<String, dynamic>) {
      return {};
    }

    final result = <String, List<String>>{};
    responseData.forEach((key, value) {
      if (value is List) {
        result[key] = value.map((e) => e.toString()).toList();
      }
    });

    return result;
  }
}
