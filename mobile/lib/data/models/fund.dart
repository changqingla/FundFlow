/// Fund information data model
class Fund {
  final String code;
  final String name;
  final String fundKey;
  final bool isHold;
  final List<String> sectors;
  final FundValuation? valuation;

  const Fund({
    required this.code,
    required this.name,
    required this.fundKey,
    this.isHold = false,
    this.sectors = const [],
    this.valuation,
  });

  Fund copyWith({
    String? code,
    String? name,
    String? fundKey,
    bool? isHold,
    List<String>? sectors,
    FundValuation? valuation,
  }) {
    return Fund(
      code: code ?? this.code,
      name: name ?? this.name,
      fundKey: fundKey ?? this.fundKey,
      isHold: isHold ?? this.isHold,
      sectors: sectors ?? this.sectors,
      valuation: valuation ?? this.valuation,
    );
  }

  factory Fund.fromJson(Map<String, dynamic> json) {
    return Fund(
      code: json['code'] as String,
      name: json['name'] as String,
      fundKey: json['fundKey'] as String,
      isHold: json['isHold'] as bool? ?? false,
      sectors: (json['sectors'] as List<dynamic>?)?.cast<String>() ?? [],
      valuation: json['valuation'] != null
          ? FundValuation.fromJson(json['valuation'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'fundKey': fundKey,
      'isHold': isHold,
      'sectors': sectors,
      'valuation': valuation?.toJson(),
    };
  }
}

/// Fund valuation data model
class FundValuation {
  final String code;
  final String name;
  final String valuationTime;
  final String valuation;
  final String dayGrowth;
  final int consecutiveDays;
  final String consecutiveGrowth;
  final String monthlyStats;
  final String monthlyGrowth;

  const FundValuation({
    required this.code,
    required this.name,
    required this.valuationTime,
    required this.valuation,
    required this.dayGrowth,
    required this.consecutiveDays,
    required this.consecutiveGrowth,
    required this.monthlyStats,
    required this.monthlyGrowth,
  });

  factory FundValuation.fromJson(Map<String, dynamic> json) {
    return FundValuation(
      code: json['code'] as String,
      name: json['name'] as String? ?? '',
      valuationTime: json['valuationTime'] as String,
      valuation: json['valuation'] as String,
      dayGrowth: json['dayGrowth'] as String,
      consecutiveDays: json['consecutiveDays'] as int? ?? 0,
      consecutiveGrowth: json['consecutiveGrowth'] as String? ?? '',
      monthlyStats: json['monthlyStats'] as String? ?? '',
      monthlyGrowth: json['monthlyGrowth'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'valuationTime': valuationTime,
      'valuation': valuation,
      'dayGrowth': dayGrowth,
      'consecutiveDays': consecutiveDays,
      'consecutiveGrowth': consecutiveGrowth,
      'monthlyStats': monthlyStats,
      'monthlyGrowth': monthlyGrowth,
    };
  }
}

/// Fund history point data model
class FundPoint {
  final String date;
  final double value;

  const FundPoint({
    required this.date,
    required this.value,
  });

  factory FundPoint.fromJson(Map<String, dynamic> json) {
    return FundPoint(
      date: json['date'] as String,
      value: (json['value'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'value': value,
    };
  }
}

/// Local fund data model for Hive storage
class FundLocal {
  final String code;
  final String name;
  final String fundKey;
  final bool isHold;
  final List<String> sectors;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FundLocal({
    required this.code,
    required this.name,
    required this.fundKey,
    this.isHold = false,
    this.sectors = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory FundLocal.fromJson(Map<String, dynamic> json) {
    return FundLocal(
      code: json['code'] as String,
      name: json['name'] as String,
      fundKey: json['fundKey'] as String,
      isHold: json['isHold'] as bool? ?? false,
      sectors: (json['sectors'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

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
}
