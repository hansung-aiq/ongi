import 'package:flutter/material.dart';

import '../common/common.dart';

/// 1-1 '이용약관 및 개인정보 처리방침'을 누르면 올라오는 안내.
/// 정식 약관이 아니라 시연용 앱이 어떤 정보를 어디에 두는지 알려 주는 요약이다.
Future<void> showPrivacySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgBase,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final body = AppTextStyles.body14.copyWith(color: AppColors.textSecondary);
      Widget item(String title, String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.label16),
            const SizedBox(height: AppSpacing.s4),
            Text(text, style: body),
          ],
        ),
      );
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.s12,
              AppSpacing.screenHorizontal,
              AppSpacing.s20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: SheetHandle()),
                const SizedBox(height: AppSpacing.s20),
                Text('이용약관 및 개인정보 처리방침', style: AppTextStyles.subtitle18),
                const SizedBox(height: AppSpacing.s4),
                Text('한성대학교 모바일시스템응용프로젝트 시연용 앱이에요.', style: body),
                const SizedBox(height: AppSpacing.s20),
                item(
                  '부모가 남긴 메시지',
                  '글과 녹음은 온기 서버에 저장되고, 아이의 온기 스피커로 전달돼요. 설정에서 언제든 지울 수 있어요.',
                ),
                item(
                  '아이의 이야기',
                  '아이가 스피커에 한 말은 스피커 안에서만 알아듣고 서버로 보내지 않아요. 어떤 메시지를 들었는지(재생 기록)만 서버에 남아요.',
                ),
                item(
                  '이 기기에 두는 것',
                  '아이 이름, 부모 호칭, 프로필 사진은 이 폰에만 저장돼요. 설정 > 이 기기 처음 상태로에서 지울 수 있어요.',
                ),
                const SizedBox(height: AppSpacing.s8),
                OngiButton.secondary(
                  label: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
