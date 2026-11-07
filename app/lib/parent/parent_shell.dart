import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/server_client.dart';
import '../api/server_models.dart';
import '../common/common.dart';
import '../config.dart';
import 'message_list_screen.dart';
import 'message_write_screen.dart';
import 'parent_home_screen.dart';
import 'parent_store.dart';
import 'save_done_screen.dart';
import 'voice_recorder.dart';

/// 부모 화면 전체. 하단 탭(홈·메시지·설정)과 서버 데이터를 가진다.
class ParentShell extends StatefulWidget {
  const ParentShell({super.key, this.serverClient, this.recorderFactory});

  /// 시험할 때 가짜 서버로 바꿔 끼운다.
  final ServerClient? serverClient;

  /// 시험할 때 가짜 녹음기로 바꿔 끼운다.
  final VoiceRecorder Function()? recorderFactory;

  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  late final ServerClient _client =
      widget.serverClient ?? ServerClient(baseUrl: AppConfig.serverUrl);
  late final ParentStore _store = ParentStore(
    client: _client,
    familyId: AppConfig.familyId,
  )..load();

  int _tab = 0;

  /// 메시지 탭에서 고른 분류. null이면 전체다.
  String? _category;

  @override
  void dispose() {
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
        onTap: (i) => setState(() {
          _tab = i;
          if (i == 1) _category = null;
        }),
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
    if (_tab == 2) return const _SettingsPlaceholder();
    if (!_store.loaded) {
      if (_store.loadError != null) {
        return _LoadError(message: _store.loadError!, onRetry: _store.load);
      }
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    return switch (_tab) {
      0 => ParentHomeScreen(store: _store, onCategory: _openCategory),
      _ => MessageListScreen(
        store: _store,
        category: _category,
        onCategoryChanged: (c) => setState(() => _category = c),
        onWrite: _write,
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

/// 3-6 설정은 아직 만들지 않았다.
class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.s8,
        AppSpacing.screenHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TopNavBar(title: '설정'),
          const SizedBox(height: AppSpacing.s24),
          Text(
            '설정은 준비 중이에요.',
            style: AppTextStyles.body14.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
