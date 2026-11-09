import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/board_client.dart';
import '../../parent/parent_profile.dart';
import '../child_screen.dart';

export '../../parent/parent_profile.dart';

/// 자녀 첫 안내(4-1~4-4)를 마쳤는지 기기에 저장한다.
class ChildOnboardingPrefs {
  ChildOnboardingPrefs._();

  static const _doneKey = 'child_onboarding_done';

  static Future<bool> isDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_doneKey) ?? false;
  }

  static Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doneKey, true);
  }
}

/// 4-1~4-4가 함께 쓰는 값. 4-1이 만들어 다음 화면에 넘긴다.
class ChildOnboardingSession {
  const ChildOnboardingSession({required this.profile, this.connector});

  /// 부모가 첫 설정에서 저장한 이름·호칭 (없으면 민준·엄마)
  final ParentProfile profile;

  /// 시험할 때 쓰는 가짜 보드. 마친 뒤 자녀 홈에도 넘긴다.
  final BoardConnector? connector;

  /// 마쳤다고 기록하고, 안내 화면을 모두 닫은 뒤 자녀 홈(5-1)으로 간다.
  /// 마지막 화면의 '온기 시작하기'와 모든 화면의 '건너뛰기'가 쓴다.
  Future<void> finish(BuildContext context) async {
    final navigator = Navigator.of(context);
    await ChildOnboardingPrefs.complete();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => ChildScreen(connector: connector, profile: profile),
      ),
      (_) => false,
    );
  }
}
