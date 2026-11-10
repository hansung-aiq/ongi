import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/endpoints.dart';
import '../api/message_playback.dart';
import '../api/server_client.dart';
import '../api/server_models.dart';
import '../child/heard_messages.dart';
import '../common/common.dart';
import '../config.dart';
import '../settings/settings_screen.dart';
import '../start/login_screen.dart';
import '../start/role_select_screen.dart';
import 'message_list_screen.dart';
import 'message_write_screen.dart';
import 'parent_home_screen.dart';
import 'parent_profile.dart';
import 'parent_store.dart';
import 'save_done_screen.dart';
import 'voice_recorder.dart';

/// 부모 화면 전체. 하단 탭(홈·메시지·설정)과 서버 데이터를 가진다.
class ParentShell extends StatefulWidget {
  const ParentShell({
    super.key,
    this.serverClient,
    this.recorderFactory,
    this.initialTab = homeTab,
    this.profile = ParentProfile.fallback,
    this.audioPlayer,
    this.refreshEvery = const Duration(seconds: 10),
  });

  /// 홈·메시지 탭에 있는 동안 목록을 다시 불러오는 간격.
  /// 보드가 메시지를 받으면(30초마다 동기화) '전달됨'으로 바뀐 것이 보이게 한다.
  final Duration refreshEvery;

  static const homeTab = 0;
  static const messagesTab = 1;

  /// 처음 열 탭 (2-7에서 '메시지 더 남기기'를 누르면 메시지 탭)
  final int initialTab;

  /// 문장에 쓰는 자녀 이름과 호칭
  final ParentProfile profile;

  /// 시험할 때 가짜 서버로 바꿔 끼운다.
  final ServerClient? serverClient;

  /// 시험할 때 가짜 녹음기로 바꿔 끼운다.
  final VoiceRecorder Function()? recorderFactory;

  /// 시험할 때 가짜 재생기로 바꿔 끼운다.
  final UrlAudioPlayer? audioPlayer;

  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  late final ServerClient _client =
      widget.serverClient ?? ServerClient(baseUrl: Endpoints.serverUrl);
  late final ParentStore _store = ParentStore(
    client: _client,
    familyId: AppConfig.familyId,
    profile: widget.profile,
  )..load();

  /// 자녀가 들은 메시지 (부모 홈에 보인다)
  late final HeardMessages _heard = HeardMessages(
    client: _client,
    familyId: AppConfig.familyId,
  )..load();

  late final MessagePlayback _playback = MessagePlayback(
    player: widget.audioPlayer,
  )..addListener(_onPlayback);
  int _shownFailures = 0;

  late int _tab = widget.initialTab;

  Timer? _refresher;

  @override
  void initState() {
    super.initState();
    _refresher = Timer.periodic(widget.refreshEvery, (_) {
      if (_tab != 2) _store.refresh();
      if (_tab == 0) _heard.load();
    });
  }

  /// 메시지 탭에서 고른 분류. null이면 전체다.
  String? _category;

  @override
  void dispose() {
    _refresher?.cancel();
    _heard.dispose();
    _playback.dispose();
    _store.dispose();
    if (widget.serverClient == null) _client.close();
    super.dispose();
  }

  void _openCategory(String? category) => setState(() {
    _tab = 1;
    _category = category;
  });

  Future<void> _write(Situation situation) async {
    final action = await Navigator.of(context).push<SaveDoneAction>(
      MaterialPageRoute(
        builder: (_) => MessageWriteScreen(
          store: _store,
          situation: situation,
          recorderFactory: widget.recorderFactory ?? DeviceVoiceRecorder.new,
        ),
      ),
    );
    if (!mounted || action == null) return;
    setState(() {
      if (action == SaveDoneAction.done) {
        _tab = 0;
      } else {
        _tab = 1;
        _category = situation.category;
      }
    });
  }

