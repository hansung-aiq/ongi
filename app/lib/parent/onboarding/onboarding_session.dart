import '../../api/server_client.dart';
import '../parent_profile.dart';
import '../parent_store.dart';
import '../voice_recorder.dart';

export '../parent_profile.dart';

/// 2-2~2-7 화면이 함께 쓰는 값. 2-1이 만들어 다음 화면에 넘긴다.
class OnboardingSession {
  const OnboardingSession({
    required this.store,
    required this.profile,
    required this.recorderFactory,
    this.serverClient,
  });

  final ParentStore store;
  final ParentProfile profile;
  final VoiceRecorder Function() recorderFactory;

  /// 시험할 때 쓰는 가짜 서버. 마친 뒤 부모 홈에도 넘긴다.
  final ServerClient? serverClient;
}
