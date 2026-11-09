import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/server_client.dart';
import '../child/child_screen.dart';
import '../child/onboarding/child_onboarding.dart';
import '../child/onboarding/child_welcome_screen.dart';
import '../common/common.dart';
import '../parent/onboarding/child_info_screen.dart';
import '../parent/parent_shell.dart';

enum _Role { parent, child }

/// 1-2 역할 선택. 부모는 부모 홈(3-1), 자녀는 자녀 홈(5-1)으로 간다.
/// 부모를 처음 고르면 첫 설정(2-1~2-7), 자녀를 처음 고르면 첫 안내(4-1~4-4)를 먼저 한다.
class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key, this.serverClient});

  /// 시험할 때 가짜 서버로 바꿔 끼운다.
  final ServerClient? serverClient;

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  _Role? _role;

  Future<void> _start() async {
    /// 부모를 처음 고르면 첫 설정(2-1)부터 한다. 뒤로 가면 이 화면으로 돌아온다.
    if (_role == _Role.parent && !await OnboardingPrefs.isDone()) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChildInfoScreen(serverClient: widget.serverClient),
        ),
      );
      return;
    }

    /// 자녀를 처음 고르면 첫 안내(4-1)부터 한다. 뒤로 가면 이 화면으로 돌아온다.
    if (_role == _Role.child && !await ChildOnboardingPrefs.isDone()) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChildWelcomeScreen(serverClient: widget.serverClient),
        ),
      );
      return;
    }
    final profile = await OnboardingPrefs.loadProfile();
    if (!mounted) return;
    final Widget next = switch (_role!) {
      _Role.parent => ParentShell(
        serverClient: widget.serverClient,
        profile: profile,
      ),
      _Role.child => ChildScreen(
        serverClient: widget.serverClient,
        profile: profile,
      ),
    };
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => next),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
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
              TopNavBar(
                title: '온기',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('이 기기는 누가 쓰나요?', style: AppTextStyles.title28),
                      const SizedBox(height: AppSpacing.s12),
                      Text(
                        '온기를 어떻게 사용하실지 알려주세요.\n각자의 자리에서 마음을 나눌 수 있어요.',
                        style: AppTextStyles.body16.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 40),
                      _RoleCard(
                        icon: LucideIcons.heartHandshake,
                        title: '부모',
                        subtitle: '아이에게 들려줄 마음을 남겨요',
                        selected: _role == _Role.parent,
                        onTap: () => setState(() => _role = _Role.parent),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      _RoleCard(
                        icon: LucideIcons.headphones,
                        title: '자녀',
                        subtitle: '부모님이 남긴 마음을 들어요',
                        selected: _role == _Role.child,
                        onTap: () => setState(() => _role = _Role.child),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              OngiButton(
                label: '시작하기',
                onPressed: _role == null ? null : _start,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 역할 카드.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: OngiCard(
        onTap: onTap,
        color: selected ? AppColors.bgSoft : AppColors.surface,
        borderColor: selected ? AppColors.textPrimary : AppColors.line,
        borderWidth: selected
            ? AppSizes.borderSelected
            : AppSizes.borderDefault,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s20,
          vertical: 34,
        ),
        child: Row(
          children: [
            Icon(icon, size: 30, color: AppColors.textPrimary),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.heading20),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    subtitle,
                    style: AppTextStyles.body14.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
            Icon(
              selected ? LucideIcons.circleCheck : LucideIcons.circle,
              size: AppSizes.iconNav,
              color: selected ? AppColors.accent : AppColors.line,
            ),
          ],
        ),
      ),
    );
  }
}
