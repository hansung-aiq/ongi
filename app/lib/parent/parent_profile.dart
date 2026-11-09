import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// 2-1에서 입력한 자녀 이름과 호칭. 부모 화면 문장에 쓴다.
class ParentProfile {
  const ParentProfile({required this.childName, required this.author});

  /// 첫 설정을 하기 전이거나 시험할 때 쓰는 시연용 값 (민준, 엄마)
  static const fallback = ParentProfile(
    childName: AppConfig.childName,
    author: AppConfig.parentAuthor,
  );

  final String childName;

  /// 'mom' 또는 'dad' (서버의 author 값)
  final String author;

  /// 엄마 / 아빠
  String get title => AppConfig.parentTitle(author);

  /// 문장 속 이름. 받침이 있으면 '이'를 붙인다 (민준 → 민준이, 서아 → 서아).
  /// 끝이 늘 받침 없는 소리라서 뒤에는 '를·가·에게'를 붙이면 된다.
  String get nickname => _hasBatchim(childName) ? '$childName이' : childName;

  /// 부르는 이름. 받침이 있으면 '아', 없으면 '야' (민준아, 서아야).
  String get called => '$childName${_hasBatchim(childName) ? '아' : '야'}';

  static bool _hasBatchim(String word) {
    if (word.isEmpty) return false;
    final code = word.runes.last;
    if (code < 0xAC00 || code > 0xD7A3) return false;
    return (code - 0xAC00) % 28 != 0;
  }
}

/// 첫 설정(2-1~2-7)을 마쳤는지와 입력한 이름·호칭을 기기에 저장한다.
class OnboardingPrefs {
  OnboardingPrefs._();

  static const _doneKey = 'parent_onboarding_done';
  static const _childNameKey = 'child_name';
  static const _authorKey = 'parent_author';

  static Future<bool> isDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_doneKey) ?? false;
  }

  /// 저장한 이름·호칭. 없으면 [ParentProfile.fallback]의 값을 쓴다.
  static Future<ParentProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return ParentProfile(
      childName:
          prefs.getString(_childNameKey) ?? ParentProfile.fallback.childName,
      author: prefs.getString(_authorKey) ?? ParentProfile.fallback.author,
    );
  }

  static Future<void> complete(ParentProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_childNameKey, profile.childName);
    await prefs.setString(_authorKey, profile.author);
    await prefs.setBool(_doneKey, true);
  }
}
