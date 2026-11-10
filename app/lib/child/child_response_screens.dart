import 'package:flutter/material.dart';

import '../api/board_signal.dart';
import '../api/situations.dart';
import '../common/common.dart';
import '../config.dart';

String _authorTitle(String? author) =>
    author == 'dad' ? AppConfig.dadTitle : AppConfig.momTitle;

/// 5-4 온기의 공감 한마디.
class ChildEmpathyScreen extends StatelessWidget {
  const ChildEmpathyScreen({
    super.key,
    required this.signal,
    required this.onStop,
    this.parentPhoto,
  });

  final EmpathySignal signal;
  final VoidCallback onStop;

  /// 이어서 들려줄 메시지를 남긴 부모의 사진
  final String? parentPhoto;

  @override
  Widget build(BuildContext context) {
    return _ResponseLayout(
      navTitle: '온기의 메시지',
      picture: const OngiLogo(),
      name: '온기',
      onStop: onStop,
      children: [
        const _Caption('네 이야기를 들었어'),
        const SizedBox(height: AppSpacing.s28),
        const Waveform.small(),
        const SizedBox(height: 10),
        _Heading(signal.text),
        if (signal.hasMessage) ...[
          const SizedBox(height: AppSpacing.s28),
          _NextVoiceChip(
            title: _authorTitle(signal.author),
            photo: parentPhoto,
          ),
        ],
      ],
    );
  }
}

/// 5-5 부모 메시지 재생.
class ChildPlayingScreen extends StatelessWidget {
  const ChildPlayingScreen({
    super.key,
    required this.signal,
    this.parentPhoto,
    required this.onStop,
  });

  final PlayingSignal signal;

  /// 메시지를 남긴 부모의 사진
  final String? parentPhoto;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final title = _authorTitle(signal.author);
    /// 글 메시지는 원문, 녹음 메시지는 보드가 받아쓴 글(신호 규격 v1.1). 비어 있으면 안 보인다.
    final text = (signal.text?.trim().isEmpty ?? true) ? null : signal.text;
    return _ResponseLayout(
      navTitle: '$title의 메시지',
      picture: ProfileAvatar(size: 96, imagePath: parentPhoto),
      name: title,
      onStop: onStop,
      children: [
        const SizedBox(height: AppSpacing.s16),
        _Caption(situationNames[signal.situationId] ?? ''),
        const SizedBox(height: 10),
        const Waveform.small(),
        if (text != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
            child: Text(
              keepWords(text),
              textAlign: TextAlign.center,
              style: AppTextStyles.body18.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 5-6 맞는 메시지 없음. 안전 응답도 같은 모양을 쓴다.
class ChildNoMessageScreen extends StatelessWidget {
  const ChildNoMessageScreen({
    super.key,
    required this.text,
    this.detail,
    required this.onStop,
  });

  final String text;
  final String? detail;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return _ResponseLayout(
      navTitle: '온기의 메시지',
      picture: const OngiLogo(),
      name: '온기',
      onStop: onStop,
      children: [
        const _Caption('네 이야기를 들었어'),
        const SizedBox(height: AppSpacing.s28),
        const Waveform.small(),
        const SizedBox(height: 10),
        _Heading(text),
        if (detail != null) ...[const SizedBox(height: 10), _Caption(detail!)],
      ],
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: AppTextStyles.body14.copyWith(color: AppColors.textSecondary),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      keepWords(text),
      textAlign: TextAlign.center,
      style: AppTextStyles.heading20,
    );
  }
}

class _NextVoiceChip extends StatelessWidget {
  const _NextVoiceChip({required this.title, this.photo});

  final String title;
  final String? photo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.bgSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProfileAvatar(size: 28, imagePath: photo),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              '이어서 $title의 메시지를 들려줄게',
              style: AppTextStyles.label13.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponseLayout extends StatelessWidget {
  const _ResponseLayout({
    required this.navTitle,
    required this.picture,
    required this.name,
    required this.onStop,
    required this.children,
  });

  final String navTitle;
  final Widget picture;
  final String name;
  final VoidCallback onStop;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              TopNavBar(title: navTitle, onClose: onStop),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    top: 50,
                    bottom: AppSpacing.s16,
                  ),
                  child: Column(
                    children: [
                      picture,
                      const SizedBox(height: AppSpacing.s12),
                      Text(name, style: AppTextStyles.title28),
                      const SizedBox(height: AppSpacing.s12),
                      ...children,
                    ],
                  ),
                ),
              ),
              OngiButton(label: '그만 들을래', onPressed: onStop),
            ],
          ),
        ),
      ),
    );
  }
}
