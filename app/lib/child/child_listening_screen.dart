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
        /// 숨 쉬듯 커졌다 작아지고 주황 원이 퍼진다
        const MicHalo(breathe: true),
        const SizedBox(height: AppSpacing.s24),
        Text('듣고 있어', style: AppTextStyles.title28),
        const SizedBox(height: AppSpacing.s24),
        Text(
          '${profile.called}, 무슨 일이 있었어?',
          textAlign: TextAlign.center,
          style: AppTextStyles.body16.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s24),
        const Waveform.large(),
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
      centerOpacity: 0.8,
      center: [
        const MicHalo(color: AppColors.micThinking),
        const SizedBox(height: AppSpacing.s24),
        Text('생각하는 중...', style: AppTextStyles.title28),
        const SizedBox(height: AppSpacing.s24),
        Text(
          '네 이야기에 맞는 메시지를 찾고 있어.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body16.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s24),
        const Waveform.large(animate: false, opacity: 0.3),
        const SizedBox(height: 10),

        /// 온기가 받아쓴 내 말이 한 글자씩 나타난다 (짧게, 1.2초 안에)
        TypingText(
          '“$heardText”',
          style: AppTextStyles.body16.copyWith(color: AppColors.textSecondary),
          perChar: const Duration(milliseconds: 45),
          maxDuration: const Duration(milliseconds: 1200),
          delay: const Duration(milliseconds: 200),
        ),
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
