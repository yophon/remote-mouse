import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryEntry {
  final String host;
  final int port;
  final String? name;
  final DateTime lastConnected;

  HistoryEntry({
    required this.host,
    required this.port,
    this.name,
    required this.lastConnected,
  });

  String get address => '$host:$port';

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'name': name,
        'lastConnected': lastConnected.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        host: json['host'] as String,
        port: json['port'] as int,
        name: json['name'] as String?,
        lastConnected: DateTime.parse(json['lastConnected'] as String),
      );
}

class HistoryService extends ChangeNotifier {
  static const _key = 'connection_history';
  static const _maxEntries = 20;
  late SharedPreferences _prefs;
  List<HistoryEntry> _entries = [];

  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getStringList(_key) ?? [];
    _entries = raw
        .map((s) {
          try {
            return HistoryEntry.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<HistoryEntry>()
        .toList();
  }

  Future<void> addEntry(String host, int port, {String? name}) async {
    // Remove existing entry for same address
    _entries.removeWhere((e) => e.host == host && e.port == port);

    _entries.insert(
      0,
      HistoryEntry(
        host: host,
        port: port,
        name: name,
        lastConnected: DateTime.now(),
      ),
    );

    // Keep only recent entries
    if (_entries.length > _maxEntries) {
      _entries = _entries.sublist(0, _maxEntries);
    }

    await _save();
    notifyListeners();
  }

  Future<void> removeEntry(String host, int port) async {
    _entries.removeWhere((e) => e.host == host && e.port == port);
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final raw = _entries.map((e) => jsonEncode(e.toJson())).toList();
    await _prefs.setStringList(_key, raw);
  }
}
