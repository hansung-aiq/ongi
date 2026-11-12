/// API-02 상황
class Situation {
  const Situation({
    required this.id,
    required this.name,
    required this.category,
  });

  factory Situation.fromJson(Map<String, dynamic> json) => Situation(
    id: json['id'] as int,
    name: json['name'] as String,
    category: json['category'] as String,
  );

  final int id;
  final String name;
  final String category;
}

/// API-03·04 메시지
class ParentMessage {
  const ParentMessage({
    required this.id,
    required this.situationId,
    required this.author,
    required this.kind,
    required this.text,
    required this.delivered,
    required this.createdAt,
  });

  factory ParentMessage.fromJson(Map<String, dynamic> json) => ParentMessage(
    id: json['id'] as int,
    situationId: json['situation_id'] as int,
    author: json['author'] as String,
    kind: json['kind'] as String,
    text: json['text'] as String?,
    delivered: json['delivered'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final int id;
  final int situationId;

  /// mom / dad
  final String author;

  /// text / voice
  final String kind;

  /// 글 메시지 내용. 녹음이면 null이다.
  final String? text;

  /// 보드가 받아 갔는지 (API-13)
  final bool delivered;
  final DateTime createdAt;

  bool get isVoice => kind == 'voice';
}

/// API-09 재생 기록. 보드가 메시지를 재생할 때마다 하나씩 생긴다.
class PlayLog {
  const PlayLog({
    required this.id,
    required this.messageId,
    required this.situationId,
    required this.author,
    required this.playedAt,
  });

  factory PlayLog.fromJson(Map<String, dynamic> json) => PlayLog(
    id: json['id'] as int,
    messageId: json['message_id'] as int,
    situationId: json['situation_id'] as int,
    author: json['author'] as String,
    playedAt: DateTime.parse(json['played_at'] as String),
  );

  final int id;
  final int messageId;
  final int situationId;

  /// mom / dad
  final String author;
  final DateTime playedAt;
}

/// API-15 가족 (11/11). 이름은 앱 첫 설정·설정에서 정하고, 스피커가 받아 아이를 부른다.
class Family {
  const Family({
    required this.childName,
    this.deviceLastSeenAt,
    this.deviceOnline = false,
  });

  factory Family.fromJson(Map<String, dynamic> json) => Family(
    childName: json['child_name'] as String,
    deviceLastSeenAt: switch (json['device_last_seen_at']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    deviceOnline: json['device_online'] as bool? ?? false,
  );

  final String childName;

  /// 스피커(보드)가 마지막으로 서버에서 메시지를 받아 간 시각. 한 번도 없으면 null
  final DateTime? deviceLastSeenAt;

  /// 마지막 연결이 90초 안이면 true
  final bool deviceOnline;
}

/// API-18 아이가 찾았는데 메시지가 없던 상황 (11/11)
class Need {
  const Need({
    required this.situationId,
    required this.name,
    required this.category,
    required this.count,
    required this.lastNeededAt,
  });

  factory Need.fromJson(Map<String, dynamic> json) => Need(
    situationId: json['situation_id'] as int,
    name: json['name'] as String,
    category: json['category'] as String,
    count: json['count'] as int,
    lastNeededAt: DateTime.parse(json['last_needed_at'] as String),
  );

  final int situationId;
  final String name;
  final String category;

  /// 최근 14일 동안 찾은 횟수
  final int count;
  final DateTime lastNeededAt;
}