  /// 6-2 수정하기 → 3-4를 수정 모드로 연다.
  Future<void> _edit(ParentMessage message, Situation situation) async {
    final action = await Navigator.of(context).push<SaveDoneAction>(
      MaterialPageRoute(
        builder: (_) => MessageWriteScreen(
          store: _store,
          situation: situation,
          editing: message,
          recorderFactory: widget.recorderFactory ?? DeviceVoiceRecorder.new,
        ),
      ),
    );
    if (mounted && action == SaveDoneAction.edited) _notify('메시지를 고쳤어요');
  }

  /// 6-2 삭제하기
  Future<void> _delete(ParentMessage message) async {
    try {
      await _store.delete(message.id);
    } on ServerException catch (e) {
      if (mounted) _notify(e.message, error: true);
      return;
    }
    if (mounted) _notify('메시지를 지웠어요');
  }

  /// 3-6 메시지 모두 지우기
  Future<void> _deleteAll() async {
    if (_store.messages.isEmpty) {
      _notify('지울 메시지가 없어요');
      return;
    }
    await _playback.stop();
    try {
      final count = await _store.deleteAll();
      if (mounted) _notify('메시지 $count개를 지웠어요');
    } on ServerException catch (e) {
      if (mounted) _notify(e.message, error: true);
    }
  }

  /// 3-6 이 기기 처음 상태로: 기기에 저장한 것을 지우고 시작 화면으로 간다.
  Future<void> _resetDevice() async {
    await OnboardingPrefs.reset();
    await _restart();
  }

  /// 시작 화면부터 다시 (연결 주소를 바꿨을 때도 쓴다)
  Future<void> _restart() async {
    final navigator = Navigator.of(context);
    await _playback.stop();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(serverClient: widget.serverClient),
      ),
      (_) => false,
    );
  }

  void _notify(String text, {bool error = false}) =>
      showOngiSnackBar(context, text, error: error);

  /// 녹음을 재생하지 못하면 아래에 안내를 띄운다. 같은 실패는 한 번만 알린다.
  void _onPlayback() {
    if (_playback.failures == _shownFailures || !mounted) return;
    _shownFailures = _playback.failures;
    _notify(MessagePlayback.failedMessage, error: true);
  }

  void _changeTab(int tab) {
    if (tab != 1) _playback.stop();
    if (tab != 2) _store.refresh();
    if (tab == 0) _heard.load();
    setState(() {
      _tab = tab;
      if (tab == 1) _category = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomTabBar(
        items: const [
          BottomTabItem(icon: LucideIcons.house, label: '홈'),
          BottomTabItem(icon: LucideIcons.messageCircle, label: '메시지'),
          BottomTabItem(icon: LucideIcons.settings, label: '설정'),
        ],
        currentIndex: _tab,
        onTap: _changeTab,
      ),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) => _body(),
        ),
      ),
    );
  }

  Widget _body() {
    if (_tab == 2) {
      return SettingsScreen(
        profile: _store.profile,
        isParent: true,
        onProfileChanged: (p) => _store.profile = p,
        onDeleteAllMessages: _deleteAll,
        onResetDevice: _resetDevice,
        onEndpointsChanged: _restart,
        onChangeMode: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RoleSelectScreen(serverClient: widget.serverClient),
          ),
        ),
      );
    }
    if (!_store.loaded) {
      if (_store.loadError != null) {
        return _LoadError(message: _store.loadError!, onRetry: _store.load);
      }
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    return switch (_tab) {
      0 => RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () => Future.wait([_store.refresh(), _heard.load()]),
        child: ParentHomeScreen(
          store: _store,
          onCategory: _openCategory,
          heard: _heard,
        ),
      ),
      _ => MessageListScreen(
        store: _store,
        category: _category,
        onCategoryChanged: (c) => setState(() => _category = c),
        onWrite: _write,
        onEdit: _edit,
        onDelete: _delete,
        playback: _playback,
      ),
    };
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ErrorNotice(message: message),
          const SizedBox(height: AppSpacing.s16),
          OngiButton.secondary(label: '다시 시도', onPressed: onRetry),
        ],
      ),
    );
  }
}
