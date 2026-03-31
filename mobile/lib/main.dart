import 'package:flutter/material.dart';
import 'services/settings_service.dart';
import 'services/history_service.dart';
import 'pages/connect_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsService();
  final history = HistoryService();
  await Future.wait([settings.init(), history.init()]);

  runApp(RemoteMouseApp(settings: settings, history: history));
}

class RemoteMouseApp extends StatefulWidget {
  final SettingsService settings;
  final HistoryService history;

  const RemoteMouseApp({
    super.key,
    required this.settings,
    required this.history,
  });

  @override
  State<RemoteMouseApp> createState() => _RemoteMouseAppState();
}

class _RemoteMouseAppState extends State<RemoteMouseApp> {
  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.settings.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6c63ff);

    return MaterialApp(
      title: 'Remote Mouse',
      debugShowCheckedModeBanner: false,
      themeMode: widget.settings.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: accent,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: accent,
        useMaterial3: true,
      ),
      home: ConnectPage(
        settings: widget.settings,
        history: widget.history,
      ),
    );
  }
}
