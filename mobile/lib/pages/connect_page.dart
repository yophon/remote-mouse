import 'package:flutter/material.dart';
import 'package:nsd/nsd.dart';
import '../services/connection_service.dart';
import '../services/settings_service.dart';
import '../services/history_service.dart';
import 'touchpad_page.dart';
import 'settings_page.dart';

class ConnectPage extends StatefulWidget {
  final SettingsService settings;
  final HistoryService history;

  const ConnectPage({
    super.key,
    required this.settings,
    required this.history,
  });

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '9876');
  final _connection = ConnectionService();
  Discovery? _discovery;
  final List<Service> _discovered = [];
  bool _searching = false;

  SettingsService get _settings => widget.settings;
  HistoryService get _history => widget.history;

  @override
  void initState() {
    super.initState();
    _connection.addListener(_onConnectionChanged);
    _history.addListener(_refresh);
    _connection.transportMode = _settings.transportMode;
    _startDiscovery();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onConnectionChanged() {
    if (!mounted) return;
    setState(() {});

    if (_connection.state == WsConnectionState.connected) {
      _history.addEntry(_connection.host, _connection.port);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TouchpadPage(
            connection: _connection,
            settings: _settings,
            history: _history,
          ),
        ),
      );
    }
  }

  Future<void> _startDiscovery() async {
    await _stopDiscovery();
    setState(() {
      _searching = true;
      _discovered.clear();
    });
    try {
      _discovery = await startDiscovery('_remotemouse._tcp.');
      _discovery!.addServiceListener((service, status) {
        if (!mounted) return;
        setState(() {
          if (status == ServiceStatus.found) {
            final exists = _discovered.any((s) =>
                s.host == service.host && s.port == service.port);
            if (!exists) _discovered.add(service);
          }
        });
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _stopDiscovery() async {
    if (_discovery != null) {
      try {
        await stopDiscovery(_discovery!);
      } catch (_) {}
      _discovery = null;
    }
  }

  Future<void> _connect({String? host, int? port}) async {
    final ip = host ?? _ipController.text.trim();
    final p = port ?? int.tryParse(_portController.text) ?? 9876;
    if (ip.isEmpty) return;
    _connection.transportMode = _settings.transportMode;
    await _connection.connect(ip, port: p);
  }

  @override
  void dispose() {
    _connection.removeListener(_onConnectionChanged);
    _history.removeListener(_refresh);
    _stopDiscovery();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isConnecting = _connection.state == WsConnectionState.connecting;
    final hasError = _connection.state == WsConnectionState.error;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.settings_outlined,
                        color: cs.onSurface.withValues(alpha: 0.5)),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SettingsPage(settings: _settings),
                      ),
                    ),
                  ),
                ],
              ),
              Icon(Icons.mouse, size: 56, color: cs.primary),
              const SizedBox(height: 12),
              Text(
                _settings.text('connect'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _settings.text('manual_connect'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.4)),
              ),
              const SizedBox(height: 28),

              // Manual input
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _ipController,
                      style: TextStyle(color: cs.onSurface),
                      decoration: _inputDeco('192.168.x.x', cs),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _portController,
                      style: TextStyle(color: cs.onSurface),
                      decoration: _inputDeco('Port', cs),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isConnecting ? null : () => _connect(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: cs.primary.withValues(alpha: 0.4),
                  ),
                  child: isConnecting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: cs.onPrimary))
                      : Text(_settings.text('connect'),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              if (hasError) ...[
                const SizedBox(height: 8),
                Text(
                  _connection.errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 24),

              // Sections list
              Expanded(
                child: ListView(
                  children: [
                    // Discovered
                    _buildSection(
                        title: _settings.text('discovered'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searching)
                              SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: cs.primary)),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: _searching ? null : _startDiscovery,
                              child: Icon(Icons.refresh,
                                  size: 16,
                                  color: _searching
                                      ? cs.onSurface.withValues(alpha: 0.2)
                                      : cs.primary),
                            ),
                          ],
                        ),
                        cs: cs,
                        children: _discovered.map((s) => _serverTile(
                              icon: Icons.computer,
                              title: s.name ?? _settings.text('unknown'),
                              subtitle: '${s.host ?? ""}:${s.port ?? 9876}',
                              onTap: isConnecting
                                  ? null
                                  : () => _connect(
                                      host: s.host, port: s.port ?? 9876),
                              cs: cs,
                            )),
                      ),

                    // History
                    if (_history.entries.isNotEmpty)
                      _buildSection(
                        title: _settings.text('recent'),
                        cs: cs,
                        children: _history.entries.map((e) => Dismissible(
                              key: ValueKey(e.address),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: cs.error.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.delete_outline,
                                    color: cs.error),
                              ),
                              onDismissed: (_) =>
                                  _history.removeEntry(e.host, e.port),
                              child: _serverTile(
                                icon: Icons.history,
                                title: e.address,
                                subtitle: _timeAgo(e.lastConnected),
                                onTap: isConnecting
                                    ? null
                                    : () =>
                                        _connect(host: e.host, port: e.port),
                                cs: cs,
                              ),
                            )),
                      ),
                  ],
                ),
              ),

              Text(
                _settings.text('wifi_notice'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.2), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, ColorScheme cs) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.2)),
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildSection({
    required String title,
    required ColorScheme cs,
    Widget? trailing,
    required Iterable<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  )),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _serverTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required ColorScheme cs,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Icon(icon, color: cs.primary, size: 22),
          title: Text(title,
              style: TextStyle(color: cs.onSurface, fontSize: 14)),
          subtitle: Text(subtitle,
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.4), fontSize: 12)),
          trailing: Icon(Icons.chevron_right,
              color: cs.onSurface.withValues(alpha: 0.2), size: 20),
          onTap: onTap,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          dense: true,
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return _settings.text('just_now');
    if (diff.inMinutes < 60) return '${diff.inMinutes}${_settings.text('m_ago')}';
    if (diff.inHours < 24) return '${diff.inHours}${_settings.text('h_ago')}';
    if (diff.inDays < 7) return '${diff.inDays}${_settings.text('d_ago')}';
    return '${dt.month}/${dt.day}';
  }
}
