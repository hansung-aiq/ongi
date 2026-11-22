import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/server_client.dart';
import '../../common/common.dart';

enum PreviewState {
  idle,

  /// 서버 작업기가 목소리를 만드는 중
  making,
  playing,
  failed,
}

/// 11/22 캐릭터 목소리 미리 듣기. 글을 보내면 작업기가 만들 때까지 기다렸다가 재생한다.
/// 만드는 데 글 길이에 따라 20~60초쯤 걸린다.
class TtsPreview extends ChangeNotifier {
  TtsPreview({
    required this.client,
    required this.familyId,
    required this.author,
    AudioPlayer? player,
  }) : _player = player ?? AudioPlayer() {
    _done = _player.onPlayerComplete.listen((_) {
      if (_state == PreviewState.playing) _set(PreviewState.idle);
    });
  }

  final ServerClient client;
  final int familyId;
  final String author;
  final AudioPlayer _player;
  StreamSubscription<void>? _done;
  Timer? _ticker;
  int _token = 0;

  PreviewState _state = PreviewState.idle;
  PreviewState get state => _state;

  /// 만들기 시작한 뒤 지난 초
  int elapsed = 0;
  String? error;

  /// 이만큼 기다려도 안 되면 실패로 본다(작업기가 꺼져 있을 때)
  static const timeout = Duration(minutes: 3);

  Timer? _prepTimer;
  String? _prepared;

  /// 쓰는 동안 미리 만들기: 글이 [delay] 동안 안 바뀌면 서버에 미리 듣기를 만들어 둔다.
  /// 서버가 같은 글을 다시 만들지 않으므로, 나중에 [speak]를 누르면 만들어진 것을 바로 재생한다.
  void prepare(String text, {Duration delay = const Duration(milliseconds: 1500)}) {
    _prepTimer?.cancel();
    final t = text.trim();
    if (t.isEmpty || t == _prepared) return;
    _prepTimer = Timer(delay, () {
      _prepared = t;
      client.createPreview(familyId: familyId, author: author, text: t).ignore();
    });
  }

  /// 마지막으로 들은 글과 그 미리 듣기. 같은 글이면 다시 만들지 않고 바로 다시 들려준다.
  String? _lastText;
  int? _lastId;
  String? _waitingText;

  /// 글을 캐릭터 목소리로 만들어 재생
  Future<void> speak(String text) async {
    _prepTimer?.cancel();
    final t = text.trim();
    _prepared = t;
    final lastId = _lastId;
    if (t == _lastText && lastId != null) {
      await _player.stop();
      _ticker?.cancel();
      error = null;
      try {
        await _player.play(UrlSource(client.previewAudioUrl(lastId).toString()));
        _set(PreviewState.playing);
      } on Exception {
        _fail('소리를 재생하지 못했어요');
      }
      return;
    }
    _waitingText = t;
    final token = await _begin();
    try {
      final id = await client.createPreview(familyId: familyId, author: author, text: text);
      await _waitAndPlay(id, token);
    } on ServerException catch (e) {
      if (token == _token) _fail(e.message);
    }
  }

  /// 이미 만들어 둔 미리 듣기(캐릭터 첫 인사)를 기다렸다가 재생
  Future<void> playExisting(int previewId) async {
    _waitingText = null;
    final token = await _begin();
    await _waitAndPlay(previewId, token);
  }

  Future<void> stop() async {
    _token++;
    _ticker?.cancel();
    await _player.stop();
    _set(PreviewState.idle);
  }

  Future<int> _begin() async {
    final token = ++_token;
    await _player.stop();
    error = null;
    elapsed = 0;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsed++;
      notifyListeners();
    });
    _set(PreviewState.making);
    return token;
  }

  Future<void> _waitAndPlay(int id, int token) async {
    final until = DateTime.now().add(timeout);
    while (token == _token) {
      String status;
      try {
        status = await client.previewStatus(id);
      } on ServerException {
        status = 'pending'; // 잠깐 끊긴 것은 다시 물어본다
      }
      if (token != _token) return;
      if (status == 'ready') {
        _ticker?.cancel();
        _lastId = id;
        _lastText = _waitingText;
        try {
          await _player.play(UrlSource(client.previewAudioUrl(id).toString()));
          _set(PreviewState.playing);
        } on Exception {
          _fail('소리를 재생하지 못했어요');
        }
        return;
      }
      if (status == 'failed') {
        _fail('목소리를 만들지 못했어요. 다시 들어 봐 주세요');
        return;
      }
      if (DateTime.now().isAfter(until)) {
        _fail('시간이 오래 걸려요. 목소리 만드는 컴퓨터가 켜져 있는지 확인해 주세요');
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  void _fail(String message) {
    _ticker?.cancel();
    error = message;
    _set(PreviewState.failed);
  }

  void _set(PreviewState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _token++;
    _ticker?.cancel();
    _prepTimer?.cancel();
    _done?.cancel();
    _player.dispose();
    super.dispose();
  }
}

/// 미리 듣기 버튼: 들어보기 → 목소리 만드는 중 (n초) → 듣는 중(멈추기)
class TtsPreviewButton extends StatelessWidget {
  const TtsPreviewButton({
    super.key,
    required this.preview,
    required this.onSpeak,
    this.label = '이 목소리로 들어보기',
  });

  final TtsPreview preview;

  /// 들어보기를 누르면 부른다. null이면 비활성(글이 없을 때)
  final VoidCallback? onSpeak;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: preview,
      builder: (context, _) {
        void stop() => preview.stop();
        final (String text, IconData icon, VoidCallback? onPressed) = switch (preview.state) {
          PreviewState.making => ('목소리 만드는 중… ${preview.elapsed}초', LucideIcons.audioLines, stop),
          PreviewState.playing => ('듣는 중 · 멈추기', LucideIcons.pause, stop),
          PreviewState.failed => ('다시 들어보기', LucideIcons.play, onSpeak),
          PreviewState.idle => (label, LucideIcons.play, onSpeak),
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OngiButton.secondary(label: text, icon: icon, onPressed: onPressed),
            if (preview.state == PreviewState.making) ...[
              const SizedBox(height: AppSpacing.s8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: const LinearProgressIndicator(
                  minHeight: 4,
                  color: AppColors.accent,
                  backgroundColor: AppColors.bgSoft,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                '글 길이에 따라 20초~1분 정도 걸려요',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption12.copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (preview.state == PreviewState.failed && preview.error != null) ...[
              const SizedBox(height: AppSpacing.s8),
              ErrorNotice(message: preview.error!),
            ],
          ],
        );
      },
    );
  }
}
