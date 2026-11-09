import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/server_client.dart';
import '../../api/server_models.dart';
import '../../common/common.dart';
import '../message_write_screen.dart';
import '../situation_info.dart';
import '../voice_record_panel.dart';
import '../voice_recorder.dart';
import 'first_message_done_screen.dart';
import 'onboarding_session.dart';

/// 2-4 녹음 전 / 2-5 녹음 중 / 2-6 녹음 후. 첫 메시지를 작성한다.
/// 저장하면 첫 설정을 마친 것으로 기록하고 2-7로 간다.
class FirstMessageWriteScreen extends StatefulWidget {
  const FirstMessageWriteScreen({
    super.key,
    required this.session,
    required this.situation,
  });

  final OnboardingSession session;
  final Situation situation;

  @override
  State<FirstMessageWriteScreen> createState() =>
      _FirstMessageWriteScreenState();
}

class _FirstMessageWriteScreenState extends State<FirstMessageWriteScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// 0: 음성 녹음, 1: 텍스트 입력
  int _tab = 0;
  bool _saving = false;
  String? _error;

  /// 녹음. 녹음기는 녹음을 처음 시작할 때 만든다.
  VoiceRecorder? _recorderInstance;
  StreamSubscription<void>? _playDone;
  VoiceStage _stage = VoiceStage.ready;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  String? _recordedPath;
  bool _playing = false;

  static const _recordFailed = '녹음을 저장하지 못했어요. 다시 시도해 주세요.';

  VoiceRecorder get _recorder {
    final existing = _recorderInstance;
    if (existing != null) return existing;
    final recorder = _recorderInstance = widget.session.recorderFactory();
    _playDone = recorder.onPlayComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
    return recorder;
  }

  bool get _canSave =>
      !_saving &&
      switch (_tab) {
        1 => _controller.text.trim().isNotEmpty,
        _ => _stage == VoiceStage.recorded,
      };

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _ticker?.cancel();
    _playDone?.cancel();
    final recorder = _recorderInstance;
    if (recorder != null) {
      if (_stage == VoiceStage.recording) recorder.cancel();
      recorder.dispose();
    }
    super.dispose();
  }

  void _changeTab(int tab) {
    /// 녹음하는 동안은 탭을 바꾸지 않는다.
    if (_stage == VoiceStage.recording || tab == _tab) return;
    if (_playing) _togglePlay();
    setState(() {
      _tab = tab;
      _error = null;
    });
  }

  Future<void> _startRecording() async {
    setState(() => _error = null);
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) setState(() => _error = '마이크 권한을 허용해 주세요');
        return;
      }
      await _recorder.start();
    } on Exception {
      if (mounted) setState(() => _error = _recordFailed);
      return;
    }
    if (!mounted) return;
    setState(() {
      _stage = VoiceStage.recording;
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
      if (_elapsed >= MessageWriteScreen.maxRecording) _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    _ticker?.cancel();
    _ticker = null;
    try {
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        _recordedPath = path;
        _stage = VoiceStage.recorded;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _stage = VoiceStage.ready;
        _error = _recordFailed;
      });
    }
  }

  Future<void> _togglePlay() async {
    final path = _recordedPath;
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
      _stage = VoiceStage.ready;
      _recordedPath = null;
      _elapsed = Duration.zero;
      _error = null;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_playing) await _togglePlay();
    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final store = widget.session.store;
    final author = widget.session.profile.author;
    try {
      if (_tab == 1) {
        await store.saveText(
          situationId: widget.situation.id,
          author: author,
          text: _controller.text.trim(),
        );
      } else {
        final path = _recordedPath!;
        await store.saveVoice(
          situationId: widget.situation.id,
          author: author,
          audio: await _recorder.read(path),
          filename: path.split(RegExp(r'[/\\]')).last,
        );
      }
      await OnboardingPrefs.complete(widget.session.profile);
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is ServerException ? e.message : _recordFailed;
        });
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FirstMessageDoneScreen(session: widget.session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nickname = widget.session.profile.nickname;
    return OnboardingScaffold(
      step: 2,
      actions: [
        OngiButton(
          label: _saving ? '저장하는 중…' : '저장하기',
          onPressed: _canSave ? _save : null,
        ),
        OngiButton.secondary(
          label: '이전으로',
          onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
        ),
      ],
      children: [
        PageHeading.situation(
          category: categoryLabel(widget.situation.category),
          title: widget.situation.name,
          description: '$nickname에게 전하고 싶은 마음을 남겨주세요.',
        ),
        const SizedBox(height: AppSpacing.section),
        OngiSegmentedTabs(
          segments: const [
            OngiSegment(label: '음성 녹음', icon: LucideIcons.mic),
            OngiSegment(label: '텍스트 입력', icon: LucideIcons.type),
          ],
          selectedIndex: _tab,
          onChanged: _changeTab,
        ),
        const SizedBox(height: AppSpacing.s16),
        _tab == 1
            ? _textBox()
            : VoiceRecordPanel(
                stage: _stage,
                elapsed: _elapsed,
                maxDuration: MessageWriteScreen.maxRecording,
                playing: _playing,
                enabled: !_saving,
                onStart: _startRecording,
                onStop: _stopRecording,
                onPlayToggle: _togglePlay,
                onRetake: _retake,
              ),
        const SizedBox(height: AppSpacing.s16),
        _tab == 1
            ? const HintRow(
                icon: LucideIcons.type,
                text: '남겨주신 글은 따뜻한 목소리로 읽어드려요.',
              )
            : HintRow(
                icon: LucideIcons.audioLines,
                text: '녹음한 목소리 그대로 $nickname에게 들려드려요.\n조용한 곳에서 편하게 말해주세요.',
              ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.s16),
          ErrorNotice(message: _error!),
        ],
      ],
    );
  }

  /// 글 칸의 테두리
  BoxDecoration _boxDecoration({required bool focused}) => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.card),
    border: Border.all(
      color: focused ? AppColors.textPrimary : AppColors.line,
      width: focused ? AppSizes.borderSelected : AppSizes.borderDefault,
    ),
  );

  Widget _textBox() {
    return Container(
      height: VoiceRecordPanel.height,
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: _boxDecoration(focused: _focus.hasFocus),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              enabled: !_saving,
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              inputFormatters: [
                LengthLimitingTextInputFormatter(MessageWriteScreen.maxLength),
              ],
              style: AppTextStyles.body16,
              decoration: InputDecoration.collapsed(
                hintText:
                    '${widget.session.profile.nickname}에게 전하고 싶은 마음을 적어 주세요.',
                hintStyle: AppTextStyles.body16.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            '${_controller.text.characters.length}/${MessageWriteScreen.maxLength}자',
            textAlign: TextAlign.right,
            style: AppTextStyles.caption12.copyWith(
              color: AppColors.textSecondary,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
