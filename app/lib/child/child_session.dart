import 'package:flutter/foundation.dart';

import '../api/board_client.dart';
import '../api/board_signal.dart';

/// 자녀 화면의 상태. 보드 신호대로 화면을 바꾼다.
class ChildSession extends ChangeNotifier {
  ChildSession({required Uri boardUrl, BoardConnector? connector}) {
    _board = BoardClient(
      url: boardUrl,
      connector: connector,
      onConnection: _onConnection,
      onSignal: _onSignal,
    );
    _board.connect();
  }

  late final BoardClient _board;

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
    if (value != BoardConnection.connected) signal = const IdleSignal();
    notifyListeners();
  }

  void _onSignal(BoardSignal value) {
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
    _board.dispose();
    super.dispose();
  }
}
