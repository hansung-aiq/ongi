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

  /// 녹음하는 동안의 소리 크기 (0 조용함 ~ 1 큼). 녹음 중이 아니면 오지 않는다.
  Stream<double> get level;

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

  /// dBFS(-50 이하 조용함 ~ 0 가장 큼)를 0~1로 바꾼다.
  @override
  Stream<double> get level => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 150))
      .map((a) => ((a.current + 50) / 50).clamp(0.0, 1.0));

  @override
  Future<void> dispose() async {
    await _recorder.dispose();
    await _player.dispose();
  }
}

/// 녹음 중 소리 크기를 모아 두고, 녹음이 너무 조용했는지 알려 준다.
/// 11/9에 마이크 볼륨 0·이어폰 끊김으로 무음 녹음이 두 번 저장돼서 넣었다.
class LevelMeter {
  StreamSubscription<double>? _sub;

  /// 지금 소리 크기 (0~1)
  double current = 0;

  /// 이번 녹음에서 가장 컸던 소리
  double peak = 0;
  int _samples = 0;

  /// 가장 큰 소리가 이보다 작으면 조용한 녹음으로 본다 (약 -40 dBFS).
  static const quietPeak = 0.2;

  static const quietWarning = '소리가 거의 녹음되지 않았어요. 다시 듣기로 확인하고, 작으면 다시 녹음해 주세요.';

  void start(Stream<double> levels, void Function() onChange) {
    stop();
    peak = 0;
    _samples = 0;
    _sub = levels.listen((v) {
      current = v;
      if (v > peak) peak = v;
      _samples++;
      onChange();
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    current = 0;
  }

  /// 소리 크기를 몇 번 이상 받았는데 계속 작았으면 true.
  /// 크기를 하나도 못 받았으면(지원 안 하는 기기) 판단하지 않는다.
  bool get tooQuiet => _samples >= 3 && peak < quietPeak;
}
