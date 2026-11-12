import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/message_playback.dart';
import '../api/server_models.dart';
import '../common/common.dart';
import 'message_menu_sheet.dart';

/// 메시지 자세히 보기. 3-2·3-3 카드를 누르면 올라온다.
/// 글은 끝까지 보이고(길면 스크롤), 녹음은 여기서 다시 들을 수 있다.
/// 수정하기·삭제하기를 고르면 그 행동을, 닫으면 null을 돌려준다. 닫으면 재생을 멈춘다.
Future<MessageMenuAction?> showMessageDetailSheet(
  BuildContext context, {
  required ParentMessage message,
  required String title,
  String? category,
  required String date,
  required MessagePlayback playback,
  required Uri audioUrl,
}) async {
  final action = await showModalBottomSheet<MessageMenuAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgBase,
    barrierColor: const Color(0x661A140F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _MessageDetailSheet(
      message: message,
      title: title,
      category: category,
      date: date,
      playback: playback,
      audioUrl: audioUrl,
    ),
  );
  await playback.stop();
  return action;
}

class _MessageDetailSheet extends StatelessWidget {
  const _MessageDetailSheet({
    required this.message,
    required this.title,
    required this.category,
    required this.date,
    required this.playback,
    required this.audioUrl,
  });

  final ParentMessage message;
  final String title;
  final String? category;
  final String date;
  final MessagePlayback playback;
  final Uri audioUrl;

  @override
  Widget build(BuildContext context) {
    final secondary = AppTextStyles.caption12.copyWith(
      color: AppColors.textSecondary,
    );
    final text = message.text;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.s12,
            AppSpacing.screenHorizontal,
            AppSpacing.s20,
          ),
          child: ListenableBuilder(
            listenable: playback,
            builder: (context, _) {
              final playing = playback.isPlaying(message.id);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: SheetHandle()),
                  const SizedBox(height: AppSpacing.s20),
                  Text(title, style: AppTextStyles.subtitle18),
                  if (category != null) ...[
                    const SizedBox(height: AppSpacing.s4),
                    Text(category!, style: secondary),
                  ],
                  const SizedBox(height: AppSpacing.s20),
                  OngiCard(
                    color: AppColors.bgSoft,
                    borderColor: AppColors.bgSoft,
                    padding: const EdgeInsets.all(AppSpacing.s20),
                    child: text != null && text.trim().isNotEmpty
                        ? SelectableText(text, style: AppTextStyles.body16)
                        : Center(child: Waveform.small(animate: playing)),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Text(
                    '${message.isVoice ? '음성' : '텍스트'} · '
                    '${message.delivered ? '전달됨' : '전달 대기'} · $date',
                    style: secondary,
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  if (playback.failedId == message.id) ...[
                    const ErrorNotice(message: MessagePlayback.failedMessage),
                    const SizedBox(height: AppSpacing.s12),
                  ],
                  if (message.isVoice) ...[
                    OngiButton(
                      label: playing ? '멈추기' : '다시 듣기',
                      icon: playing ? LucideIcons.pause : LucideIcons.play,
                      onPressed: () => playback.toggle(message.id, audioUrl),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OngiButton.secondary(
                    label: '수정하기',
                    onPressed: () =>
                        Navigator.of(context).pop(MessageMenuAction.edit),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(MessageMenuAction.delete),
                    child: Text(
                      '삭제하기',
                      style: AppTextStyles.label16.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      '닫기',
                      style: AppTextStyles.body16.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
