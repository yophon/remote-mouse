import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connection_service.dart';
import 'l10n.dart';

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
    final dict = _language == 'chinese' ? zhStrings : enStrings;
    return dict[key] ?? key;
  }

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
