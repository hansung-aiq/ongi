import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/board_client.dart';
import '../common/common.dart';
import '../config.dart';
import 'recent_message_card.dart';

/// 5-1 자녀 홈, 6-1 연결 안 됨.
class ChildHomeScreen extends StatelessWidget {
  const ChildHomeScreen({
    super.key,
    required this.connection,
    required this.notice,
    required this.onStart,
  });

  final BoardConnection connection;
  final String? notice;
  final VoidCallback onStart;

  bool get _offline => connection == BoardConnection.disconnected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomTabBar(
        items: const [
          BottomTabItem(icon: LucideIcons.house, label: '홈'),
          BottomTabItem(icon: LucideIcons.audioLines, label: '온기기록'),
          BottomTabItem(icon: LucideIcons.settings, label: '설정'),
        ],
        currentIndex: 0,
        onTap: (_) {},
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
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
              for (final message in sampleRecentMessages) ...[
                RecentMessageCard(message: message),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
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
                  Text(
                    '안녕, ${AppConfig.childCalled}!',
                    style: AppTextStyles.title28,
                  ),
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
            const ProfileAvatar(size: 52),
          ],
        ),
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
