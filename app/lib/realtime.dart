import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'backend.dart';
import 'config.dart';

/// Socket.IO connection to the game server. One per app; reconnects automatically.
class Live {
  static Live? _i;
  static Live get I => _i ??= Live._();
  late final io.Socket socket;
  final _events = StreamController<(String, dynamic)>.broadcast();
  Stream<(String, dynamic)> get events => _events.stream;
  bool get connected => socket.connected;
  Map? resumed;
  Live._() {
    socket = io.io(AppConfig.backendUrl, io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().setReconnectionDelay(1500).setReconnectionAttempts(1 << 30)
        .setAuth({'token': Backend.token, 'device': {'deviceId': AppConfig.deviceId, 'platform': Backend.platform, 'appVersion': AppConfig.appVersion}}).build());
    for (final ev in ['hello', 'queue:update', 'match:start', 'match:state', 'match:say', 'match:shot', 'match:left', 'match:end', 'match:error', 'room:message', 'room:presence', 'room:ended', 'challenge:incoming', 'challenge:result', 'warn']) {
      socket.on(ev, (d) { if (ev == 'hello') resumed = (d as Map)['resumed']; _events.add((ev, d)); });
    }
    socket.onConnectError((e) => _events.add(('error', '$e')));
    socket.onDisconnect((_) => _events.add(('disconnect', null)));
  }
  void connect() { if (!socket.connected) { socket.auth = {'token': Backend.token, 'device': {'deviceId': AppConfig.deviceId, 'platform': Backend.platform, 'appVersion': AppConfig.appVersion}}; socket.connect(); } }
  void disconnect() => socket.disconnect();

  /// Emit with acknowledgement. Resolves to the ack map ({ok:true,...} or {ok:false, code, message}).
  Future<Map> emit(String ev, [Map? payload]) {
    final c = Completer<Map>();
    socket.emitWithAck(ev, payload ?? {}, ack: (d) { if (!c.isCompleted) c.complete(d is Map ? d : {'ok': false, 'code': 'BAD_ACK'}); });
    Timer(const Duration(seconds: 10), () { if (!c.isCompleted) c.complete({'ok': false, 'code': 'TIMEOUT', 'message': 'Server did not answer'}); });
    return c.future;
  }
}
