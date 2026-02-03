import '../models/sector.dart';

/// Sector data repository interface
abstract class SectorRepository {
  /// Get sector list
  Future<List<Sector>> getSectors();

  /// Get funds in a sector
  Future<List<SectorFund>> getSectorFunds(String sectorId);

  /// Get sector categories
  Future<Map<String, List<String>>> getCategories();
}
