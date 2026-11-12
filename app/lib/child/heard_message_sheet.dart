import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/message_playback.dart';
import '../common/common.dart';
import 'recent_message_card.dart';

/// 자녀 화면에서 녹음을 재생하지 못했을 때의 안내
const childPlaybackFailed = '녹음을 재생하지 못했어. 다시 눌러 줄래?';

/// 들은 메시지 자세히 보기. 카드(5-1 최근에 들은 메시지, 3-7 온기기록)를 누르면 올라온다.
/// 글은 끝까지 보이고, 녹음은 이 창에서 다시 들을 수 있다. 닫으면 재생을 멈춘다.
Future<void> showHeardMessageSheet(
  BuildContext context, {
  required RecentMessage message,
  required MessagePlayback playback,
  required Uri? audioUrl,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgBase,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _HeardMessageSheet(
      message: message,
      playback: playback,
      audioUrl: audioUrl,
    ),
  );
  await playback.stop();
}

class _HeardMessageSheet extends StatelessWidget {
  const _HeardMessageSheet({
    required this.message,
    required this.playback,
    required this.audioUrl,
  });

  final RecentMessage message;
  final MessagePlayback playback;
  final Uri? audioUrl;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary;
    final text = message.text;
    final id = message.messageId;
    final url = audioUrl;
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
              final playing = id != null && playback.isPlaying(id);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: SheetHandle()),
                  const SizedBox(height: AppSpacing.s20),
                  Row(
                    children: [
                      ProfileAvatar(size: 52, imagePath: message.photo),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.author,
                              style: AppTextStyles.caption12.copyWith(
                                color: secondary,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              message.situation,
                              style: AppTextStyles.subtitle18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s20),
                  OngiCard(
                    color: AppColors.bgSoft,
                    borderColor: AppColors.bgSoft,
                    padding: const EdgeInsets.all(AppSpacing.s20),
                    child: text != null
                        ? Text(text, style: AppTextStyles.body16)
                        : Center(child: Waveform.small(animate: playing)),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Text(
                    message.heardAt,
                    style: AppTextStyles.caption12.copyWith(color: secondary),
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  if (id != null && playback.failedId == id) ...[
                    const ErrorNotice(message: childPlaybackFailed),
                    const SizedBox(height: AppSpacing.s12),
                  ],
                  if (message.isVoice && id != null && url != null) ...[
                    OngiButton(
                      label: playing ? '멈추기' : '다시 듣기',
                      icon: playing ? LucideIcons.pause : LucideIcons.play,
                      onPressed: () => playback.toggle(id, url),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OngiButton.secondary(
                    label: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
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
