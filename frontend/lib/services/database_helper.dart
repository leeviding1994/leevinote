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

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'leevinote.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion == 1) {
          // v1 -> v2: recreate tables with local_id as primary key
          await db.execute('DROP TABLE IF EXISTS notes');
          await db.execute('DROP TABLE IF EXISTS folders');
          await _createTables(db);
          await _migrateFromSharedPreferences(db);
        }
      },
      onOpen: (db) async {
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
            await db.insert('notes', {
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
            }, conflictAlgorithm: ConflictAlgorithm.replace);
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
            await db.insert('folders', {
              'id': folder.id,
              'local_id': folder.localId,
              'name': folder.name,
              'parent_id': folder.parentId,
              'local_parent_id': folder.localParentId,
              'sync_status': folder.syncStatus,
              'created_at': folder.createdAt.millisecondsSinceEpoch,
              'updated_at': folder.updatedAt.millisecondsSinceEpoch,
              'is_deleted': 0,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      await prefs.setBool('db_migrated', true);
    } catch (_) {}
  }

  // Notes CRUD
  Future<List<Map<String, dynamic>>> getAllNotes() async {
    final db = await database;
    return await db.query(
      'notes',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> searchNotes(String query) async {
    final db = await database;
    return await db.query(
      'notes',
      where: 'is_deleted = ? AND (title LIKE ? OR content LIKE ?)',
      whereArgs: [0, '%$query%', '%$query%'],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getNotesByFolder(String? localFolderId) async {
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
    await db.insert('notes', data, conflictAlgorithm: ConflictAlgorithm.replace);
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
  }

  Future<void> deleteNote(String localId) async {
    final db = await database;
    await db.update(
      'notes',
      {'is_deleted': 1},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> forceDeleteNote(String localId) async {
    final db = await database;
    await db.delete(
      'notes',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
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
    await db.insert('folders', data, conflictAlgorithm: ConflictAlgorithm.replace);
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

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('notes');
    await db.delete('folders');
  }
}
