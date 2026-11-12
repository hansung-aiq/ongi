import 'package:flutter/material.dart';

import '../api/server_client.dart';
import '../common/common.dart';
import 'privacy_sheet.dart';
import 'role_select_screen.dart';

/// 1-1 로그인.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, this.serverClient});

  /// 시험할 때 가짜 서버로 바꿔 끼운다.
  final ServerClient? serverClient;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary;
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
              const Spacer(flex: 2),
              const Center(child: OngiLogo(size: 80)),
              const SizedBox(height: AppSpacing.s20),
              Text(
                '온기',
                textAlign: TextAlign.center,
                style: AppTextStyles.display40,
              ),
              const SizedBox(height: AppSpacing.s20),

              /// 두 줄이 차례로 떠오른다
              RiseIn(
                delay: const Duration(milliseconds: 150),
                child: Text(
                  '필요한 순간에 닿는\n가장 익숙한 목소리',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body18,
                ),
              ),
              const SizedBox(height: AppSpacing.s20),
              RiseIn(
                delay: const Duration(milliseconds: 450),
                child: Text(
                  '부모의 마음을 남기고, 아이의 오늘을 안아주세요.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body14.copyWith(color: secondary),
                ),
              ),
              const Spacer(flex: 3),
              OngiButton(
                label: '시작하기',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        RoleSelectScreen(serverClient: serverClient),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              Center(
                child: InkWell(
                  onTap: () => showPrivacySheet(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s4,
                    ),
                    child: Text.rich(
                      const TextSpan(
                        children: [
                          TextSpan(text: '시작하면 '),
                          TextSpan(
                            text: '이용약관 및 개인정보 처리방침',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: '에 동의해요.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption12.copyWith(color: secondary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
