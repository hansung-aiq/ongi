import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/server_client.dart';
import '../../common/common.dart';
import '../voice_record_panel.dart';
import '../voice_recorder.dart';
import 'voice_character_screen.dart';

/// 11/22 목소리 만들기: 이름 정하기 → 문장 5개 읽기 → 만들기 → 완성(첫 인사).
/// 모델을 새로 학습하지 않는다. 읽은 녹음 5개를 서버에 견본으로 두고,
/// 작업기가 글을 만들 때마다 이 견본을 참고해 같은 목소리로 읽는다.
class VoiceCreateScreen extends StatefulWidget {
  const VoiceCreateScreen({
    super.key,
    required this.client,
    required this.familyId,
    required this.author,
    required this.title,
    this.recorderFactory = DeviceVoiceRecorder.new,
  });

  final ServerClient client;
  final int familyId;

  /// 'mom' / 'dad'
  final String author;

  /// 호칭 ('아빠'). 이름 칸의 처음 값
  final String title;
  final VoiceRecorder Function() recorderFactory;

  static const maxRecording = Duration(seconds: 20);
  static const nameMax = 20;

  /// 서버를 못 부를 때 쓰는 문장. 서버 VOICE_SENTENCES와 같다.
  static const fallbackSentences = [
    '안녕, 오늘 하루는 어땠어? 학교에서 재미있는 일 있었니?',
    '힘든 일이 있으면 언제든 이야기해 줘. 다 들어 줄게.',
    '네가 웃으면 나도 덩달아 행복해져. 정말 고마워.',
    '밥 잘 챙겨 먹고, 일찍 자고, 감기 조심해야 해.',
    '무슨 일이 있어도 늘 네 편이야. 사랑해.',
  ];

  @override
  State<VoiceCreateScreen> createState() => _VoiceCreateScreenState();
}

class _VoiceCreateScreenState extends State<VoiceCreateScreen> {
  late final VoiceRecorder _recorder = widget.recorderFactory();
  late final _name = TextEditingController(text: '${widget.title} ');
  final _meter = LevelMeter();
  List<String> _sentences = VoiceCreateScreen.fallbackSentences;

  /// 0: 이름, 1~5: 문장
  int _step = 0;
  late List<String?> _paths = List.filled(_sentences.length, null);
  VoiceStage _stage = VoiceStage.ready;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  bool _playing = false;
  bool _saving = false;
  String? _progress;
  String? _error;
  StreamSubscription<void>? _playDone;

  int get _index => _step - 1;
  bool get _onName => _step == 0;
  bool get _last => _step == _sentences.length;

  @override
  void initState() {
    super.initState();
    widget.client.voiceSentences().then((list) {
      if (mounted && list.isNotEmpty && _step == 0) {
        setState(() {
          _sentences = list;
          _paths = List.filled(list.length, null);
        });
      }
    }, onError: (_) {});
    _playDone = _recorder.onPlayComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _meter.stop();
    _playDone?.cancel();
    if (_stage == VoiceStage.recording) _recorder.cancel();
    _recorder.dispose();
    _name.dispose();
    super.dispose();
  }

  void _go(int step) {
    if (_stage == VoiceStage.recording) return;
    if (_playing) _togglePlay();
    setState(() {
      _step = step;
      _error = null;
      _elapsed = Duration.zero;
      _stage = step > 0 && _paths[step - 1] != null ? VoiceStage.recorded : VoiceStage.ready;
    });
  }

