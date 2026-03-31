import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WsConnectionState { disconnected, connecting, connected, error }

enum TransportMode { websocketOnly, hybrid }

class ConnectionService extends ChangeNotifier {
  WebSocketChannel? _wsChannel;
  RawDatagramSocket? _udpSocket;
  InternetAddress? _udpTarget;
  int _udpPort = 9877;

  WsConnectionState _state = WsConnectionState.disconnected;
  String _serverAddress = '';
  String _host = '';
  int _port = 9876;
  String _errorMessage = '';
  TransportMode _transportMode = TransportMode.hybrid;

  int _msgId = 0;

  WsConnectionState get state => _state;
  String get serverAddress => _serverAddress;
  String get host => _host;
  int get port => _port;
  String get errorMessage => _errorMessage;
  TransportMode get transportMode => _transportMode;

  set transportMode(TransportMode mode) {
    _transportMode = mode;
    if (mode == TransportMode.hybrid && _state == WsConnectionState.connected) {
      _initUdp();
    } else if (mode == TransportMode.websocketOnly) {
      _udpSocket?.close();
      _udpSocket = null;
    }
    notifyListeners();
  }

  Future<void> connect(String host, {int port = 9876}) async {
    if (_state == WsConnectionState.connecting) return;

    _state = WsConnectionState.connecting;
    _host = host;
    _port = port;
    _serverAddress = '$host:$port';
    _errorMessage = '';
    _msgId = 0;
    notifyListeners();

    try {
      final uri = Uri.parse('ws://$host:$port');
      _wsChannel = WebSocketChannel.connect(uri);
      await _wsChannel!.ready;

      _state = WsConnectionState.connected;

      if (_transportMode == TransportMode.hybrid) {
        await _initUdp();
      }

      notifyListeners();

      _wsChannel!.stream.listen(
        (_) {},
        onError: (error) {
          _errorMessage = error.toString();
          _state = WsConnectionState.error;
          notifyListeners();
        },
        onDone: () {
          _state = WsConnectionState.disconnected;
          _udpSocket?.close();
          _udpSocket = null;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _state = WsConnectionState.error;
      notifyListeners();
    }
  }

  Future<void> _initUdp() async {
    try {
      _udpSocket?.close();
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _udpTarget = InternetAddress(_host);
      _udpPort = _port + 1;
    } catch (_) {
      _udpSocket = null;
    }
  }

  void disconnect() {
    _wsChannel?.sink.close();
    _wsChannel = null;
    _udpSocket?.close();
    _udpSocket = null;
    _state = WsConnectionState.disconnected;
    notifyListeners();
  }

  int _nextId() => ++_msgId;

  void _sendWs(Map<String, dynamic> data) {
    if (_state != WsConnectionState.connected || _wsChannel == null) return;
    _wsChannel!.sink.add(jsonEncode(data));
  }

  void _sendUdp(Map<String, dynamic> data) {
    if (_udpSocket == null || _udpTarget == null) return;
    final bytes = utf8.encode(jsonEncode(data));
    _udpSocket!.send(bytes, _udpTarget!, _udpPort);
  }

  /// Fire-and-forget via best channel (move/drag: high freq, loss OK)
  void _sendFast(Map<String, dynamic> data) {
    if (_transportMode == TransportMode.hybrid) {
      _sendUdp(data);
    } else {
      _sendWs(data);
    }
  }

  /// Dual-send: UDP first for speed, then WS for reliability.
  /// Server deduplicates by message id.
  void _sendReliable(Map<String, dynamic> data) {
    if (_transportMode == TransportMode.hybrid) {
      _sendUdp(data);
      _sendWs(data);
    } else {
      _sendWs(data);
    }
  }

  void sendMove(double dx, double dy) {
    _sendFast({'type': 'move', 'dx': dx, 'dy': dy, 'id': _nextId()});
  }

  void sendDrag(double dx, double dy) {
    _sendFast({'type': 'drag', 'dx': dx, 'dy': dy, 'id': _nextId()});
  }

  void sendClick({String button = 'left'}) {
    _sendReliable({'type': 'click', 'button': button, 'id': _nextId()});
  }

  void sendMouseDown({String button = 'left'}) {
    _sendReliable({'type': 'mouseDown', 'button': button, 'id': _nextId()});
  }

  void sendMouseUp({String button = 'left'}) {
    _sendReliable({'type': 'mouseUp', 'button': button, 'id': _nextId()});
  }

  void sendDoubleClick() {
    _sendReliable({'type': 'doubleClick', 'id': _nextId()});
  }

  void sendScroll(double dx, double dy) {
    _sendReliable({'type': 'scroll', 'dx': dx, 'dy': dy, 'id': _nextId()});
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
