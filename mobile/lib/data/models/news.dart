/// News item data model
class NewsItem {
  final String id;
  final String title;
  final String content;
  final String evaluate; // 利好/利空/空
  final int publishTime;
  final List<NewsEntity> entities;

  const NewsItem({
    required this.id,
    required this.title,
    required this.content,
    required this.evaluate,
    required this.publishTime,
    this.entities = const [],
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      evaluate: json['evaluate'] as String? ?? '',
      publishTime: json['publishTime'] as int,
      entities: (json['entities'] as List<dynamic>?)
              ?.map((e) => NewsEntity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'evaluate': evaluate,
      'publishTime': publishTime,
      'entities': entities.map((e) => e.toJson()).toList(),
    };
  }
}

/// News entity (related stock) data model
class NewsEntity {
  final String code;
  final String name;
  final String ratio;

  const NewsEntity({
    required this.code,
    required this.name,
    required this.ratio,
  });

  factory NewsEntity.fromJson(Map<String, dynamic> json) {
    return NewsEntity(
      code: json['code'] as String,
      name: json['name'] as String,
      ratio: json['ratio'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'ratio': ratio,
    };
  }
}
