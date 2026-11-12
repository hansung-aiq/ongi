import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 서버의 녹음 파일을 재생한다. 시험할 때 가짜로 바꿔 끼운다.
abstract class UrlAudioPlayer {
  Future<void> play(Uri url);
  Future<void> stop();

  /// 끝까지 재생되면 알린다.
  Stream<void> get onComplete;
  Future<void> dispose();
}

class DeviceUrlAudioPlayer implements UrlAudioPlayer {
  final _player = AudioPlayer();

  @override
  Future<void> play(Uri url) => _player.play(UrlSource(url.toString()));

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<void> get onComplete => _player.onPlayerComplete;

  @override
  Future<void> dispose() => _player.dispose();
}

/// 녹음 메시지 다시 듣기 (6-2 메시지 카드, 3-7 온기기록).
/// 한 번에 하나만 재생하고, 지금 재생 중인 메시지 번호를 알려 준다.
class MessagePlayback extends ChangeNotifier {
  MessagePlayback({UrlAudioPlayer? player})
    : _player = player ?? DeviceUrlAudioPlayer() {
    _done = _player.onComplete.listen((_) => _set(null));
  }

  final UrlAudioPlayer _player;
  late final StreamSubscription<void> _done;
  bool _disposed = false;

  /// 재생 중인 메시지 번호. 없으면 null이다.
  int? playingId;

  /// 마지막으로 재생하지 못한 메시지 번호. 다시 재생하거나 멈추면 지운다.
  /// 들은 메시지 창은 이 값으로 창 안에 안내를 띄운다.
  int? failedId;

  /// 지금까지 재생에 실패한 횟수. 화면이 새 실패만 골라 안내할 때 쓴다.
  int failures = 0;

  /// 재생하지 못했을 때 보여 줄 안내 문구
  static const failedMessage = '녹음을 재생하지 못했어요. 다시 눌러 주세요.';

  bool isPlaying(int messageId) => playingId == messageId;

  /// 재생 중인 메시지면 멈추고, 아니면 그 메시지를 재생한다.
  Future<void> toggle(int messageId, Uri url) async {
    failedId = null;
    if (isPlaying(messageId)) {
      _set(null);
      await _player.stop();
      return;
    }
    _set(messageId);
    try {
      await _player.stop();
      await _player.play(url);
    } on Exception {
      /// 파일이 없거나 소리 파일이 아니거나 서버에 닿지 않을 때
      failedId = messageId;
      failures++;
      _set(null);
    }
  }

  Future<void> stop() async {
    failedId = null;
    if (playingId == null) return;
    _set(null);
    await _player.stop();
  }

  void _set(int? id) {
    playingId = id;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _done.cancel();
    _player.dispose();
    super.dispose();
  }
}
