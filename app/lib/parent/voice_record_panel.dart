import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../common/common.dart';

enum VoiceStage {
  /// 녹음 전: 마이크를 누르면 시작
  ready,

  /// 녹음 중: 파형, 시간, 멈춤 버튼
  recording,

  /// 녹음 후: 다시 듣기, 다시 녹음
  recorded,
}

/// 3-4 음성 녹음 탭의 입력 칸. 상태와 버튼 동작은 화면이 정한다.
class VoiceRecordPanel extends StatelessWidget {
  const VoiceRecordPanel({
    super.key,
    required this.stage,
    required this.elapsed,
    required this.maxDuration,
    required this.playing,
    required this.enabled,
    required this.onStart,
    required this.onStop,
    required this.onPlayToggle,
    required this.onRetake,
  });

  final VoiceStage stage;

  /// 녹음 중이면 지금까지, 녹음 후면 녹음한 길이
  final Duration elapsed;
  final Duration maxDuration;
  final bool playing;

  /// 저장하는 동안은 누를 수 없다.
  final bool enabled;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onPlayToggle;
  final VoidCallback onRetake;

  static String format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: switch (stage) {
          VoiceStage.ready => _ready(),
          VoiceStage.recording => _recording(),
          VoiceStage.recorded => _recorded(),
        },
      ),
    );
  }

  TextStyle get _secondary =>
      AppTextStyles.caption12.copyWith(color: AppColors.textSecondary);

  List<Widget> _ready() => [
    Semantics(
      button: true,
      label: '녹음 시작',
      child: GestureDetector(
        onTap: enabled ? onStart : null,
        child: const MicHalo(size: 120),
      ),
    ),
    const SizedBox(height: AppSpacing.s16),
    Text('마이크를 눌러 녹음을 시작하세요', style: AppTextStyles.label14),
    const SizedBox(height: AppSpacing.s4),
    Text('최대 ${maxDuration.inSeconds ~/ 60}분까지 녹음할 수 있어요', style: _secondary),
  ];

  List<Widget> _recording() => [
    const Waveform.large(),
    const SizedBox(height: AppSpacing.s16),
    Text(
      '${format(elapsed)} / ${format(maxDuration)}',
      style: AppTextStyles.label16,
    ),
    const SizedBox(height: AppSpacing.s16),
    _RoundButton(icon: LucideIcons.square, tooltip: '녹음 멈추기', onTap: onStop),
  ];

  List<Widget> _recorded() => [
    Waveform.small(animate: playing),
    const SizedBox(height: AppSpacing.s16),
    Text('${format(elapsed)} 녹음했어요', style: AppTextStyles.label16),
    const SizedBox(height: AppSpacing.s16),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundButton(
          icon: playing ? LucideIcons.pause : LucideIcons.play,
          tooltip: playing ? '멈추기' : '다시 듣기',
          onTap: enabled ? onPlayToggle : null,
        ),
        const SizedBox(width: AppSpacing.s16),
        TextButton.icon(
          onPressed: enabled ? onRetake : null,
          icon: const Icon(LucideIcons.rotateCcw, size: AppSizes.iconSmall),
          label: const Text('다시 녹음'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            textStyle: AppTextStyles.label14,
          ),
        ),
      ],
    ),
  ];
}

/// 멈춤·재생에 쓰는 진한 원형 버튼
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? AppSizes.disabledOpacity : 1,
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        iconSize: 20,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: AppColors.bgBase,
          disabledBackgroundColor: AppColors.textPrimary,
          disabledForegroundColor: AppColors.bgBase,
          fixedSize: const Size.square(AppSizes.buttonHeight),
        ),
        icon: Icon(icon),
      ),
    );
  }
}
