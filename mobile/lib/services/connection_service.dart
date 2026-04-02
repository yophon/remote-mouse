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
  bool _udpAvailable = false;

  int _msgId = 0;

  WsConnectionState get state => _state;
  String get serverAddress => _serverAddress;
  String get host => _host;
  int get port => _port;
  String get errorMessage => _errorMessage;
  TransportMode get transportMode => _transportMode;
  bool get udpAvailable => _udpAvailable;

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

  Future<void> connect(String host, {int port = 9876, Duration timeout = const Duration(seconds: 5)}) async {
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
      await _wsChannel!.ready.timeout(timeout);

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
      _udpAvailable = true;
    } catch (_) {
      _udpSocket = null;
      _udpAvailable = false;
    }
    notifyListeners();
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

  // Binary protocol tags matching server-side Message.swift
  static const int _tagMove = 1;
  static const int _tagDrag = 2;
  static const int _tagScroll = 3;

  /// Encode a high-frequency message as 13-byte binary:
  ///   [tag:1][dx:f32][dy:f32][id:i32]
  Uint8List _encodeBinary(int tag, double dx, double dy, int id) {
    final buf = ByteData(13);
    buf.setUint8(0, tag);
    buf.setFloat32(1, dx, Endian.little);
    buf.setFloat32(5, dy, Endian.little);
    buf.setInt32(9, id, Endian.little);
    return buf.buffer.asUint8List();
  }

  void _sendWs(dynamic data) {
    if (_state != WsConnectionState.connected || _wsChannel == null) return;
    if (data is Uint8List) {
      _wsChannel!.sink.add(data);
    } else {
      _wsChannel!.sink.add(jsonEncode(data));
    }
  }

  void _sendUdp(dynamic data) {
    if (_udpSocket == null || _udpTarget == null) return;
    final List<int> bytes;
    if (data is Uint8List) {
      bytes = data;
    } else {
      bytes = utf8.encode(jsonEncode(data));
    }
    _udpSocket!.send(bytes, _udpTarget!, _udpPort);
  }

  /// Fire-and-forget via best channel (move/drag/scroll: high freq, loss OK)
  void _sendFast(dynamic data) {
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
    _sendFast(_encodeBinary(_tagMove, dx, dy, _nextId()));
  }

  void sendDrag(double dx, double dy) {
    _sendFast(_encodeBinary(_tagDrag, dx, dy, _nextId()));
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
    _sendFast(_encodeBinary(_tagScroll, dx, dy, _nextId()));
  }

  void sendKeyText(String text) {
    _sendReliable({'type': 'keyText', 'key': text, 'id': _nextId()});
  }

  void sendKeySpecial(String key, {List<String> modifiers = const []}) {
    _sendReliable({
      'type': 'keySpecial',
      'key': key,
      'modifiers': modifiers,
      'id': _nextId(),
    });
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
