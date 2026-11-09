import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// 자녀 이름, 부모 호칭, 프로필 사진. 2-1에서 처음 정하고 3-6 설정에서 바꾼다.
/// 부모·자녀 화면 문장과 프로필 그림에 쓴다.
class ParentProfile {
  const ParentProfile({
    required this.childName,
    required this.author,
    this.childPhoto,
    this.parentPhoto,
  });

  /// 첫 설정을 하기 전이거나 시험할 때 쓰는 시연용 값 (민준, 엄마)
  static const fallback = ParentProfile(
    childName: AppConfig.childName,
    author: AppConfig.parentAuthor,
  );

  final String childName;

  /// 'mom' 또는 'dad' (서버의 author 값)
  final String author;

  /// 기기에 저장한 자녀 사진 경로. 없으면 기본 아이콘을 쓴다.
  final String? childPhoto;

  /// 기기에 저장한 부모 사진 경로. 없으면 기본 아이콘을 쓴다.
  final String? parentPhoto;

  /// 엄마 / 아빠
  String get title => AppConfig.parentTitle(author);

  /// 문장 속 이름. 받침이 있으면 '이'를 붙인다 (민준 → 민준이, 서아 → 서아).
  /// 끝이 늘 받침 없는 소리라서 뒤에는 '를·가·에게'를 붙이면 된다.
  String get nickname => _hasBatchim(childName) ? '$childName이' : childName;

  /// 부르는 이름. 받침이 있으면 '아', 없으면 '야' (민준아, 서아야).
  String get called => '$childName${_hasBatchim(childName) ? '아' : '야'}';

  /// 메시지를 남긴 사람([author])의 사진. 이 기기의 부모가 아니면 null이다.
  String? photoFor(String? author) =>
      author == this.author ? parentPhoto : null;

  /// 사진을 지우려면 [clearChildPhoto]·[clearParentPhoto]를 true로 준다.
  ParentProfile copyWith({
    String? childName,
    String? author,
    String? childPhoto,
    String? parentPhoto,
    bool clearChildPhoto = false,
    bool clearParentPhoto = false,
  }) => ParentProfile(
    childName: childName ?? this.childName,
    author: author ?? this.author,
    childPhoto: clearChildPhoto ? null : childPhoto ?? this.childPhoto,
    parentPhoto: clearParentPhoto ? null : parentPhoto ?? this.parentPhoto,
  );

  static bool _hasBatchim(String word) {
    if (word.isEmpty) return false;
    final code = word.runes.last;
    if (code < 0xAC00 || code > 0xD7A3) return false;
    return (code - 0xAC00) % 28 != 0;
  }
}

/// 첫 설정(2-1~2-7)을 마쳤는지와 프로필을 기기에 저장한다.
class OnboardingPrefs {
  OnboardingPrefs._();

  static const _doneKey = 'parent_onboarding_done';
  static const _childNameKey = 'child_name';
  static const _authorKey = 'parent_author';
  static const _childPhotoKey = 'child_photo';
  static const _parentPhotoKey = 'parent_photo';

  static Future<bool> isDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_doneKey) ?? false;
  }

  /// 저장한 프로필. 없으면 [ParentProfile.fallback]의 값을 쓴다.
  static Future<ParentProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return ParentProfile(
      childName:
          prefs.getString(_childNameKey) ?? ParentProfile.fallback.childName,
      author: prefs.getString(_authorKey) ?? ParentProfile.fallback.author,
      childPhoto: prefs.getString(_childPhotoKey),
      parentPhoto: prefs.getString(_parentPhotoKey),
    );
  }

  /// 프로필만 저장한다 (3-6 설정).
  static Future<void> saveProfile(ParentProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_childNameKey, profile.childName);
    await prefs.setString(_authorKey, profile.author);
    await _setOrRemove(prefs, _childPhotoKey, profile.childPhoto);
    await _setOrRemove(prefs, _parentPhotoKey, profile.parentPhoto);
  }

  /// 프로필을 저장하고 첫 설정을 마친 것으로 기록한다 (2-6 저장).
  static Future<void> complete(ParentProfile profile) async {
    await saveProfile(profile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doneKey, true);
  }

  static Future<void> _setOrRemove(
    SharedPreferences prefs,
    String key,
    String? value,
  ) => value == null ? prefs.remove(key) : prefs.setString(key, value);
}
