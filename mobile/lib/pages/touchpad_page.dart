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

/// Termux-style modifier state: off → once (one-shot) → locked (sticky)
enum _ModState { off, once, locked }

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
  int _kbPage = 0; // 0 = extra keys bar, 1 = text input field
  final TextEditingController _keyboardController = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();
  String _prevText = ' ';

  // Termux-style modifier keys: single tap = one-shot, double tap = lock
  final Map<String, _ModState> _modifiers = {
    'ctrl': _ModState.off,
    'alt': _ModState.off,
    'shift': _ModState.off,
    'cmd': _ModState.off,
  };
  DateTime? _lastModTapTime;
  String? _lastModTapKey;

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
        _kbPage = 0;
        _resetKeyboardText();
        Future.microtask(() {
          _keyboardFocusNode.requestFocus();
          _keyboardController.selection = TextSelection.collapsed(
              offset: _keyboardController.text.length);
        });
      } else {
        _keyboardFocusNode.unfocus();
        for (final key in _modifiers.keys) {
          _modifiers[key] = _ModState.off;
        }
      }
    });
  }

  void _onKeyboardInput() {
    final current = _keyboardController.text;
    final prev = _prevText;

    if (current.length > prev.length) {
      final added = current.substring(prev.length);
      final mods = _activeModifierNames();
      if (mods.isNotEmpty) {
        // With modifiers, send each char as special key
        for (final char in added.split('')) {
          _conn.sendKeySpecial(char, modifiers: mods);
        }
        _consumeOneShotModifiers();
      } else {
        _conn.sendKeyText(added);
      }
    } else if (current.length < prev.length) {
      final deleted = prev.length - current.length;
      for (int i = 0; i < deleted; i++) {
        _conn.sendKeySpecial('backspace');
      }
    }

    _prevText = current;

    if (current.isEmpty) {
      _keyboardController.text = ' ';
      _keyboardController.selection =
          const TextSelection.collapsed(offset: 1);
      _prevText = ' ';
    }
  }

  List<String> _activeModifierNames() {
    return _modifiers.entries
        .where((e) => e.value != _ModState.off)
        .map((e) => e.key)
        .toList();
  }

  /// Reset one-shot modifiers after a key is sent.
  void _consumeOneShotModifiers() {
    setState(() {
      _modifiers.updateAll((_, v) => v == _ModState.once ? _ModState.off : v);
    });
  }

  void _onModTap(String mod) {
    final now = DateTime.now();
    setState(() {
      if (_lastModTapKey == mod &&
          _lastModTapTime != null &&
          now.difference(_lastModTapTime!) < const Duration(milliseconds: 400)) {
        // Double tap → lock
        _modifiers[mod] = _ModState.locked;
        _lastModTapKey = null;
        _lastModTapTime = null;
      } else {
        // Single tap → cycle: off→once, once→off, locked→off
        final cur = _modifiers[mod]!;
        _modifiers[mod] = cur == _ModState.off ? _ModState.once : _ModState.off;
        _lastModTapKey = mod;
        _lastModTapTime = now;
      }
    });
    _vibrate(HapticFile.selection);
  }

  void _sendSpecialWithMods(String key) {
    final mods = _activeModifierNames();
    _conn.sendKeySpecial(key, modifiers: mods);
    _consumeOneShotModifiers();
    _vibrate(HapticFile.selection);
  }

  Widget _buildKeyboardBar(ColorScheme cs) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        // Swipe up → show extra keys (page 0), swipe down → show input (page 1)
        if (details.primaryVelocity != null) {
          setState(() {
            _kbPage = details.primaryVelocity! < 0 ? 0 : 1;
          });
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _pageIndicatorDot(cs, _kbPage == 0),
              const SizedBox(width: 4),
              _pageIndicatorDot(cs, _kbPage == 1),
            ],
          ),
          const SizedBox(height: 3),
          if (_kbPage == 0) ...[
            // Extra keys bar (Termux-style)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _modKey(cs, 'ESC', 'esc'),
                  _modKey(cs, 'TAB', 'tab'),
                  _modKeyToggle(cs, 'CTRL', 'ctrl'),
                  _modKeyToggle(cs, 'ALT', 'alt'),
                  _modKeyToggle(cs, 'SHIFT', 'shift'),
                  _modKeyToggle(cs, 'CMD', 'cmd'),
                  const SizedBox(width: 6),
                  _modKey(cs, '↑', 'up'),
                  _modKey(cs, '↓', 'down'),
                  _modKey(cs, '←', 'left'),
                  _modKey(cs, '→', 'right'),
                  _modKey(cs, 'HOME', 'home'),
                  _modKey(cs, 'END', 'end'),
                  _modKey(cs, 'PGUP', 'pageup'),
                  _modKey(cs, 'PGDN', 'pagedown'),
                  _modKey(cs, 'DEL', 'delete'),
                  const SizedBox(width: 6),
                  _shortcutKey(cs, '⌘C', 'c', ['cmd']),
                  _shortcutKey(cs, '⌘V', 'v', ['cmd']),
                  _shortcutKey(cs, '⌘X', 'x', ['cmd']),
                  _shortcutKey(cs, '⌘Z', 'z', ['cmd']),
                  _shortcutKey(cs, '⌘A', 'a', ['cmd']),
                  _shortcutKey(cs, '⌘⇧Z', 'z', ['cmd', 'shift']),
                  _shortcutKey(cs, '⌘T', 'tab', ['cmd']),
                  _shortcutKey(cs, '⌘W', 'w', ['cmd']),
                  _shortcutKey(cs, '⌘Q', 'q', ['cmd']),
                  _shortcutKey(cs, '⌘SP', 'space', ['cmd']),
                ],
              ),
            ),
            // Hidden text field to keep system keyboard open and capture input
            SizedBox(
              height: 0,
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: _keyboardController,
                  focusNode: _keyboardFocusNode,
                  autofocus: false,
                  enableSuggestions: false,
                  autocorrect: false,
                  onChanged: (_) => _onKeyboardInput(),
                  onSubmitted: (_) {
                    _sendSpecialWithMods('enter');
                    _resetKeyboardText();
                    _keyboardFocusNode.requestFocus();
                  },
                ),
              ),
            ),
          ] else ...[
            // Visible text input row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: SizedBox(
                height: 38,
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
                        color: cs.onSurface.withValues(alpha: 0.3),
                        fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor:
                        cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => _onKeyboardInput(),
                  onSubmitted: (_) {
                    _sendSpecialWithMods('enter');
                    _resetKeyboardText();
                    _keyboardFocusNode.requestFocus();
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pageIndicatorDot(ColorScheme cs, bool active) {
    return Container(
      width: active ? 12 : 6,
      height: 4,
      decoration: BoxDecoration(
        color: active
            ? cs.primary.withValues(alpha: 0.6)
            : cs.onSurface.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  void _resetKeyboardText() {
    _keyboardController.text = ' ';
    _keyboardController.selection =
        const TextSelection.collapsed(offset: 1);
    _prevText = ' ';
  }

  /// Modifier toggle button (Termux-style: tap=once, double-tap=lock)
  Widget _modKeyToggle(ColorScheme cs, String label, String mod) {
    final state = _modifiers[mod] ?? _ModState.off;
    final Color bg;
    final Color fg;
    switch (state) {
      case _ModState.off:
        bg = cs.surfaceContainerHighest.withValues(alpha: 0.5);
        fg = cs.onSurface.withValues(alpha: 0.6);
      case _ModState.once:
        bg = cs.primary.withValues(alpha: 0.25);
        fg = cs.primary;
      case _ModState.locked:
        bg = cs.primary;
        fg = cs.onPrimary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _onModTap(mod),
          child: Container(
            constraints: const BoxConstraints(minWidth: 40),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
          ),
        ),
      ),
    );
  }

  /// Regular special key button (sends with active modifiers)
  Widget _modKey(ColorScheme cs, String label, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _sendSpecialWithMods(key),
          child: Container(
            constraints: const BoxConstraints(minWidth: 34),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.6))),
          ),
        ),
      ),
    );
  }

  /// One-tap shortcut button (e.g. ⌘C = Cmd+C)
  Widget _shortcutKey(
      ColorScheme cs, String label, String key, List<String> mods) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            _conn.sendKeySpecial(key, modifiers: mods);
            _vibrate(HapticFile.selection);
          },
          child: Container(
            constraints: const BoxConstraints(minWidth: 38),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.5))),
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
