import 'package:flutter/material.dart';

import '../../api/endpoints.dart';
import '../../api/server_client.dart';
import '../../common/common.dart';
import '../../config.dart';
import '../parent_store.dart';
import '../voice_recorder.dart';
import 'first_message_intro_screen.dart';
import 'onboarding_session.dart';

/// 2-1 자녀 정보 설정
/// 첫 설정 동안 쓸 서버 데이터([ParentStore])를 이 화면이 가진다.
class ChildInfoScreen extends StatefulWidget {
  const ChildInfoScreen({super.key, this.serverClient, this.recorderFactory});

  final ServerClient? serverClient;

  final VoiceRecorder Function()? recorderFactory;

  static const maxNameLength = 10;

  @override
  State<ChildInfoScreen> createState() => _ChildInfoScreenState();
}

class _ChildInfoScreenState extends State<ChildInfoScreen> {
  late final ServerClient _client =
      widget.serverClient ?? ServerClient(baseUrl: Endpoints.serverUrl);
  late final ParentStore _store = ParentStore(
    client: _client,
    familyId: AppConfig.familyId,
  )..load();

  final _name = TextEditingController();

  /// 0: 엄마, 1: 아빠
  int _title = 0;

  static const _authors = ['mom', 'dad'];

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _store.dispose();
    if (widget.serverClient == null) _client.close();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    final session = OnboardingSession(
      store: _store,
      profile: ParentProfile(
        childName: _name.text.trim(),
        author: _authors[_title],
      ),
      recorderFactory: widget.recorderFactory ?? DeviceVoiceRecorder.new,
      serverClient: widget.serverClient,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FirstMessageIntroScreen(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      header: TopNavBar(
        title: '온기',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        OngiButton(
          label: '다음',
          onPressed: _name.text.trim().isEmpty ? null : _next,
        ),
      ],
      children: [
        const Padding(
          padding: EdgeInsets.only(top: AppSpacing.s24),
          child: PageHeading(
            title: '아이를 알려주세요.',
            description: '메시지에 담길 이름과 호칭이에요.',
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        LabeledField(
          label: '자녀 이름',
          child: OngiTextField(
            controller: _name,
            hintText: '이름을 입력해 주세요',
            maxLength: ChildInfoScreen.maxNameLength,
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        LabeledField(
          label: '아이가 부르는 호칭',
          child: OngiChoiceGroup(
            options: [AppConfig.momTitle, AppConfig.dadTitle],
            selectedIndex: _title,
            onChanged: (i) => setState(() => _title = i),
          ),
        ),
      ],
    );
  }
}
