/// Market index data model
class MarketIndex {
  final String name;
  final String price;
  final String change;
  final bool isUp;
  final String updatedAt;

  const MarketIndex({
    required this.name,
    required this.price,
    required this.change,
    required this.isUp,
    required this.updatedAt,
  });

  factory MarketIndex.fromJson(Map<String, dynamic> json) {
    return MarketIndex(
      name: json['name'] as String,
      price: json['price'] as String,
      change: json['change'] as String,
      isUp: json['isUp'] as bool? ?? false,
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'change': change,
      'isUp': isUp,
      'updatedAt': updatedAt,
    };
  }
}

/// Precious metal data model
class PreciousMetal {
  final String name;
  final double price;
  final double change;
  final String changeRate;
  final double open;
  final double high;
  final double low;
  final double close;
  final String unit;
  final String updatedAt;

  const PreciousMetal({
    required this.name,
    required this.price,
    required this.change,
    required this.changeRate,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.unit,
    required this.updatedAt,
  });

  factory PreciousMetal.fromJson(Map<String, dynamic> json) {
    return PreciousMetal(
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      change: (json['change'] as num).toDouble(),
      changeRate: json['changeRate'] as String,
      open: (json['open'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      close: (json['close'] as num).toDouble(),
      unit: json['unit'] as String,
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'change': change,
      'changeRate': changeRate,
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'unit': unit,
      'updatedAt': updatedAt,
    };
  }
}

/// Gold price history data model
class GoldPrice {
  final String date;
  final String chinaGoldPrice;
  final String chowTaiFook;
  final String chinaChange;
  final String chowChange;

  const GoldPrice({
    required this.date,
    required this.chinaGoldPrice,
    required this.chowTaiFook,
    required this.chinaChange,
    required this.chowChange,
  });

  factory GoldPrice.fromJson(Map<String, dynamic> json) {
    return GoldPrice(
      date: json['date'] as String,
      chinaGoldPrice: json['chinaGoldPrice'] as String,
      chowTaiFook: json['chowTaiFook'] as String,
      chinaChange: json['chinaChange'] as String? ?? '',
      chowChange: json['chowChange'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'chinaGoldPrice': chinaGoldPrice,
      'chowTaiFook': chowTaiFook,
      'chinaChange': chinaChange,
      'chowChange': chowChange,
    };
  }
}

/// Volume trend data model
class VolumeTrend {
  final String date;
  final String totalVolume;
  final String shanghai;
  final String shenzhen;
  final String beijing;

  const VolumeTrend({
    required this.date,
    required this.totalVolume,
    required this.shanghai,
    required this.shenzhen,
    required this.beijing,
  });

  factory VolumeTrend.fromJson(Map<String, dynamic> json) {
    return VolumeTrend(
      date: json['date'] as String,
      totalVolume: json['totalVolume'] as String,
      shanghai: json['shanghai'] as String,
      shenzhen: json['shenzhen'] as String,
      beijing: json['beijing'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'totalVolume': totalVolume,
      'shanghai': shanghai,
      'shenzhen': shenzhen,
      'beijing': beijing,
    };
  }
}

/// Minute data model
class MinuteData {
  final String time;
  final String price;
  final String change;
  final String changeRate;
  final String volume;
  final String amount;

  const MinuteData({
    required this.time,
    required this.price,
    required this.change,
    required this.changeRate,
    required this.volume,
    required this.amount,
  });

  factory MinuteData.fromJson(Map<String, dynamic> json) {
    return MinuteData(
      time: json['time'] as String,
      price: json['price'] as String,
      change: json['change'] as String,
      changeRate: json['changeRate'] as String,
      volume: json['volume'] as String,
      amount: json['amount'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'price': price,
      'change': change,
      'changeRate': changeRate,
      'volume': volume,
      'amount': amount,
    };
  }
}