  void _back() {
    if (_onName) {
      Navigator.of(context).maybePop();
    } else {
      _go(_step - 1);
    }
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) setState(() => _error = '마이크 권한을 허용해 주세요');
        return;
      }
      await _recorder.start();
    } on Exception {
      if (mounted) setState(() => _error = '녹음을 시작하지 못했어요');
      return;
    }
    if (!mounted) return;
    setState(() {
      _stage = VoiceStage.recording;
      _elapsed = Duration.zero;
    });
    _meter.start(_recorder.level, () {
      if (mounted) setState(() {});
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
      if (_elapsed >= VoiceCreateScreen.maxRecording) _stop();
    });
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    _ticker = null;
    _meter.stop();
    try {
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        _stage = VoiceStage.recorded;
        if (_meter.tooQuiet) {
          _error = LevelMeter.quietWarning;
        } else if (_elapsed < const Duration(seconds: 2)) {
          _error = '조금 짧아요. 문장을 끝까지 읽어 주세요';
        }
        _paths[_index] = path;
      });
    } on Exception {
      if (mounted) setState(() => _stage = VoiceStage.ready);
    }
  }

  Future<void> _togglePlay() async {
    final path = _onName ? null : _paths[_index];
    if (path == null) return;
    setState(() => _playing = !_playing);
    try {
      _playing ? await _recorder.play(path) : await _recorder.pause();
    } on Exception {
      if (mounted) setState(() => _playing = false);
    }
  }

  void _retake() {
    if (_playing) _togglePlay();
    setState(() {
      _paths[_index] = null;
      _stage = VoiceStage.ready;
      _elapsed = Duration.zero;
      _error = null;
    });
  }

  Future<void> _create() async {
    if (_playing) await _togglePlay();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final keys = <String>[];
      for (var i = 0; i < _paths.length; i++) {
        setState(() => _progress = '녹음 올리는 중 (${i + 1}/${_paths.length})');
        keys.add(await widget.client.uploadAudio(
          await _recorder.read(_paths[i]!),
          filename: 'voice_${i + 1}.m4a',
        ));
      }
      setState(() => _progress = '목소리 만드는 중');
      final created = await widget.client.createVoiceCharacter(
        familyId: widget.familyId,
        author: widget.author,
        name: _name.text.trim(),
        audioPaths: keys,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<bool>(
          builder: (_) => VoiceCharacterScreen(
            client: widget.client,
            familyId: widget.familyId,
            author: widget.author,
            title: widget.title,
            character: created.character,
            greetingPreviewId: created.greetingPreviewId,
            queuedMessages: created.queuedMessages,
          ),
        ),
        result: true,
      );
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _progress = null;
          _error = e is ServerException ? e.message : '녹음을 올리지 못했어요. 다시 시도해 주세요';
        });
      }
    }
  }

  bool get _canNext {
    if (_saving || _stage == VoiceStage.recording) return false;
    if (_onName) return _name.text.trim().isNotEmpty;
    return _paths[_index] != null;
  }

  @override
  Widget build(BuildContext context) {
    final label = _saving
        ? (_progress ?? '만드는 중…')
        : _onName
        ? '문장 읽기 시작'
        : _last
        ? '이 목소리로 만들기'
        : '다음 문장';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.s8,
            AppSpacing.screenHorizontal,
            AppSpacing.s32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TopNavBar(title: '목소리 만들기', onBack: _saving ? null : _back),
              const SizedBox(height: AppSpacing.s16),
              Center(child: StepDots(count: _sentences.length + 1, current: _step)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: AppSpacing.s24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_onName) ..._nameStep() else ..._sentenceStep(),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.s16),
                        ErrorNotice(message: _error!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              OngiButton(
                label: label,
                onPressed: _canNext ? (_last ? _create : () => _go(_step + 1)) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _nameStep() => [
    Text('어떤 목소리를 만들까요?', style: AppTextStyles.title28),
    const SizedBox(height: AppSpacing.s8),
    Text(
      '문장 ${_sentences.length}개를 읽으면, 앞으로 남기는 글 메시지를 이 목소리로 들려줘요.',
      style: AppTextStyles.body16.copyWith(color: AppColors.textSecondary),
    ),
    const SizedBox(height: AppSpacing.s24),
    Text('목소리 이름', style: AppTextStyles.label14),
    const SizedBox(height: AppSpacing.s8),
    OngiTextField(
      controller: _name,
      hintText: '예: 아빠 지현이',
      maxLength: VoiceCreateScreen.nameMax,
      onChanged: (_) => setState(() {}),
    ),
    const SizedBox(height: AppSpacing.s24),
    const HintRow(
      icon: LucideIcons.mic,
      text: '조용한 곳에서 평소 말투로 읽어 주세요.\n한 문장에 3~6초면 충분해요.',
    ),
    const SizedBox(height: AppSpacing.s12),
    const HintRow(
      icon: LucideIcons.heart,
      text: '본인 목소리만 만들어 주세요. 내가 쓴 글만 이 목소리로 읽어요.',
    ),
  ];

  List<Widget> _sentenceStep() => [
    Text(
      '문장 $_step / ${_sentences.length}',
      style: AppTextStyles.label14.copyWith(color: AppColors.textSecondary),
    ),
    const SizedBox(height: AppSpacing.s8),
    Text('소리 내어 읽어 주세요', style: AppTextStyles.title28),
    const SizedBox(height: AppSpacing.s16),
    OngiCard(
      color: AppColors.paper,
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Text(_sentences[_index], style: AppTextStyles.heading20),
    ),
    const SizedBox(height: AppSpacing.s16),
    VoiceRecordPanel(
      stage: _stage,
      elapsed: _elapsed,
      level: _meter.current,
      maxDuration: VoiceCreateScreen.maxRecording,
      playing: _playing,
      enabled: !_saving,
      onStart: _start,
      onStop: _stop,
      onPlayToggle: _togglePlay,
      onRetake: _retake,
    ),
  ];
}
