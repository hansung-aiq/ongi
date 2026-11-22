import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/server_client.dart';
import '../../api/server_models.dart';
import '../../common/common.dart';
import 'tts_preview.dart';
import 'voice_create_screen.dart';

/// 11/22 내 목소리 캐릭터: 캐릭터 카드, 첫 인사, 써 보기(글 → 이 목소리), 다시 만들기.
class VoiceCharacterScreen extends StatefulWidget {
  const VoiceCharacterScreen({
    super.key,
    required this.client,
    required this.familyId,
    required this.author,
    required this.title,
    required this.character,
    this.greetingPreviewId,
    this.queuedMessages = 0,
  });

  final ServerClient client;
  final int familyId;
  final String author;
  final String title;
  final VoiceCharacter character;

  /// 방금 만들었으면 첫 인사 미리 듣기. 화면을 열면 만들어지는 대로 바로 들려준다.
  final int? greetingPreviewId;

  /// 이 목소리로 다시 만드는 글 메시지 개수
  final int queuedMessages;

  @override
  State<VoiceCharacterScreen> createState() => _VoiceCharacterScreenState();
}

class _VoiceCharacterScreenState extends State<VoiceCharacterScreen> {
  late final _greeting = TtsPreview(client: widget.client, familyId: widget.familyId, author: widget.author);
  late final _tryIt = TtsPreview(client: widget.client, familyId: widget.familyId, author: widget.author);
  final _text = TextEditingController();

  String get _sample => '오늘 하루도 정말 수고했어. 네가 있어서 ${widget.title}는 매일 힘이 나.';

  @override
  void initState() {
    super.initState();
    final id = widget.greetingPreviewId;
    if (id != null) _greeting.playExisting(id);
  }

  @override
  void dispose() {
    _greeting.dispose();
    _tryIt.dispose();
    _text.dispose();
    super.dispose();
  }

  void _speak() {
    _greeting.stop();
    final text = _text.text.trim().isEmpty ? _sample : _text.text.trim();
    _tryIt.speak(text);
  }

  void _sayHello() {
    _tryIt.stop();
    final name = widget.character.name;
    final last = name.isEmpty ? 0 : name.codeUnitAt(name.length - 1) - 0xAC00;
    final ya = last >= 0 && last < 11172 && last % 28 != 0 ? '이야' : '야';
    _greeting.speak('안녕, 나는 $name$ya. 이제 내가 남긴 글은 이 목소리로 들려줄게.');
  }

  Future<void> _recreate() async {
    await _greeting.stop();
    await _tryIt.stop();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<bool>(
        builder: (_) => VoiceCreateScreen(
          client: widget.client,
          familyId: widget.familyId,
          author: widget.author,
          title: widget.title,
        ),
      ),
      result: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.character;
    final made = '${c.createdAt.month}월 ${c.createdAt.day}일';
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
              TopNavBar(title: '내 목소리', onBack: () => Navigator.of(context).maybePop(true)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: AppSpacing.s24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OngiCard(
                        color: AppColors.stampBg,
                        borderColor: AppColors.stampBg,
                        padding: const EdgeInsets.all(AppSpacing.s20),
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                              child: const Icon(LucideIcons.audioLines, size: 34, color: AppColors.accent),
                            ),
                            const SizedBox(height: AppSpacing.s12),
                            Text(c.name, style: AppTextStyles.title28, textAlign: TextAlign.center),
                            const SizedBox(height: AppSpacing.s4),
                            Text(
                              '${c.sampleCount > 1 ? '문장 ${c.sampleCount}개' : '녹음'}로 만든 목소리 · $made',
                              style: AppTextStyles.body14.copyWith(color: AppColors.stampText),
                            ),
                            const SizedBox(height: AppSpacing.s16),
                            TtsPreviewButton(preview: _greeting, onSpeak: _sayHello, label: '첫 인사 듣기'),
                          ],
                        ),
                      ),
                      if (widget.queuedMessages > 0) ...[
                        const SizedBox(height: AppSpacing.s12),
                        HintRow(
                          icon: LucideIcons.audioLines,
                          text: '남긴 글 ${widget.queuedMessages}개를 이 목소리로 바꾸고 있어요.\n'
                              '하나에 1분쯤 걸리고, 끝나면 스피커에서도 이 목소리로 들려줘요.',
                        ),
                      ],
                      const SizedBox(height: AppSpacing.section),
                      Text('써 보기', style: AppTextStyles.subtitle18),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        '아무 글이나 써서 ${c.name} 목소리로 들어 보세요',
                        style: AppTextStyles.body14.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      OngiTextField(
                        controller: _text,
                        hintText: _sample,
                        maxLength: 200,
                        maxLines: 4,
                        // 쓰다가 멈추면 미리 만들어 두어 '들어보기'를 누를 때 기다림을 줄인다
                        onChanged: _tryIt.prepare,
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      TtsPreviewButton(preview: _tryIt, onSpeak: _speak),
                      const SizedBox(height: AppSpacing.section),
                      const HintRow(
                        icon: LucideIcons.heart,
                        text: '모델을 새로 학습하지 않고, 읽어 준 문장 5개를 참고해 같은 목소리로 읽어요.\n'
                            '아이 스피커에서는 부모님이 남긴 글만 이 목소리로 들려줘요.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              OngiButton.secondary(label: '목소리 다시 만들기', icon: LucideIcons.mic, onPressed: _recreate),
            ],
          ),
        ),
      ),
    );
  }
}
