import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:leevinote/models/password_entry.dart';
import 'package:leevinote/services/database_helper.dart';
import 'package:leevinote/services/vault_crypto_service.dart';

enum VaultStatus { loading, unconfigured, locked, unlocked, error }

class PasswordVaultService extends ChangeNotifier {
  static const autoLockDuration = Duration(minutes: 5);
  static const clipboardClearDuration = Duration(seconds: 30);

  final DatabaseHelper _database;
  final VaultCryptoService _crypto;

  VaultStatus _status = VaultStatus.loading;
  SecretKey? _dataKey;
  List<PasswordEntry> _entries = [];
  Timer? _autoLockTimer;
  String? _errorMessage;
  bool _initialized = false;
  VaultBootstrap? _pendingBootstrap;

  PasswordVaultService({
    DatabaseHelper? database,
    VaultCryptoService? crypto,
  })  : _database = database ?? DatabaseHelper(),
        _crypto = crypto ?? VaultCryptoService();

  VaultStatus get status => _status;
  bool get isUnlocked => _status == VaultStatus.unlocked;
  bool get isConfigured => _status != VaultStatus.unconfigured;
  String? get errorMessage => _errorMessage;
  List<PasswordEntry> get entries => List.unmodifiable(_entries);
  int get favoriteCount => _entries.where((entry) => entry.favorite).length;
  int get weakPasswordCount => _entries
      .where((entry) =>
          evaluatePasswordStrength(entry.password) == PasswordStrength.weak)
      .length;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final configured = await _crypto.isConfigured();
      _status = configured ? VaultStatus.locked : VaultStatus.unconfigured;
      _errorMessage = null;
    } catch (e, st) {
      debugPrint('初始化密码库失败: $e\n$st');
      _initialized = false;
      _status = VaultStatus.error;
      _errorMessage = '无法访问系统安全存储：$e';
    }
    notifyListeners();
  }

  /// Generate keys and recovery code only. Vault stays unconfigured until
  /// [commitSetup] succeeds after the user confirms the recovery code.
  Future<String> prepareSetup(String masterPassword) async {
    _discardPendingBootstrap();
    _errorMessage = null;
    try {
      final bootstrap = await _crypto.prepareVault(masterPassword);
      _pendingBootstrap = bootstrap;
      _status = VaultStatus.unconfigured;
      notifyListeners();
      return bootstrap.recoveryCode;
    } catch (e) {
      _discardPendingBootstrap();
      _status = VaultStatus.unconfigured;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> commitSetup() async {
    final pending = _pendingBootstrap;
    if (pending == null) {
      throw const VaultException('没有待确认的密码库初始化');
    }
    try {
      await _crypto.commitVault(pending.metadata);
      _dataKey = pending.dataKey;
      _pendingBootstrap = null;
      _entries = [];
      _status = VaultStatus.unlocked;
      _errorMessage = null;
      _scheduleAutoLock();
      notifyListeners();
    } catch (e) {
      _discardPendingBootstrap();
      _status = VaultStatus.unconfigured;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void cancelSetup() {
    _discardPendingBootstrap();
    _status = VaultStatus.unconfigured;
    _errorMessage = null;
    notifyListeners();
  }

  void _discardPendingBootstrap() {
    final pending = _pendingBootstrap;
    if (pending == null) return;
    final key = pending.dataKey;
    if (key is SecretKeyData) key.destroy();
    _pendingBootstrap = null;
  }

  Future<void> unlockWithMasterPassword(String masterPassword) async {
    await _unlock(() => _crypto.unlockWithMasterPassword(masterPassword));
  }

  Future<void> unlockWithRecoveryCode(String recoveryCode) async {
    await _unlock(() => _crypto.unlockWithRecoveryCode(recoveryCode));
  }

  Future<void> _unlock(Future<SecretKey> Function() unlockKey) async {
    _status = VaultStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _dataKey = await unlockKey();
      await _loadEntries();
      _status = VaultStatus.unlocked;
      _scheduleAutoLock();
      notifyListeners();
    } catch (e) {
      _dataKey = null;
      _entries = [];
      _status = VaultStatus.locked;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void lock() {
    _autoLockTimer?.cancel();
    final key = _dataKey;
    if (key is SecretKeyData) {
      key.destroy();
    }
    _dataKey = null;
    _entries = [];
    _status = VaultStatus.locked;
    _errorMessage = null;
    notifyListeners();
  }

  void recordActivity() {
    if (isUnlocked) _scheduleAutoLock();
  }

  List<PasswordEntry> search(String query, {bool favoritesOnly = false}) {
    final normalized = query.trim().toLowerCase();
    return _entries.where((entry) {
      if (favoritesOnly && !entry.favorite) return false;
      if (normalized.isEmpty) return true;
      return entry.title.toLowerCase().contains(normalized) ||
          entry.username.toLowerCase().contains(normalized) ||
          (entry.website?.toLowerCase().contains(normalized) ?? false) ||
          entry.tags.any((tag) => tag.toLowerCase().contains(normalized));
    }).toList();
  }

  Future<void> saveEntry(PasswordEntry entry) async {
    final key = _requireDataKey();
    final encrypted = await _crypto.encryptPayload(
      localId: entry.localId,
      jsonPayload: jsonEncode(entry.toJson()),
      dataKey: key,
    );
    final payload = encrypted.toJson();
    await _database.upsertPasswordVaultItem({
      'local_id': entry.localId,
      'nonce': payload['nonce'],
      'cipher_text': payload['cipher_text'],
      'mac': payload['mac'],
      'created_at': entry.createdAt.millisecondsSinceEpoch,
      'updated_at': entry.updatedAt.millisecondsSinceEpoch,
    });

    final index =
        _entries.indexWhere((existing) => existing.localId == entry.localId);
    if (index == -1) {
      _entries.insert(0, entry);
    } else {
      _entries[index] = entry;
    }
    _sortEntries();
    recordActivity();
    notifyListeners();
  }

  Future<void> deleteEntry(String localId) async {
    _requireDataKey();
    await _database.deletePasswordVaultItem(localId);
    _entries.removeWhere((entry) => entry.localId == localId);
    recordActivity();
    notifyListeners();
  }

  /// Wipe local vault metadata and ciphertext so the user can create a new
  /// vault after losing both master password and recovery key.
  Future<void> recreateVault() async {
    _autoLockTimer?.cancel();
    _discardPendingBootstrap();
    final key = _dataKey;
    if (key is SecretKeyData) key.destroy();
    _dataKey = null;
    _entries = [];

    await _database.clearPasswordVault();
    await _crypto.deleteVaultMetadata();

    _status = VaultStatus.unconfigured;
    _errorMessage = null;
    _initialized = true;
    notifyListeners();
  }

  Future<void> copySecret(String value) async {
    recordActivity();
    await Clipboard.setData(ClipboardData(text: value));
    Timer(clipboardClearDuration, () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  String generatePassword({
    int length = 20,
    bool includeSymbols = true,
  }) {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    const symbols = r'!@#$%^&*()-_=+[]{};:,.?';
    final alphabet = includeSymbols ? '$letters$symbols' : letters;
    final output = StringBuffer();
    final maxAccepted = 256 - (256 % alphabet.length);

    while (output.length < length) {
      final randomBytes = SecretKeyData.random(length: length).bytes;
      for (final byte in randomBytes) {
        if (byte >= maxAccepted) continue;
        output.write(alphabet[byte % alphabet.length]);
        if (output.length == length) break;
      }
    }
    recordActivity();
    return output.toString();
  }

  Future<void> _loadEntries() async {
    final key = _requireDataKey();
    final rows = await _database.getAllPasswordVaultItems();
    final entries = <PasswordEntry>[];
    for (final row in rows) {
      final localId = row['local_id'] as String;
      final jsonPayload = await _crypto.decryptPayload(
        localId: localId,
        payload: EncryptedVaultPayload.fromJson({
          'nonce': row['nonce'],
          'cipher_text': row['cipher_text'],
          'mac': row['mac'],
        }),
        dataKey: key,
      );
      entries.add(
        PasswordEntry.fromJson(
          jsonDecode(jsonPayload) as Map<String, dynamic>,
        ),
      );
    }
    _entries = entries;
    _sortEntries();
  }

  SecretKey _requireDataKey() {
    final key = _dataKey;
    if (key == null || !isUnlocked && _status != VaultStatus.loading) {
      throw const VaultException('密码库已锁定');
    }
    return key;
  }

  void _sortEntries() {
    _entries.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  void _scheduleAutoLock() {
    _autoLockTimer?.cancel();
    _autoLockTimer = Timer(autoLockDuration, lock);
  }

  @override
  void dispose() {
    _autoLockTimer?.cancel();
    _discardPendingBootstrap();
    final key = _dataKey;
    if (key is SecretKeyData) key.destroy();
    _dataKey = null;
    _entries = [];
    super.dispose();
  }
}
