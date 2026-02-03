import '../models/fund.dart';

/// Fund data repository interface
abstract class FundRepository {
  /// Get user's fund list
  Future<List<Fund>> getFunds();

  /// Add a fund to user's list
  Future<Fund> addFund(String code);

  /// Delete a fund from user's list
  Future<void> deleteFund(String code);

  /// Update fund hold status
  Future<void> updateHoldStatus(String code, bool isHold);

  /// Update fund sectors
  Future<void> updateSectors(String code, List<String> sectors);

  /// Get fund valuation
  Future<FundValuation> getValuation(String code);

  /// Get fund history
  Future<List<FundPoint>> getFundHistory(String code, String interval);
}
