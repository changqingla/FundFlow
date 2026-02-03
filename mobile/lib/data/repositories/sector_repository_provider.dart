import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client_provider.dart';
import 'sector_repository.dart';
import 'sector_repository_impl.dart';

/// Provider for SectorRepository
final sectorRepositoryProvider = Provider<SectorRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SectorRepositoryImpl(apiClient: apiClient);
});
