import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/io.dart';

import 'board_signal.dart';

enum BoardConnection { connecting, connected, disconnected }

typedef BoardConnector = Future<StreamChannel<dynamic>> Function(Uri url);

/// 보드와 WebSocket으로 연결한다. 끊기면 3초마다 다시 연결한다.
class BoardClient {
  BoardClient({
    required this.url,
    required this.onConnection,
    required this.onSignal,
    BoardConnector? connector,
    this.retryDelay = const Duration(seconds: 3),
  }) : _connector = connector ?? _connectWebSocket;

  final Uri url;
  final void Function(BoardConnection connection) onConnection;
  final void Function(BoardSignal signal) onSignal;
  final Duration retryDelay;
  final BoardConnector _connector;
  final Clock _clock = clock;

  StreamChannel<dynamic>? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retryTimer;
  bool _disposed = false;

  /// ping 응답이 없어도 끊긴 것으로 보므로 보드 전원이 꺼진 경우도 알 수 있다.
  static Future<StreamChannel<dynamic>> _connectWebSocket(Uri url) async {
    final channel = IOWebSocketChannel.connect(
      url,
      pingInterval: const Duration(seconds: 3),
      connectTimeout: const Duration(seconds: 3),
    );
    await channel.ready;
    return channel;
  }

  Future<void> connect() async {
    if (_disposed) return;
    final startedAt = _clock.now();
    final StreamChannel<dynamic> channel;
    try {
      channel = await _connector(url);
    } catch (_) {
      // 시도를 시작한 때부터 재서 retryDelay마다 다시 시도한다.
      final remaining = retryDelay - _clock.now().difference(startedAt);
      _disconnected(retryIn: remaining.isNegative ? Duration.zero : remaining);
      return;
    }
    if (_disposed) {
      await channel.sink.close();
      return;
    }
    _channel = channel;
    _subscription = channel.stream.listen(
      _onData,
      onError: (Object _) => _disconnected(),
      onDone: _disconnected,
      cancelOnError: true,
    );
    onConnection(BoardConnection.connected);
  }

  void _onData(dynamic raw) {
    if (raw is! String) return;
    final signal = BoardSignal.tryParse(raw);
    if (signal != null) onSignal(signal);
  }

  void _disconnected({Duration? retryIn}) {
    if (_disposed) return;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    onConnection(BoardConnection.disconnected);
    _retryTimer?.cancel();
    _retryTimer = Timer(retryIn ?? retryDelay, connect);
  }

  void start() => _send('start');

  void stop() => _send('stop');

  void _send(String type) {
    _channel?.sink.add(jsonEncode({'type': type}));
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
