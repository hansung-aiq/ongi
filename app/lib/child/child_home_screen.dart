import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/board_client.dart';
import '../api/message_playback.dart';
import '../common/common.dart';
import '../parent/parent_profile.dart';
import 'heard_message_sheet.dart';
import 'heard_messages.dart';
import 'recent_message_card.dart';

/// 5-1 자녀 홈, 6-1 연결 안 됨. 하단 탭은 자녀 화면 틀(ChildScreen)이 가진다.
class ChildHomeScreen extends StatelessWidget {
  const ChildHomeScreen({
    super.key,
    required this.profile,
    required this.connection,
    required this.notice,
    required this.onStart,
    required this.heard,
    required this.playback,
  });

  /// 부모가 첫 설정에서 저장한 이름·호칭
  final ParentProfile profile;
  final BoardConnection connection;
  final String? notice;
  final VoidCallback onStart;

  /// 최근에 들은 메시지 (3-7 온기기록과 같은 데이터, 2개까지 보인다)
  final HeardMessages heard;
  final MessagePlayback playback;

  static const _recentCount = 2;

  /// 처음 들어와 연결을 시도하는 동안에도 비연결로 보이고,
  /// 보드와 연결이 잡히면 그때 연결 상태로 바뀐다.
  bool get _offline => connection != BoardConnection.connected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.s16,
        AppSpacing.screenHorizontal,
        AppSpacing.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _greeting(),
          if (notice != null) ...[
            const SizedBox(height: AppSpacing.s16),
            ErrorNotice(message: notice!),
          ],
          const SizedBox(height: AppSpacing.s28),
          _speakCard(),
          const SizedBox(height: AppSpacing.s28),
          Text('최근에 들은 메시지', style: AppTextStyles.subtitle18),
          const SizedBox(height: 14),
          ListenableBuilder(
            listenable: Listenable.merge([heard, playback]),
            builder: (context, _) => _recent(context),
          ),
        ],
      ),
    );
  }

  Widget _greeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OngiChip(
          label: _offline ? '온기 스피커 연결 안 됨' : '온기 스피커 연결됨',
          dotColor: _offline ? AppColors.dotOffline : AppColors.accent,
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('안녕, ${profile.called}!', style: AppTextStyles.title28),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    '오늘도 네 이야기를 듣고 싶어.',
                    style: AppTextStyles.body14.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            ProfileAvatar(size: 52, imagePath: profile.childPhoto),
          ],
        ),
      ],
    );
  }

  Widget _recent(BuildContext context) {
    final cards = heard.cards(profile).take(_recentCount).toList();
    if (cards.isEmpty) {
      if (!heard.loaded) return const SizedBox.shrink();
      return Text(
        '아직 들은 메시지가 없어.\n온기에게 이야기하면 여기에 모여.',
        style: AppTextStyles.body14.copyWith(color: AppColors.textSecondary),
      );
    }
    return Column(
      children: [
        for (final card in cards) ...[
          RecentMessageCard(
            message: card,
            maxLines: 2,
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
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _speakCard() {
    return OngiCard(
      color: AppColors.textPrimary,
      borderColor: AppColors.textPrimary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s28,
        vertical: AppSpacing.s20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘 마음은\n어땠어?',
            style: AppTextStyles.title28.copyWith(
              color: AppColors.bgBase,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            _offline
                ? '스피커 전원과 와이파이를 확인해줘.\n연결되면 다시 이야기할 수 있어.'
                : '기쁜 일도, 속상한 일도 괜찮아. 편하게 이야기해줘.',
            style: AppTextStyles.body14.copyWith(
              color: AppColors.textOnDarkSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          OngiButton.onDark(
            label: '온기에게 말하기',
            icon: LucideIcons.mic,
            onPressed: connection == BoardConnection.connected ? onStart : null,
          ),
        ],
      ),
    );
  }
}
