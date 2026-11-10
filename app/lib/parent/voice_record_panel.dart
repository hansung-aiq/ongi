import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../common/common.dart';
import 'voice_recorder.dart';

enum VoiceStage {
  /// 녹음 전: 마이크를 누르면 시작
  ready,

  /// 녹음 중: 파형, 시간, 멈춤 버튼
  recording,

  /// 녹음 후: 다시 듣기, 다시 녹음
  recorded,
}

/// 음성 녹음 칸 (2-4 녹음 전, 2-5 녹음 중, 2-6 녹음 후).
/// 첫 메시지(2-4~2-6)와 메시지 남기기(3-4)가 함께 쓴다.
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
    this.level = 0,
  });

  /// 녹음 중 소리 크기 (0~1). 막대로 보여 준다.
  final double level;

  final VoiceStage stage;

  /// 녹음 중에 지금까지 녹음한 길이
  final Duration elapsed;

  /// 녹음할 수 있는 가장 긴 길이
  final Duration maxDuration;
  final bool playing;

  /// 저장하는 동안은 누를 수 없다.
  final bool enabled;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onPlayToggle;
  final VoidCallback onRetake;

  static const height = 260.0;

  static String format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
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

  static const _gap = SizedBox(height: AppSpacing.s16);

  List<Widget> _ready() => [
    RoundIconButton(
      icon: LucideIcons.mic,
      tooltip: '녹음 시작',
      size: 88,
      iconSize: 48,
      onPressed: enabled ? onStart : null,
    ),
    _gap,
    Text('버튼을 누르고 말해주세요.', style: AppTextStyles.label16),
    const SizedBox(height: AppSpacing.s8),
    Text(
      '천천히, 평소 말투 그대로 괜찮아요.',
      style: AppTextStyles.caption12.copyWith(color: AppColors.textSecondary),
    ),
    const SizedBox(height: AppSpacing.s4),
    Text(
      '최대 ${maxDuration.inSeconds ~/ 60}분까지 녹음할 수 있어요',
      style: AppTextStyles.caption12.copyWith(color: AppColors.textSecondary),
    ),
  ];

  List<Widget> _recording() => [
    Text('녹음 중이에요.', style: AppTextStyles.label16),
    _gap,
    const Waveform.small(),
    const SizedBox(height: AppSpacing.s12),
    _LevelBar(level: level),
    _gap,
    Text(
      '${format(elapsed)} / ${format(maxDuration)}',
      style: AppTextStyles.body16.copyWith(color: AppColors.textSecondary),
    ),
    _gap,
    RoundIconButton(
      icon: Icons.stop_rounded,
      tooltip: '녹음 멈추기',
      size: 64,
      iconSize: 36,
      onPressed: onStop,
    ),
  ];

  List<Widget> _recorded() => [
    Text('녹음을 마쳤어요.', style: AppTextStyles.label16),
    _gap,
    Waveform.small(animate: playing),
    _gap,
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OngiPillButton(
          label: playing ? '멈추기' : '다시 듣기',
          icon: playing ? LucideIcons.pause : LucideIcons.play,
          onPressed: enabled ? onPlayToggle : null,
        ),
        const SizedBox(width: AppSpacing.s8),
        OngiPillButton(label: '다시 녹음', onPressed: enabled ? onRetake : null),
      ],
    ),
  ];
}

/// 녹음 중 소리 크기 막대. 너무 작으면 회색, 들리면 주황.
class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    final loud = level >= LevelMeter.quietPeak;
    return Semantics(
      label: '소리 크기',
      value: '${(level * 100).round()}',
      child: SizedBox(
        width: 160,
        height: 6,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: level,
            backgroundColor: AppColors.line,
            color: loud ? AppColors.accent : AppColors.dotOffline,
          ),
        ),
      ),
    );
  }
}
