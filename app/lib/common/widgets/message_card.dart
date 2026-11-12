import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_text_styles.dart';
import 'ongi_card.dart';
import 'ongi_chip.dart';
import 'waveform.dart';

/// 저장된 메시지를 보여 주는 카드.
class MessageCard extends StatelessWidget {
  const MessageCard({
    super.key,
    required this.title,
    this.category,
    this.body,
    this.bodyMaxLines = 1,
    required this.typeLabel,
    required this.typeIcon,
    this.statusLabel,
    this.statusMuted = false,
    required this.date,
    this.onTap,
    this.onMore,
    this.onPlay,
    this.playing = false,
    this.highlighted = false,
  });

  final String title;

  /// 없으면 분류 줄을 숨긴다.
  final String? category;

  /// 없으면 본문 줄을 숨긴다 (녹음 메시지).
  final String? body;

  /// 본문을 이 줄 수까지만 보여 주고 나머지는 '…'로 줄인다.
  final int bodyMaxLines;
  final String typeLabel;
  final IconData typeIcon;

  /// 전달 상태 칩 ('전달됨', '전달 대기'). 없으면 숨긴다.
  final String? statusLabel;

  /// 아직 전달되지 않은 상태처럼 흐리게 보인다.
  final bool statusMuted;
  final String date;
  final VoidCallback? onTap;

  /// 없으면 더보기 버튼을 숨긴다.
  final VoidCallback? onMore;

  /// 있으면 날짜 옆에 작은 파형과 재생 버튼을 보인다 (녹음 메시지).
  final VoidCallback? onPlay;

  /// 재생 중이면 파형이 움직이고 버튼이 멈춤으로 바뀐다.
  final bool playing;

  /// 6-2처럼 메뉴를 연 카드를 붉은 테두리로 표시한다.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final secondary = AppTextStyles.caption12.copyWith(
      color: AppColors.textSecondary,
    );
    return OngiCard(
      onTap: onTap,
      color: highlighted ? AppColors.errorTint : AppColors.surface,
      borderColor: highlighted ? AppColors.error : AppColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.label16),
                    if (category != null) ...[
                      const SizedBox(height: AppSpacing.s4),
                      Text(category!, style: secondary),
                    ],
                  ],
                ),
              ),
              if (onMore != null)
                IconButton(
                  onPressed: onMore,
                  tooltip: '더보기',
                  icon: const Icon(LucideIcons.ellipsis),
                  iconSize: AppSizes.iconNav,
                  color: AppColors.textPrimary,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (body != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(
              body!,
              maxLines: bodyMaxLines,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body14.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s12),

          /// 한 줄에 다 들어가지 않으면 날짜만 아래 줄로 내린다.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OngiChip(label: typeLabel, icon: typeIcon),
                    if (statusLabel != null) ...[
                      const SizedBox(width: AppSpacing.s8),
                      Opacity(
                        opacity: statusMuted ? AppSizes.disabledOpacity : 1,
                        child: OngiChip(label: statusLabel!),
                      ),
                    ],
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onPlay != null) ...[
                      Waveform.mini(animate: playing),
                      const SizedBox(width: AppSpacing.s12),
                    ],
                    Text(date, style: secondary),
                    if (onPlay != null) ...[
                      const SizedBox(width: AppSpacing.s12),
                      _PlayButton(playing: playing, onPressed: onPlay!),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 녹음 메시지를 다시 듣는 작은 진한 원형 버튼
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback onPressed;

  static const _size = 30.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: playing ? '멈추기' : '다시 듣기',
      child: Tooltip(
        message: playing ? '멈추기' : '다시 듣기',
        child: Material(
          color: AppColors.textPrimary,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: _size,
              child: Icon(
                playing ? LucideIcons.pause : LucideIcons.play,
                size: 12,
                color: AppColors.bgBase,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
