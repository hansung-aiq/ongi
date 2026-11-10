import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ongi_app/api/board_client.dart';
import 'package:ongi_app/api/board_signal.dart';
import 'package:ongi_app/child/child_screen.dart';
import 'package:ongi_app/common/common.dart';
import 'package:stream_channel/stream_channel.dart';

/// 앱과 가짜 보드 사이의 연결.
class FakeBoard {
  StreamChannelController<dynamic> controller = StreamChannelController();
  final sent = <String>[];

  Future<StreamChannel<dynamic>> connect(Uri _) async {
    controller.foreign.stream.listen(
      (message) => sent.add(jsonDecode(message as String)['type'] as String),
    );
    return controller.local;
  }

  void send(Map<String, Object?> signal) =>
      controller.foreign.sink.add(jsonEncode(signal));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<FakeBoard> _openChild(WidgetTester tester) async {
  final board = FakeBoard();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ChildScreen(connector: board.connect),
    ),
  );
  await _settle(tester);
  return board;
}

void main() {
  group('신호 해석', () {
    test('규격서의 예시를 읽는다', () {
      final playing = BoardSignal.tryParse(
        '{"type":"playing","situation_id":11,"message_id":3,"author":"dad",'
        '"kind":"text","text":"축하해"}',
      );
      expect(playing, isA<PlayingSignal>());
      expect((playing as PlayingSignal).situationId, 11);

      final empathy = BoardSignal.tryParse(
        '{"type":"empathy","text":"그랬구나","has_message":false,"author":null}',
      );
      expect((empathy as EmpathySignal).author, isNull);
    });

    test('모르는 신호와 잘못된 값은 무시한다', () {
      expect(BoardSignal.tryParse('{"type":"unknown"}'), isNull);
      expect(BoardSignal.tryParse('글자'), isNull);
      expect(BoardSignal.tryParse('{"type":"thinking"}'), isNull);
    });
  });

  group('연결', () {
    test('연결에 실패하면 다시 시도한다', () async {
      var attempts = 0;
      final states = <BoardConnection>[];
      final connected = Completer<void>();
      final controller = StreamChannelController<dynamic>();
      final client = BoardClient(
        url: Uri.parse('ws://test'),
        retryDelay: const Duration(milliseconds: 5),
        connector: (_) async {
          if (++attempts == 1) throw Exception('실패');
          return controller.local;
        },
        onConnection: (state) {
          states.add(state);
          if (state == BoardConnection.connected) connected.complete();
        },
        onSignal: (_) {},
      );

      await client.connect();
      await connected.future;
      client.dispose();

      expect(attempts, 2);
      expect(states, [BoardConnection.disconnected, BoardConnection.connected]);
    });
  });

  group('재연결 간격', () {
    test('연결 시도가 오래 걸려도 시작 시점부터 3초마다 시도한다', () {
      fakeAsync((async) {
        final attempts = <Duration>[];
        final client = BoardClient(
          url: Uri.parse('ws://test'),
          connector: (_) async {
            attempts.add(async.elapsed);
            await Future<void>.delayed(const Duration(seconds: 3));
            throw Exception('시간 초과');
          },
          onConnection: (_) {},
          onSignal: (_) {},
        );

        client.connect();
        async.elapse(const Duration(seconds: 10));
        client.dispose();

        expect(attempts, const [
          Duration.zero,
          Duration(seconds: 3),
          Duration(seconds: 6),
          Duration(seconds: 9),
        ]);
      });
    });

    test('바로 실패해도 3초를 기다리고, 끊기면 3초 뒤에 다시 시도한다', () {
      fakeAsync((async) {
        final attempts = <Duration>[];
        late StreamChannelController<dynamic> controller;
        final client = BoardClient(
          url: Uri.parse('ws://test'),
          connector: (_) async {
            attempts.add(async.elapsed);
            if (attempts.length == 1) throw Exception('거절');
            controller = StreamChannelController<dynamic>();
            return controller.local;
          },
          onConnection: (_) {},
          onSignal: (_) {},
        );

        client.connect();
        async.elapse(const Duration(seconds: 10));
        controller.foreign.sink.close();
        async.elapse(const Duration(seconds: 2));
        expect(attempts.length, 2);
        async.elapse(const Duration(seconds: 2));
        client.dispose();

        expect(attempts, const [
          Duration.zero,
          Duration(seconds: 3),
          Duration(seconds: 13),
        ]);
      });
    });
  });

  group('자녀 화면', () {
    testWidgets('처음엔 비연결로 보이고 연결이 잡히면 연결됨으로 바뀐다', (tester) async {
      final board = FakeBoard();
      final connected = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ChildScreen(
            connector: (url) async {
              await connected.future;
              return board.connect(url);
            },
          ),
        ),
      );
      await tester.pump();

      /// 연결을 시도하는 동안
      expect(find.text('온기 스피커 연결 중'), findsOneWidget);
      expect(find.text('온기 스피커 연결 안 됨'), findsNothing);
      expect(find.text('온기 스피커 연결됨'), findsNothing);
      final button = find.widgetWithText(TextButton, '온기에게 말하기');
      expect(tester.widget<TextButton>(button).onPressed, isNull);

      /// 연결이 잡힌 뒤
      connected.complete();
      await _settle(tester);
      expect(find.text('온기 스피커 연결됨'), findsOneWidget);
      expect(tester.widget<TextButton>(button).onPressed, isNotNull);
    });

    testWidgets('말하기 버튼은 start를 보낸다', (tester) async {
      final board = await _openChild(tester);

      expect(find.text('온기 스피커 연결됨'), findsOneWidget);
      await tester.tap(find.text('온기에게 말하기'));
      await tester.pump();

      expect(board.sent, ['start']);
    });

    testWidgets('신호대로 5-2부터 5-5를 거쳐 홈으로 돌아온다', (tester) async {
      final board = await _openChild(tester);

      board.send({'type': 'listening'});
      await _settle(tester);
      expect(find.text('듣고 있어'), findsOneWidget);

      board.send({'type': 'thinking', 'text': '오늘 친구랑 싸웠어'});
      await _settle(tester);
      expect(find.text(keepWords('“오늘 친구랑 싸웠어”')), findsOneWidget);

      board.send({
        'type': 'empathy',
        'text': '속상한 일이 있었나 보다',
        'has_message': true,
        'author': 'mom',
      });
      await _settle(tester);
      expect(find.text(keepWords('속상한 일이 있었나 보다')), findsOneWidget);
      expect(find.text('이어서 엄마의 메시지를 들려줄게'), findsOneWidget);

      board.send({
        'type': 'playing',
        'situation_id': 11,
        'message_id': 3,
        'author': 'dad',
        'kind': 'text',
        'text': '축하해',
      });
      await _settle(tester);
      expect(find.text('아빠의 메시지'), findsOneWidget);
      expect(find.text('자랑하고 싶은 날'), findsOneWidget);
      expect(find.text(keepWords('축하해')), findsOneWidget);

      board.send({'type': 'idle'});
      await _settle(tester);
      expect(find.text('온기에게 말하기'), findsOneWidget);
    });

    testWidgets('공감만 있으면 다음 메시지 안내를 숨긴다', (tester) async {
      final board = await _openChild(tester);

      board.send({
        'type': 'empathy',
        'text': '그랬구나',
        'has_message': false,
        'author': null,
      });
      await _settle(tester);

      expect(find.text(keepWords('그랬구나')), findsOneWidget);
      expect(find.textContaining('이어서'), findsNothing);
    });

    testWidgets('녹음 재생에 글이 없으면 글을 보여 주지 않는다', (tester) async {
      final board = await _openChild(tester);

      board.send({
        'type': 'playing',
        'situation_id': 4,
        'message_id': 1,
        'author': 'mom',
        'kind': 'voice',
        'text': null,
      });
      await _settle(tester);

      expect(find.text('엄마의 메시지'), findsOneWidget);
      expect(find.text('친구와 싸운 날'), findsOneWidget);
      expect(find.byType(Waveform), findsOneWidget);
    });

    testWidgets('녹음 재생에 받아쓴 글이 오면 글도 보여 준다', (tester) async {
      final board = await _openChild(tester);

      board.send({
        'type': 'playing',
        'situation_id': 4,
        'message_id': 1,
        'author': 'mom',
        'kind': 'voice',
        'text': '엄마는 언제나 네 편이야',
      });
      await _settle(tester);

      expect(find.byType(Waveform), findsOneWidget);
      expect(find.text(keepWords('엄마는 언제나 네 편이야')), findsOneWidget);
    });

    testWidgets('메시지 없음과 안전 응답은 받은 글을 그대로 보여 준다', (tester) async {
      final board = await _openChild(tester);

      board.send({'type': 'not_found', 'text': '그런 날도 있지'});
      await _settle(tester);
      expect(find.text(keepWords('그런 날도 있지')), findsOneWidget);
      expect(find.textContaining('꼭 맞는 엄마의 메시지'), findsOneWidget);

      board.send({'type': 'safety', 'text': '상담전화 1388에 전화해'});
      await _settle(tester);
      expect(find.text(keepWords('상담전화 1388에 전화해')), findsOneWidget);
      expect(find.textContaining('꼭 맞는'), findsNothing);
    });

    testWidgets('이야기 중에 뒤로 가기를 누르면 stop을 보내고 화면은 닫지 않는다', (tester) async {
      final board = await _openChild(tester);

      board.send({'type': 'listening'});
      await _settle(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(board.sent, ['stop']);
      expect(find.text('듣고 있어'), findsOneWidget);
    });

    testWidgets('재생 길이가 오면 진행 막대가 차고 글은 끝까지 보인다', (tester) async {
      final board = await _openChild(tester);

      board.send({
        'type': 'playing',
        'situation_id': 11,
        'message_id': 3,
        'author': 'dad',
        'kind': 'text',
        'text': '민준아, 축하해! 아빠는 네가 자랑스러워.',
        'seconds': 4.0,
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final bar = find.byType(LinearProgressIndicator);
      expect(bar, findsOneWidget);
      expect(tester.widget<LinearProgressIndicator>(bar).value, lessThan(0.5));

      await tester.pump(const Duration(seconds: 4));
      expect(tester.widget<LinearProgressIndicator>(bar).value, 1.0);
      expect(find.text(keepWords('민준아, 축하해! 아빠는 네가 자랑스러워.')), findsOneWidget);
    });

    testWidgets('재생이 끝나 홈으로 오면 온기기록에 담았다고 알려 준다', (tester) async {
      final board = await _openChild(tester);

      board.send({
        'type': 'playing',
        'situation_id': 11,
        'message_id': 3,
        'author': 'dad',
        'kind': 'text',
        'text': '축하해',
      });
      await _settle(tester);
      board.send({'type': 'idle'});
      await _settle(tester);

      expect(find.text('아빠 메시지를 온기기록에 담았어'), findsOneWidget);
    });

    testWidgets('말하기 끝내기와 그만 들을래, X는 stop을 보낸다', (tester) async {
      final board = await _openChild(tester);

      board.send({'type': 'listening'});
      await _settle(tester);
      await tester.tap(find.text('말하기 끝내기'));
      await tester.pump();

      board.send({'type': 'not_found', 'text': '그런 날도 있지'});
      await _settle(tester);
      await tester.tap(find.text('그만 들을래'));
      await tester.pump();
      await tester.tap(find.byTooltip('닫기'));
      await tester.pump();

      expect(board.sent, ['stop', 'stop', 'stop']);
    });

    testWidgets('오류 신호는 안내를 띄우고 다음 말하기에서 지운다', (tester) async {
      final board = await _openChild(tester);

      board.send({'type': 'listening'});
      await _settle(tester);
      board.send({'type': 'error', 'code': 'D-003'});
      await _settle(tester);
      board.send({'type': 'idle'});
      await _settle(tester);

      expect(find.text('온기를 다시 켜 주세요'), findsOneWidget);
      await tester.tap(find.text('온기에게 말하기'));
      await _settle(tester);
      expect(find.text('온기를 다시 켜 주세요'), findsNothing);
    });

    testWidgets('연결이 끊기면 6-1이 되고 말하기 버튼이 잠긴다', (tester) async {
      final board = await _openChild(tester);

      board.send({'type': 'listening'});
      await _settle(tester);
      await board.controller.foreign.sink.close();
      await _settle(tester);

      expect(find.text('온기 스피커 연결 안 됨'), findsOneWidget);
      expect(find.textContaining('스피커 전원과 와이파이'), findsOneWidget);
      await tester.tap(find.text('온기에게 말하기'), warnIfMissed: false);
      expect(board.sent, isEmpty);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('작은 화면에서도 긴 글이 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final board = await _openChild(tester);

      board.send({
        'type': 'playing',
        'situation_id': 11,
        'message_id': 3,
        'author': 'dad',
        'kind': 'text',
        'text': '가나다라마바사 ' * 25,
      });
      await _settle(tester);

      expect(tester.takeException(), isNull);
    });
  });
}
