import 'package:flutter/material.dart';

import '../../api/server_client.dart';
import '../parent_profile.dart';
import '../parent_shell.dart';
import '../parent_store.dart';
import '../voice_recorder.dart';

export '../parent_profile.dart';

/// 2-2~2-7 화면이 함께 쓰는 값. 2-1이 만들어 다음 화면에 넘긴다.
class OnboardingSession {
  const OnboardingSession({
    required this.store,
    required this.profile,
    required this.recorderFactory,
    this.serverClient,
  });

  final ParentStore store;
  final ParentProfile profile;
  final VoiceRecorder Function() recorderFactory;

  /// 시험할 때 쓰는 가짜 서버. 마친 뒤 부모 홈에도 넘긴다.
  final ServerClient? serverClient;

  /// 첫 설정을 마친 것으로 기록하고(이름·호칭 저장), 첫 설정 화면을 모두 닫은 뒤
  /// 부모 화면으로 간다. 2-7 완료, 2-2·2-3의 '건너뛰기', 2-3의 '홈으로'가 쓴다.
  Future<void> finish(
    BuildContext context, {
    int tab = ParentShell.homeTab,
  }) async {
    final navigator = Navigator.of(context);
    await OnboardingPrefs.complete(profile);
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => ParentShell(
          serverClient: serverClient,
          recorderFactory: recorderFactory,
          initialTab: tab,
          profile: profile,
        ),
      ),
      (_) => false,
    );
  }
}
