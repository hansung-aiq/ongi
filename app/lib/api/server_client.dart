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

/// 부모 화면이 쓰는 서버 API
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
