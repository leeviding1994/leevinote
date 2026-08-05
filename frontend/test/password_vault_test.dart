import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leevinote/models/password_entry.dart';
import 'package:leevinote/services/vault_crypto_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('生成恢复密钥时不会初始化密码库，确认后才持久化', () async {
    final crypto = VaultCryptoService();
    final bootstrap = await crypto.prepareVault('Abc123!@');

    expect(await crypto.isConfigured(), isFalse);

    await crypto.commitVault(bootstrap.metadata);

    expect(await crypto.isConfigured(), isTrue);
    final masterKey = await crypto.unlockWithMasterPassword('Abc123!@');
    final recoveryKey =
        await crypto.unlockWithRecoveryCode(bootstrap.recoveryCode);
    expect(
      await masterKey.extractBytes(),
      await recoveryKey.extractBytes(),
    );
  });

  test('条目敏感字段加密后可完整恢复且错误主密码被拒绝', () async {
    final crypto = VaultCryptoService();
    final bootstrap =
        await crypto.prepareVault('a commercially strong master passphrase');
    await crypto.commitVault(bootstrap.metadata);
    final dataKey = await crypto.unlockWithMasterPassword(
      'a commercially strong master passphrase',
    );
    final entry = PasswordEntry(
      localId: 'entry-1',
      title: 'GitHub',
      username: 'user@example.com',
      password: 'M2!g7w#Q9zLp4@xR',
      notes: 'backup codes are offline',
    );

    final encrypted = await crypto.encryptPayload(
      localId: entry.localId,
      jsonPayload: jsonEncode(entry.toJson()),
      dataKey: dataKey,
    );
    final decrypted = await crypto.decryptPayload(
      localId: entry.localId,
      payload: encrypted,
      dataKey: dataKey,
    );

    expect(
        PasswordEntry.fromJson(jsonDecode(decrypted)).password, entry.password);
    await expectLater(
      crypto.unlockWithMasterPassword('this password is definitely wrong'),
      throwsA(isA<VaultException>()),
    );
  });

  test('密码强度评级不会把短密码标记为强密码', () {
    expect(evaluatePasswordStrength('123456'), PasswordStrength.weak);
    expect(
      evaluatePasswordStrength('N4!vQ8@rT2#xL7\$p'),
      PasswordStrength.strong,
    );
  });
}
