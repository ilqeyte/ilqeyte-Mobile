import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/chat_models.dart';
import '../models/provider_models.dart';

/// SQLite gateway. Row payloads are stored as JSON in `data` columns so the
/// model classes remain the single source of truth — no ORM, no codegen, and
/// the whole project still builds with a plain `flutter build`.
class DatabaseService {
  Database? _db;

  bool get isOpen => _db != null;
  Database get db => _db!;

  Future<void> open({Directory? directory}) async {
    if (_db != null) return;
    final dir = directory ?? await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'ilqeyte.db'));
    await file.parent.create(recursive: true);
    _db = sqlite3.open(file.path);
    _db!.execute('PRAGMA journal_mode = WAL;');
    _db!.execute('PRAGMA foreign_keys = ON;');
    _migrate();
  }

  Future<void> close() async {
    _db?.dispose();
    _db = null;
  }

  void _migrate() {
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS providers(
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS conversations(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        mode TEXT NOT NULL,
        provider_id TEXT,
        model TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS messages(
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        seq INTEGER NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    _db!.execute(
        'CREATE INDEX IF NOT EXISTS idx_messages_conv ON messages(conversation_id, seq)');
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS memory(
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        weight REAL NOT NULL DEFAULT 0,
        accessed_at INTEGER NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    _db!.execute(
        'CREATE INDEX IF NOT EXISTS idx_memory_kind ON memory(kind, weight DESC)');
  }

  // ----------------------------- providers -----------------------------

  void upsertProvider(ProviderConfig provider) {
    db.execute(
      'INSERT INTO providers(id, kind, data, created_at) VALUES(?,?,?,?) '
      'ON CONFLICT(id) DO UPDATE SET kind=excluded.kind, data=excluded.data',
      [
        provider.id,
        provider.kind.name,
        jsonEncode(provider.toJson()),
        provider.createdAt.toIso8601String(),
      ],
    );
  }

  void deleteProvider(String id) =>
      db.execute('DELETE FROM providers WHERE id = ?', [id]);

  List<ProviderConfig> providers({ProviderKind? kind}) {
    final rows = kind == null
        ? db.select('SELECT data FROM providers ORDER BY created_at')
        : db.select(
            'SELECT data FROM providers WHERE kind = ? ORDER BY created_at',
            [kind.name]);
    return [
      for (final r in rows)
        ProviderConfig.fromJson(jsonDecode(r['data']) as Map<String, dynamic>)
    ];
  }

  // --------------------------- conversations ---------------------------

  void upsertConversation({
    required String id,
    required String title,
    required ChatMode mode,
    String? providerId,
    String? model,
    String status = 'active',
  }) {
    final now = DateTime.now().toIso8601String();
    db.execute(
      'INSERT INTO conversations(id,title,mode,provider_id,model,status,created_at,updated_at) '
      'VALUES(?,?,?,?,?,?,?,?) '
      'ON CONFLICT(id) DO UPDATE SET title=excluded.title, mode=excluded.mode, '
      'provider_id=excluded.provider_id, model=excluded.model, '
      'status=excluded.status, updated_at=excluded.updated_at',
      [id, title, mode.name, providerId, model, status, now, now],
    );
  }

  void touchConversation(String id, {String status = 'active'}) {
    db.execute(
      'UPDATE conversations SET updated_at = ?, status = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), status, id],
    );
  }

  List<ConversationRow> conversations({int limit = 200}) {
    final rows = db.select(
        'SELECT id, title, mode, status, updated_at FROM conversations '
        'ORDER BY updated_at DESC LIMIT ?',
        [limit]);
    return [for (final r in rows) ConversationRow.fromRow(r)];
  }

  ConversationRow? conversation(String id) {
    final rows = db.select(
      'SELECT id, title, mode, status, updated_at FROM conversations WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return ConversationRow.fromRow(rows.first);
  }

  void deleteConversation(String id) {
    db.execute('DELETE FROM messages WHERE conversation_id = ?', [id]);
    db.execute('DELETE FROM conversations WHERE id = ?', [id]);
  }

  // ----------------------------- messages ------------------------------

  void upsertMessage(String conversationId, int seq, ChatMessage message) {
    db.execute(
      'INSERT INTO messages(id, conversation_id, seq, data, created_at) VALUES(?,?,?,?,?) '
      'ON CONFLICT(id) DO UPDATE SET seq=excluded.seq, data=excluded.data',
      [
        message.id,
        conversationId,
        seq,
        jsonEncode(message.toJson()),
        message.createdAt.toIso8601String(),
      ],
    );
  }

  List<ChatMessage> messages(String conversationId) {
    final rows = db.select(
        'SELECT data FROM messages WHERE conversation_id = ? ORDER BY seq',
        [conversationId]);
    return [
      for (final r in rows)
        ChatMessage.fromJson(jsonDecode(r['data']) as Map<String, dynamic>)
    ];
  }

  // ------------------------------ memory -------------------------------

  void upsertMemory(
      String id, String kind, double weight, Map<String, dynamic> data) {
    db.execute(
      'INSERT INTO memory(id, kind, weight, accessed_at, data) VALUES(?,?,?,?,?) '
      'ON CONFLICT(id) DO UPDATE SET kind=excluded.kind, weight=excluded.weight, '
      'accessed_at=excluded.accessed_at, data=excluded.data',
      [
        id,
        kind,
        weight,
        DateTime.now().millisecondsSinceEpoch,
        jsonEncode(data),
      ],
    );
  }

  void touchMemory(String id) {
    db.execute('UPDATE memory SET accessed_at = ? WHERE id = ?',
        [DateTime.now().millisecondsSinceEpoch, id]);
  }

  void deleteMemory(String id) =>
      db.execute('DELETE FROM memory WHERE id = ?', [id]);

  /// Simple, dependency-free semantic recall: any memory whose payload mentions
  /// one of the query words wins, ranked by weight then recency. This is the
  /// seam where an open-source embedding/vector plugin plugs in later.
  List<Map<String, dynamic>> searchMemory(List<String> words,
      {int limit = 6}) {
    if (words.isEmpty) return const [];
    final clauses = [for (final _ in words) 'data LIKE ?'];
    final args = <Object?>[
      for (final w in words) '%$w%',
    ];
    final rows = db.select(
      'SELECT id, data, weight FROM memory WHERE ${clauses.join(' OR ')} '
      'ORDER BY weight DESC, accessed_at DESC LIMIT ?',
      [...args, limit],
    );
    return [
      for (final r in rows)
        {
          'id': r['id'] as String,
          'weight': (r['weight'] as num).toDouble(),
          'data': jsonDecode(r['data']) as Map<String, dynamic>,
        }
    ];
  }

  List<Map<String, dynamic>> recentMemory({int limit = 12}) {
    final rows = db.select(
        'SELECT id, data FROM memory ORDER BY accessed_at DESC LIMIT ?',
        [limit]);
    return [
      for (final r in rows)
        {
          'id': r['id'] as String,
          'data': jsonDecode(r['data']) as Map<String, dynamic>,
        }
    ];
  }
}

/// A conversation row for history lists.
class ConversationRow {
  final String id;
  final String title;
  final ChatMode mode;
  final String status;
  final DateTime updatedAt;

  const ConversationRow({
    required this.id,
    required this.title,
    required this.mode,
    required this.status,
    required this.updatedAt,
  });

  factory ConversationRow.fromRow(Map<String, dynamic> r) => ConversationRow(
        id: r['id'] as String,
        title: r['title'] as String,
        mode: ChatMode.values.byName(r['mode'] as String),
        status: r['status'] as String,
        updatedAt: DateTime.parse(r['updated_at'] as String),
      );
}
