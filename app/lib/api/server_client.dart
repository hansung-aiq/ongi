import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'server_models.dart';

/// 서버 오류. [message]는 화면에 그대로 보여 줄 안내 문구다.
class ServerException implements Exception {
  const ServerException(this.message, {this.code});

  final String message;

  /// E-400, E-404, E-409 같은 서버 오류 코드. 연결 실패면 null이다.
  final String? code;

  @override
  String toString() => 'ServerException($code, $message)';
}

/// 부모·자녀 화면이 쓰는 서버 API
class ServerClient {
  ServerClient({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const _timeout = Duration(seconds: 5);

  /// API-02 상황 목록
  Future<List<Situation>> situations() async {
    final json = await _send(() => _client.get(_uri('/situations')));
    return [
      for (final item in json['items'] as List)
        Situation.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// API-03 메시지 목록
  Future<List<ParentMessage>> messages(int familyId) async {
    final json = await _send(
      () => _client.get(_uri('/messages', {'family_id': '$familyId'})),
    );
    return [
      for (final item in json['items'] as List)
        ParentMessage.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// API-04 글 메시지 등록 (200자까지)
  Future<ParentMessage> createTextMessage({
    required int familyId,
    required int situationId,
    required String author,
    required String text,
  }) async {
    final json = await _send(
      () => _client.post(
        _uri('/messages'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'family_id': familyId,
          'situation_id': situationId,
          'author': author,
          'kind': 'text',
          'text': text,
        }),
      ),
    );
    return ParentMessage.fromJson(json);
  }

  /// API-05 녹음 올리기 (m4a, 10MB까지). 받은 audio_path를 돌려준다.
  Future<String> uploadAudio(
    List<int> bytes, {
    required String filename,
  }) async {
    final json = await _send(() async {
      final request = http.MultipartRequest('POST', _uri('/audio'))
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename),
        );
      return http.Response.fromStream(await _client.send(request));
    });
    return json['audio_path'] as String;
  }

  /// API-04 녹음 메시지 등록. [audioPath]는 API-05가 준 값이다.
  Future<ParentMessage> createVoiceMessage({
    required int familyId,
    required int situationId,
    required String author,
    required String audioPath,
  }) async {
    final json = await _send(
      () => _client.post(
        _uri('/messages'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'family_id': familyId,
          'situation_id': situationId,
          'author': author,
          'kind': 'voice',
          'audio_path': audioPath,
        }),
      ),
    );
    return ParentMessage.fromJson(json);
  }

  /// API-06 메시지 수정. 글로 바꾸면 [text], 녹음으로 바꾸면 [audioPath]를 준다.
  /// 서버는 고친 메시지를 다시 '전달 대기'로 돌린다.
  Future<ParentMessage> updateMessage(
    int messageId, {
    required String kind,
    String? text,
    String? audioPath,
  }) async {
    final json = await _send(
      () => _client.patch(
        _uri('/messages/$messageId'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'kind': kind,
          if (kind == 'text') 'text': text,
          if (kind == 'voice') 'audio_path': audioPath,
        }),
      ),
    );
    return ParentMessage.fromJson(json);
  }

  /// API-07 메시지 삭제
  Future<void> deleteMessage(int messageId) async {
    await _send(() => _client.delete(_uri('/messages/$messageId')));
  }

  /// API-09 재생 기록 (최근 순)
  Future<List<PlayLog>> playLogs(int familyId) async {
    final json = await _send(
      () => _client.get(_uri('/play-logs', {'family_id': '$familyId'})),
    );
    return [
      for (final item in json['items'] as List)
        PlayLog.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// API-15 가족 조회 (이름, 스피커 마지막 연결)
  Future<Family> family(int familyId) async {
    final json = await _send(() => _client.get(_uri('/families/$familyId')));
    return _parse(() => Family.fromJson(json));
  }

  /// API-16 자녀 이름 바꾸기. 스피커는 다음 동기화(30초 안)에 새 이름을 받는다.
  Future<Family> updateChildName(int familyId, String childName) async {
    final json = await _send(
      () => _client.patch(
        _uri('/families/$familyId'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'child_name': childName}),
      ),
    );
    return _parse(() => Family.fromJson(json));
  }

  /// API-18 아이가 찾았는데 메시지가 없던 상황 (최근 14일, 최근 순)
  Future<List<Need>> needs(int familyId) async {
    final json = await _send(
      () => _client.get(_uri('/needs', {'family_id': '$familyId'})),
    );
    return _parse(
      () => [
        for (final item in json['items'] as List)
          Need.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  /// API-19 재생 기록·필요 기록 지우기 (메시지는 그대로)
  Future<void> deleteHistory(int familyId) async {
    await _send(() => _client.delete(_uri('/families/$familyId/history')));
  }

  /// 녹음 메시지의 소리 파일 주소 (API-12). 앱에서 다시 들을 때 쓴다.
  Uri audioUrl(int messageId) => _uri('/device/audio/$messageId');

  /// 11/11 확장 응답은 예전 서버·다른 서버에서 모양이 다를 수 있어,
  /// 읽다가 실패하면 [ServerException]으로 바꿔 화면이 멈추지 않게 한다.
  T _parse<T>(T Function() read) {
    try {
      return read();
    } on Object {
      throw const ServerException('서버 응답을 읽을 수 없어요');
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on Exception {
      throw const ServerException('서버에 연결할 수 없어요');
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ServerException('서버 응답을 읽을 수 없어요');
    }
    if (json is! Map<String, dynamic>) {
      throw const ServerException('서버 응답을 읽을 수 없어요');
    }
    if (response.statusCode >= 400) {
      final code = json['error'] as String?;
      throw ServerException(_messageFor(code, json['message']), code: code);
    }
    return json;
  }

  /// 공통지침의 안내 문구. 정해지지 않은 오류는 서버 문구를 쓴다.
  String _messageFor(String? code, Object? serverMessage) => switch (code) {
    'E-409' => '이 상황에는 이미 메시지가 있어요',
    _ when serverMessage is String => serverMessage,
    _ => '저장하지 못했어요. 다시 시도해 주세요',
  };

  void close() => _client.close();
}
