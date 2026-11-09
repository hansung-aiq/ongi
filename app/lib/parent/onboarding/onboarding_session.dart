import 'package:flutter/material.dart';

import '../../api/server_client.dart';
import '../../common/common.dart';
import '../parent_profile.dart';
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
}

/// 첫 설정 화면의 공통 틀.
/// 위에 단계 점(또는 [header]), 가운데 내용, 아래 버튼 묶음이 온다.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    this.step,
    this.header,
    required this.children,
    required this.actions,
  });

  /// 단계 점에서 지금 단계 (0~3). 없으면 점을 숨긴다.
  final int? step;

  /// 단계 점 대신 놓을 위쪽 줄 (2-1의 상단 내비게이션)
  final Widget? header;
  final List<Widget> children;
  final List<Widget> actions;

  static const stepCount = 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.s8,
                  AppSpacing.screenHorizontal,
                  AppSpacing.s24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ?header,
                    if (step != null)
                      SizedBox(
                        height: AppSizes.navBarHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: StepDots(count: stepCount, current: step!),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.section),
                    ...children,
                  ],
                ),
              ),
            ),
            BottomActions(children: actions),
          ],
        ),
      ),
    );
  }
}
