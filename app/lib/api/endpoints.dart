import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// 서버·보드 주소. 처음에는 [AppConfig]의 값이고, 3-6 설정 > 연결 주소에서 바꾸면
/// 기기에 저장해 다음부터 그 값을 쓴다. 다시 빌드하지 않고 시연 장소의 IP에 맞출 수 있다.
class Endpoints {
  Endpoints._();

  static const _serverKey = 'endpoint_server';
  static const _boardKey = 'endpoint_board';

  static String serverUrl = AppConfig.serverUrl;
  static String boardWsUrl = AppConfig.boardWsUrl;

  /// 기본값과 다른 주소를 쓰고 있으면 true
  static bool get customized =>
      serverUrl != AppConfig.serverUrl || boardWsUrl != AppConfig.boardWsUrl;

  /// 앱을 켤 때 한 번 부른다.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    serverUrl = prefs.getString(_serverKey) ?? AppConfig.serverUrl;
    boardWsUrl = prefs.getString(_boardKey) ?? AppConfig.boardWsUrl;
  }

  static Future<void> save({
    required String server,
    required String board,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    serverUrl = _trimSlash(server.trim());
    boardWsUrl = _trimSlash(board.trim());
    await prefs.setString(_serverKey, serverUrl);
    await prefs.setString(_boardKey, boardWsUrl);
  }

  /// 빌드할 때 정한 기본 주소로 되돌린다.
  static Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverKey);
    await prefs.remove(_boardKey);
    serverUrl = AppConfig.serverUrl;
    boardWsUrl = AppConfig.boardWsUrl;
  }

  /// 서버 주소 확인. 맞으면 null, 틀리면 안내 문구.
  static String? checkServer(String value) =>
      _check(value, const {'http', 'https'}, 'http://192.168.0.20:8000');

  /// 보드 주소 확인. 맞으면 null, 틀리면 안내 문구.
  static String? checkBoard(String value) =>
      _check(value, const {'ws', 'wss'}, 'ws://192.168.0.10:8765');

  static String? _check(String value, Set<String> schemes, String example) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !schemes.contains(uri.scheme) || uri.host.isEmpty) {
      return '$example 모양으로 적어 주세요';
    }
    return null;
  }

  static String _trimSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
