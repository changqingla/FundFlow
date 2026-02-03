/// Sector data model
class Sector {
  final String id;
  final String name;
  final String changeRate;
  final String mainNetInflow;
  final String mainInflowRatio;
  final String smallNetInflow;
  final String smallInflowRatio;

  const Sector({
    required this.id,
    required this.name,
    required this.changeRate,
    required this.mainNetInflow,
    required this.mainInflowRatio,
    required this.smallNetInflow,
    required this.smallInflowRatio,
  });

  factory Sector.fromJson(Map<String, dynamic> json) {
    return Sector(
      id: json['id'] as String,
      name: json['name'] as String,
      changeRate: json['changeRate'] as String,
      mainNetInflow: json['mainNetInflow'] as String? ?? '',
      mainInflowRatio: json['mainInflowRatio'] as String? ?? '',
      smallNetInflow: json['smallNetInflow'] as String? ?? '',
      smallInflowRatio: json['smallInflowRatio'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'changeRate': changeRate,
      'mainNetInflow': mainNetInflow,
      'mainInflowRatio': mainInflowRatio,
      'smallNetInflow': smallNetInflow,
      'smallInflowRatio': smallInflowRatio,
    };
  }
}

/// Sector fund data model
class SectorFund {
  final String code;
  final String name;
  final String type;
  final String date;
  final String netValue;
  final String week1;
  final String month1;
  final String month3;
  final String month6;
  final String yearToDate;
  final String year1;
  final String year2;
  final String year3;
  final String sinceStart;

  const SectorFund({
    required this.code,
    required this.name,
    required this.type,
    required this.date,
    required this.netValue,
    required this.week1,
    required this.month1,
    required this.month3,
    required this.month6,
    required this.yearToDate,
    required this.year1,
    required this.year2,
    required this.year3,
    required this.sinceStart,
  });

  factory SectorFund.fromJson(Map<String, dynamic> json) {
    return SectorFund(
      code: json['code'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? '',
      date: json['date'] as String? ?? '',
      netValue: json['netValue'] as String? ?? '',
      week1: json['week1'] as String? ?? '',
      month1: json['month1'] as String? ?? '',
      month3: json['month3'] as String? ?? '',
      month6: json['month6'] as String? ?? '',
      yearToDate: json['yearToDate'] as String? ?? '',
      year1: json['year1'] as String? ?? '',
      year2: json['year2'] as String? ?? '',
      year3: json['year3'] as String? ?? '',
      sinceStart: json['sinceStart'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'type': type,
      'date': date,
      'netValue': netValue,
      'week1': week1,
      'month1': month1,
      'month3': month3,
      'month6': month6,
      'yearToDate': yearToDate,
      'year1': year1,
      'year2': year2,
      'year3': year3,
      'sinceStart': sinceStart,
    };
  }
}

/// Sector category data model
class SectorCategory {
  final String name;
  final List<String> sectors;

  const SectorCategory({
    required this.name,
    required this.sectors,
  });

  factory SectorCategory.fromJson(Map<String, dynamic> json) {
    return SectorCategory(
      name: json['name'] as String,
      sectors: (json['sectors'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sectors': sectors,
    };
  }
}
