import 'package:flutter/foundation.dart';

import '../api/server_client.dart';
import '../api/server_models.dart';
import 'parent_profile.dart';

/// 부모 화면이 함께 쓰는 서버 데이터 (상황 목록, 메시지 목록).
class ParentStore extends ChangeNotifier {
  ParentStore({
    required this.client,
    required this.familyId,
    this._profile = ParentProfile.fallback,
  });

  final ServerClient client;
  final int familyId;

  ParentProfile _profile;

  /// 자녀 이름·부모 호칭·사진. 3-6 설정에서 바꾸면 화면이 다시 그려진다.
  ParentProfile get profile => _profile;
  set profile(ParentProfile value) {
    _profile = value;
    notifyListeners();
  }

  /// '추천 10개 채우기'의 목표 수
  static const goal = 10;

  List<Situation> situations = const [];
  List<ParentMessage> messages = const [];

  /// 가족(이름·스피커 마지막 연결, API-15). 예전 서버라 없으면 null
  Family? family;

  /// 아이가 찾았는데 메시지가 없던 상황 (API-18). 예전 서버면 빈 목록
  List<Need> needs = const [];

  /// 불러오기에 실패했을 때의 안내 문구
  String? loadError;

  bool get loaded => situations.isNotEmpty;

  /// 서버의 분류 순서 그대로
  List<String> get categories =>
      {for (final s in situations) s.category}.toList();

  List<Situation> situationsIn(String category) =>
      situations.where((s) => s.category == category).toList();

  Situation? situation(int id) {
    for (final s in situations) {
      if (s.id == id) return s;
    }
    return null;
  }

  ParentMessage? messageFor(int situationId) {
    for (final m in messages) {
      if (m.situationId == situationId) return m;
    }
    return null;
  }

  int savedIn(String category) =>
      situationsIn(category).where((s) => messageFor(s.id) != null).length;

  /// 목표 수를 넘으면 목표 수에서 멈춘다.
  int get progress => messages.length.clamp(0, goal);

  Future<void> load() async {
    loadError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        client.situations(),
        client.messages(familyId),
      ]);
      situations = results[0] as List<Situation>;
      messages = results[1] as List<ParentMessage>;
    } on ServerException catch (e) {
      loadError = e.message;
    } finally {
      notifyListeners();
    }
    if (loadError == null) await _loadExtras();
  }

  /// 11/11 확장(API-15·18)을 불러온다. 서버에 없으면(예전 서버) 조용히 넘어간다.
  /// 서버의 자녀 이름이 이 기기와 다르면(다른 기기에서 바꿈) 서버 이름을 따른다.
  Future<void> _loadExtras() async {
    try {
      family = await client.family(familyId);
      final name = family!.childName;
      if (name != _profile.childName) {
        _profile = _profile.copyWith(childName: name);
        await OnboardingPrefs.saveProfile(_profile);
      }
    } on ServerException {
      family = null;
    }
    try {
      needs = await client.needs(familyId);
    } on ServerException {
      needs = const [];
    }
    notifyListeners();
  }

  /// 자녀 이름을 서버에 저장한다(API-16). 스피커가 이 이름으로 부른다.
  /// 서버가 받지 못해도(예전 서버·연결 끊김) 기기 저장은 그대로라 오류를 내지 않는다.
  Future<void> pushChildName(String name) async {
    try {
      family = await client.updateChildName(familyId, name);
      notifyListeners();
    } on ServerException {
      // 다음에 이름을 바꿀 때 다시 보낸다
    }
  }

  /// 재생 기록·필요 기록 지우기 (API-19). 실패하면 [ServerException]
  Future<void> deleteHistory() async {
    await client.deleteHistory(familyId);
    needs = const [];
    notifyListeners();
  }

  /// 메시지 목록만 조용히 다시 불러온다 (전달 상태 바뀜 등).
  /// 실패해도 지금 목록을 그대로 두고 안내하지 않는다. 처음 불러오기 전이면 [load]를 한다.
  Future<void> refresh() async {
    if (!loaded) return load();
    try {
      messages = await client.messages(familyId);
      loadError = null;
      notifyListeners();
    } on ServerException {
      /// 잠깐 끊긴 것일 수 있어 다음 새로고침을 기다린다.
      return;
    }
    await _loadExtras();
  }

  /// 글 메시지를 저장한다. 실패하면 [ServerException]을 던진다.
  Future<void> saveText({
    required int situationId,
    required String author,
    required String text,
  }) async {
    final message = await client.createTextMessage(
      familyId: familyId,
      situationId: situationId,
      author: author,
      text: text,
    );
    _add(message);
  }

  /// 녹음을 올리고(API-05) 녹음 메시지로 등록한다(API-04).
  /// 실패하면 [ServerException]을 던진다.
  Future<void> saveVoice({
    required int situationId,
    required String author,
    required List<int> audio,
    required String filename,
  }) async {
    final audioPath = await client.uploadAudio(audio, filename: filename);
    final message = await client.createVoiceMessage(
      familyId: familyId,
      situationId: situationId,
      author: author,
      audioPath: audioPath,
    );
    _add(message);
  }

  /// 글 메시지로 고친다 (API-06). 실패하면 [ServerException]을 던진다.
  Future<void> updateText({
    required int messageId,
    required String text,
  }) async {
    final message = await client.updateMessage(
      messageId,
      kind: 'text',
      text: text,
    );
    _replace(message);
  }

  /// 새 녹음을 올리고(API-05) 녹음 메시지로 고친다(API-06).
  /// 실패하면 [ServerException]을 던진다.
  Future<void> updateVoice({
    required int messageId,
    required List<int> audio,
    required String filename,
  }) async {
    final audioPath = await client.uploadAudio(audio, filename: filename);
    final message = await client.updateMessage(
      messageId,
      kind: 'voice',
      audioPath: audioPath,
    );
    _replace(message);
  }

  /// 메시지를 지운다 (API-07). 실패하면 [ServerException]을 던진다.
  Future<void> delete(int messageId) async {
    await client.deleteMessage(messageId);
    messages = messages.where((m) => m.id != messageId).toList();
    notifyListeners();
  }

  /// 메시지를 모두 지운다 (API-07을 하나씩). 지운 개수를 돌려준다.
  /// 중간에 실패하면 거기서 멈추고 [ServerException]을 던진다. 이미 지운 것은 목록에서 빠져 있다.
  Future<int> deleteAll() async {
    var count = 0;
    for (final m in List.of(messages)) {
      await delete(m.id);
      count++;
    }
    return count;
  }

  void _replace(ParentMessage message) {
    messages = [for (final m in messages) m.id == message.id ? message : m];
    notifyListeners();
  }

  bool _disposed = false;

  /// 화면을 닫은 뒤에 서버 응답이 와도 오류가 나지 않게 한다.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _add(ParentMessage message) {
    messages = [...messages, message]
      ..sort((a, b) => a.situationId.compareTo(b.situationId));
    notifyListeners();
  }
}
