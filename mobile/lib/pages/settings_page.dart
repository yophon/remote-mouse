import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/connection_service.dart';

class SettingsPage extends StatefulWidget {
  final SettingsService settings;
  final ConnectionService? connection;

  const SettingsPage({
    super.key,
    required this.settings,
    this.connection,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SettingsService get _s => widget.settings;
  late TextEditingController _sensController;
  late TextEditingController _scrollController;

  @override
  void initState() {
    super.initState();
    _s.addListener(_refresh);
    _sensController =
        TextEditingController(text: _s.sensitivity.toStringAsFixed(1));
    _scrollController =
        TextEditingController(text: _s.scrollSensitivity.toStringAsFixed(1));
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _s.removeListener(_refresh);
    _sensController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(_s.text('settings')),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // --- Appearance ---
          _sectionHeader(_s.text('appearance'), cs),
          _card(cs, children: [
            _tileSwitch(
              icon: Icons.dark_mode,
              title: _s.text('dark_mode'),
              value: _s.themeMode == ThemeMode.dark,
              onChanged: (v) {
                _s.themeMode = v ? ThemeMode.dark : ThemeMode.light;
              },
              cs: cs,
            ),
            _divider(cs),
            _tileSwitch(
              icon: Icons.vibration,
              title: _s.text('haptic'),
              subtitle: _s.text('haptic_desc'), // I forgot to add this to dict, I'll update it
              value: _s.hapticFeedback,
              onChanged: (v) => _s.hapticFeedback = v,
              cs: cs,
            ),
          ]),
          const SizedBox(height: 20),

          // --- Language ---
          _sectionHeader(_s.text('language'), cs),
          _card(cs, children: [
            _tileRadio<String>(
              icon: Icons.language,
              title: '简体中文',
              subtitle: 'Simplified Chinese',
              value: 'chinese',
              groupValue: _s.language,
              onChanged: (v) => _s.language = v,
              cs: cs,
            ),
            _divider(cs),
            _tileRadio<String>(
              icon: Icons.language,
              title: 'English',
              subtitle: 'English',
              value: 'english',
              groupValue: _s.language,
              onChanged: (v) => _s.language = v,
              cs: cs,
            ),
          ]),
          const SizedBox(height: 20),

          // --- Orientation ---
          _sectionHeader(_s.text('orientation'), cs),
          _card(cs, children: [
            _tileRadio<OrientationLock>(
              icon: Icons.stay_current_portrait,
              title: _s.text('portrait'),
              subtitle: '',
              value: OrientationLock.portrait,
              groupValue: _s.orientationLock,
              onChanged: (v) {
                _s.orientationLock = v;
                _s.applyOrientation();
              },
              cs: cs,
            ),
            _divider(cs),
            _tileRadio<OrientationLock>(
              icon: Icons.stay_current_landscape,
              title: _s.text('landscape'),
              subtitle: '',
              value: OrientationLock.landscape,
              groupValue: _s.orientationLock,
              onChanged: (v) {
                _s.orientationLock = v;
                _s.applyOrientation();
              },
              cs: cs,
            ),
            _divider(cs),
            _tileRadio<OrientationLock>(
              icon: Icons.screen_rotation,
              title: _s.text('auto'),
              subtitle: '',
              value: OrientationLock.auto,
              groupValue: _s.orientationLock,
              onChanged: (v) {
                _s.orientationLock = v;
                _s.applyOrientation();
              },
              cs: cs,
            ),
          ]),
          const SizedBox(height: 20),

          // --- Communication ---
          _sectionHeader(_s.text('communication'), cs),
          _card(cs, children: [
            _tileRadio<TransportMode>(
              icon: Icons.speed,
              title: 'UDP + WebSocket',
              subtitle: 'UDP + WS',
              value: TransportMode.hybrid,
              groupValue: _s.transportMode,
              onChanged: (v) {
                _s.transportMode = v;
                widget.connection?.transportMode = v;
              },
              cs: cs,
            ),
            _divider(cs),
            _tileRadio<TransportMode>(
              icon: Icons.wifi,
              title: 'WebSocket Only',
              subtitle: 'WS',
              value: TransportMode.websocketOnly,
              groupValue: _s.transportMode,
              onChanged: (v) {
                _s.transportMode = v;
                widget.connection?.transportMode = v;
              },
              cs: cs,
            ),
          ]),
          const SizedBox(height: 20),

          // --- Cursor ---
          _sectionHeader(_s.text('cursor'), cs),
          _card(cs, children: [
            _tileSliderWithInput(
              icon: Icons.mouse,
              title: _s.text('cursor_speed'),
              value: _s.sensitivity,
              min: 0.0,
              max: 10.0,
              controller: _sensController,
              onSliderChanged: (v) {
                _s.sensitivity = v;
                _sensController.text = v.toStringAsFixed(1);
              },
              onTextSubmitted: (text) {
                final v = double.tryParse(text);
                if (v != null && v >= 0) {
                  _s.sensitivity = v;
                }
              },
              cs: cs,
            ),
            _divider(cs),
            _tileSwitch(
              icon: Icons.swap_horiz,
              title: _s.text('invert_cursor'),
              subtitle: '',
              value: _s.invertMouse,
              onChanged: (v) => _s.invertMouse = v,
              cs: cs,
            ),
            _divider(cs),
            _tileSwitch(
              icon: Icons.center_focus_strong,
              title: _s.text('precision'),
              subtitle: '',
              value: _s.enhancePrecision,
              onChanged: (v) => _s.enhancePrecision = v,
              cs: cs,
            ),
          ]),
          const SizedBox(height: 20),

          // --- Scroll ---
          _sectionHeader(_s.text('scroll'), cs),
          _card(cs, children: [
            _tileSliderWithInput(
              icon: Icons.swap_vert,
              title: _s.text('scroll_speed'),
              value: _s.scrollSensitivity,
              min: 0.0,
              max: 10.0,
              controller: _scrollController,
              onSliderChanged: (v) {
                _s.scrollSensitivity = v;
                _scrollController.text = v.toStringAsFixed(1);
              },
              onTextSubmitted: (text) {
                final v = double.tryParse(text);
                if (v != null && v >= 0) {
                  _s.scrollSensitivity = v;
                }
              },
              cs: cs,
            ),
            _divider(cs),
            _tileSwitch(
              icon: Icons.swap_vert_circle_outlined,
              title: _s.text('natural_scroll'),
              subtitle: '',
              value: _s.naturalScroll,
              onChanged: (v) => _s.naturalScroll = v,
              cs: cs,
            ),
          ]),
          const SizedBox(height: 20),

          // --- About ---
          _sectionHeader(_s.text('about'), cs),
          _card(cs, children: [
            ListTile(
              leading: Icon(Icons.info_outline, color: cs.primary),
              title:
                  Text(_s.text('version'), style: TextStyle(color: cs.onSurface)),
              trailing: Text('1.0.0',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5))),
            ),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ---- Helpers ----

  Widget _divider(ColorScheme cs) =>
      Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3));

  Widget _sectionHeader(String text, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: cs.primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _card(ColorScheme cs, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _tileSwitch({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ColorScheme cs,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: cs.primary),
      title: Text(title, style: TextStyle(color: cs.onSurface)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12))
          : null,
      value: value,
      onChanged: onChanged,
      activeTrackColor: cs.primary,
    );
  }

  Widget _tileRadio<T>({
    required IconData icon,
    required String title,
    required String subtitle,
    required T value,
    required T groupValue,
    required ValueChanged<T> onChanged,
    required ColorScheme cs,
  }) {
    final selected = value == groupValue;
    return ListTile(
      leading: Icon(icon,
          color:
              selected ? cs.primary : cs.onSurface.withValues(alpha: 0.4)),
      title: Text(title, style: TextStyle(color: cs.onSurface)),
      subtitle: Text(subtitle,
          style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12)),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.3),
      ),
      onTap: () => onChanged(value),
    );
  }

  Widget _tileSliderWithInput({
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required TextEditingController controller,
    required ValueChanged<double> onSliderChanged,
    required ValueChanged<String> onTextSubmitted,
    required ColorScheme cs,
  }) {
    // Clamp slider value to slider range, but allow text input for larger values
    final sliderVal = value.clamp(min, max);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: cs.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: TextStyle(
                              color: cs.onSurface, fontSize: 14)),
                    ),
                    // Editable value input
                    SizedBox(
                      width: 56,
                      height: 30,
                      child: TextField(
                        controller: controller,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 6),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color:
                                    cs.outlineVariant.withValues(alpha: 0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color:
                                    cs.outlineVariant.withValues(alpha: 0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: cs.primary),
                          ),
                        ),
                        onSubmitted: onTextSubmitted,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: sliderVal,
                    min: min,
                    max: max,
                    activeColor: cs.primary,
                    inactiveColor:
                        cs.outlineVariant.withValues(alpha: 0.3),
                    onChanged: onSliderChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
