import 'package:flutter/material.dart';

import '../common/common.dart';
import 'parent_store.dart';
import 'progress_card.dart';

/// 3-5에서 고른 행동
enum SaveDoneAction {
  /// 메시지 더 남기기 → 메시지 목록
  more,

  /// 완료 → 부모 홈
  done,
}

/// 3-5 저장 완료
class SaveDoneScreen extends StatelessWidget {
  const SaveDoneScreen({super.key, required this.store});

  final ParentStore store;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary;
    final title = store.profile.title;
    final nickname = store.profile.nickname;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.s8,
            AppSpacing.screenHorizontal,
            AppSpacing.s32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TopNavBar(title: '저장 완료'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 58),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: OngiLogo(size: 96)),
                      const SizedBox(height: AppSpacing.section),
                      Text(
                        '메시지를 남겼어요',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.title28,
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Text(
                        '$nickname가 필요한 순간,\n$title의 마음을 그대로 전해드릴게요.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body16.copyWith(color: secondary),
                      ),
                      const SizedBox(height: AppSpacing.section),
                      ProgressCard(progress: store.progress),
                      const SizedBox(height: AppSpacing.section),
                      Text(
                        '$nickname를 위한 온기가 차곡차곡 쌓이고 있어요.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body14.copyWith(color: secondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              OngiButton(
                label: '메시지 더 남기기',
                onPressed: () => Navigator.of(context).pop(SaveDoneAction.more),
              ),
              const SizedBox(height: 10),
              OngiButton.secondary(
                label: '완료',
                onPressed: () => Navigator.of(context).pop(SaveDoneAction.done),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
