/// API endpoint definitions
class ApiEndpoints {
  ApiEndpoints._();

  // Auth endpoints
  static const String register = '/auth/register';
  static const String verifyEmail = '/auth/verify-email';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String currentUser = '/auth/me';

  // Market endpoints
  static const String marketIndices = '/market/indices';
  static const String preciousMetals = '/market/precious-metals';
  static const String goldHistory = '/market/gold-history';
  static const String volumeTrend = '/market/volume';
  static const String minuteData = '/market/minute-data';

  // Fund endpoints
  static const String funds = '/funds';
  static String fundByCode(String code) => '/funds/$code';
  static String fundHoldStatus(String code) => '/funds/$code/hold';
  static String fundSectors(String code) => '/funds/$code/sectors';
  static String fundValuation(String code) => '/funds/$code/valuation';

  // Sector endpoints
  static const String sectors = '/sectors';
  static String sectorFunds(String id) => '/sectors/$id/funds';
  static const String sectorCategories = '/sectors/categories';

  // News endpoints
  static const String news = '/news';

  // AI endpoints
  static const String aiChat = '/ai/chat';
  static const String aiAnalyzeStandard = '/ai/analyze/standard';
  static const String aiAnalyzeFast = '/ai/analyze/fast';
  static const String aiAnalyzeDeep = '/ai/analyze/deep';
}
