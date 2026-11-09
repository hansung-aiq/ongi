import 'package:flutter/material.dart';

import '../../api/board_client.dart';
import '../../api/server_client.dart';
import '../../common/common.dart';
import '../../config.dart';
import 'child_onboarding.dart';
import 'child_speak_guide_screen.dart';

/// 4-1 자녀 환영. 자녀 첫 안내의 시작이다.
/// 부모가 남긴 메시지 수를 서버에서 받아 칩으로 보인다.
class ChildWelcomeScreen extends StatefulWidget {
  const ChildWelcomeScreen({super.key, this.serverClient, this.connector});

  /// 시험할 때 가짜 서버로 바꿔 끼운다.
  final ServerClient? serverClient;

  /// 시험할 때 가짜 보드로 바꿔 끼운다.
  final BoardConnector? connector;

  @override
  State<ChildWelcomeScreen> createState() => _ChildWelcomeScreenState();
}

class _ChildWelcomeScreenState extends State<ChildWelcomeScreen> {
  late final ServerClient _client =
      widget.serverClient ?? ServerClient(baseUrl: AppConfig.serverUrl);

  ParentProfile _profile = ParentProfile.fallback;

  /// 부모가 남긴 메시지 수. 받기 전이거나 받지 못하면 null이다.
  int? _messageCount;

  ChildOnboardingSession get _session => ChildOnboardingSession(
    profile: _profile,
    connector: widget.connector,
    serverClient: widget.serverClient,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await OnboardingPrefs.loadProfile();
    if (mounted) setState(() => _profile = profile);
    try {
      final messages = await _client.messages(AppConfig.familyId);
      if (mounted) setState(() => _messageCount = messages.length);
    } on ServerException {
      // 서버에 닿지 않으면 칩만 숨긴다.
    }
  }

  @override
  void dispose() {
    if (widget.serverClient == null) _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = _messageCount;
    return OnboardingScaffold(
      step: 0,
      onSkip: () => _session.finish(context),
      actions: [
        OngiButton(
          label: '좋아, 시작해볼래!',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ChildSpeakGuideScreen(session: _session),
            ),
          ),
        ),
      ],
      children: [
        const SizedBox(height: 90),
        const Center(child: ProfileAvatar(size: 128)),
        const SizedBox(height: AppSpacing.section),
        PageHeading(
          title: '안녕, ${_profile.called}!',
          description:
              '난 네 이야기를 들어주는 온기야.\n'
              '기쁜 날에도, 조금 힘든 날에도\n'
              '${_profile.title}의 마음을 들려줄게.',
          centered: true,
          gap: AppSpacing.section,
        ),
        if (count != null && count > 0) ...[
          const SizedBox(height: AppSpacing.section),
          Center(
            child: OngiChip(label: '${_profile.title}가 메시지 $count개를 남겨뒀어'),
          ),
        ],
      ],
    );
  }
}
