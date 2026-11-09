import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/server_client.dart';
import '../api/server_models.dart';
import '../common/common.dart';
import 'parent_store.dart';
import 'save_done_screen.dart';
import 'situation_info.dart';
import 'voice_record_panel.dart';
import 'voice_recorder.dart';

/// 3-4 메시지 남기기. 글(200자까지) 또는 녹음(60초까지)을 저장한다.
/// 저장하면 3-5를 띄우고, 3-5에서 고른 행동을 돌려준다.
/// [editing]을 주면 6-2 수정하기로, 고쳐 저장한 뒤 [SaveDoneAction.edited]를 돌려준다.
class MessageWriteScreen extends StatefulWidget {
  const MessageWriteScreen({
    super.key,
    required this.store,
    required this.situation,
    this.recorderFactory = DeviceVoiceRecorder.new,
    this.editing,
  });

  final ParentStore store;
  final Situation situation;

  /// 고칠 메시지. 글이면 내용을 채워 두고, 녹음이면 새로 녹음한다.
  final ParentMessage? editing;

  /// 시험할 때 가짜 녹음기로 바꿔 끼운다.
  final VoiceRecorder Function() recorderFactory;

  static const maxLength = 200;
  static const maxRecording = Duration(seconds: 60);

  @override
  State<MessageWriteScreen> createState() => _MessageWriteScreenState();
}

class _MessageWriteScreenState extends State<MessageWriteScreen> {
  late final _controller = TextEditingController(
    text: widget.editing?.text ?? '',
  );
  final _focus = FocusNode();

  /// 0: 음성 녹음, 1: 텍스트 입력. 녹음 메시지를 고칠 때는 녹음 탭부터 연다.
  late int _tab = widget.editing?.isVoice ?? false ? 0 : 1;
  bool _saving = false;
  String? _error;

  /// 녹음. 녹음기는 녹음 탭을 처음 쓸 때 만든다.
  VoiceRecorder? _recorderInstance;
  StreamSubscription<void>? _playDone;
  VoiceStage _stage = VoiceStage.ready;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  String? _recordedPath;
  bool _playing = false;

  VoiceRecorder get _recorder {
    final existing = _recorderInstance;
    if (existing != null) return existing;
    final recorder = _recorderInstance = widget.recorderFactory();
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

  static const _recordFailed = '녹음을 저장하지 못했어요. 다시 시도해 주세요.';

  Future<void> _save() async {
    if (_playing) await _togglePlay();
    setState(() {
      _saving = true;
      _error = null;
    });
    final editing = widget.editing;
    try {
      if (editing != null && _tab == 1) {
        await widget.store.updateText(
          messageId: editing.id,
          text: _controller.text.trim(),
        );
      } else if (editing != null) {
        final path = _recordedPath!;
        await widget.store.updateVoice(
          messageId: editing.id,
          audio: await _recorder.read(path),
          filename: path.split(RegExp(r'[/\\]')).last,
        );
      } else if (_tab == 1) {
        await widget.store.saveText(
          situationId: widget.situation.id,
          author: widget.store.profile.author,
          text: _controller.text.trim(),
        );
      } else {
        final path = _recordedPath!;
        await widget.store.saveVoice(
          situationId: widget.situation.id,
          author: widget.store.profile.author,
          audio: await _recorder.read(path),
          filename: path.split(RegExp(r'[/\\]')).last,
        );
      }
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
    if (editing != null) {
      Navigator.of(context).pop(SaveDoneAction.edited);
      return;
    }
    final action = await Navigator.of(context).push<SaveDoneAction>(
      MaterialPageRoute(builder: (_) => SaveDoneScreen(store: widget.store)),
    );
    if (mounted) Navigator.of(context).pop(action ?? SaveDoneAction.more);
  }

  @override
  Widget build(BuildContext context) {
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
              TopNavBar(
                title: widget.editing == null ? '메시지 남기기' : '메시지 수정하기',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: AppSpacing.s24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        categoryLabel(widget.situation.category),
                        style: AppTextStyles.caption12.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(widget.situation.name, style: AppTextStyles.title28),
                      const SizedBox(height: AppSpacing.s24),
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
                              text:
                                  '녹음한 목소리 그대로 ${widget.store.profile.nickname}에게 들려드려요.\n'
                                  '조용한 곳에서 편하게 말해주세요.',
                            ),
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
                label: _saving ? '저장하는 중…' : '저장하기',
                onPressed: _canSave ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 입력 중이면 가이드의 '입력창 선택됨'처럼 진한 1.5 테두리가 된다.
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
                    '${widget.store.profile.nickname}에게 전하고 싶은 마음을 적어 주세요.',
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
