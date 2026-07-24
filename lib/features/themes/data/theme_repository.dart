import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/button_theme_spec.dart';

/// Custom-theme store: a JSON document in the app-support directory.
///
/// Plan deviation from doc §4 (Isar): Isar 3.x is broken on Dart 3.12, and
/// ≤ 50 small documents (backend limit) don't justify a database. The
/// interface is the doc's `ThemeRepository`; the backing store is swappable.
/// Sync metadata (`dirty`/`deleted`/`updatedAt`) is kept per entry for the
/// M5+ cloud-sync path (backend doc §7.4 last-write-wins).
class ThemeRepository {
  ThemeRepository({Directory? overrideDir}) {
    _overrideDir = overrideDir;
  }

  late final Directory? _overrideDir;
  List<_Entry>? _cache;

  Future<File> _file() async {
    final dir = _overrideDir ?? await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}themes.json');
  }

  Future<List<_Entry>> _load() async {
    if (_cache != null) return _cache!;
    try {
      final file = await _file();
      if (!file.existsSync()) return _cache = [];
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _cache = (raw['themes'] as List? ?? [])
          .map((e) => _Entry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _cache = [];
    }
    return _cache!;
  }

  Future<void> _persist() async {
    final file = await _file();
    final payload = jsonEncode({
      'schemaVersion': 1,
      'themes': (_cache ?? []).map((e) => e.toJson()).toList(),
    });
    await file.writeAsString(payload, flush: true);
  }

  /// Live (non-tombstoned) custom themes, newest first.
  Future<List<ButtonThemeSpec>> customThemes() async {
    final entries = await _load();
    final live = entries.where((e) => !e.deleted).map((e) => e.spec).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return live;
  }

  Future<ButtonThemeSpec?> byId(String id) async {
    final entries = await _load();
    for (final e in entries) {
      if (!e.deleted && e.spec.id == id) return e.spec;
    }
    return null;
  }

  Future<void> upsert(ButtonThemeSpec spec) async {
    final entries = await _load();
    entries.removeWhere((e) => e.spec.id == spec.id);
    entries.add(_Entry(spec: spec, dirty: true));
    await _persist();
  }

  /// Tombstone, not hard delete — sync needs it (backend doc §7.4).
  Future<void> delete(String id) async {
    final entries = await _load();
    final index = entries.indexWhere((e) => e.spec.id == id);
    if (index < 0) return;
    entries[index] = _Entry(
      spec: entries[index].spec.copyWith(updatedAt: DateTime.now().toUtc()),
      dirty: true,
      deleted: true,
    );
    await _persist();
  }
}

class _Entry {
  _Entry({required this.spec, this.dirty = false, this.deleted = false});

  final ButtonThemeSpec spec;
  final bool dirty;
  final bool deleted;

  Map<String, dynamic> toJson() => {
        'spec': spec.toJson(),
        'dirty': dirty,
        'deleted': deleted,
      };

  factory _Entry.fromJson(Map<String, dynamic> json) => _Entry(
        spec: ButtonThemeSpec.fromJson(json['spec'] as Map<String, dynamic>),
        dirty: json['dirty'] as bool? ?? false,
        deleted: json['deleted'] as bool? ?? false,
      );
}
