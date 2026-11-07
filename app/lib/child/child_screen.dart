import 'package:flutter/material.dart';

import '../api/board_client.dart';
import '../api/board_signal.dart';
import '../config.dart';
import 'child_home_screen.dart';
import 'child_listening_screen.dart';
import 'child_response_screens.dart';
import 'child_session.dart';

/// 자녀 화면 전체. 이 화면에 있는 동안 보드 연결을 유지한다.
class ChildScreen extends StatefulWidget {
  const ChildScreen({super.key, this.connector});

  /// 시험할 때 가짜 연결로 바꿔 끼운다.
  final BoardConnector? connector;

  @override
  State<ChildScreen> createState() => _ChildScreenState();
}

class _ChildScreenState extends State<ChildScreen> {
  late final ChildSession _session = ChildSession(
    boardUrl: Uri.parse(AppConfig.boardWsUrl),
    connector: widget.connector,
  );

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  Widget _screenFor(BoardSignal signal) => switch (signal) {
    IdleSignal() || ErrorSignal() => ChildHomeScreen(
      connection: _session.connection,
      notice: _session.notice,
      onStart: _session.start,
    ),
    ListeningSignal() => ChildListeningScreen(onStop: _session.stop),
    ThinkingSignal(:final text) => ChildThinkingScreen(
      heardText: text,
      onStop: _session.stop,
    ),
    EmpathySignal() => ChildEmpathyScreen(
      signal: signal,
      onStop: _session.stop,
    ),
    PlayingSignal() => ChildPlayingScreen(
      signal: signal,
      onStop: _session.stop,
    ),
    NotFoundSignal(:final text) => ChildNoMessageScreen(
      text: text,
      detail: '지금은 꼭 맞는 ${AppConfig.momTitle}의 메시지가 없어.\n대신 온기가 곁에 있을게.',
      onStop: _session.stop,
    ),
    SafetySignal(:final text) => ChildNoMessageScreen(
      text: text,
      onStop: _session.stop,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey(_session.signal.runtimeType),
          child: _screenFor(_session.signal),
        ),
      ),
    );
  }
}
