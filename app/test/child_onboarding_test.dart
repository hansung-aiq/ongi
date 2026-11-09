import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ongi_app/api/server_client.dart';
import 'package:ongi_app/child/onboarding/child_onboarding.dart';
import 'package:ongi_app/child/onboarding/child_welcome_screen.dart';
import 'package:ongi_app/common/common.dart';
import 'package:ongi_app/start/role_select_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_channel/stream_channel.dart';

/// 메시지 [count]개를 가진 가짜 서버. [offline]이면 연결이 안 된다.
ServerClient _server({int count = 3, bool offline = false}) {
  Map<String, Object?> message(int id) => {
    'id': id,
    'family_id': 1,
    'situation_id': id,
    'author': 'mom',
    'kind': 'text',
    'text': '메시지 $id',
    'audio_path': null,
    'delivered': false,
    'created_at': '2026-11-01T09:00:00',
    'updated_at': '2026-11-01T09:00:00',
    'deleted': false,
  };
  return ServerClient(
    baseUrl: 'http://server',
    client: MockClient((request) async {
      if (offline) throw http.ClientException('연결 안 됨');
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'items': [for (var i = 1; i <= count; i++) message(i)],
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
}

/// 연결만 되고 신호는 보내지 않는 가짜 보드
Future<StreamChannel<dynamic>> _board(Uri _) async =>
    StreamChannelController<dynamic>().local;

/// 파형이 계속 움직이는 화면이 있어서 pumpAndSettle 대신 시간을 넘긴다.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pump();
  await tester.tap(find.text(text));
  await _settle(tester);
}

Future<void> _openWelcome(WidgetTester tester, ServerClient server) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ChildWelcomeScreen(serverClient: server, connector: _board),
    ),
  );
  await _settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('부르는 이름은 받침에 따라 아·야를 붙인다', () {
    String called(String name) =>
        ParentProfile(childName: name, author: 'mom').called;
    expect(called('민준'), '민준아');
    expect(called('서아'), '서아야');
  });

  testWidgets('4-1부터 4-4까지 넘기고 온기 시작하기를 누르면 자녀 홈으로 간다', (tester) async {
    await _openWelcome(tester, _server());

    expect(find.text('안녕, 민준아!'), findsOneWidget);
    expect(find.text('엄마가 메시지 3개를 남겨뒀어'), findsOneWidget);
    await _tap(tester, '좋아, 시작해볼래!');

    expect(find.text('힘든 날엔\n온기한테 말해봐'), findsOneWidget);
    expect(find.text('민준이를 위해 남긴 메시지'), findsOneWidget);
    await _tap(tester, '다음');

    expect(find.text('들은 말은\n언제든 다시 들을 수 있어'), findsOneWidget);
    expect(find.text('재생 버튼을 눌러봐!'), findsOneWidget);
    await _tap(tester, '다음');

    expect(find.text('이제 준비 끝!'), findsOneWidget);
    await _tap(tester, '온기 시작하기');

    expect(find.text('오늘 마음은\n어땠어?'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('child_onboarding_done'), isTrue);
  });

  testWidgets('건너뛰기를 누르면 바로 자녀 홈으로 가고 다시 보이지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RoleSelectScreen(serverClient: _server()),
      ),
    );
    await tester.tap(find.text('자녀'));
    await tester.pump();
    await _tap(tester, '시작하기');
    expect(find.text('안녕, 민준아!'), findsOneWidget);

    await _tap(tester, '좋아, 시작해볼래!');
    await _tap(tester, '건너뛰기');
    expect(find.text('오늘 마음은\n어땠어?'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('child_onboarding_done'), isTrue);

    /// 한 번 마치면 역할 선택에서 바로 자녀 홈으로 간다.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RoleSelectScreen(serverClient: _server()),
      ),
    );
    await tester.tap(find.text('자녀'));
    await tester.pump();
    await _tap(tester, '시작하기');
    expect(find.text('좋아, 시작해볼래!'), findsNothing);
    expect(find.text('오늘 마음은\n어땠어?'), findsOneWidget);

    /// 진짜 보드에 연결하려던 재시도 타이머를 정리한다.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('부모가 저장한 이름과 호칭을 쓴다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'child_name': '서아',
      'parent_author': 'dad',
    });
    await _openWelcome(tester, _server(count: 5));

    expect(find.text('안녕, 서아야!'), findsOneWidget);
    expect(find.text('아빠가 메시지 5개를 남겨뒀어'), findsOneWidget);
    expect(find.textContaining('아빠의 마음을 들려줄게.'), findsOneWidget);

    /// 자녀 홈(5-1)도 같은 이름과 호칭을 쓴다.
    await _tap(tester, '건너뛰기');
    expect(find.text('안녕, 서아야!'), findsOneWidget);
    expect(find.text('서아야, 마음이 많이 속상했지?\n아빠는 언제나 네 편이야.'), findsNWidgets(2));
  });

  testWidgets('서버에 닿지 않거나 메시지가 없으면 메시지 수 칩을 숨긴다', (tester) async {
    await _openWelcome(tester, _server(offline: true));
    expect(find.textContaining('메시지'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await _openWelcome(tester, _server(count: 0));
    expect(find.textContaining('메시지'), findsNothing);
  });

  testWidgets('작은 화면에서도 자녀 첫 안내가 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _openWelcome(tester, _server());
    expect(tester.takeException(), isNull);
    for (final button in ['좋아, 시작해볼래!', '다음', '다음']) {
      await _tap(tester, button);
      expect(tester.takeException(), isNull);
    }
    expect(find.text('이제 준비 끝!'), findsOneWidget);
  });
}
