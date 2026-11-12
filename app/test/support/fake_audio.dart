import 'dart:async';

import 'package:ongi_app/api/message_playback.dart';

/// 소리 없이 재생한 주소만 기록하는 가짜 재생기.
class FakeUrlPlayer implements UrlAudioPlayer {
  final played = <Uri>[];
  int stops = 0;

  /// true면 소리 파일이 깨진 것처럼 재생에 실패한다.
  bool fail = false;
  final _complete = StreamController<void>.broadcast();

  @override
  Future<void> play(Uri url) async {
    played.add(url);
    if (fail) throw Exception('재생할 수 없는 파일');
  }

  @override
  Future<void> stop() async => stops++;

  /// 끝까지 재생된 것처럼 알린다.
  void finish() => _complete.add(null);

  @override
  Stream<void> get onComplete => _complete.stream;

  @override
  Future<void> dispose() async {}
}
