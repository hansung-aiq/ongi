import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// 부모 메시지 녹음·다시 듣기. 시험할 때 가짜로 바꿔 끼운다.
abstract class VoiceRecorder {
  /// 마이크 권한. 없으면 한 번 물어본다.
  Future<bool> hasPermission();

  /// 녹음을 시작한다. 파일은 m4a(AAC)로 저장된다.
  Future<void> start();

  /// 녹음을 끝내고 파일 경로를 돌려준다.
  Future<String> stop();

  /// 녹음 중이면 버린다.
  Future<void> cancel();

  Future<void> play(String path);
  Future<void> pause();

  /// 다시 듣기가 끝까지 재생되면 알린다.
  Stream<void> get onPlayComplete;

  /// 서버에 올릴 녹음 파일 내용
  Future<List<int>> read(String path);

  Future<void> dispose();
}

class DeviceVoiceRecorder implements VoiceRecorder {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/ongi_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
      path: path,
    );
  }

  @override
  Future<String> stop() async {
    final path = await _recorder.stop();
    if (path == null) throw const FileSystemException('녹음 파일이 없어요');
    return path;
  }

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> play(String path) => _player.play(DeviceFileSource(path));

  @override
  Future<void> pause() => _player.pause();

  @override
  Stream<void> get onPlayComplete => _player.onPlayerComplete;

  @override
  Future<List<int>> read(String path) => File(path).readAsBytes();

  @override
  Future<void> dispose() async {
    await _recorder.dispose();
    await _player.dispose();
  }
}
