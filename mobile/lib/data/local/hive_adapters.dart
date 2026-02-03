import 'package:hive/hive.dart';

part 'hive_adapters.g.dart';

/// Hive type IDs for adapters
class HiveTypeIds {
  static const int fundLocal = 0;
  static const int userSettings = 1;
}

/// Local fund data model for Hive storage
@HiveType(typeId: HiveTypeIds.fundLocal)
class FundLocalHive extends HiveObject {
  @HiveField(0)
  final String code;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String fundKey;

  @HiveField(3)
  bool isHold;

  @HiveField(4)
  List<String> sectors;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  FundLocalHive({
    required this.code,
    required this.name,
    required this.fundKey,
    this.isHold = false,
    List<String>? sectors,
    required this.createdAt,
    required this.updatedAt,
  }) : sectors = sectors ?? [];

  /// Create a copy with updated fields
  FundLocalHive copyWith({
    String? code,
    String? name,
    String? fundKey,
    bool? isHold,
    List<String>? sectors,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FundLocalHive(
      code: code ?? this.code,
      name: name ?? this.name,
      fundKey: fundKey ?? this.fundKey,
      isHold: isHold ?? this.isHold,
      sectors: sectors ?? List.from(this.sectors),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'fundKey': fundKey,
      'isHold': isHold,
      'sectors': sectors,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON map
  factory FundLocalHive.fromJson(Map<String, dynamic> json) {
    return FundLocalHive(
      code: json['code'] as String,
      name: json['name'] as String,
      fundKey: json['fundKey'] as String,
      isHold: json['isHold'] as bool? ?? false,
      sectors: (json['sectors'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  String toString() {
    return 'FundLocalHive(code: $code, name: $name, isHold: $isHold, sectors: $sectors)';
  }
}

/// User settings data model for Hive storage
@HiveType(typeId: HiveTypeIds.userSettings)
class UserSettingsHive extends HiveObject {
  @HiveField(0)
  String themeMode; // 'light', 'dark', 'system'

  @HiveField(1)
  String? lastUserId;

  @HiveField(2)
  DateTime? lastSyncTime;

  @HiveField(3)
  bool notificationsEnabled;

  @HiveField(4)
  String language; // 'zh', 'en'

  UserSettingsHive({
    this.themeMode = 'system',
    this.lastUserId,
    this.lastSyncTime,
    this.notificationsEnabled = true,
    this.language = 'zh',
  });

  /// Create a copy with updated fields
  UserSettingsHive copyWith({
    String? themeMode,
    String? lastUserId,
    DateTime? lastSyncTime,
    bool? notificationsEnabled,
    String? language,
  }) {
    return UserSettingsHive(
      themeMode: themeMode ?? this.themeMode,
      lastUserId: lastUserId ?? this.lastUserId,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      language: language ?? this.language,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode,
      'lastUserId': lastUserId,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'notificationsEnabled': notificationsEnabled,
      'language': language,
    };
  }

  /// Create from JSON map
  factory UserSettingsHive.fromJson(Map<String, dynamic> json) {
    return UserSettingsHive(
      themeMode: json['themeMode'] as String? ?? 'system',
      lastUserId: json['lastUserId'] as String?,
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.parse(json['lastSyncTime'] as String)
          : null,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      language: json['language'] as String? ?? 'zh',
    );
  }

  @override
  String toString() {
    return 'UserSettingsHive(themeMode: $themeMode, language: $language, notificationsEnabled: $notificationsEnabled)';
  }
}
