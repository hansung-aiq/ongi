import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ongi_app/api/server_client.dart';
import 'package:ongi_app/child/child_screen.dart';
import 'package:ongi_app/child/heard_message_sheet.dart';
import 'package:ongi_app/child/heard_messages.dart';
import 'package:ongi_app/common/common.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_channel/stream_channel.dart';

import 'support/fake_audio.dart';

/// 메시지 1(녹음, 친구와 싸운 날)과 3(글, 자랑하고 싶은 날)을 가진 가짜 서버.
ServerClient _server() {
  final now = DateTime.now();
  String at(Duration ago) => now.subtract(ago).toIso8601String();
  Map<String, Object?> message(
    int id,
    int situation,
    String kind,
    String? text,
  ) => {
    'id': id,
    'family_id': 1,
    'situation_id': situation,
    'author': 'mom',
    'kind': kind,
    'text': text,
    'audio_path': kind == 'voice' ? '$id.m4a' : null,
    'delivered': true,
    'created_at': '2026-11-01T09:00:00',
    'updated_at': '2026-11-01T09:00:00',
    'deleted': false,
  };
  Map<String, Object?> log(
    int id,
    int messageId,
    int situation,
    Duration ago,
  ) => {
    'id': id,
    'message_id': messageId,
    'situation_id': situation,
    'author': 'mom',
    'played_at': at(ago),
  };
  final body = <String, Object?>{
    '/messages': {
      'items': [
        message(1, 4, 'voice', null),
        message(3, 11, 'text', '민준아, 상 받은 거 정말 축하해!'),
      ],
    },
    '/play-logs': {
      'items': [
        log(4, 1, 4, const Duration(minutes: 1)),
        log(3, 9, 7, const Duration(minutes: 2)),
        log(2, 3, 11, const Duration(minutes: 3)),
        log(1, 1, 4, const Duration(minutes: 4)),
      ],
    },
  };
  return ServerClient(
    baseUrl: 'http://server',
    client: MockClient(
      (request) async => http.Response.bytes(
        utf8.encode(jsonEncode(body[request.url.path] ?? {'items': []})),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    ),
  );
}

/// 연결만 되고 신호는 보내지 않는 가짜 보드
Future<StreamChannel<dynamic>> _board(Uri _) async =>
    StreamChannelController<dynamic>().local;

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _openChild(WidgetTester tester, {FakeUrlPlayer? player}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ChildScreen(
        connector: _board,
        serverClient: _server(),
        audioPlayer: player ?? FakeUrlPlayer(),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(BottomTabBar), matching: find.text(label)),
  );
  await _settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('들은 날은 오늘·어제·날짜와 오전·오후로 쓴다', () {
    final now = DateTime(2026, 11, 9, 18);
    expect(
      heardAtLabel(DateTime(2026, 11, 9, 16, 32), now),
      '들은 날 · 오늘 · 오후 4:32',
    );
    expect(
      heardAtLabel(DateTime(2026, 11, 8, 8, 10), now),
      '들은 날 · 어제 · 오전 8:10',
    );
    expect(
      heardAtLabel(DateTime(2026, 11, 7, 0, 5), now),
      '들은 날 · 11월 7일 · 오전 12:05',
    );
    expect(
      heardAtLabel(DateTime(2026, 11, 9, 12), now),
      '들은 날 · 오늘 · 오후 12:00',
    );
  });

  testWidgets('3-7 온기기록: 같은 메시지는 한 번만, 지운 메시지는 빼고 최근 순으로 보인다', (tester) async {
    final player = FakeUrlPlayer();
    await _openChild(tester, player: player);
    await _tapTab(tester, '온기기록');

    expect(find.text('이미 들었던 엄마의 메시지야.\n다시 듣고 싶을 때 언제든 눌러봐.'), findsOneWidget);
    expect(find.text('들은 메시지 2'), findsOneWidget);
    expect(find.text('친구와 싸운 날'), findsOneWidget);
    expect(find.text('자랑하고 싶은 날'), findsOneWidget);
    expect(find.text('울고 싶은 날'), findsNothing);
    expect(find.textContaining('들은 날 · 오늘'), findsNWidgets(2));
    expect(find.text('민준아, 상 받은 거 정말 축하해!'), findsOneWidget);
    expect(tester.widget<Text>(find.text('민준아, 상 받은 거 정말 축하해!')).maxLines, 2);

    /// 녹음 메시지만 다시 들을 수 있다.
    expect(find.byTooltip('다시 듣기'), findsOneWidget);
    await tester.tap(find.byTooltip('다시 듣기'));
    await tester.pump();
    expect(player.played, [Uri.parse('http://server/device/audio/1')]);
    expect(find.byTooltip('멈추기'), findsOneWidget);

    /// 다른 탭으로 가면 재생을 멈춘다.
    await _tapTab(tester, '홈');
    expect(player.stops, greaterThan(0));
    expect(find.byTooltip('멈추기'), findsNothing);
  });

  testWidgets('5-1 홈의 최근에 들은 메시지도 재생 기록을 쓴다', (tester) async {
    await _openChild(tester);
    expect(find.text('친구와 싸운 날'), findsOneWidget);
    expect(find.text('자랑하고 싶은 날'), findsOneWidget);

    /// 홈에서는 글을 2줄까지만 보이고 '…'로 줄인다.
    final text = tester.widget<Text>(find.text('민준아, 상 받은 거 정말 축하해!'));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('들은 메시지 카드를 누르면 글을 다시 보고 녹음을 다시 들을 수 있다', (tester) async {
    final player = FakeUrlPlayer();
    await _openChild(tester, player: player);
    final fullText = find.text('민준아, 상 받은 거 정말 축하해!');
    Finder button(String label) => find.widgetWithText(OngiButton, label);

    /// 글 메시지: 줄이지 않은 글이 보이고, 다시 듣기 버튼은 없다.
    await tester.ensureVisible(find.text('자랑하고 싶은 날'));
    await _settle(tester);
    await tester.tap(find.text('자랑하고 싶은 날'));
    await _settle(tester);
    expect(fullText, findsNWidgets(2));
    expect(tester.widget<Text>(fullText.last).maxLines, isNull);
    expect(button('다시 듣기'), findsNothing);
    await tester.tap(button('닫기'));
    await _settle(tester);
    expect(fullText, findsOneWidget);

    /// 녹음 메시지: 창에서 다시 듣고, 닫으면 멈춘다.
    await tester.ensureVisible(find.text('친구와 싸운 날'));
    await _settle(tester);
    await tester.tap(find.text('친구와 싸운 날'));
    await _settle(tester);
    await tester.tap(button('다시 듣기'));
    await tester.pump();
    expect(player.played, [Uri.parse('http://server/device/audio/1')]);
    expect(button('멈추기'), findsOneWidget);
    await tester.tap(button('닫기'));
    await _settle(tester);
    expect(button('멈추기'), findsNothing);
    expect(player.stops, greaterThan(0));
  });

  testWidgets('녹음을 재생하지 못하면 카드에서는 아래 안내, 창에서는 창 안에 알린다', (tester) async {
    final player = FakeUrlPlayer()..fail = true;
    await _openChild(tester, player: player);
    await _tapTab(tester, '온기기록');

    /// 카드의 재생 버튼
    await tester.tap(find.byTooltip('다시 듣기'));
    await tester.pump();
    expect(find.widgetWithText(SnackBar, childPlaybackFailed), findsOneWidget);
    expect(find.byTooltip('멈추기'), findsNothing);
    ScaffoldMessenger.of(tester.element(find.byType(BottomTabBar)))
        .removeCurrentSnackBar();
    await _settle(tester);

    /// 들은 메시지 창의 다시 듣기 버튼
    await tester.tap(find.text('친구와 싸운 날'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(OngiButton, '다시 듣기'));
    await tester.pump();
    expect(
      find.widgetWithText(ErrorNotice, childPlaybackFailed),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('자녀 앱 3-6 설정은 스피커 연결 상태와 자녀 모드를 보인다', (tester) async {
    await _openChild(tester);
    await _tapTab(tester, '설정');

    expect(find.text('나 · 이름과 사진 바꾸기'), findsOneWidget);
    expect(find.text('부모 · 호칭과 사진 바꾸기'), findsOneWidget);
    expect(find.text('온기 스피커'), findsOneWidget);
    expect(find.text('연결됨'), findsOneWidget);
    expect(find.text('자녀'), findsOneWidget);

    /// 이름을 바꾸면 홈 인사도 바뀐다.
    await tester.tap(find.text('민준'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), '서아');
    await tester.tap(find.text('저장하기'));
    await _settle(tester);
    await _tapTab(tester, '홈');
    expect(find.text('안녕, 서아야!'), findsOneWidget);
  });

  testWidgets('작은 화면에서도 온기기록과 설정이 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _openChild(tester);
    for (final tab in ['온기기록', '설정', '홈']) {
      await _tapTab(tester, tab);
      expect(tester.takeException(), isNull);
    }
  });
}
