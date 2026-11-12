import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import '../common/common.dart';
import '../config.dart';
import '../parent/parent_profile.dart';

/// 사진을 고르고 기기에 보관한 경로를 돌려준다. 고르지 않으면 null이다.
typedef PhotoPicker = Future<String?> Function();

/// 사진첩에서 사진을 골라 앱 폴더에 복사한다 (임시 파일은 지워질 수 있어서).
Future<String?> pickProfilePhoto() async {
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
  } on Exception {
    return null;
  }
  if (file == null) return null;
  final dir = await getApplicationDocumentsDirectory();
  final path =
      '${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
  await file.saveTo(path);
  return path;
}

/// 어느 프로필을 고치는지
enum ProfileTarget { child, parent }

/// 프로필 수정 창 (3-6에서 프로필 줄을 누르면 아래에서 올라온다).
/// 자녀는 이름과 사진, 부모는 호칭(엄마/아빠)과 사진을 바꾼다.
/// 저장하면 바뀐 프로필을, 닫으면 null을 돌려준다.
Future<ParentProfile?> showProfileEditSheet(
  BuildContext context, {
  required ParentProfile profile,
  required ProfileTarget target,
  PhotoPicker pickPhoto = pickProfilePhoto,
}) {
  return showModalBottomSheet<ParentProfile>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgBase,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ProfileEditSheet(
      profile: profile,
      target: target,
      pickPhoto: pickPhoto,
    ),
  );
}

class _ProfileEditSheet extends StatefulWidget {
  const _ProfileEditSheet({
    required this.profile,
    required this.target,
    required this.pickPhoto,
  });

  final ParentProfile profile;
  final ProfileTarget target;
  final PhotoPicker pickPhoto;

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  late final _name = TextEditingController(text: widget.profile.childName);
  late String _author = widget.profile.author;
  late String? _photo = _isChild
      ? widget.profile.childPhoto
      : widget.profile.parentPhoto;

  static const _authors = ['mom', 'dad'];

  bool get _isChild => widget.target == ProfileTarget.child;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final path = await widget.pickPhoto();
    if (path != null && mounted) setState(() => _photo = path);
  }

  void _save() {
    final p = widget.profile;
    Navigator.of(context).pop(
      _isChild
          ? p.copyWith(
              childName: _name.text.trim(),
              childPhoto: _photo,
              clearChildPhoto: _photo == null,
            )
          : p.copyWith(
              author: _author,
              parentPhoto: _photo,
              clearParentPhoto: _photo == null,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_isChild || _name.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
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
              const SizedBox(height: AppSpacing.s12),
              Text(
                _isChild ? '자녀 프로필' : '부모 프로필',
                style: AppTextStyles.subtitle18,
              ),
              const SizedBox(height: AppSpacing.s20),
              Center(child: ProfileAvatar(size: 96, imagePath: _photo)),
              const SizedBox(height: AppSpacing.s12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  OngiPillButton(
                    label: _photo == null ? '사진 등록' : '사진 바꾸기',
                    icon: LucideIcons.image,
                    onPressed: _choosePhoto,
                  ),
                  if (_photo != null)
                    OngiPillButton(
                      label: '사진 지우기',
                      onPressed: () => setState(() => _photo = null),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s24),
              if (_isChild)
                LabeledField(
                  label: '자녀 이름',
                  child: OngiTextField(
                    controller: _name,
                    hintText: '이름을 입력해 주세요',
                    maxLength: 10,
                  ),
                )
              else
                LabeledField(
                  label: '아이가 부르는 호칭',
                  child: OngiChoiceGroup(
                    options: const [AppConfig.momTitle, AppConfig.dadTitle],
                    selectedIndex: _authors.indexOf(_author),
                    onChanged: (i) => setState(() => _author = _authors[i]),
                  ),
                ),
              const SizedBox(height: AppSpacing.s24),
              OngiButton(label: '저장하기', onPressed: canSave ? _save : null),
            ],
          ),
        ),
      ),
    );
  }
}
