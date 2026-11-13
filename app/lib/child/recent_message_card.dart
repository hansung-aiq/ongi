import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../common/common.dart';

/// 자녀가 들은 메시지 한 개 (5-1 최근에 들은 메시지, 3-7 온기기록, 4-3 안내)
class RecentMessage {
  const RecentMessage({
    required this.author,
    required this.situation,
    required this.text,
    required this.heardAt,
    this.messageId,
    this.isVoice = false,
    this.photo,
  });

  /// 엄마 / 아빠
  final String author;
  final String situation;

  /// 글 메시지 내용. 녹음이면 null이고 파형을 보인다.
  final String? text;

  /// '들은 날 · 오늘 · 오후 4:32'
  final String heardAt;

  /// 서버의 메시지 번호. 안내 화면의 예시는 null이다.
  final int? messageId;
  final bool isVoice;

  /// 메시지를 남긴 부모의 사진 경로
  final String? photo;
}

/// 들은 메시지 카드.
class RecentMessageCard extends StatelessWidget {
  const RecentMessageCard({
    super.key,
    required this.message,
    this.highlighted = false,
    this.onPlay,
    this.playing = false,
    this.showPlay = false,
    this.maxLines,
    this.onTap,
    this.letter = false,
  });

  /// 5-7 온기기록: 받은 편지처럼 종이색 바탕, 작은 편지 아이콘, 받은 날 위 점선.
  final bool letter;

  final RecentMessage message;

  /// 4-3 안내처럼 진한 1.5 테두리로 강조한다.
  final bool highlighted;

  /// 있으면 재생 버튼을 눌러 다시 들을 수 있다 (녹음 메시지).
  final VoidCallback? onPlay;

  /// 재생 중이면 버튼이 멈춤으로 바뀌고 파형이 움직인다.
  final bool playing;

  /// [onPlay] 없이 재생 버튼 모양만 보인다 (4-3 안내).
  final bool showPlay;

  /// 글을 이 줄 수까지만 보이고 나머지는 '…'로 줄인다. null이면 다 보인다.
  final int? maxLines;

  /// 카드를 누르면 부른다 (자세히 보기).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary;
    final text = message.text;
    return OngiCard(
      onTap: onTap,
      color: letter ? AppColors.paper : AppColors.surface,
      borderColor: highlighted ? AppColors.textPrimary : AppColors.line,
      borderWidth: highlighted
          ? AppSizes.borderSelected
          : AppSizes.borderDefault,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(size: 44, imagePath: message.photo),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (letter) ...[
                          const Icon(
                            LucideIcons.mail,
                            size: 12,
                            color: AppColors.stampText,
                          ),
                          const SizedBox(width: AppSpacing.s4),
                        ],
                        Text(
                          message.author,
                          style: AppTextStyles.caption12.copyWith(
                            color: secondary,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(message.situation, style: AppTextStyles.label16),
                  ],
                ),
              ),
              if (onPlay != null || showPlay)
                _PlayButton(playing: playing, onPressed: onPlay),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (text != null)
                  Text(
                    text,
                    maxLines: maxLines,
                    overflow: maxLines == null ? null : TextOverflow.ellipsis,
                    style: AppTextStyles.body14.copyWith(color: secondary),
                  )
                else
                  Waveform.small(animate: playing),
                const SizedBox(height: AppSpacing.s12),
                if (letter) ...[
                  const DashedDivider(),
                  const SizedBox(height: AppSpacing.s8),
                ],
                Text(
                  message.heardAt,
                  style: AppTextStyles.caption12.copyWith(color: secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 진한 원형 재생 버튼 (36). [onPressed]가 없으면 모양만 보인다.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = playing ? '멈추기' : '다시 듣기';
    final button = Material(
      color: AppColors.textPrimary,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 36,
          child: Icon(
            playing ? LucideIcons.pause : LucideIcons.play,
            size: 14.4,
            color: AppColors.bgBase,
          ),
        ),
      ),
    );
    if (onPressed == null) return ExcludeSemantics(child: button);
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(message: label, child: button),
    );
  }
}
