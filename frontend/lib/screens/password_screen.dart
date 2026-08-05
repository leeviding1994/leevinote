import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/design/app_theme.dart';
import 'package:leevinote/models/password_entry.dart';
import 'package:leevinote/services/password_vault_service.dart';
import 'package:leevinote/widgets/widgets.dart';

class PasswordScreen extends StatefulWidget {
  final bool active;

  const PasswordScreen({
    super.key,
    this.active = true,
  });

  @override
  State<PasswordScreen> createState() => PasswordScreenState();
}

class PasswordScreenState extends State<PasswordScreen> {
  final _searchController = TextEditingController();
  final _unlockController = TextEditingController();
  bool _favoritesOnly = false;
  bool _showUnlockPassword = false;
  bool _useRecoveryCode = false;
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _initializeVault();
  }

  @override
  void didUpdateWidget(covariant PasswordScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _initializeVault();
    }
  }

  void _initializeVault() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PasswordVaultService>().initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _unlockController.dispose();
    super.dispose();
  }

  Future<void> openAddPassword() async {
    final vault = context.read<PasswordVaultService>();
    if (!vault.isUnlocked) return;
    await _showEntryEditor();
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<PasswordVaultService>();
    return switch (vault.status) {
      VaultStatus.loading => const Center(child: CircularProgressIndicator()),
      VaultStatus.unconfigured => _buildOnboarding(vault),
      VaultStatus.locked => _buildLocked(vault),
      VaultStatus.unlocked => _buildVault(vault),
      VaultStatus.error => _buildError(vault),
    };
  }

  bool get _isNarrow => MediaQuery.sizeOf(context).width < 640;
  bool get _isWide => MediaQuery.sizeOf(context).width >= 900;

  EdgeInsets get _pagePadding {
    final narrow = _isNarrow;
    return EdgeInsets.fromLTRB(
      narrow ? AppSpacing.lg : AppSpacing.xl,
      narrow ? AppSpacing.lg : AppSpacing.xl,
      narrow ? AppSpacing.lg : AppSpacing.xl,
      narrow ? 96 : AppSpacing.xl,
    );
  }

  Widget _buildOnboarding(PasswordVaultService vault) {
    final narrow = _isNarrow;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: _pagePadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Container(
                width: narrow ? 56 : 72,
                height: narrow ? 56 : 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: narrow ? 28 : 34,
                  color: theme.colorScheme.primary,
                ),
              ),
              SizedBox(height: narrow ? AppSpacing.lg : AppSpacing.xl),
              Text(
                '创建你的私人密码库',
                style: narrow ? context.h2 : context.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                narrow
                    ? 'AES-256-GCM 本机加密，Argon2id 强化主密码，数据不离开当前设备。'
                    : '所有密码在离开内存前均使用 AES-256-GCM 加密。主密码由 Argon2id 强化，数据只保存在当前设备。',
                style: context.body,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: narrow ? AppSpacing.xl : AppSpacing.xxl),
              if (narrow) ...[
                const _SecurityFeature(
                  icon: Icons.key_outlined,
                  title: '零明文存储',
                  body: '标题、账号、密码、网址和备注全部加密。',
                  compact: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                const _SecurityFeature(
                  icon: Icons.timer_outlined,
                  title: '自动锁定',
                  body: '闲置五分钟后自动锁定，也可随时手动锁定。',
                  compact: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                const _SecurityFeature(
                  icon: Icons.phonelink_lock_outlined,
                  title: '仅限本机',
                  body: '不上传服务器，不参与任何业务数据同步。',
                  compact: true,
                ),
              ] else
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        child: _SecurityFeature(
                          icon: Icons.key_outlined,
                          title: '零明文存储',
                          body: '标题、账号、密码、网址和备注全部加密。',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        child: _SecurityFeature(
                          icon: Icons.timer_outlined,
                          title: '自动锁定',
                          body: '闲置五分钟后自动锁定，也可随时手动锁定。',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        child: _SecurityFeature(
                          icon: Icons.phonelink_lock_outlined,
                          title: '仅限本机',
                          body: '不上传服务器，不参与任何业务数据同步。',
                        ),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: narrow ? AppSpacing.xl : AppSpacing.xxl),
              AppButton(
                label: '创建加密密码库',
                icon: Icons.lock_outline,
                width: narrow ? double.infinity : 280,
                onPressed: () => _showSetupDialog(vault),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '主密码无法由服务器找回，请妥善保存稍后生成的恢复密钥。',
                style: context.small,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocked(PasswordVaultService vault) {
    final narrow = _isNarrow;
    return Center(
      child: SingleChildScrollView(
        padding: _pagePadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: AppCard(
            padding: EdgeInsets.all(narrow ? AppSpacing.xl : AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: narrow ? 28 : 36,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('密码库已锁定', style: narrow ? context.h2 : context.h1),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _useRecoveryCode
                      ? '输入离线恢复密钥以解锁密码库。'
                      : '输入主密码，解密过程仅在当前设备完成。',
                  style: context.caption,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppInput(
                  controller: _unlockController,
                  labelText: _useRecoveryCode ? '恢复密钥' : '主密码',
                  obscureText: !_useRecoveryCode && !_showUnlockPassword,
                  autofocus: true,
                  prefixIcon: Icon(
                    _useRecoveryCode
                        ? Icons.key_outlined
                        : Icons.password_outlined,
                  ),
                  suffixIcon: _useRecoveryCode
                      ? null
                      : AppIconButton(
                          icon: _showUnlockPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          tooltip: _showUnlockPassword ? '隐藏' : '显示',
                          onPressed: () => setState(() {
                            _showUnlockPassword = !_showUnlockPassword;
                          }),
                        ),
                  onSubmitted: (_) => _unlock(vault),
                ),
                if (vault.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    vault.errorMessage!,
                    style: context.caption.copyWith(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: '安全解锁',
                  icon: Icons.lock_open_outlined,
                  isLoading: _unlocking,
                  onPressed: () => _unlock(vault),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton.secondary(
                  label: _useRecoveryCode ? '使用主密码' : '使用恢复密钥',
                  onPressed: () {
                    _unlockController.clear();
                    setState(() => _useRecoveryCode = !_useRecoveryCode);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '主密码和恢复密钥都丢失后，无法解密已有数据。',
                  style: context.small,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton.secondary(
                  label: '忘记了？重新新建密码库',
                  destructive: true,
                  icon: Icons.restart_alt_outlined,
                  onPressed: () => _confirmRecreateVault(vault),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVault(PasswordVaultService vault) {
    final entries = vault.search(
      _searchController.text,
      favoritesOnly: _favoritesOnly,
    );
    final narrow = _isNarrow;
    final wide = _isWide;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: vault.recordActivity,
      child: ListView(
        padding: _pagePadding,
        children: [
          _buildVaultHeader(vault, narrow: narrow),
          SizedBox(height: narrow ? AppSpacing.lg : AppSpacing.xl),
          _buildMetrics(vault, narrow: narrow),
          SizedBox(height: narrow ? AppSpacing.lg : AppSpacing.xl),
          if (narrow)
            AppInput(
              controller: _searchController,
              hintText: '搜索名称、账号或网址',
              prefixIcon: const Icon(Icons.search, size: 20),
              onChanged: (_) => setState(() {}),
              suffixIcon: AppIconButton(
                icon: _favoritesOnly ? Icons.star : Icons.star_outline,
                tooltip: '仅看收藏',
                color: _favoritesOnly ? AppColors.warning : null,
                onPressed: () =>
                    setState(() => _favoritesOnly = !_favoritesOnly),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    controller: _searchController,
                    hintText: '搜索名称、账号、网址或标签',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                AppChip(
                  label: '收藏',
                  icon: Icons.star_outline,
                  selected: _favoritesOnly,
                  onSelected: (selected) =>
                      setState(() => _favoritesOnly = selected),
                ),
              ],
            ),
          SizedBox(height: narrow ? AppSpacing.lg : AppSpacing.xl),
          if (entries.isEmpty)
            AppEmptyState(
              icon: Icons.key_off_outlined,
              title: vault.entries.isEmpty ? '密码库还是空的' : '没有匹配结果',
              subtitle: vault.entries.isEmpty
                  ? '添加第一个账号，之后即可快速搜索和复制。'
                  : '尝试更换关键词或关闭收藏筛选。',
              action: vault.entries.isEmpty
                  ? AppButton(
                      label: '添加第一个密码',
                      icon: Icons.add,
                      width: narrow ? double.infinity : 210,
                      onPressed: openAddPassword,
                    )
                  : null,
            )
          else if (wide)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.45,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
              ),
              itemCount: entries.length,
              itemBuilder: (_, index) => _PasswordCard(
                entry: entries[index],
                onOpen: () => _showEntryDetails(entries[index]),
                onFavorite: () => vault.saveEntry(
                  entries[index].copyWith(
                    favorite: !entries[index].favorite,
                  ),
                ),
              ),
            )
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _PasswordCard(
                  entry: entry,
                  dense: narrow,
                  onOpen: () => _showEntryDetails(entry),
                  onFavorite: () => vault.saveEntry(
                    entry.copyWith(favorite: !entry.favorite),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVaultHeader(
    PasswordVaultService vault, {
    required bool narrow,
  }) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Secure Vault', style: context.smallMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('你的私人密码库', style: narrow ? context.h2 : context.h1),
        const SizedBox(height: AppSpacing.xs),
        Text(
          narrow ? '本机加密 · 闲置 5 分钟锁定' : '端到端本机加密 · 闲置 5 分钟自动锁定',
          style: context.caption,
        ),
      ],
    );

    if (narrow) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: title),
          AppIconButton(
            icon: Icons.lock_outline,
            tooltip: '立即锁定',
            onPressed: vault.lock,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: title),
        AppButton.secondary(
          label: '立即锁定',
          icon: Icons.lock_outline,
          width: 140,
          height: 44,
          onPressed: vault.lock,
        ),
        const SizedBox(width: AppSpacing.md),
        AppButton(
          label: '添加密码',
          icon: Icons.add,
          width: 140,
          height: 44,
          onPressed: openAddPassword,
        ),
      ],
    );
  }

  Widget _buildMetrics(
    PasswordVaultService vault, {
    required bool narrow,
  }) {
    final metrics = [
      _VaultMetric(
        label: narrow ? '全部' : '全部项目',
        value: '${vault.entries.length}',
        icon: Icons.key_outlined,
        compact: narrow,
      ),
      _VaultMetric(
        label: narrow ? '收藏' : '已收藏',
        value: '${vault.favoriteCount}',
        icon: Icons.star_outline,
        compact: narrow,
      ),
      _VaultMetric(
        label: '弱密码',
        value: '${vault.weakPasswordCount}',
        icon: Icons.security_outlined,
        warning: vault.weakPasswordCount > 0,
        compact: narrow,
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          Expanded(child: metrics[i]),
          if (i < metrics.length - 1)
            SizedBox(width: narrow ? AppSpacing.sm : AppSpacing.md),
        ],
      ],
    );
  }

  Widget _buildError(PasswordVaultService vault) {
    return AppEmptyState(
      icon: Icons.gpp_bad_outlined,
      title: '密码库不可用',
      subtitle: vault.errorMessage ?? '系统安全存储初始化失败。',
      action: AppButton(
        label: '重试',
        width: 140,
        onPressed: vault.initialize,
      ),
    );
  }

  Future<void> _unlock(PasswordVaultService vault) async {
    if (_unlocking || _unlockController.text.trim().isEmpty) return;
    setState(() => _unlocking = true);
    try {
      if (_useRecoveryCode) {
        await vault.unlockWithRecoveryCode(_unlockController.text.trim());
      } else {
        await vault.unlockWithMasterPassword(_unlockController.text);
      }
      _unlockController.clear();
    } catch (_) {
      // Service exposes a safe, user-facing error message.
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<void> _confirmRecreateVault(PasswordVaultService vault) async {
    final confirmed = await AppDialog.confirm(
      context: context,
      title: '重新新建密码库',
      content: '将永久删除本机全部已加密密码，且无法通过主密码或恢复密钥找回。确定后可重新设置主密码。',
      confirmLabel: '删除并新建',
      destructive: true,
    );
    if (confirmed != true) return;
    try {
      await vault.recreateVault();
      _unlockController.clear();
      setState(() {
        _useRecoveryCode = false;
        _showUnlockPassword = false;
      });
      if (mounted) AppToast.success(context, '旧密码库已清除，请重新初始化');
    } catch (e) {
      if (mounted) AppToast.error(context, '重建失败：$e');
    }
  }

  Future<void> _showSetupDialog(PasswordVaultService vault) async {
    final masterController = TextEditingController();
    final confirmController = TextEditingController();
    var showPassword = false;
    var submitting = false;

    final recoveryCode = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('设置主密码', style: context.h2),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '至少 8 个字符。此步只会生成恢复密钥，确认保存后才会真正初始化密码库。',
                    style: context.caption,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppInput(
                    controller: masterController,
                    labelText: '主密码',
                    obscureText: !showPassword,
                    prefixIcon: const Icon(Icons.password_outlined),
                    suffixIcon: AppIconButton(
                      icon: showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      tooltip: showPassword ? '隐藏' : '显示',
                      onPressed: () =>
                          setDialogState(() => showPassword = !showPassword),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppInput(
                    controller: confirmController,
                    labelText: '确认主密码',
                    obscureText: !showPassword,
                    prefixIcon: const Icon(Icons.verified_user_outlined),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.secondary(
                          label: '取消',
                          onPressed: submitting
                              ? null
                              : () {
                                  vault.cancelSetup();
                                  Navigator.pop(dialogContext);
                                },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppButton(
                          label: '生成恢复密钥',
                          isLoading: submitting,
                          onPressed: () async {
                            final master = masterController.text;
                            if (master.length < 8) {
                              AppToast.error(context, '主密码至少需要 8 个字符');
                              return;
                            }
                            if (master != confirmController.text) {
                              AppToast.error(context, '两次输入的主密码不一致');
                              return;
                            }
                            setDialogState(() => submitting = true);
                            try {
                              final code = await vault.prepareSetup(master);
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext, code);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                AppToast.error(context, e.toString());
                                setDialogState(() => submitting = false);
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    masterController.dispose();
    confirmController.dispose();
    if (recoveryCode == null) {
      vault.cancelSetup();
      return;
    }
    if (mounted) {
      await _showRecoveryCode(recoveryCode, vault);
    } else {
      vault.cancelSetup();
    }
  }

  Future<void> _showRecoveryCode(
    String recoveryCode,
    PasswordVaultService vault,
  ) async {
    var confirmed = false;
    var committing = false;
    final committed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.key_outlined,
                    size: 36,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('保存离线恢复密钥', style: context.h2),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '确认保存后才会真正初始化密码库。取消将丢弃本次生成结果，密码库保持未初始化。',
                    style: context.caption,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: SelectableText(
                      recoveryCode,
                      style: context.bodyMedium.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton.secondary(
                    label: '复制恢复密钥',
                    icon: Icons.copy_outlined,
                    onPressed: committing
                        ? null
                        : () async {
                            await vault.copySecret(recoveryCode);
                            if (context.mounted) {
                              AppToast.success(context, '已复制，30 秒后自动清除');
                            }
                          },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: confirmed,
                    onChanged: committing
                        ? null
                        : (value) =>
                            setDialogState(() => confirmed = value ?? false),
                    title: const Text('我已将恢复密钥保存在安全的离线位置'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.secondary(
                          label: '取消',
                          onPressed: committing
                              ? null
                              : () {
                                  vault.cancelSetup();
                                  Navigator.pop(dialogContext, false);
                                },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppButton(
                          label: '确认并初始化',
                          isLoading: committing,
                          onPressed: !confirmed || committing
                              ? null
                              : () async {
                                  setDialogState(() => committing = true);
                                  try {
                                    await vault.commitSetup();
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext, true);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      AppToast.error(context, e.toString());
                                      setDialogState(() => committing = false);
                                    }
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (committed != true) {
      vault.cancelSetup();
    }
  }

  Future<void> _showEntryEditor([PasswordEntry? entry]) async {
    final vault = context.read<PasswordVaultService>();
    final titleController = TextEditingController(text: entry?.title ?? '');
    final usernameController =
        TextEditingController(text: entry?.username ?? '');
    final passwordController =
        TextEditingController(text: entry?.password ?? '');
    final websiteController = TextEditingController(text: entry?.website ?? '');
    final notesController = TextEditingController(text: entry?.notes ?? '');
    final tagsController =
        TextEditingController(text: entry?.tags.join(', ') ?? '');
    var showPassword = false;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry == null ? '添加密码' : '编辑密码', style: context.h2),
                  const SizedBox(height: AppSpacing.sm),
                  Text('敏感字段将在保存前完成本机加密。', style: context.caption),
                  const SizedBox(height: AppSpacing.xl),
                  AppInput(
                    controller: titleController,
                    labelText: '名称',
                    hintText: '例如 GitHub、公司邮箱',
                    prefixIcon: const Icon(Icons.label_outline),
                    autofocus: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppInput(
                    controller: usernameController,
                    labelText: '用户名或邮箱',
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppInput(
                    controller: passwordController,
                    labelText: '密码',
                    obscureText: !showPassword,
                    prefixIcon: const Icon(Icons.password_outlined),
                    onChanged: (_) => setSheetState(() {}),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIconButton(
                          icon: Icons.auto_awesome_outlined,
                          tooltip: '生成强密码',
                          onPressed: () {
                            passwordController.text = vault.generatePassword();
                            setSheetState(() => showPassword = true);
                          },
                        ),
                        AppIconButton(
                          icon: showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          tooltip: showPassword ? '隐藏' : '显示',
                          onPressed: () => setSheetState(
                            () => showPassword = !showPassword,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _PasswordStrengthIndicator(
                      strength:
                          evaluatePasswordStrength(passwordController.text),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppInput(
                    controller: websiteController,
                    labelText: '网址（可选）',
                    hintText: 'https://example.com',
                    prefixIcon: const Icon(Icons.language_outlined),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppInput(
                    controller: tagsController,
                    labelText: '标签（可选）',
                    hintText: '工作, 邮箱',
                    prefixIcon: const Icon(Icons.sell_outlined),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppInput(
                    controller: notesController,
                    labelText: '安全备注（可选）',
                    maxLines: 3,
                    prefixIcon: const Icon(Icons.notes_outlined),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: entry == null ? '加密并保存' : '保存修改',
                    icon: Icons.shield_outlined,
                    isLoading: saving,
                    onPressed: () async {
                      final title = titleController.text.trim();
                      final password = passwordController.text;
                      if (title.isEmpty || password.isEmpty) {
                        AppToast.error(context, '名称和密码不能为空');
                        return;
                      }
                      setSheetState(() => saving = true);
                      try {
                        final tags = tagsController.text
                            .split(',')
                            .map((tag) => tag.trim())
                            .where((tag) => tag.isNotEmpty)
                            .toSet()
                            .toList();
                        final updated = entry == null
                            ? PasswordEntry(
                                title: title,
                                username: usernameController.text.trim(),
                                password: password,
                                website: websiteController.text.trim().isEmpty
                                    ? null
                                    : websiteController.text.trim(),
                                notes: notesController.text.trim().isEmpty
                                    ? null
                                    : notesController.text.trim(),
                                tags: tags,
                              )
                            : entry.copyWith(
                                title: title,
                                username: usernameController.text.trim(),
                                password: password,
                                website: () =>
                                    websiteController.text.trim().isEmpty
                                        ? null
                                        : websiteController.text.trim(),
                                notes: () => notesController.text.trim().isEmpty
                                    ? null
                                    : notesController.text.trim(),
                                tags: tags,
                              );
                        await vault.saveEntry(updated);
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                        if (context.mounted) {
                          AppToast.success(context, '密码已安全保存');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppToast.error(context, '保存失败：$e');
                          setSheetState(() => saving = false);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    titleController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    websiteController.dispose();
    notesController.dispose();
    tagsController.dispose();
  }

  Future<void> _showEntryDetails(PasswordEntry entry) async {
    final vault = context.read<PasswordVaultService>();
    var revealPassword = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final narrow = MediaQuery.sizeOf(context).width < 640;
          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: narrow ? AppSpacing.lg : 40,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  narrow ? AppSpacing.xl : AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _EntryIcon(
                          title: entry.title,
                          size: narrow ? 40 : 48,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            entry.title,
                            style: narrow ? context.h3 : context.h2,
                          ),
                        ),
                        AppIconButton(
                          icon: Icons.edit_outlined,
                          tooltip: '编辑',
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showEntryEditor(entry);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SecretField(
                      label: '用户名',
                      value: entry.username.isEmpty ? '未填写' : entry.username,
                      onCopy: entry.username.isEmpty
                          ? null
                          : () => _copyWithFeedback(entry.username, '用户名'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SecretField(
                      label: '密码',
                      value: revealPassword ? entry.password : '••••••••••••',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIconButton(
                            icon: revealPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            tooltip: revealPassword ? '隐藏' : '显示',
                            onPressed: () => setDialogState(
                              () => revealPassword = !revealPassword,
                            ),
                          ),
                          AppIconButton(
                            icon: Icons.copy_outlined,
                            tooltip: '复制密码',
                            onPressed: () =>
                                _copyWithFeedback(entry.password, '密码'),
                          ),
                        ],
                      ),
                    ),
                    if (entry.website != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _SecretField(label: '网址', value: entry.website!),
                    ],
                    if (entry.notes != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _SecretField(label: '安全备注', value: entry.notes!),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    if (narrow) ...[
                      AppButton(
                        label: '复制密码',
                        icon: Icons.copy_outlined,
                        onPressed: () =>
                            _copyWithFeedback(entry.password, '密码'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppButton.secondary(
                        label: '删除',
                        destructive: true,
                        onPressed: () async {
                          final confirmed = await AppDialog.confirm(
                            context: context,
                            title: '删除密码',
                            content: '删除后无法恢复，确定删除“${entry.title}”吗？',
                            confirmLabel: '删除',
                            destructive: true,
                          );
                          if (confirmed == true) {
                            await vault.deleteEntry(entry.localId);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          }
                        },
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: AppButton.secondary(
                              label: '删除',
                              destructive: true,
                              onPressed: () async {
                                final confirmed = await AppDialog.confirm(
                                  context: context,
                                  title: '删除密码',
                                  content: '删除后无法恢复，确定删除“${entry.title}”吗？',
                                  confirmLabel: '删除',
                                  destructive: true,
                                );
                                if (confirmed == true) {
                                  await vault.deleteEntry(entry.localId);
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppButton(
                              label: '复制密码',
                              icon: Icons.copy_outlined,
                              onPressed: () =>
                                  _copyWithFeedback(entry.password, '密码'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _copyWithFeedback(String value, String label) async {
    await context.read<PasswordVaultService>().copySecret(value);
    if (mounted) AppToast.success(context, '$label已复制，30 秒后自动清除');
  }
}

class _SecurityFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool compact;

  const _SecurityFeature({
    required this.icon,
    required this.title,
    required this.body,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.bodyMedium),
                  const SizedBox(height: 2),
                  Text(body, style: context.caption),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: context.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: context.caption),
        ],
      ),
    );
  }
}

class _VaultMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool warning;
  final bool compact;

  const _VaultMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.warning = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        warning ? AppColors.warning : Theme.of(context).colorScheme.primary;
    if (compact) {
      return AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: context.h3),
            Text(
              label,
              style: context.small,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: context.h2),
                Text(
                  label,
                  style: context.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordCard extends StatelessWidget {
  final PasswordEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final bool dense;

  const _PasswordCard({
    required this.entry,
    required this.onOpen,
    required this.onFavorite,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final host = entry.website == null
        ? null
        : Uri.tryParse(entry.website!)?.host.replaceFirst('www.', '');
    return AppCard(
      onTap: onOpen,
      padding: EdgeInsets.all(dense ? AppSpacing.md : AppSpacing.lg),
      child: Row(
        children: [
          _EntryIcon(title: entry.title, size: dense ? 40 : 48),
          SizedBox(width: dense ? AppSpacing.sm : AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: context.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.username.isEmpty ? '未填写用户名' : entry.username,
                  style: context.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!dense && host != null && host.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(host, style: context.small),
                ],
              ],
            ),
          ),
          AppIconButton(
            icon: entry.favorite ? Icons.star : Icons.star_outline,
            tooltip: entry.favorite ? '取消收藏' : '收藏',
            color: entry.favorite ? AppColors.warning : null,
            onPressed: onFavorite,
          ),
        ],
      ),
    );
  }
}

class _EntryIcon extends StatelessWidget {
  final String title;
  final double size;

  const _EntryIcon({required this.title, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final initial = title.trim().isEmpty ? '?' : title.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        initial,
        style: (size < 44 ? context.bodyMedium : context.h3).copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SecretField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;
  final Widget? trailing;

  const _SecretField({
    required this.label,
    required this.value,
    this.onCopy,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.small),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(value, style: context.bodyMedium),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onCopy != null)
            AppIconButton(
              icon: Icons.copy_outlined,
              tooltip: '复制',
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  final PasswordStrength strength;

  const _PasswordStrengthIndicator({required this.strength});

  @override
  Widget build(BuildContext context) {
    final (label, color, segments) = switch (strength) {
      PasswordStrength.weak => ('弱', AppColors.error, 1),
      PasswordStrength.fair => ('一般', AppColors.warning, 2),
      PasswordStrength.good => ('良好', AppColors.brand, 3),
      PasswordStrength.strong => ('强', AppColors.success, 4),
    };
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i < segments
                    ? color
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i < 3) const SizedBox(width: 4),
        ],
        const SizedBox(width: AppSpacing.sm),
        Text('强度：$label', style: context.small.copyWith(color: color)),
      ],
    );
  }
}
