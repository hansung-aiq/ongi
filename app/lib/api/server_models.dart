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
