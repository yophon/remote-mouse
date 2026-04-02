import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/connection_service.dart';
import '../services/settings_service.dart';
import '../services/history_service.dart';
import 'connect_page.dart';
import 'settings_page.dart';

enum HapticFile { selection, light, medium, heavy }

class TouchpadPage extends StatefulWidget {
  final ConnectionService connection;
  final SettingsService settings;
  final HistoryService history;

  const TouchpadPage({
    super.key,
    required this.connection,
    required this.settings,
    required this.history,
  });

  @override
  State<TouchpadPage> createState() => _TouchpadPageState();
}

class _TouchpadPageState extends State<TouchpadPage> {
  // Tap detection
  bool _moved = false;
  static const _tapSlop = 10.0;

  // Double-tap detection
  DateTime? _lastTapTime;

  // Multi-finger tracking
  int _pointerCount = 0;
  int _maxPointersInGesture = 0;
  bool _isScrolling = false;

  // Delayed tap: wait to see if a second finger arrives
  Timer? _tapDecisionTimer;
  bool _pendingTap = false;

  // Drag mode
  bool _isDragging = false;
  double _gestureDistance = 0.0;
  final Set<String> _activeButtons = {};

  // Keyboard
  bool _showKeyboard = false;
  final TextEditingController _keyboardController = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();
  String _prevText = ' ';

  ConnectionService get _conn => widget.connection;
  SettingsService get _settings => widget.settings;

  @override
  void initState() {
    super.initState();
    _conn.addListener(_onConnectionChanged);
    _settings.addListener(_refresh);
    _settings.applyOrientation();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onConnectionChanged() {
    if (!mounted) return;
    if (_conn.state == WsConnectionState.disconnected ||
        _conn.state == WsConnectionState.error) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ConnectPage(
            settings: _settings,
            history: widget.history,
          ),
        ),
      );
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerCount++;
    if (_pointerCount == 1) {
      _maxPointersInGesture = 1;
      _moved = false;
      _gestureDistance = 0.0;
      _pendingTap = false;
      _tapDecisionTimer?.cancel();
    } else if (_pointerCount > _maxPointersInGesture) {
      _maxPointersInGesture = _pointerCount;
    }

