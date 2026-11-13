import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/board_client.dart';
import '../api/board_signal.dart';

/// 자녀 화면의 상태. 보드 신호대로 화면을 바꾼다.
class ChildSession extends ChangeNotifier {
  ChildSession({
    required Uri boardUrl,
    BoardConnector? connector,
    this.minThinking = const Duration(milliseconds: 800),
  }) {
    _board = BoardClient(
      url: boardUrl,
      connector: connector,
      onConnection: _onConnection,
      onSignal: _onSignal,
    );
    _board.connect();
  }

  late final BoardClient _board;

  /// 5-3 생각하는 중을 적어도 이만큼 보여 준다. 판단이 빨라도 받아쓴 내 말을 읽을 시간.
  final Duration minThinking;

  /// 생각하는 중을 붙잡아 두는 동안 온 신호. 시간이 지나면 온 순서대로 반영한다.
  Timer? _hold;
  final _waiting = <BoardSignal>[];

  BoardConnection connection = BoardConnection.connecting;

  /// 지금 화면을 정하는 신호. idle이면 홈이다.
  BoardSignal signal = const IdleSignal();

  /// 홈에 보여 줄 오류 안내. 다음 말하기를 시작하면 지운다.
  String? notice;

  void start() {
    notice = null;
    notifyListeners();
    _board.start();
  }

  void stop() => _board.stop();

  void _onConnection(BoardConnection value) {
    connection = value;
    if (value != BoardConnection.connected) {
      _release();
      signal = const IdleSignal();
    }
    notifyListeners();
  }

  void _onSignal(BoardSignal value) {
    if (_hold != null) {
      _waiting.add(value);
      return;
    }
    _apply(value);
    if (value is ThinkingSignal && minThinking > Duration.zero) {
      _hold = Timer(minThinking, () {
        _hold = null;
        final waiting = List.of(_waiting);
        _waiting.clear();
        for (final s in waiting) {
          _onSignal(s);
        }
      });
    }
  }

  void _release() {
    _hold?.cancel();
    _hold = null;
    _waiting.clear();
  }

  void _apply(BoardSignal value) {
    if (value is ErrorSignal) {
      notice = _noticeFor(value.code);
      signal = const IdleSignal();
    } else {
      signal = value;
    }
    notifyListeners();
  }

  /// 신호 규격서
  String _noticeFor(String code) =>
      code == 'D-003' ? '온기를 다시 켜 주세요' : '다시 말해 줄래?';

  @override
  void dispose() {
    _release();
    _board.dispose();
    super.dispose();
  }
}
