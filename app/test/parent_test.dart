import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ongi_app/api/message_playback.dart';
import 'package:ongi_app/api/server_client.dart';
import 'package:ongi_app/common/common.dart';
import 'package:ongi_app/parent/message_write_screen.dart';
import 'package:ongi_app/parent/onboarding/child_info_screen.dart';
import 'package:ongi_app/parent/onboarding/onboarding_session.dart';
import 'package:ongi_app/parent/parent_shell.dart';
import 'package:ongi_app/parent/voice_recorder.dart';
import 'package:ongi_app/start/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_audio.dart';

/// device/mock_server.py와 같은 모양으로 답하는 가짜 서버.
class FakeServer {
  static const _situations = [
    (1, '학교 가기 싫은 날', '학교·학업'),
    (2, '실수해서 혼났을 때', '학교·학업'),
    (3, '시험을 망친 날', '학교·학업'),
    (4, '친구와 싸운 날', '관계·비교'),
    (5, '친구가 날 싫어하는 것 같을 때', '관계·비교'),
    (6, '남들과 비교될 때', '관계·비교'),
    (7, '울고 싶은 날', '감정·일상'),
    (8, '아무것도 하기 싫은 날', '감정·일상'),
    (9, '잠이 안 오는 밤', '감정·일상'),
    (10, '부모님이 보고 싶을 때', '가족·기념일'),
    (11, '자랑하고 싶은 날', '가족·기념일'),
    (12, '생일', '가족·기념일'),
  ];

  final messages = <Map<String, Object?>>[
    _message(1, 4, 'voice', null),
    _message(2, 10, 'voice', null),
    _message(3, 11, 'text', '민준아, 상 받은 거 정말 축하해!', delivered: true),
  ];
  final posted = <Map<String, dynamic>>[];

  /// API-05로 올라온 multipart 본문
  final uploads = <List<int>>[];

  /// true면 연결이 안 되는 것처럼 동작한다.
  bool offline = false;

  /// API-06으로 고친 내용 ({id, kind, text | audio_path})
  final patched = <Map<String, dynamic>>[];

  /// API-07로 지운 메시지 번호
  final deleted = <int>[];

  static Map<String, Object?> _message(
    int id,
    int situationId,
    String kind,
    String? text, {
    bool delivered = false,
  }) => {
    'id': id,
    'family_id': 1,
    'situation_id': situationId,
    'author': 'mom',
    'kind': kind,
    'text': text,
    'audio_path': kind == 'voice' ? '$id.m4a' : null,
    'delivered': delivered,
    'created_at': '2026-11-01T09:00:00',
    'updated_at': '2026-11-01T09:00:00',
    'deleted': false,
  };

  ServerClient get client =>
      ServerClient(baseUrl: 'http://server', client: MockClient(_handle));

  Future<http.Response> _handle(http.Request request) async {
    if (offline) throw http.ClientException('연결 안 됨');
    final path = request.url.path;
    if (request.method == 'GET' && path == '/situations') {
      return _json(200, {
        'items': [
          for (final (id, name, category) in _situations)
            {'id': id, 'name': name, 'category': category},
        ],
      });
    }
    if (request.method == 'GET' && path == '/messages') {
      return _json(200, {'items': messages});
    }
    if (request.method == 'POST' && path == '/audio') {
      uploads.add(request.bodyBytes);
      return _json(201, {
        'audio_path': 'up1.m4a',
        'size_bytes': 4,
        'content_type': 'audio/mp4',
      });
    }
    if (request.method == 'POST' && path == '/messages') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      posted.add(body);
      final sid = body['situation_id'] as int;
      if (messages.any((m) => m['situation_id'] == sid)) {
        return _json(409, {'error': 'E-409', 'message': '이 상황에는 이미 메시지가 있어요'});
      }
      final m = _message(
        messages.length + 1,
        sid,
        body['kind'] as String,
        body['text'] as String?,
      );
      messages.add(m);
      return _json(201, m);
    }
    if (request.method == 'PATCH' && path.startsWith('/messages/')) {
      final id = int.parse(path.split('/').last);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      patched.add({'id': id, ...body});
      final m = messages.firstWhere((m) => m['id'] == id);
      m
        ..addAll(body)
        ..['delivered'] = false;
      return _json(200, m);
    }
    if (request.method == 'DELETE' && path.startsWith('/messages/')) {
      final id = int.parse(path.split('/').last);
      deleted.add(id);
      final m = messages.firstWhere((m) => m['id'] == id);
      messages.remove(m);
      return _json(200, {...m, 'deleted': true});
    }
    return _json(404, {'error': 'E-404', 'message': '없는 주소'});
  }

  static http.Response _json(int status, Object body) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// 화면 밖에 있으면 스크롤해서 보이게 한 뒤 누른다.
Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// 마이크 없이 녹음·다시 듣기를 흉내 내는 녹음기.
class FakeRecorder implements VoiceRecorder {
  bool permitted = true;
  bool recording = false;
  bool cancelled = false;
  final played = <String>[];
  final _complete = StreamController<void>.broadcast();

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<void> start() async => recording = true;

