import 'package:flutter/material.dart';

import '../common/common.dart';
import '../parent/parent_profile.dart';

/// 5-2 듣는 중.
class ChildListeningScreen extends StatelessWidget {
  const ChildListeningScreen({
    super.key,
    required this.profile,
    required this.onStop,
  });

  /// 부모가 첫 설정에서 저장한 이름·호칭
  final ParentProfile profile;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return _SpeakingLayout(
      onStop: onStop,
      center: [
        /// 11/23 온기 빛 구슬: 빛 물결이 바깥으로 퍼지며 듣는다
        const OngiOrb(size: 240, mood: OrbMood.listening),
        const SizedBox(height: AppSpacing.s16),
        Text('듣고 있어', style: AppTextStyles.title28),
        const SizedBox(height: AppSpacing.s12),
        Text(
          '${profile.called}, 무슨 일이 있었어?',
          textAlign: TextAlign.center,
          style: AppTextStyles.body16.copyWith(color: AppColors.textSecondary),
        ),
      ],
      bottom: [
        Text(
          '잠깐 멈춰도 괜찮아. 천천히 말해줘.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption12.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        OngiButton(label: '말하기 끝내기', onPressed: onStop),
      ],
    );
  }
}

/// 5-3 생각하는 중.
class ChildThinkingScreen extends StatelessWidget {
  const ChildThinkingScreen({
    super.key,
    required this.heardText,
    required this.onStop,
  });

  final String heardText;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return _SpeakingLayout(
      onStop: onStop,
      center: [
        /// 11/23 작은 빛이 구슬 둘레를 돌며 생각한다
        const OngiOrb(size: 240, mood: OrbMood.thinking),
        const SizedBox(height: AppSpacing.s16),
        Text('생각하는 중...', style: AppTextStyles.title28),
        const SizedBox(height: AppSpacing.s12),
        Text(
          '네 이야기에 맞는 메시지를 찾고 있어.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body16.copyWith(color: AppColors.textSecondary),
        ),
        if (heardText.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s24),

          /// 온기가 받아쓴 내 말: 말풍선 안에 가운데로 한 글자씩 (짧게, 1.2초 안에)
          Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s20,
              vertical: AppSpacing.s12,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.line),
            ),
            child: TypingText(
              heardText.trim(),
              style: AppTextStyles.body16.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
              perChar: const Duration(milliseconds: 45),
              maxDuration: const Duration(milliseconds: 1200),
              delay: const Duration(milliseconds: 200),
            ),
          ),
        ],
      ],
      bottom: [
        Text(
          '잠깐만 기다려줘.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption12.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SpeakingLayout extends StatelessWidget {
  const _SpeakingLayout({
    required this.onStop,
    required this.center,
    required this.bottom,
    this.centerOpacity = 1,
  });

  final VoidCallback onStop;
  final List<Widget> center;
  final List<Widget> bottom;
  final double centerOpacity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSoft,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.s8,
            AppSpacing.screenHorizontal,
            AppSpacing.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TopNavBar(title: '온기에게 말하기', onClose: onStop),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Opacity(
                      opacity: centerOpacity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: center,
                      ),
                    ),
                  ),
                ),
              ),
              ...bottom,
            ],
          ),
        ),
      ),
    );
  }
}
