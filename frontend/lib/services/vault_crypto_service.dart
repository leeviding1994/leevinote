import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VaultCryptoService {
  static const _metadataKey = 'password_vault_metadata_v1';
  static const _dekAad = 'leevinote-password-vault-dek-v1';
  static const _itemAadPrefix = 'leevinote-password-vault-item-v1:';

  final FlutterSecureStorage _storage;
  final AesGcm _cipher = AesGcm.with256bits();
  final Argon2id _argon2 = Argon2id(
    memory: 19 * 1024,
    parallelism: 1,
    iterations: 2,
    hashLength: 32,
  );

  VaultCryptoService({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  Future<bool> isConfigured() async {
    return await _storage.containsKey(key: _metadataKey);
  }

  Future<void> deleteVaultMetadata() async {
    await _storage.delete(key: _metadataKey);
  }

  /// Prepare vault keys in memory only. Does not persist until [commitVault].
  Future<VaultBootstrap> prepareVault(String masterPassword) async {
    if (await isConfigured()) {
      throw const VaultException('密码库已经存在，不能重复初始化');
    }
    if (masterPassword.length < 8) {
      throw const VaultException('主密码至少需要 8 个字符');
    }

    final salt = SecretKeyData.random(length: 16).bytes;
    final dataKey = await _cipher.newSecretKey();
    final recoveryBytes = SecretKeyData.random(length: 32).bytes;
    final masterKey = await _deriveMasterKey(masterPassword, salt);
    final recoveryKey = SecretKey(recoveryBytes);
    final recoveryCode = _formatRecoveryCode(recoveryBytes);

    final metadata = VaultMetadata(
      version: 1,
      salt: salt,
      masterWrappedKey: await _wrapDataKey(dataKey, masterKey),
      recoveryWrappedKey: await _wrapDataKey(dataKey, recoveryKey),
      createdAt: DateTime.now(),
    );

    // Self-check: master password and recovery key must unwrap the same DEK.
    final masterUnwrapped =
        await _unwrapDataKey(metadata.masterWrappedKey, masterKey);
    final recoveryUnwrapped =
        await _unwrapDataKey(metadata.recoveryWrappedKey, recoveryKey);
    final expected = await dataKey.extractBytes();
    final fromMaster = await masterUnwrapped.extractBytes();
    final fromRecovery = await recoveryUnwrapped.extractBytes();
    if (!_bytesEqual(expected, fromMaster) ||
        !_bytesEqual(expected, fromRecovery)) {
      throw const VaultException('恢复密钥生成校验失败，请重试');
    }

    return VaultBootstrap(
      dataKey: dataKey,
      recoveryCode: recoveryCode,
      metadata: metadata,
    );
  }

  Future<void> commitVault(VaultMetadata metadata) async {
    if (await isConfigured()) {
      throw const VaultException('密码库已经存在，不能重复初始化');
    }
    await _storage.write(
      key: _metadataKey,
      value: jsonEncode(metadata.toJson()),
    );
  }

  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  Future<SecretKey> unlockWithMasterPassword(String masterPassword) async {
    final metadata = await _readMetadata();
    final masterKey = await _deriveMasterKey(masterPassword, metadata.salt);
    return _unwrapDataKey(metadata.masterWrappedKey, masterKey);
  }

  Future<SecretKey> unlockWithRecoveryCode(String recoveryCode) async {
    final metadata = await _readMetadata();
    final recoveryBytes = _parseRecoveryCode(recoveryCode);
    return _unwrapDataKey(
      metadata.recoveryWrappedKey,
      SecretKey(recoveryBytes),
    );
  }

  Future<EncryptedVaultPayload> encryptPayload({
    required String localId,
    required String jsonPayload,
    required SecretKey dataKey,
  }) async {
    final box = await _cipher.encrypt(
      utf8.encode(jsonPayload),
      secretKey: dataKey,
      aad: utf8.encode('$_itemAadPrefix$localId'),
    );
    return EncryptedVaultPayload.fromSecretBox(box);
  }

  Future<String> decryptPayload({
    required String localId,
    required EncryptedVaultPayload payload,
    required SecretKey dataKey,
  }) async {
    try {
      final clearText = await _cipher.decrypt(
        payload.toSecretBox(),
        secretKey: dataKey,
        aad: utf8.encode('$_itemAadPrefix$localId'),
      );
      return utf8.decode(clearText);
    } on SecretBoxAuthenticationError {
      throw const VaultException('密码库数据完整性校验失败');
    }
  }

  Future<SecretKey> _deriveMasterKey(
    String masterPassword,
    List<int> salt,
  ) {
    return _argon2.deriveKeyFromPassword(
      password: masterPassword,
      nonce: salt,
    );
  }

  Future<EncryptedVaultPayload> _wrapDataKey(
    SecretKey dataKey,
    SecretKey wrappingKey,
  ) async {
    final dataKeyBytes = await dataKey.extractBytes();
    final box = await _cipher.encrypt(
      dataKeyBytes,
      secretKey: wrappingKey,
      aad: utf8.encode(_dekAad),
    );
    return EncryptedVaultPayload.fromSecretBox(box);
  }

  Future<SecretKey> _unwrapDataKey(
    EncryptedVaultPayload payload,
    SecretKey wrappingKey,
  ) async {
    try {
      final bytes = await _cipher.decrypt(
        payload.toSecretBox(),
        secretKey: wrappingKey,
        aad: utf8.encode(_dekAad),
      );
      return SecretKey(bytes);
    } on SecretBoxAuthenticationError {
      throw const VaultException('主密码或恢复密钥不正确');
    }
  }

  Future<VaultMetadata> _readMetadata() async {
    final raw = await _storage.read(key: _metadataKey);
    if (raw == null) {
      throw const VaultException('密码库尚未初始化');
    }
    try {
      return VaultMetadata.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const VaultException('密码库元数据损坏');
    }
  }

  String _formatRecoveryCode(List<int> bytes) {
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return List.generate(
      8,
      (index) => hex.substring(index * 8, (index + 1) * 8),
    ).join('-');
  }

  List<int> _parseRecoveryCode(String code) {
    final normalized = code.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (normalized.length != 64) {
      throw const VaultException('恢复密钥格式不正确');
    }
    return List.generate(
      32,
      (index) => int.parse(
        normalized.substring(index * 2, index * 2 + 2),
        radix: 16,
      ),
    );
  }
}

class VaultBootstrap {
  final SecretKey dataKey;
  final String recoveryCode;
  final VaultMetadata metadata;

  const VaultBootstrap({
    required this.dataKey,
    required this.recoveryCode,
    required this.metadata,
  });
}

class VaultMetadata {
  final int version;
  final List<int> salt;
  final EncryptedVaultPayload masterWrappedKey;
  final EncryptedVaultPayload recoveryWrappedKey;
  final DateTime createdAt;

  const VaultMetadata({
    required this.version,
    required this.salt,
    required this.masterWrappedKey,
    required this.recoveryWrappedKey,
    required this.createdAt,
  });

  factory VaultMetadata.fromJson(Map<String, dynamic> json) {
    return VaultMetadata(
      version: json['version'] as int,
      salt: base64Decode(json['salt'] as String),
      masterWrappedKey: EncryptedVaultPayload.fromJson(
        json['master_wrapped_key'] as Map<String, dynamic>,
      ),
      recoveryWrappedKey: EncryptedVaultPayload.fromJson(
        json['recovery_wrapped_key'] as Map<String, dynamic>,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'salt': base64Encode(salt),
      'master_wrapped_key': masterWrappedKey.toJson(),
      'recovery_wrapped_key': recoveryWrappedKey.toJson(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class EncryptedVaultPayload {
  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;

  const EncryptedVaultPayload({
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  factory EncryptedVaultPayload.fromSecretBox(SecretBox box) {
    return EncryptedVaultPayload(
      nonce: box.nonce,
      cipherText: box.cipherText,
      mac: box.mac.bytes,
    );
  }

  factory EncryptedVaultPayload.fromJson(Map<String, dynamic> json) {
    return EncryptedVaultPayload(
      nonce: base64Decode(json['nonce'] as String),
      cipherText: base64Decode(json['cipher_text'] as String),
      mac: base64Decode(json['mac'] as String),
    );
  }

  SecretBox toSecretBox() {
    return SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(mac),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nonce': base64Encode(nonce),
      'cipher_text': base64Encode(cipherText),
      'mac': base64Encode(mac),
    };
  }
}

class VaultException implements Exception {
  final String message;

  const VaultException(this.message);

  @override
  String toString() => message;
}
