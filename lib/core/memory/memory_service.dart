import 'package:uuid/uuid.dart';

import '../storage/database.dart';

/// One thing worth remembering. [kind] separates ephemeral notes from hard-won
/// lessons, which is what makes self-improvement across runs possible.
class MemoryNote {
  final String id;
  final String kind;
  final String text;
  final List<String> tags;
  final double weight;
  final DateTime createdAt;

  const MemoryNote({
    required this.id,
    required this.kind,
    required this.text,
    this.tags = const [],
    this.weight = 0,
    required this.createdAt,
  });

  factory MemoryNote.fromMap(Map<String, dynamic> m) => MemoryNote(
        id: (m['id'] as String?) ?? '',
        kind: (m['kind'] as String?) ?? 'note',
        text: (m['text'] as String?) ?? '',
        tags: ((m['tags'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        weight: (m['weight'] as num?)?.toDouble() ?? 0,
        createdAt: m['createdAt'] != null
            ? DateTime.parse(m['createdAt'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'kind': kind,
        'text': text,
        'tags': tags,
        'weight': weight,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Long-term memory. This is deliberately a thin, replaceable layer: the
/// recall contract here is the seam where an open-source memory/embedding
/// plugin drops in without touching the agent loop or the tools.
class MemoryService {
  MemoryService(this._db);

  final DatabaseService _db;
  static const Uuid _uuid = Uuid();

  Future<void> save(
    String text, {
    String kind = 'note',
    List<String> tags = const [],
    double weight = 0,
  }) async {
    final note = MemoryNote(
      id: _uuid.v4(),
      kind: kind,
      text: text,
      tags: tags,
      weight: weight,
      createdAt: DateTime.now(),
    );
    _db.upsertMemory(note.id, note.kind, note.weight, note.toMap());
  }

  /// Recalls whatever is relevant to [query], falling back to recent notes.
  Future<List<MemoryNote>> recall(String query, {int limit = 6}) async {
    final words = query
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase())
        .where((w) => w.length > 2)
        .take(6)
        .toList(growable: false);
    if (words.isEmpty) return recent(limit: limit);
    final rows = _db.searchMemory(words, limit: limit);
    final notes = [
      for (final r in rows)
        MemoryNote.fromMap({
          ...r['data'] as Map<String, dynamic>,
          'id': r['id'],
          'weight': r['weight'],
        })
    ];
    for (final n in notes) {
      _db.touchMemory(n.id);
    }
    return notes;
  }

  Future<List<MemoryNote>> recent({int limit = 12}) async {
    final rows = _db.recentMemory(limit: limit);
    return [
      for (final r in rows)
        MemoryNote.fromMap({
          ...(r['data'] as Map<String, dynamic>),
          'id': r['id'],
        })
    ];
  }

  /// Injects relevant memory into the system prompt so past lessons carry
  /// forward into the next run — the self-improvement hook.
  Future<String> promptAddendum(String goal) async {
    if (goal.trim().isEmpty) return '';
    final notes = await recall(goal, limit: 6);
    if (notes.isEmpty) return '';
    return '\n\n## Long-term memory\n'
        'Notes and lessons from earlier sessions:\n'
        '${notes.map((n) => '- [${n.kind}] ${n.text}').join('\n')}';
  }

  Future<void> forget(String id) async => _db.deleteMemory(id);
}