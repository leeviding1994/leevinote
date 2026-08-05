import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leevinote/models/note.dart';
import 'package:leevinote/models/folder.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;
  bool _migrated = false;
  bool _noteSearchIndexEnabled = false;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'leevinote.db');

    return await openDatabase(
      path,
      version: 6,
      onCreate: (db, version) async {
        await _createTables(db);
        await _createTransactionTables(db);
        await _createHealthTables(db);
        await _createVaultTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion == 1) {
          // v1 -> v2: recreate tables with local_id as primary key
          await db.execute('DROP TABLE IF EXISTS notes');
          await db.execute('DROP TABLE IF EXISTS folders');
          await _createTables(db);
          await _migrateFromSharedPreferences(db);
        }
        if (oldVersion <= 2) {
          // v2 -> v3: add bookkeeping module tables
          await _createTransactionTables(db);
        }
        if (oldVersion <= 3) {
          // v3 -> v4: add FTS index for local note search
          await _createNoteSearchIndex(db);
          await _rebuildNoteSearchIndex(db);
        }
        if (oldVersion <= 4) {
          // v4 -> v5: add health tracking module tables
          await _createHealthTables(db);
        }
        if (oldVersion <= 5) {
          // v5 -> v6: add encrypted password vault tables
          await _createVaultTables(db);
        }
      },
      onOpen: (db) async {
        await _createTransactionTables(db);
        await _createHealthTables(db);
        await _createVaultTables(db);
        await _createNoteSearchIndex(db);
        if (!_migrated) {
          await _migrateFromSharedPreferences(db);
          _migrated = true;
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id INTEGER,
        local_id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT,
        category TEXT,
        folder_id INTEGER,
        local_folder_id TEXT,
        sync_status TEXT NOT NULL DEFAULT 'local',
        created_at INTEGER,
        updated_at INTEGER,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_notes_title ON notes(title)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_notes_sync_status ON notes(sync_status)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_notes_is_deleted ON notes(is_deleted)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_notes_local_folder ON notes(local_folder_id)
    ''');
    await _createNoteSearchIndex(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS folders (
        id INTEGER,
        local_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parent_id INTEGER,
        local_parent_id TEXT,
        sync_status TEXT NOT NULL DEFAULT 'local',
        created_at INTEGER,
        updated_at INTEGER,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_folders_sync_status ON folders(sync_status)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_folders_is_deleted ON folders(is_deleted)
    ''');
  }

  Future<void> _createNoteSearchIndex(Database db) async {
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
          local_id UNINDEXED,
          title,
          content
        )
      ''');
      _noteSearchIndexEnabled = true;
    } catch (_) {
      try {
        await db.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts4(
            local_id,
            title,
            content,
            notindexed=local_id
          )
        ''');
        _noteSearchIndexEnabled = true;
      } catch (_) {
        _noteSearchIndexEnabled = false;
      }
    }
  }

  Future<void> _rebuildNoteSearchIndex(Database db) async {
    if (!_noteSearchIndexEnabled) return;
    await db.delete('notes_fts');
    await db.execute('''
      INSERT INTO notes_fts(local_id, title, content)
      SELECT local_id, title, COALESCE(content, '')
      FROM notes
      WHERE is_deleted = 0
    ''');
  }

  Future<void> _upsertNoteSearchIndex(Database db, Note note) async {
    if (!_noteSearchIndexEnabled) return;
    await db
        .delete('notes_fts', where: 'local_id = ?', whereArgs: [note.localId]);
    await db.insert('notes_fts', {
      'local_id': note.localId,
      'title': note.title,
      'content': note.content ?? '',
    });
  }

  Future<void> _deleteNoteSearchIndex(Database db, String localId) async {
    if (!_noteSearchIndexEnabled) return;
    await db.delete('notes_fts', where: 'local_id = ?', whereArgs: [localId]);
  }

  Future<void> _migrateFromSharedPreferences(Database db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final migrated = prefs.getBool('db_migrated') ?? false;
      if (migrated) return;

      // Migrate notes
      final notesJson = prefs.getString('local_notes');
      if (notesJson != null && notesJson.isNotEmpty) {
        final list = jsonDecode(notesJson) as List;
        for (final e in list) {
          final note = Note.fromJson(e as Map<String, dynamic>);
          if (note.syncStatus != 'deleted') {
            await db.insert(
                'notes',
                {
                  'id': note.id,
                  'local_id': note.localId,
                  'title': note.title,
                  'content': note.content,
                  'category': note.category,
                  'folder_id': note.folderId,
                  'local_folder_id': note.localFolderId,
                  'sync_status': note.syncStatus,
                  'created_at': note.createdAt.millisecondsSinceEpoch,
                  'updated_at': note.updatedAt.millisecondsSinceEpoch,
                  'is_deleted': 0,
                },
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      // Migrate folders
      final foldersJson = prefs.getString('local_folders');
      if (foldersJson != null && foldersJson.isNotEmpty) {
        final list = jsonDecode(foldersJson) as List;
        for (final e in list) {
          final folder = Folder.fromJson(e as Map<String, dynamic>);
          if (folder.syncStatus != 'deleted') {
            await db.insert(
                'folders',
                {
                  'id': folder.id,
                  'local_id': folder.localId,
                  'name': folder.name,
                  'parent_id': folder.parentId,
                  'local_parent_id': folder.localParentId,
                  'sync_status': folder.syncStatus,
                  'created_at': folder.createdAt.millisecondsSinceEpoch,
                  'updated_at': folder.updatedAt.millisecondsSinceEpoch,
                  'is_deleted': 0,
                },
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      await prefs.setBool('db_migrated', true);
    } catch (_) {}
  }

  // Notes CRUD
  Future<List<Map<String, dynamic>>> getAllNotes({
    bool includeDeleted = false,
  }) async {
    final db = await database;
    return await db.query(
      'notes',
      where: includeDeleted ? null : 'is_deleted = ?',
      whereArgs: includeDeleted ? null : [0],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> searchNotes(String query) async {
    final db = await database;
    if (!_noteSearchIndexEnabled) {
      return _searchNotesWithLike(db, query);
    }
    try {
      return await db.rawQuery('''
        SELECT notes.*
        FROM notes_fts
        JOIN notes ON notes.local_id = notes_fts.local_id
        WHERE notes.is_deleted = 0 AND notes_fts MATCH ?
        ORDER BY notes.created_at DESC
      ''', [_buildFtsQuery(query)]);
    } catch (_) {
      return _searchNotesWithLike(db, query);
    }
  }

  Future<List<Map<String, dynamic>>> _searchNotesWithLike(
      Database db, String query) async {
    return await db.rawQuery('''
      SELECT *
      FROM notes
      WHERE is_deleted = 0 AND (title LIKE ? OR content LIKE ?)
      ORDER BY created_at DESC
    ''', ['%$query%', '%$query%']);
  }

  String _buildFtsQuery(String query) {
    final terms = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .map((term) => '"${term.replaceAll('"', '""')}"*')
        .toList();
    return terms.isEmpty ? '""' : terms.join(' AND ');
  }

  Future<List<Map<String, dynamic>>> getNotesByFolder(
      String? localFolderId) async {
    final db = await database;
    if (localFolderId != null) {
      return await db.query(
        'notes',
        where: 'is_deleted = ? AND local_folder_id = ?',
        whereArgs: [0, localFolderId],
        orderBy: 'created_at DESC',
      );
    } else {
      return await db.query(
        'notes',
        where: 'is_deleted = ? AND local_folder_id IS NULL',
        whereArgs: [0],
        orderBy: 'created_at DESC',
      );
    }
  }

  Future<Map<String, dynamic>?> getNoteByLocalId(String localId) async {
    final db = await database;
    final results = await db.query(
      'notes',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertNote(Note note) async {
    final db = await database;
    final data = {
      'local_id': note.localId,
      'title': note.title,
      'content': note.content,
      'category': note.category,
      'folder_id': note.folderId,
      'local_folder_id': note.localFolderId,
      'sync_status': note.syncStatus,
      'created_at': note.createdAt.millisecondsSinceEpoch,
      'updated_at': note.updatedAt.millisecondsSinceEpoch,
      'is_deleted': 0,
    };
    // 只有远程同步过的笔记才有 id
    if (note.id != null) {
      data['id'] = note.id;
    }
    await db.insert('notes', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _upsertNoteSearchIndex(db, note);
  }

  Future<void> updateNote(Note note) async {
    final db = await database;
    final data = {
      'title': note.title,
      'content': note.content,
      'category': note.category,
      'folder_id': note.folderId,
      'local_folder_id': note.localFolderId,
      'sync_status': note.syncStatus,
      'updated_at': note.updatedAt.millisecondsSinceEpoch,
    };
    if (note.id != null) {
      data['id'] = note.id;
    }
    await db.update(
      'notes',
      data,
      where: 'local_id = ?',
      whereArgs: [note.localId],
    );
    await _upsertNoteSearchIndex(db, note);
  }

  Future<void> deleteNote(String localId) async {
    final db = await database;
    await db.update(
      'notes',
      {'is_deleted': 1},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
    await _deleteNoteSearchIndex(db, localId);
  }

  Future<void> forceDeleteNote(String localId) async {
    final db = await database;
    await db.delete(
      'notes',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
    await _deleteNoteSearchIndex(db, localId);
  }

  // Folders CRUD
  Future<List<Map<String, dynamic>>> getAllFolders() async {
    final db = await database;
    return await db.query(
      'folders',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'name ASC',
    );
  }

  Future<Map<String, dynamic>?> getFolderByLocalId(String localId) async {
    final db = await database;
    final results = await db.query(
      'folders',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertFolder(Folder folder) async {
    final db = await database;
    final data = {
      'local_id': folder.localId,
      'name': folder.name,
      'parent_id': folder.parentId,
      'local_parent_id': folder.localParentId,
      'sync_status': folder.syncStatus,
      'created_at': folder.createdAt.millisecondsSinceEpoch,
      'updated_at': folder.updatedAt.millisecondsSinceEpoch,
      'is_deleted': 0,
    };
    if (folder.id != null) {
      data['id'] = folder.id;
    }
    await db.insert('folders', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateFolder(Folder folder) async {
    final db = await database;
    final data = {
      'name': folder.name,
      'parent_id': folder.parentId,
      'local_parent_id': folder.localParentId,
      'sync_status': folder.syncStatus,
      'updated_at': folder.updatedAt.millisecondsSinceEpoch,
    };
    if (folder.id != null) {
      data['id'] = folder.id;
    }
    await db.update(
      'folders',
      data,
      where: 'local_id = ?',
      whereArgs: [folder.localId],
    );
  }

  Future<void> deleteFolder(String localId) async {
    final db = await database;
    await db.update(
      'folders',
      {'is_deleted': 1},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> forceDeleteFolder(String localId) async {
    final db = await database;
    await db.delete(
      'folders',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> _createTransactionTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transaction_categories (
        id INTEGER,
        local_id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        icon TEXT,
        color TEXT,
        sync_status TEXT NOT NULL DEFAULT 'local',
        created_at INTEGER,
        updated_at INTEGER,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transaction_categories_type ON transaction_categories(type)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transaction_categories_sync_status ON transaction_categories(sync_status)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transaction_categories_is_deleted ON transaction_categories(is_deleted)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER,
        local_id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        transaction_date INTEGER NOT NULL,
        category_id INTEGER,
        local_category_id TEXT,
        note TEXT,
        sync_status TEXT NOT NULL DEFAULT 'local',
        created_at INTEGER,
        updated_at INTEGER,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transactions_transaction_date ON transactions(transaction_date)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transactions_category_id ON transactions(category_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transactions_local_category_id ON transactions(local_category_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transactions_sync_status ON transactions(sync_status)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transactions_is_deleted ON transactions(is_deleted)
    ''');
  }

  Future<void> _createHealthTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS health_entries (
        local_id TEXT PRIMARY KEY,
        entry_date INTEGER NOT NULL,
        weight_kg REAL,
        body_photo_path TEXT,
        estimated_body_fat_percent REAL,
        body_analysis_note TEXT,
        created_at INTEGER,
        updated_at INTEGER,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_health_entries_date ON health_entries(entry_date)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_health_entries_is_deleted ON health_entries(is_deleted)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meal_entries (
        local_id TEXT PRIMARY KEY,
        meal_date INTEGER NOT NULL,
        meal_type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        photo_path TEXT,
        estimated_calories REAL NOT NULL,
        protein_g REAL NOT NULL DEFAULT 0,
        carbs_g REAL NOT NULL DEFAULT 0,
        fat_g REAL NOT NULL DEFAULT 0,
        analysis_note TEXT,
        created_at INTEGER,
        updated_at INTEGER,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_meal_entries_date ON meal_entries(meal_date)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_meal_entries_is_deleted ON meal_entries(is_deleted)
    ''');
  }

  Future<void> _createVaultTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS password_vault_items (
        local_id TEXT PRIMARY KEY,
        nonce TEXT NOT NULL,
        cipher_text TEXT NOT NULL,
        mac TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_password_vault_items_updated_at
      ON password_vault_items(updated_at DESC)
    ''');
  }

  // Transaction Categories CRUD
  Future<List<Map<String, dynamic>>> getAllTransactionCategories() async {
    final db = await database;
    return await db.query(
      'transaction_categories',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'type ASC, created_at ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getTransactionCategoriesByType(
      String type) async {
    final db = await database;
    return await db.query(
      'transaction_categories',
      where: 'is_deleted = ? AND type = ?',
      whereArgs: [0, type],
      orderBy: 'created_at ASC',
    );
  }

  Future<Map<String, dynamic>?> getTransactionCategoryByLocalId(
      String localId) async {
    final db = await database;
    final results = await db.query(
      'transaction_categories',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertTransactionCategory(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'transaction_categories',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTransactionCategory(
      String localId, Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      'transaction_categories',
      data,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> deleteTransactionCategory(String localId) async {
    final db = await database;
    await db.update(
      'transaction_categories',
      {'is_deleted': 1},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> forceDeleteTransactionCategory(String localId) async {
    final db = await database;
    await db.delete(
      'transaction_categories',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  // Transactions CRUD
  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await database;
    return await db.query(
      'transactions',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'transaction_date DESC, created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getTransactionsByDateRange(
      int start, int end) async {
    final db = await database;
    return await db.query(
      'transactions',
      where:
          'is_deleted = ? AND transaction_date >= ? AND transaction_date <= ?',
      whereArgs: [0, start, end],
      orderBy: 'transaction_date DESC, created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getTransactionsByType(String type) async {
    final db = await database;
    return await db.query(
      'transactions',
      where: 'is_deleted = ? AND type = ?',
      whereArgs: [0, type],
      orderBy: 'transaction_date DESC, created_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getTransactionByLocalId(String localId) async {
    final db = await database;
    final results = await db.query(
      'transactions',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertTransaction(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'transactions',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTransaction(
      String localId, Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      'transactions',
      data,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> deleteTransaction(String localId) async {
    final db = await database;
    await db.update(
      'transactions',
      {'is_deleted': 1},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> forceDeleteTransaction(String localId) async {
    final db = await database;
    await db.delete(
      'transactions',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  // Health CRUD
  Future<List<Map<String, dynamic>>> getAllHealthEntries() async {
    final db = await database;
    return await db.query(
      'health_entries',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'entry_date DESC',
    );
  }

  Future<void> insertHealthEntry(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'health_entries',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllMealEntries() async {
    final db = await database;
    return await db.query(
      'meal_entries',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'meal_date DESC, created_at DESC',
    );
  }

  Future<void> insertMealEntry(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'meal_entries',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMealEntry(String localId) async {
    final db = await database;
    await db.update(
      'meal_entries',
      {'is_deleted': 1},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  // Encrypted password vault CRUD. No plaintext secret fields are persisted.
  Future<List<Map<String, dynamic>>> getAllPasswordVaultItems() async {
    final db = await database;
    return db.query(
      'password_vault_items',
      orderBy: 'updated_at DESC',
    );
  }

  Future<void> upsertPasswordVaultItem(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'password_vault_items',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePasswordVaultItem(String localId) async {
    final db = await database;
    await db.delete(
      'password_vault_items',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> clearPasswordVault() async {
    final db = await database;
    await db.delete('password_vault_items');
  }

  Future<void> clearNotes() async {
    final db = await database;
    await db.delete('notes');
    await db.delete('notes_fts');
  }

  Future<void> clearFolders() async {
    final db = await database;
    await db.delete('folders');
  }

  Future<void> clearAll() async {
    final db = await database;
    await clearNotes();
    await clearFolders();
    await db.delete('transactions');
    await db.delete('transaction_categories');
    await db.delete('health_entries');
    await db.delete('meal_entries');
  }
}
