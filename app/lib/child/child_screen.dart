import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/board_client.dart';
import '../api/board_signal.dart';
import '../api/message_playback.dart';
import '../api/server_client.dart';
import '../common/common.dart';
import '../config.dart';
import '../parent/parent_profile.dart';
import '../settings/settings_screen.dart';
import '../start/role_select_screen.dart';
import 'child_home_screen.dart';
import 'child_listening_screen.dart';
import 'child_response_screens.dart';
import 'child_session.dart';
import 'heard_message_sheet.dart';
import 'heard_messages.dart';
import 'ongi_record_screen.dart';

/// 자녀 화면 전체. 이 화면에 있는 동안 보드 연결을 유지한다.
/// 보드가 쉬는 동안(idle)은 하단 탭(홈·온기기록·설정)을 보인다.
class ChildScreen extends StatefulWidget {
  const ChildScreen({
    super.key,
    this.connector,
    this.serverClient,
    this.audioPlayer,
    this.profile = ParentProfile.fallback,
  });

  /// 시험할 때 가짜 연결로 바꿔 끼운다.
  final BoardConnector? connector;

  /// 시험할 때 가짜 서버로 바꿔 끼운다.
  final ServerClient? serverClient;

  /// 시험할 때 가짜 재생기로 바꿔 끼운다.
  final UrlAudioPlayer? audioPlayer;

  /// 부모가 저장한 이름·호칭·사진
  final ParentProfile profile;

  @override
  State<ChildScreen> createState() => _ChildScreenState();
}

class _ChildScreenState extends State<ChildScreen> {
  late final ChildSession _session = ChildSession(
    boardUrl: Uri.parse(AppConfig.boardWsUrl),
    connector: widget.connector,
  )..addListener(_onSessionChanged);
  late final ServerClient _client =
      widget.serverClient ?? ServerClient(baseUrl: AppConfig.serverUrl);
  late final HeardMessages _heard = HeardMessages(
    client: _client,
    familyId: AppConfig.familyId,
  )..load();
  late final MessagePlayback _playback = MessagePlayback(
    player: widget.audioPlayer,
  )..addListener(_onPlayback);
  int _shownFailures = 0;

  late ParentProfile _profile = widget.profile;
  int _tab = 0;
  bool _wasIdle = true;

  @override
  void dispose() {
    _session.dispose();
    _playback.dispose();
    _heard.dispose();
    if (widget.serverClient == null) _client.close();
    super.dispose();
  }

  bool _isIdle(BoardSignal s) => s is IdleSignal || s is ErrorSignal;

  /// 온기와 이야기를 시작하면 다시 듣기를 멈추고,
  /// 이야기가 끝나 홈으로 돌아오면 들은 메시지를 새로 불러온다.
  void _onSessionChanged() {
    final idle = _isIdle(_session.signal);
    if (!idle && _wasIdle) _playback.stop();
    if (idle && !_wasIdle) _heard.load();
    _wasIdle = idle;
  }

  /// 녹음을 재생하지 못하면 아래에 안내를 띄운다. 같은 실패는 한 번만 알린다.
  /// 들은 메시지 창이 열려 있으면 창 안에서 알려 주므로 여기서는 띄우지 않는다.
  void _onPlayback() {
    if (_playback.failures == _shownFailures || !mounted) return;
    _shownFailures = _playback.failures;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    showOngiSnackBar(context, childPlaybackFailed, error: true);
  }

  void _changeTab(int tab) {
    _playback.stop();
    if (tab != 2) _heard.load();
    setState(() => _tab = tab);
  }

  Widget _screenFor(BoardSignal signal) => switch (signal) {
    IdleSignal() || ErrorSignal() => _tabs(),
    ListeningSignal() => ChildListeningScreen(
      profile: _profile,
      onStop: _session.stop,
    ),
    ThinkingSignal(:final text) => ChildThinkingScreen(
      heardText: text,
      onStop: _session.stop,
    ),
    EmpathySignal(:final author) => ChildEmpathyScreen(
      signal: signal,
      parentPhoto: _profile.photoFor(author),
      onStop: _session.stop,
    ),
    PlayingSignal(:final author) => ChildPlayingScreen(
      signal: signal,
      parentPhoto: _profile.photoFor(author),
      onStop: _session.stop,
    ),
    NotFoundSignal(:final text) => ChildNoMessageScreen(
      text: text,
      detail: '지금은 꼭 맞는 ${_profile.title}의 메시지가 없어.\n대신 온기가 곁에 있을게.',
      onStop: _session.stop,
    ),
    SafetySignal(:final text) => ChildNoMessageScreen(
      text: text,
      onStop: _session.stop,
    ),
  };

  Widget _tabs() {
    return Scaffold(
      bottomNavigationBar: BottomTabBar(
        items: const [
          BottomTabItem(icon: LucideIcons.house, label: '홈'),
          BottomTabItem(icon: LucideIcons.audioLines, label: '온기기록'),
          BottomTabItem(icon: LucideIcons.settings, label: '설정'),
        ],
        currentIndex: _tab,
        onTap: _changeTab,
      ),
      body: SafeArea(
        bottom: false,
        child: switch (_tab) {
          0 => ChildHomeScreen(
            profile: _profile,
            connection: _session.connection,
            notice: _session.notice,
            onStart: _session.start,
            heard: _heard,
            playback: _playback,
          ),
          1 => OngiRecordScreen(
            profile: _profile,
            heard: _heard,
            playback: _playback,
          ),
          _ => SettingsScreen(
            profile: _profile,
            isParent: false,
            speaker: _session.connection,
            onProfileChanged: (p) => setState(() => _profile = p),
            onChangeMode: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    RoleSelectScreen(serverClient: widget.serverClient),
              ),
            ),
          ),
        },
      ),
    );
  }

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
