import 'package:flutter/material.dart';

import '../api/message_playback.dart';
import '../common/common.dart';
import '../parent/parent_profile.dart';
import 'heard_message_sheet.dart';
import 'heard_messages.dart';
import 'recent_message_card.dart';

/// 3-7 온기기록. 이미 들었던 메시지를 모아 보여 주고, 녹음은 다시 들을 수 있다.
class OngiRecordScreen extends StatelessWidget {
  const OngiRecordScreen({
    super.key,
    required this.profile,
    required this.heard,
    required this.playback,
  });

  final ParentProfile profile;
  final HeardMessages heard;
  final MessagePlayback playback;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary;
    return ListenableBuilder(
      listenable: Listenable.merge([heard, playback]),
      builder: (context, _) {
        final cards = heard.cards(profile);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.s8,
            AppSpacing.screenHorizontal,
            AppSpacing.s24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TopNavBar(title: '온기기록'),
              const SizedBox(height: AppSpacing.s8),
              Text(
                '이미 들었던 ${profile.title}의 메시지야.\n다시 듣고 싶을 때 언제든 눌러봐.',
                style: AppTextStyles.body14.copyWith(color: secondary),
              ),
              const SizedBox(height: AppSpacing.s20),
              if (heard.error != null)
                ErrorNotice(message: heard.error!)
              else if (heard.loaded && cards.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
                  child: Text(
                    '아직 들은 메시지가 없어.\n온기에게 이야기하면 여기에 모여.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body14.copyWith(color: secondary),
                  ),
                )
              else if (cards.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: OngiChip(
                    label: '들은 메시지 ${cards.length}',
                    selected: true,
                  ),
                ),
                for (final card in cards) ...[
                  const SizedBox(height: AppSpacing.s16),
                  RecentMessageCard(
                    message: card,
                    maxLines: 2,
                    letter: true,
                    onTap: () => showHeardMessageSheet(
                      context,
                      message: card,
                      playback: playback,
                      audioUrl: heard.client.audioUrl(card.messageId!),
                    ),
                    playing: playback.isPlaying(card.messageId!),
                    onPlay: card.isVoice
                        ? () => playback.toggle(
                            card.messageId!,
                            heard.client.audioUrl(card.messageId!),
                          )
                        : null,
                  ),
                ],
                const SizedBox(height: AppSpacing.s16),
                Text(
                  '따뜻한 말은, 몇 번을 들어도 좋아.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption12.copyWith(color: secondary),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
