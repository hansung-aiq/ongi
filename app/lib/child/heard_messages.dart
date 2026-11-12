import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../api/server_client.dart';
import '../api/server_models.dart';
import '../api/situations.dart';
import '../config.dart';
import '../parent/parent_profile.dart';
import 'recent_message_card.dart';

/// 자녀가 들은 메시지. 재생 기록(API-09)과 메시지(API-03)를 합친다.
/// 같은 메시지를 여러 번 들었으면 가장 최근에 들은 것 하나만 남긴다.
class HeardMessages extends ChangeNotifier {
  HeardMessages({required this.client, required this.familyId});

  final ServerClient client;
  final int familyId;

  List<(PlayLog, ParentMessage)> _items = const [];
  bool loaded = false;

  /// 불러오지 못했을 때의 안내 문구
  String? error;
  bool _disposed = false;

  Future<void> load() async {
    try {
      final results = await Future.wait([
        client.playLogs(familyId),
        client.messages(familyId),
      ]);
      final logs = results[0] as List<PlayLog>;
      final messages = {
        for (final m in results[1] as List<ParentMessage>) m.id: m,
      };
      final seen = <int>{};
      _items = [
        for (final log in logs)
          /// 지운 메시지는 목록에 없으므로 건너뛴다.
          if (messages[log.messageId] case final m? when seen.add(m.id))
            (log, m),
      ];
      error = null;
    } on ServerException catch (e) {
      error = e.message;
    } on Object {
      /// 응답 모양이 규격과 다를 때도 화면이 멈추지 않게 한다.
      error = '들은 메시지를 불러오지 못했어';
    }
    loaded = true;
    if (!_disposed) notifyListeners();
  }

  /// 화면에 보일 카드 모양. 최근에 들은 순서다.
  List<RecentMessage> cards(ParentProfile profile) {
    final now = clock.now();
    return [
      for (final (log, m) in _items)
        RecentMessage(
          messageId: m.id,
          author: AppConfig.parentTitle(m.author),
          situation: situationNames[m.situationId] ?? '',
          text: m.isVoice ? null : m.text,
          isVoice: m.isVoice,
          heardAt: heardAtLabel(log.playedAt, now),
          photo: profile.photoFor(m.author),
        ),
    ];
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// '들은 날 · 오늘 · 오후 4:32'. 이틀 전부터는 '11월 7일'처럼 날짜로 쓴다.
String heardAtLabel(DateTime at, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final days = today.difference(day).inDays;
  final date = switch (days) {
    0 => '오늘',
    1 => '어제',
    _ => '${at.month}월 ${at.day}일',
  };
  final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final minute = at.minute.toString().padLeft(2, '0');
  return '들은 날 · $date · ${at.hour < 12 ? '오전' : '오후'} $hour:$minute';
}
