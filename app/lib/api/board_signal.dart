import 'dart:convert';

/// 보드가 앱으로 보내는 신호
sealed class BoardSignal {
  const BoardSignal();

  /// 받은 글자를 신호로 바꾼다. 모르는 신호나 잘못된 값은 null이다.
  static BoardSignal? tryParse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return switch (json['type']) {
        'listening' => const ListeningSignal(),
        'thinking' => ThinkingSignal(json['text'] as String),
        'empathy' => EmpathySignal(
          text: json['text'] as String,
          hasMessage: json['has_message'] as bool,
          author: json['author'] as String?,
        ),
        'playing' => PlayingSignal(
          situationId: json['situation_id'] as int,
          author: json['author'] as String,
          kind: json['kind'] as String,
          text: json['text'] as String?,
          seconds: (json['seconds'] as num?)?.toDouble(),
        ),
        'not_found' => NotFoundSignal(json['text'] as String),
        'safety' => SafetySignal(json['text'] as String),
        'idle' => const IdleSignal(),
        'error' => ErrorSignal(json['code'] as String),
        _ => null,
      };
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

class ListeningSignal extends BoardSignal {
  const ListeningSignal();
}

class ThinkingSignal extends BoardSignal {
  const ThinkingSignal(this.text);

  final String text;
}

class EmpathySignal extends BoardSignal {
  const EmpathySignal({
    required this.text,
    required this.hasMessage,
    required this.author,
  });

  final String text;
  final bool hasMessage;
  final String? author;
}

class PlayingSignal extends BoardSignal {
  const PlayingSignal({
    required this.situationId,
    required this.author,
    required this.kind,
    required this.text,
    this.seconds,
  });

  final int situationId;
  final String author;
  final String kind;
  final String? text;

  /// 메시지 재생 길이(초). 신호 규격 v1.2부터 온다. 없으면 null이다.
  final double? seconds;
}

class NotFoundSignal extends BoardSignal {
  const NotFoundSignal(this.text);

  final String text;
}

class SafetySignal extends BoardSignal {
  const SafetySignal(this.text);

  final String text;
}

class IdleSignal extends BoardSignal {
  const IdleSignal();
}

class ErrorSignal extends BoardSignal {
  const ErrorSignal(this.code);

  final String code;
}