  @override
  Future<String> stop() async {
    recording = false;
    return '/tmp/ongi_1.m4a';
  }

  @override
  Future<void> cancel() async {
    recording = false;
    cancelled = true;
  }

  @override
  Future<void> play(String path) async => played.add(path);

  @override
  Future<void> pause() async {}

  void finishPlaying() => _complete.add(null);

  @override
  Stream<void> get onPlayComplete => _complete.stream;

  @override
  Future<List<int>> read(String path) async => utf8.encode('m4a!');

  @override
  Future<void> dispose() async {}
}

Future<void> _openParent(
  WidgetTester tester,
  FakeServer server, {
  FakeRecorder? recorder,
  FakeUrlPlayer? player,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ParentShell(
        serverClient: server.client,
        recorderFactory: () => recorder ?? FakeRecorder(),
        audioPlayer: player ?? FakeUrlPlayer(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 학교·학업 > 시험을 망친 날의 녹음 탭을 연다.
Future<void> _openVoiceTab(WidgetTester tester) async {
  await _tapText(tester, '학교 · 학업');
  await _tapText(tester, '시험을 망친 날');
  await tester.tap(find.text('음성 녹음'));
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('4차: 설정·수정·삭제·재생', settingsAndMenuTests);

  test('문장 속 이름은 받침이 있을 때만 이를 붙인다', () {
    String nick(String name) =>
        ParentProfile(childName: name, author: 'mom').nickname;
    expect(nick('민준'), '민준이');
    expect(nick('서아'), '서아');
    expect(nick('Alex'), 'Alex');
  });

  testWidgets('처음 부모를 고르면 2-1이 열리고 뒤로 가면 역할 선택으로 돌아온다', (tester) async {
    final server = FakeServer();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginScreen(serverClient: server.client),
      ),
    );
    await _tapText(tester, '시작하기');
    await tester.tap(find.text('부모'));
    await tester.pump();
    await _tapText(tester, '시작하기');
    expect(find.text('아이를 알려주세요.'), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('이 기기는 누가 쓰나요?'), findsOneWidget);
  });

  testWidgets('2-1부터 녹음으로 첫 메시지를 남기고 홈으로 간다', (tester) async {
    final server = FakeServer()..messages.clear();
    final recorder = FakeRecorder();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ChildInfoScreen(
          serverClient: server.client,
          recorderFactory: () => recorder,
        ),
      ),
    );
    await tester.pumpAndSettle();

    /// 2-1: 이름을 넣기 전에는 다음으로 갈 수 없다.
    expect(find.text('아이를 알려주세요.'), findsOneWidget);
    await _tapText(tester, '다음');
    expect(find.text('아이를 알려주세요.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '민준');
    await _tapText(tester, '아빠');
    await _tapText(tester, '다음');

    /// 2-2
    expect(find.text('민준이를 위한\n첫 번째 메시지를\n남겨볼까요?'), findsOneWidget);
    expect(find.textContaining('아빠의 목소리로 말해주세요.'), findsOneWidget);
    await _tapText(tester, '다음');

    /// 2-3
    expect(find.text('이런 순간,\n아빠의 목소리가 필요해요.'), findsOneWidget);
    expect(find.text('친구와 싸운 날'), findsOneWidget);
    await _tapText(tester, '이 상황에 메시지 남기기');

    /// 2-4 → 2-5 → 2-6
    expect(find.text('버튼을 누르고 말해주세요.'), findsOneWidget);
    await tester.tap(find.byTooltip('녹음 시작'));
    await tester.pump();
    expect(find.text('녹음 중이에요.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('0:02 / 1:00'), findsOneWidget);
    await tester.tap(find.byTooltip('녹음 멈추기'));
    await tester.pump();
    expect(find.text('녹음을 마쳤어요.'), findsOneWidget);

    /// 재생 중에는 파형이 계속 움직이므로 pumpAndSettle을 쓰지 않는다.
    await tester.tap(find.text('다시 듣기'));
    await tester.pump();
    expect(recorder.played, ['/tmp/ongi_1.m4a']);
    expect(find.text('멈추기'), findsOneWidget);
    recorder.finishPlaying();
    await tester.pump();
    expect(find.text('다시 듣기'), findsOneWidget);
    await _tapText(tester, '저장하기');

    /// 2-7
    expect(server.posted.single['situation_id'], 4);
    expect(server.posted.single['author'], 'dad');
    expect(find.text('첫 메시지를 남겼어요'), findsOneWidget);
    expect(find.text('1/10'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('parent_onboarding_done'), isTrue);
    expect(prefs.getString('child_name'), '민준');

    await _tapText(tester, '홈으로');
    expect(find.text('민준이의 부모님'), findsOneWidget);
  });

  testWidgets('작은 화면에서도 첫 설정 화면이 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = FakeServer()..messages.clear();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ChildInfoScreen(
          serverClient: server.client,
          recorderFactory: FakeRecorder.new,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '민준');
    for (final button in ['다음', '다음', '이 상황에 메시지 남기기']) {
      await _tapText(tester, button);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('텍스트 입력'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '민준아, 아빠는 네 편이야.');
    await _tapText(tester, '저장하기');
    expect(find.text('첫 메시지를 남겼어요'), findsOneWidget);
    expect(tester.takeException(), isNull);

    /// 메시지 탭의 카드도 칩 글자를 줄여서 넘치지 않는다.
    await _tapText(tester, '메시지 더 남기기');
    expect(tester.takeException(), isNull);
  });

  testWidgets('2-7에서 메시지 더 남기기를 누르면 메시지 탭으로 간다', (tester) async {
    final server = FakeServer()..messages.clear();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ChildInfoScreen(
          serverClient: server.client,
          recorderFactory: FakeRecorder.new,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '민준');
    for (final button in ['다음', '다음', '이 상황에 메시지 남기기']) {
      await _tapText(tester, button);
    }
    await tester.tap(find.text('텍스트 입력'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '민준아, 엄마는 네 편이야.');
    await _tapText(tester, '저장하기');

    await _tapText(tester, '메시지 더 남기기');
    expect(find.textContaining('메시지가 민준이를 기다리고 있어요'), findsOneWidget);
    expect(find.text('민준이의 부모님'), findsNothing);
  });

  testWidgets('첫 설정에서 저장한 이름과 호칭을 부모 화면에 쓴다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'parent_onboarding_done': true,
      'child_name': '서아',
      'parent_author': 'dad',
    });
    final server = FakeServer();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginScreen(serverClient: server.client),
      ),
    );
    await _tapText(tester, '시작하기');
    await tester.tap(find.text('부모'));
    await tester.pump();
    await _tapText(tester, '시작하기');
    expect(find.text('서아의 부모님'), findsOneWidget);

    await _tapText(tester, '학교 · 학업');
    await _tapText(tester, '시험을 망친 날');
    await tester.enterText(find.byType(TextField), '서아야, 괜찮아.');
    await _tapText(tester, '저장하기');
    expect(server.posted.single['author'], 'dad');
    expect(find.textContaining('아빠의 마음을'), findsOneWidget);
  });

  testWidgets('시작하기 → 부모 선택 → 부모 홈에 서버 데이터가 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({'parent_onboarding_done': true});
    final server = FakeServer();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginScreen(serverClient: server.client),
      ),
    );

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('이 기기는 누가 쓰나요?'), findsOneWidget);

    /// 역할을 고르기 전에는 시작할 수 없다.
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('이 기기는 누가 쓰나요?'), findsOneWidget);

    await tester.tap(find.text('부모'));
    await tester.pump();
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('민준이의 부모님'), findsOneWidget);
    expect(find.text('3/10'), findsOneWidget);
    expect(find.text('학교 · 학업'), findsOneWidget);
    expect(find.text('가족 · 기념일'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('메시지 탭은 저장한 메시지와 전달 상태를 보여 준다', (tester) async {
    await _openParent(tester, FakeServer());

    await tester.tap(find.text('메시지'));
    await tester.pumpAndSettle();

    expect(find.text('전체 3'), findsOneWidget);
    expect(find.text('친구와 싸운 날'), findsOneWidget);
    expect(find.text('민준아, 상 받은 거 정말 축하해!'), findsOneWidget);
    expect(find.text('전달됨'), findsOneWidget);
    expect(find.text('전달 대기'), findsNWidgets(2));
  });

  testWidgets('분류 → 빈 상황 → 글 저장 → 저장 완료 → 홈', (tester) async {
    final server = FakeServer();
    await _openParent(tester, server);

    await _tapText(tester, '학교 · 학업');
    expect(find.text('학교 · 학업 0/3'), findsOneWidget);

    await _tapText(tester, '시험을 망친 날');
    expect(find.text('메시지 남기기'), findsOneWidget);

    /// 비어 있으면 저장할 수 없다.
    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();
    expect(server.posted, isEmpty);

    await tester.enterText(find.byType(TextField), '민준아, 엄마는 언제나 너를 믿어.');
    await tester.pump();
    expect(find.text('19/200자'), findsOneWidget);

    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();

    expect(server.posted.single, {
      'family_id': 1,
      'situation_id': 3,
      'author': 'mom',
      'kind': 'text',
      'text': '민준아, 엄마는 언제나 너를 믿어.',
    });
    expect(find.text('메시지를 남겼어요'), findsOneWidget);
    expect(find.text('4/10'), findsOneWidget);

    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();
    expect(find.text('민준이의 부모님'), findsOneWidget);
    expect(find.text('4/10'), findsOneWidget);
  });

  testWidgets('메시지 더 남기기는 그 분류의 목록으로 돌아간다', (tester) async {
    await _openParent(tester, FakeServer());

    await _tapText(tester, '감정 · 일상');
    await _tapText(tester, '울고 싶은 날');
    await tester.enterText(find.byType(TextField), '울어도 괜찮아');
    await tester.pump();
    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('메시지 더 남기기'));
    await tester.pumpAndSettle();

    expect(find.text('감정 · 일상 1/3'), findsOneWidget);
    expect(find.text('울어도 괜찮아'), findsOneWidget);
  });

  testWidgets('글은 200자를 넘겨 입력되지 않는다', (tester) async {
    await _openParent(tester, FakeServer());
    await _tapText(tester, '학교 · 학업');
    await _tapText(tester, '학교 가기 싫은 날');

    await tester.enterText(find.byType(TextField), '가' * 250);
    await tester.pump();

    expect(find.text('200/200자'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text.length,
      MessageWriteScreen.maxLength,
    );
  });

  testWidgets('이미 메시지가 있으면 E-409 안내를 보여 준다', (tester) async {
    final server = FakeServer();
    await _openParent(tester, server);
    await _tapText(tester, '학교 · 학업');
    await _tapText(tester, '학교 가기 싫은 날');

    /// 다른 기기에서 먼저 저장한 경우
    server.messages.add(FakeServer._message(9, 1, 'text', '먼저 저장'));
    await tester.enterText(find.byType(TextField), '안녕');
    await tester.pump();
    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();

    expect(find.text('이 상황에는 이미 메시지가 있어요'), findsOneWidget);
    expect(find.text('메시지 남기기'), findsOneWidget);
  });

  testWidgets('서버에 연결할 수 없으면 안내하고 다시 시도할 수 있다', (tester) async {
    final server = FakeServer()..offline = true;
    await _openParent(tester, server);

    expect(find.text('서버에 연결할 수 없어요'), findsOneWidget);

    server.offline = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('민준이의 부모님'), findsOneWidget);
  });

  testWidgets('작은 화면에서도 부모 화면이 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _openParent(tester, FakeServer());
    expect(tester.takeException(), isNull);

    await _tapText(tester, '학교 · 학업');
    await _tapText(tester, '시험을 망친 날');
    expect(tester.takeException(), isNull);

    // 녹음 탭의 세 상태
    await tester.tap(find.text('음성 녹음'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('녹음 시작'));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('녹음 멈추기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('녹음 → 멈춤 → 다시 듣기 → 저장하면 API-05, API-04 순서로 올린다', (tester) async {
    final server = FakeServer();
    final recorder = FakeRecorder();
    await _openParent(tester, server, recorder: recorder);
    await _openVoiceTab(tester);

    expect(find.text('버튼을 누르고 말해주세요.'), findsOneWidget);
    expect(find.textContaining('민준이에게 들려드려요'), findsOneWidget);
    expect(find.text('최대 1분까지 녹음할 수 있어요'), findsOneWidget);

    await tester.tap(find.byTooltip('녹음 시작'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(recorder.recording, isTrue);
    expect(find.text('0:03 / 1:00'), findsOneWidget);

    /// 녹음하는 동안은 탭을 바꿀 수 없다.
    await tester.tap(find.text('텍스트 입력'));
    await tester.pump();
    expect(find.text('0:03 / 1:00'), findsOneWidget);

    await tester.tap(find.byTooltip('녹음 멈추기'));
    await tester.pumpAndSettle();
    expect(find.text('녹음을 마쳤어요.'), findsOneWidget);

    await tester.tap(find.text('다시 듣기'));
    await tester.pump();
    expect(recorder.played, ['/tmp/ongi_1.m4a']);
    expect(find.text('멈추기'), findsOneWidget);
    recorder.finishPlaying();
    await tester.pumpAndSettle();
    expect(find.text('다시 듣기'), findsOneWidget);

    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();

    expect(server.uploads, hasLength(1));
    expect(utf8.decode(server.uploads.single), contains('ongi_1.m4a'));
    expect(server.posted.single, {
      'family_id': 1,
      'situation_id': 3,
      'author': 'mom',
      'kind': 'voice',
      'audio_path': 'up1.m4a',
    });
    expect(find.text('메시지를 남겼어요'), findsOneWidget);
  });

  testWidgets('녹음은 60초에서 저절로 멈춘다', (tester) async {
    final recorder = FakeRecorder();
    await _openParent(tester, FakeServer(), recorder: recorder);
    await _openVoiceTab(tester);

    await tester.tap(find.byTooltip('녹음 시작'));
    await tester.pump();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();

    expect(recorder.recording, isFalse);
    expect(find.text('녹음을 마쳤어요.'), findsOneWidget);
  });

  testWidgets('다시 녹음하면 녹음 전으로 돌아가고 저장할 수 없다', (tester) async {
    final server = FakeServer();
    await _openParent(tester, server);
    await _openVoiceTab(tester);

    await tester.tap(find.byTooltip('녹음 시작'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byTooltip('녹음 멈추기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다시 녹음'));
    await tester.pumpAndSettle();

    expect(find.text('버튼을 누르고 말해주세요.'), findsOneWidget);
    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();
    expect(server.uploads, isEmpty);
  });

  testWidgets('마이크 권한이 없으면 안내한다', (tester) async {
    final recorder = FakeRecorder()..permitted = false;
    await _openParent(tester, FakeServer(), recorder: recorder);
    await _openVoiceTab(tester);

    await tester.tap(find.byTooltip('녹음 시작'));
    await tester.pumpAndSettle();

    expect(find.text('마이크 권한을 허용해 주세요'), findsOneWidget);
    expect(recorder.recording, isFalse);
  });

  testWidgets('녹음 중에 화면을 나가면 녹음을 버린다', (tester) async {
    final recorder = FakeRecorder();
    await _openParent(tester, FakeServer(), recorder: recorder);
    await _openVoiceTab(tester);

    await tester.tap(find.byTooltip('녹음 시작'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();

    expect(recorder.cancelled, isTrue);
    expect(find.text('학교 · 학업 0/3'), findsOneWidget);
  });
}

/// 하단 탭바의 [label] 탭을 누른다.
Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(BottomTabBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void settingsAndMenuTests() {
  testWidgets('3-6 설정: 스피커는 숨기고 이름·호칭을 바꾸면 홈에도 반영된다', (tester) async {
    await _openParent(tester, FakeServer());
    await _tapTab(tester, '설정');

    expect(find.text('프로필'), findsOneWidget);
    expect(find.text('자녀 · 이름과 사진 바꾸기'), findsOneWidget);
    expect(find.text('나 · 호칭과 사진 바꾸기'), findsOneWidget);
    expect(find.text('온기 스피커'), findsNothing);
    expect(find.text('로그아웃'), findsNothing);

    await _tapText(tester, '민준');
    expect(find.text('자녀 프로필'), findsOneWidget);
    expect(find.text('사진 등록'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '서아');
    await _tapText(tester, '저장하기');
    expect(find.text('서아'), findsOneWidget);

    await _tapText(tester, '엄마');
    expect(find.text('부모 프로필'), findsOneWidget);
    await _tapText(tester, '아빠');
    await _tapText(tester, '저장하기');
    expect(find.text('아빠'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('child_name'), '서아');
    expect(prefs.getString('parent_author'), 'dad');

    await _tapTab(tester, '홈');
    expect(find.text('서아의 부모님'), findsOneWidget);
  });

  testWidgets('3-6 설정: 사용 모드를 누르면 1-2 역할 선택으로 간다', (tester) async {
    await _openParent(tester, FakeServer());
    await _tapTab(tester, '설정');
    await _tapText(tester, '사용 모드');
    expect(find.text('이 기기는 누가 쓰나요?'), findsOneWidget);
  });

  testWidgets('6-2: 닫기는 아무것도 하지 않고, 삭제하기는 메시지를 지운다', (tester) async {
    final server = FakeServer();
    await _openParent(tester, server);
    await _tapTab(tester, '메시지');
    expect(find.text('전체 3'), findsOneWidget);

    await tester.tap(find.byTooltip('더보기').first);
    await tester.pumpAndSettle();
    expect(find.text('이 메시지를 어떻게 할까요?'), findsOneWidget);
    await _tapText(tester, '닫기');
    expect(find.text('이 메시지를 어떻게 할까요?'), findsNothing);
    expect(server.deleted, isEmpty);

    await tester.tap(find.byTooltip('더보기').first);
    await tester.pumpAndSettle();
    await _tapText(tester, '삭제하기');
    expect(server.deleted, [1]);
    expect(find.text('메시지를 지웠어요'), findsOneWidget);
    expect(find.text('전체 2'), findsOneWidget);
  });

  testWidgets('6-2: 수정하기로 글 메시지를 고치면 API-06으로 저장하고 목록으로 돌아온다', (tester) async {
    final server = FakeServer();
    await _openParent(tester, server);
    await _tapTab(tester, '메시지');

    final more = find.byTooltip('더보기').at(2);
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
    await _tapText(tester, '수정하기');

    expect(find.text('메시지 수정하기'), findsOneWidget);
    expect(find.text('민준아, 상 받은 거 정말 축하해!'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '민준아, 정말 멋졌어!');
    await _tapText(tester, '저장하기');

    expect(server.patched.single, {
      'id': 3,
      'kind': 'text',
      'text': '민준아, 정말 멋졌어!',
    });
    expect(find.text('메시지를 고쳤어요'), findsOneWidget);
    expect(find.text('민준아, 정말 멋졌어!'), findsOneWidget);
    expect(find.text('메시지를 남겼어요'), findsNothing);
  });

  testWidgets('녹음 메시지 카드의 재생 버튼은 서버의 녹음을 재생하고 멈춘다', (tester) async {
    final player = FakeUrlPlayer();
    await _openParent(tester, FakeServer(), player: player);
    await _tapTab(tester, '메시지');

    /// 녹음 메시지 2개만 재생 버튼이 있다.
    expect(find.byTooltip('다시 듣기'), findsNWidgets(2));
    await tester.tap(find.byTooltip('다시 듣기').first);
    await tester.pump();
    expect(player.played, [Uri.parse('http://server/device/audio/1')]);
    expect(find.byTooltip('멈추기'), findsOneWidget);

    await tester.tap(find.byTooltip('멈추기'));
    await tester.pump();
    expect(find.byTooltip('멈추기'), findsNothing);

    /// 재생에 실패하면 아래에 안내를 띄우고 재생 버튼으로 돌아온다.
    player.fail = true;
    await tester.tap(find.byTooltip('다시 듣기').first);
    await tester.pump();
    expect(find.text(MessagePlayback.failedMessage), findsOneWidget);
    expect(find.byTooltip('멈추기'), findsNothing);
    player.fail = false;

    /// 끝까지 들으면 저절로 재생 버튼으로 돌아온다.
    await tester.tap(find.byTooltip('다시 듣기').last);
    await tester.pump();
    player.finish();
    await tester.pump();
    expect(find.byTooltip('멈추기'), findsNothing);
  });
}