    if (_pointerCount == 2) {
      // Second finger arrived — cancel any pending single-finger tap
      _tapDecisionTimer?.cancel();
      _pendingTap = false;
      _isScrolling = true;
    }
  }

  void _vibrate(HapticFile feedback) {
    if (_settings.hapticFeedback) {
      switch (feedback) {
        case HapticFile.selection:
          HapticFeedback.selectionClick();
        case HapticFile.light:
          HapticFeedback.lightImpact();
        case HapticFile.medium:
          HapticFeedback.mediumImpact();
        case HapticFile.heavy:
          HapticFeedback.heavyImpact();
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_pointerCount == 2 && !_moved && _maxPointersInGesture == 2) {
      // Two-finger tap = right click (fire immediately on second finger lift)
      _conn.sendClick(button: 'right');
      _vibrate(HapticFile.light);
      // Suppress any further tap logic for this gesture
      _pendingTap = false;
      _tapDecisionTimer?.cancel();
    } else if (_pointerCount == 1 &&
        !_moved &&
        _maxPointersInGesture == 1) {
      // Single finger lifted without move — schedule tap with delay
      // to allow a second finger to arrive (which would cancel this)
      _pendingTap = true;
      _tapDecisionTimer?.cancel();
      _tapDecisionTimer = Timer(const Duration(milliseconds: 20), () {
        if (_pendingTap && _maxPointersInGesture == 1) {
          _handleTap();
        }
        _pendingTap = false;
      });
    }

    _pointerCount--;
    if (_pointerCount <= 0) {
      _pointerCount = 0;
      _isScrolling = false;
      if (_isDragging) _isDragging = false;
    }
  }

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 300)) {
      // Second tap within window — upgrade to double-click
      _conn.sendDoubleClick();
      _vibrate(HapticFile.medium);
      _lastTapTime = null;
    } else {
      // First tap — send click immediately, no delay
      _lastTapTime = now;
      _conn.sendClick();
      _vibrate(HapticFile.selection);
      // Guard: if a second tap arrives within 300ms, the doubleClick
      // branch above will fire. The server's dedup prevents the first
      // click from interfering with the double-click because
      // sendDoubleClick uses a separate message type.
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final delta = event.delta;
    final sens = _settings.sensitivity;

    _gestureDistance += delta.distance;
    if (_gestureDistance > _tapSlop / math.max(sens, 0.1)) {
      _moved = true;
    }

    final invert = _settings.invertMouse ? -1.0 : 1.0;

    if (_isScrolling && _pointerCount >= 2) {
      final scrollInvert = _settings.naturalScroll ? 1.0 : -1.0;
      _conn.sendScroll(
        delta.dx * _settings.scrollSensitivity * scrollInvert,
        delta.dy * _settings.scrollSensitivity * scrollInvert,
      );
    } else if (_pointerCount == 1) {
      double dx = delta.dx * sens * invert;
      double dy = delta.dy * sens * invert;

      if (_settings.enhancePrecision) {
        final speed = delta.distance * sens;
        if (speed > 0.01) {
          // Normalize around 4.0 as the unity gain point.
          // Below 4.0 = deceleration, Above 4.0 = acceleration.
          final factor = math.sqrt(speed / 4.0);
          dx *= factor;
          dy *= factor;
        }
      }

      if (_isDragging) {
        _conn.sendDrag(dx, dy);
      } else {
        _conn.sendMove(dx, dy);
      }
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerCount = (_pointerCount - 1).clamp(0, 10);
    if (_pointerCount == 0) {
      _isScrolling = false;
      _isDragging = false;
      _maxPointersInGesture = 0;
    }
  }

  @override
  void dispose() {
    _conn.removeListener(_onConnectionChanged);
    _settings.removeListener(_refresh);
    _tapDecisionTimer?.cancel();
    _keyboardController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(cs),
            Expanded(child: _buildTouchpad(cs)),
            if (_showKeyboard) _buildKeyboardBar(cs),
            _buildBottomBar(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ColorScheme cs) {
    final modeLabel = _conn.transportMode == TransportMode.hybrid
        ? (_conn.udpAvailable ? 'UDP+WS' : 'WS (UDP failed)')
        : 'WS';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF4ade80),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _conn.serverAddress,
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              modeLabel,
              style: TextStyle(
                  color: cs.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
                _showKeyboard ? Icons.keyboard_hide : Icons.keyboard,
                color: _showKeyboard
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.4),
                size: 20),
            onPressed: _toggleKeyboard,
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: cs.onSurface.withValues(alpha: 0.4), size: 20),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsPage(
                  settings: _settings,
                  connection: _conn,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.link_off,
                color: cs.onSurface.withValues(alpha: 0.4), size: 20),
            onPressed: () => _conn.disconnect(),
          ),
        ],
      ),
    );
  }

  Widget _buildTouchpad(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        onPointerMove: _onPointerMove,
        onPointerCancel: _onPointerCancel,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app,
                    size: 48,
                    color: cs.onSurface.withValues(alpha: 0.06)),
                const SizedBox(height: 8),
                Text(
                  _settings.text('slide_to_move'),
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.08),
                      fontSize: 14),
                ),
                if (_isDragging) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_settings.text('dragging'),
                        style: TextStyle(
                            color: cs.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _buildMouseButton(
              buttonId: 'left',
              label: _settings.text('left'),
              onDown: () {
                _conn.sendMouseDown(button: 'left');
                setState(() {
                  _isDragging = true;
                  _activeButtons.add('left');
                });
                _vibrate(HapticFile.selection);
              },
              onUp: () {
                _conn.sendMouseUp(button: 'left');
                setState(() {
                  _isDragging = false;
                  _activeButtons.remove('left');
                });
              },
              cs: cs,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Icon(Icons.unfold_more,
                    color: cs.onSurface.withValues(alpha: 0.15), size: 20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMouseButton(
              buttonId: 'right',
              label: _settings.text('right'),
              onDown: () {
                _conn.sendMouseDown(button: 'right');
                setState(() => _activeButtons.add('right'));
                _vibrate(HapticFile.selection);
              },
              onUp: () {
                _conn.sendMouseUp(button: 'right');
                setState(() => _activeButtons.remove('right'));
              },
              cs: cs,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleKeyboard() {
    setState(() {
      _showKeyboard = !_showKeyboard;
      if (_showKeyboard) {
        _keyboardController.text = ' ';
        _prevText = ' ';
        // Delay focus to after the widget is built
        Future.microtask(() {
          _keyboardFocusNode.requestFocus();
          // Place cursor at end
          _keyboardController.selection = TextSelection.collapsed(
              offset: _keyboardController.text.length);
        });
      } else {
        _keyboardFocusNode.unfocus();
      }
    });
  }

  void _onKeyboardInput() {
    final current = _keyboardController.text;
    final prev = _prevText;

    if (current.length > prev.length) {
      // Characters were added
      final added = current.substring(prev.length);
      _conn.sendKeyText(added);
    } else if (current.length < prev.length) {
      // Characters were deleted (backspace)
      final deleted = prev.length - current.length;
      for (int i = 0; i < deleted; i++) {
        _conn.sendKeySpecial('backspace');
      }
    }

    _prevText = current;

    // Keep at least a space so backspace always works
    if (current.isEmpty) {
      _keyboardController.text = ' ';
      _keyboardController.selection =
          const TextSelection.collapsed(offset: 1);
      _prevText = ' ';
    }
  }

  Widget _buildKeyboardBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _keyboardController,
                focusNode: _keyboardFocusNode,
                autofocus: false,
                enableSuggestions: false,
                autocorrect: false,
                style: TextStyle(color: cs.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: _settings.text('keyboard_hint'),
                  hintStyle: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.3), fontSize: 13),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => _onKeyboardInput(),
                onSubmitted: (_) {
                  _conn.sendKeySpecial('enter');
                  // Reset the text field
                  _keyboardController.text = ' ';
                  _keyboardController.selection =
                      const TextSelection.collapsed(offset: 1);
                  _prevText = ' ';
                  _keyboardFocusNode.requestFocus();
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          _specialKeyButton(cs, Icons.keyboard_return, 'enter'),
          _specialKeyButton(cs, Icons.arrow_upward, 'up'),
          _specialKeyButton(cs, Icons.arrow_downward, 'down'),
          _specialKeyButton(cs, Icons.arrow_back, 'left'),
          _specialKeyButton(cs, Icons.arrow_forward, 'right'),
        ],
      ),
    );
  }

  Widget _specialKeyButton(ColorScheme cs, IconData icon, String key) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Material(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              _conn.sendKeySpecial(key);
              _vibrate(HapticFile.selection);
            },
            child: Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: 0.6)),
          ),
        ),
      ),
    );
  }

  Widget _buildMouseButton({
    required String buttonId,
    required String label,
    required VoidCallback onDown,
    required VoidCallback onUp,
    required ColorScheme cs,
  }) {
    final isActive = _activeButtons.contains(buttonId);

    return Listener(
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isActive
              ? cs.primary.withValues(alpha: 0.25)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? cs.primary : cs.primary.withValues(alpha: 0.15),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
