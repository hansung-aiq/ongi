import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/board_client.dart';
import '../common/common.dart';
import '../parent/parent_profile.dart';
import 'profile_edit_sheet.dart';

/// 3-6 설정. 부모 앱과 자녀 앱이 함께 쓴다.
/// 스피커 상태는 보드와 연결하는 자녀 앱에서만 보인다.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.profile,
    required this.isParent,
    required this.onProfileChanged,
    required this.onChangeMode,
    this.onDeleteAllMessages,
    this.onResetDevice,
    this.speaker,
    this.pickPhoto = pickProfilePhoto,
  });

  final ParentProfile profile;

  /// 부모 앱이면 true, 자녀 앱이면 false
  final bool isParent;

  /// 프로필을 바꿔 기기에 저장한 뒤 부른다.
  final ValueChanged<ParentProfile> onProfileChanged;

  /// '사용 모드'를 누르면 부른다 (1-2 역할 선택으로 간다).
  final VoidCallback onChangeMode;

  /// '메시지 모두 지우기'를 확인하면 부른다. null이면 줄을 숨긴다 (자녀 앱).
  final Future<void> Function()? onDeleteAllMessages;

  /// '이 기기 처음 상태로'를 확인하면 부른다. null이면 줄을 숨긴다.
  final Future<void> Function()? onResetDevice;

  /// 보드 연결 상태. null이면 스피커 구역을 숨긴다 (부모 앱).
  final BoardConnection? speaker;

  /// 시험할 때 가짜 사진 고르기로 바꿔 끼운다.
  final PhotoPicker pickPhoto;

  Future<void> _edit(BuildContext context, ProfileTarget target) async {
    final updated = await showProfileEditSheet(
      context,
      profile: profile,
      target: target,
      pickPhoto: pickPhoto,
    );
    if (updated == null) return;
    await OnboardingPrefs.saveProfile(updated);
    onProfileChanged(updated);
  }

  /// 지우기 전에 한 번 더 묻는다. '지우기'를 누르면 true.
  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgBase,
        title: Text(title, style: AppTextStyles.subtitle18),
        content: Text(
          body,
          style: AppTextStyles.body14.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              '취소',
              style: AppTextStyles.label16.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              action,
              style: AppTextStyles.label16.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _deleteAll(BuildContext context) async {
    final ok = await _confirm(
      context,
      title: '메시지를 모두 지울까요?',
      body: '남긴 메시지가 모두 지워지고 스피커에서도 빠져요. 되돌릴 수 없어요.',
      action: '모두 지우기',
    );
    if (ok) await onDeleteAllMessages!();
  }

  Future<void> _reset(BuildContext context) async {
    final ok = await _confirm(
      context,
      title: '이 기기를 처음 상태로 돌릴까요?',
      body: '이 기기에 저장한 이름·호칭·사진과 첫 설정 기록을 지우고 시작 화면으로 가요. '
          '서버에 남긴 메시지는 그대로예요.',
      action: '처음 상태로',
    );
    if (ok) await onResetDevice!();
  }

  @override
  Widget build(BuildContext context) {
    final speaker = this.speaker;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.s8,
        AppSpacing.screenHorizontal,
        AppSpacing.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TopNavBar(title: '설정'),
          const SizedBox(height: AppSpacing.section),
          _Section(
            title: '프로필',
            rows: [
              _SettingRow(
                leading: ProfileAvatar(size: 44, imagePath: profile.childPhoto),
                title: profile.childName,
                subtitle: isParent ? '자녀 · 이름과 사진 바꾸기' : '나 · 이름과 사진 바꾸기',
                onTap: () => _edit(context, ProfileTarget.child),
              ),
              _SettingRow(
                leading: ProfileAvatar(
                  size: 44,
                  imagePath: profile.parentPhoto,
                ),
                title: profile.title,
                subtitle: isParent ? '나 · 호칭과 사진 바꾸기' : '부모 · 호칭과 사진 바꾸기',
                onTap: () => _edit(context, ProfileTarget.parent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '사진은 자녀 화면에서 메시지와 함께 보여요.',
            style: AppTextStyles.caption12.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (speaker != null) ...[
            const SizedBox(height: AppSpacing.section),
            _Section(
              title: '스피커',
              rows: [
                _SettingRow(
                  title: '온기 스피커',
                  subtitle: '스피커 연결 상태예요',
                  trailing: _SpeakerStatus(
                    connected: speaker == BoardConnection.connected,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          _Section(
            title: '이 기기',
            rows: [
              _SettingRow(
                title: '사용 모드',
                subtitle: '부모용과 자녀용 중에서 골라요',
                value: isParent ? '부모' : '자녀',
                onTap: onChangeMode,
              ),
            ],
          ),
          if (onDeleteAllMessages != null || onResetDevice != null) ...[
            const SizedBox(height: AppSpacing.section),
            _Section(
              title: '데이터',
              rows: [
                if (onDeleteAllMessages != null)
                  _SettingRow(
                    title: '메시지 모두 지우기',
                    subtitle: '남긴 메시지를 한 번에 지워요',
                    titleColor: AppColors.error,
                    onTap: () => _deleteAll(context),
                  ),
                if (onResetDevice != null)
                  _SettingRow(
                    title: '이 기기 처음 상태로',
                    subtitle: '이름·호칭·사진과 첫 설정 기록을 지워요',
                    titleColor: AppColors.error,
                    onTap: () => _reset(context),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 구역 이름 + 줄들을 담은 카드. 줄 사이에는 구분선을 넣는다.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppTextStyles.label14),
        const SizedBox(height: 10),
        OngiCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.line),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 설정 한 줄. [onTap]이 있으면 오른쪽에 화살표를 보인다.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    this.leading,
    this.value,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  final String title;

  /// 지우기처럼 조심해야 하는 줄은 붉은 글자로 보인다.
  final Color? titleColor;
  final String subtitle;
  final Widget? leading;

  /// 오른쪽에 보이는 지금 값 ('부모')
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.s12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: titleColor == null
                      ? AppTextStyles.label16
                      : AppTextStyles.label16.copyWith(color: titleColor),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  subtitle,
                  style: AppTextStyles.caption12.copyWith(
                    color: secondary,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: AppSpacing.s12),
            Text(
              value!,
              style: AppTextStyles.body14.copyWith(color: secondary),
            ),
          ],
          ?trailing,
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.s12),
            Icon(
              LucideIcons.chevronRight,
              size: AppSizes.iconSmall,
              color: secondary,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// 주황(연결됨)·회색(연결 안 됨) 점 + 글자
class _SpeakerStatus extends StatelessWidget {
  const _SpeakerStatus({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: AppSpacing.s12),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: connected ? AppColors.accent : AppColors.dotOffline,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          connected ? '연결됨' : '연결 안 됨',
          style: AppTextStyles.body14.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
