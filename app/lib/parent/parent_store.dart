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
