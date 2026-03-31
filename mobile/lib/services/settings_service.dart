import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connection_service.dart';

enum OrientationLock { portrait, landscape, auto }

class SettingsService extends ChangeNotifier {
  late SharedPreferences _prefs;

  // Defaults
  ThemeMode _themeMode = ThemeMode.light;
  TransportMode _transportMode = TransportMode.hybrid;
  double _sensitivity = 1.5;
  double _scrollSensitivity = 2.0;
  bool _invertMouse = false;
  bool _naturalScroll = true;
  bool _enhancePrecision = false;
  bool _hapticFeedback = true;
  String _language = 'english'; // 'english' or 'chinese'
  OrientationLock _orientationLock = OrientationLock.portrait;

  ThemeMode get themeMode => _themeMode;
  TransportMode get transportMode => _transportMode;
  double get sensitivity => _sensitivity;
  double get scrollSensitivity => _scrollSensitivity;
  bool get invertMouse => _invertMouse;
  bool get naturalScroll => _naturalScroll;
  bool get enhancePrecision => _enhancePrecision;
  bool get hapticFeedback => _hapticFeedback;
  String get language => _language;
  OrientationLock get orientationLock => _orientationLock;

  String text(String key) {
    final dict = _language == 'chinese' ? _zh : _en;
    return dict[key] ?? key;
  }

  static const _en = {
    'connect': 'Connect',
    'connected': 'Connected',
    'connecting': 'Connecting...',
    'disconnected': 'Disconnected',
    'error': 'Error',
    'settings': 'Settings',
    'appearance': 'Appearance',
    'dark_mode': 'Dark Mode',
    'orientation': 'Orientation',
    'portrait': 'Portrait',
    'landscape': 'Landscape',
    'auto': 'Auto',
    'communication': 'Communication',
    'cursor': 'Cursor',
    'cursor_speed': 'Cursor Speed',
    'invert_cursor': 'Invert Cursor',
    'precision': 'Enhance Precision',
    'scroll': 'Scroll',
    'scroll_speed': 'Scroll Speed',
    'natural_scroll': 'Natural Scroll',
    'haptic': 'Haptic Feedback',
    'haptic_desc': 'Vibrate the device on click',
    'language': 'Language',
    'about': 'About',
    'version': 'Version',
    'recent': 'Recent',
    'discovered': 'Discovered',
    'manual_connect': 'Connect to your computer',
    'wifi_notice': 'Make sure phone and computer are on the same Wi-Fi network',
    'just_now': 'Just now',
    'm_ago': 'm ago',
    'h_ago': 'h ago',
    'd_ago': 'd ago',
    'slide_to_move': 'Slide to move cursor',
    'dragging': 'Dragging',
    'left': 'Left',
    'right': 'Right',
    'unknown': 'Unknown',
  };

  static const _zh = {
    'connect': '连接',
    'connected': '已连接',
    'connecting': '连接中...',
    'disconnected': '未连接',
    'error': '错误',
    'settings': '设置',
    'appearance': '外观',
    'dark_mode': '深色模式',
    'orientation': '屏幕方向',
    'portrait': '竖屏',
    'landscape': '横屏',
    'auto': '自动',
    'communication': '传输协议',
    'cursor': '指针',
    'cursor_speed': '移动速度',
    'invert_cursor': '反转方向',
    'precision': '提高精准度',
    'scroll': '滚动',
    'scroll_speed': '滚动速度',
    'natural_scroll': '自然滚动',
    'haptic': '触感反馈',
    'haptic_desc': '在点击时触发震动',
    'language': '语言',
    'about': '关于',
    'version': '版本',
    'recent': '最近连接',
    'discovered': '自动发现',
    'manual_connect': '连接到您的电脑',
    'wifi_notice': '请确保手机和电脑在同一个 Wi-Fi 网络',
    'just_now': '刚刚',
    'm_ago': '分钟前',
    'h_ago': '小时前',
    'd_ago': '天前',
    'slide_to_move': '滑动移动光标',
    'dragging': '拖拽中',
    'left': '左键',
    'right': '右键',
    'unknown': '未知设备',
  };

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _themeMode = _prefs.getString('themeMode') == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    _transportMode = _prefs.getString('transportMode') == 'websocketOnly'
        ? TransportMode.websocketOnly
        : TransportMode.hybrid;
    _sensitivity = _prefs.getDouble('sensitivity') ?? 1.5;
    _scrollSensitivity = _prefs.getDouble('scrollSensitivity') ?? 2.0;
    _invertMouse = _prefs.getBool('invertMouse') ?? false;
    _naturalScroll = _prefs.getBool('naturalScroll') ?? true;
    _enhancePrecision = _prefs.getBool('enhancePrecision') ?? false;
    _hapticFeedback = _prefs.getBool('hapticFeedback') ?? true;
    _language = _prefs.getString('language') ?? 'chinese';
    final oriStr = _prefs.getString('orientationLock') ?? 'portrait';
    _orientationLock = OrientationLock.values.firstWhere(
      (e) => e.name == oriStr,
      orElse: () => OrientationLock.portrait,
    );
    notifyListeners();
  }

  set themeMode(ThemeMode mode) {
    _themeMode = mode;
    _prefs.setString('themeMode', mode == ThemeMode.light ? 'light' : 'dark');
    notifyListeners();
  }

  set transportMode(TransportMode mode) {
    _transportMode = mode;
    _prefs.setString('transportMode',
        mode == TransportMode.websocketOnly ? 'websocketOnly' : 'hybrid');
    notifyListeners();
  }

  set sensitivity(double v) {
    _sensitivity = v;
    _prefs.setDouble('sensitivity', v);
    notifyListeners();
  }

  set scrollSensitivity(double v) {
    _scrollSensitivity = v;
    _prefs.setDouble('scrollSensitivity', v);
    notifyListeners();
  }

  set invertMouse(bool v) {
    _invertMouse = v;
    _prefs.setBool('invertMouse', v);
    notifyListeners();
  }

  set naturalScroll(bool v) {
    _naturalScroll = v;
    _prefs.setBool('naturalScroll', v);
    notifyListeners();
  }

  set enhancePrecision(bool v) {
    _enhancePrecision = v;
    _prefs.setBool('enhancePrecision', v);
    notifyListeners();
  }

  set hapticFeedback(bool v) {
    _hapticFeedback = v;
    _prefs.setBool('hapticFeedback', v);
    notifyListeners();
  }

  set language(String v) {
    _language = v;
    _prefs.setString('language', v);
    notifyListeners();
  }

  set orientationLock(OrientationLock v) {
    _orientationLock = v;
    _prefs.setString('orientationLock', v.name);
    notifyListeners();
  }

  void applyOrientation() {
    switch (_orientationLock) {
      case OrientationLock.portrait:
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      case OrientationLock.landscape:
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      case OrientationLock.auto:
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }
}
