import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leevinote/services/api_service.dart';

enum AppThemeMode { system, light, dark }

class NavModule {
  final String id;
  final String label;
  final IconData icon;
  final bool visible;

  const NavModule({
    required this.id,
    required this.label,
    required this.icon,
    this.visible = true,
  });

  NavModule copyWith({bool? visible}) {
    return NavModule(
      id: id,
      label: label,
      icon: icon,
      visible: visible ?? this.visible,
    );
  }
}

const _defaultModules = [
  NavModule(id: 'notes', label: '笔记', icon: Icons.note),
  NavModule(id: 'alarms', label: '闹钟', icon: Icons.alarm),
  NavModule(id: 'music', label: '音乐', icon: Icons.music_note),
  NavModule(id: 'videos', label: '视频', icon: Icons.video_library),
  NavModule(id: 'schedules', label: '日程', icon: Icons.calendar_today),
  NavModule(id: 'transactions', label: '记账', icon: Icons.account_balance_wallet),
  NavModule(id: 'profile', label: '我的', icon: Icons.person, visible: true),
];

const _defaultModuleVisibility = {
  'notes': true,
  'alarms': true,
  'music': true,
  'videos': true,
  'schedules': true,
  'transactions': true,
  'profile': true,
};

const _themeColors = [
  Color(0xFF6366F1), // 蓝紫（默认）
  Color(0xFF8B5CF6), // 紫罗兰
  Color(0xFF3B82F6), // 蓝色
  Color(0xFF10B981), // 翠绿色
  Color(0xFFF59E0B), // 琥珀色
  Color(0xFFEF4444), // 红色
  Color(0xFFEC4899), // 粉色
  Color(0xFF06B6D4), // 青色
];

class SettingsService extends ChangeNotifier {
  final ApiService _api;

  AppThemeMode _themeMode = AppThemeMode.system;
  Color _themeColor = _themeColors.first;
  List<String> _moduleOrder = _defaultModules.map((m) => m.id).toList();
  Map<String, bool> _moduleVisibility = Map.from(_defaultModuleVisibility);
  bool _loaded = false;

  SettingsService({required ApiService apiService}) : _api = apiService;

  AppThemeMode get themeMode => _themeMode;
  Color get themeColor => _themeColor;
  List<String> get moduleOrder => _moduleOrder;
  Map<String, bool> get moduleVisibility => Map.unmodifiable(_moduleVisibility);
  List<NavModule> get allModules => _defaultModules;
  List<NavModule> get modules {
    final map = {for (final m in _defaultModules) m.id: m};
    final visibleModules = _moduleOrder
        .where((id) => _moduleVisibility[id] == true && map.containsKey(id))
        .map((id) => map[id]!)
        .toList();
    final profileModule = map['profile'];
    final withoutProfile = visibleModules.where((m) => m.id != 'profile').toList();
    if (profileModule == null) return withoutProfile;
    return [...withoutProfile, profileModule];
  }

  List<Color> get availableColors => _themeColors;

  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _load();
    _loaded = true;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeStr = prefs.getString('theme_mode') ?? 'system';
      _themeMode = AppThemeMode.values.firstWhere(
        (e) => e.name == themeModeStr,
        orElse: () => AppThemeMode.system,
      );
      final colorValue = prefs.getInt('theme_color');
      _themeColor = colorValue != null ? Color(colorValue) : _themeColors.first;
      final order = prefs.getStringList('module_order');
      if (order != null) {
        _moduleOrder = _normalizeModuleOrder(order);
      }
      final visibility = prefs.getStringList('module_visibility');
      if (visibility != null) {
        final savedVisibility = {for (final v in visibility) v.split(':')[0]: v.split(':')[1] == 'true'};
        // 合并保存的可见性设置与默认设置：新增模块默认可见
        _moduleVisibility = Map.from(_defaultModuleVisibility);
        for (final entry in savedVisibility.entries) {
          if (_moduleVisibility.containsKey(entry.key)) {
            _moduleVisibility[entry.key] = entry.value;
          }
        }
        _moduleVisibility['profile'] = true;
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', _themeMode.name);
      await prefs.setInt('theme_color', _themeColor.toARGB32());
      await prefs.setStringList('module_order', _moduleOrder);
      await prefs.setStringList('module_visibility', _moduleVisibility.entries.map((e) => '${e.key}:${e.value}').toList());
    } catch (_) {}
  }

  Future<void> syncFromServer() async {
    try {
      final response = await _api.get('/user-settings');
      if (response.isNotEmpty) {
        final themeModeStr = response['theme_mode'] as String?;
        if (themeModeStr != null) {
          _themeMode = AppThemeMode.values.firstWhere(
            (e) => e.name == themeModeStr,
            orElse: () => AppThemeMode.system,
          );
        }
        final themeColorStr = response['theme_color'] as String?;
        if (themeColorStr != null && themeColorStr.isNotEmpty) {
          _themeColor = Color(int.parse(themeColorStr.replaceFirst('#', '0xFF')));
        }
        final orderStr = response['module_order'] as String?;
        if (orderStr != null && orderStr.isNotEmpty) {
          final order = orderStr.split(',');
          _moduleOrder = _normalizeModuleOrder(order);
        }
        final visibilityStr = response['module_visibility'] as String?;
        if (visibilityStr != null && visibilityStr.isNotEmpty) {
          final visibility = visibilityStr.split(',');
          for (final v in visibility) {
            final parts = v.split(':');
            if (parts.length == 2 && parts[0] != 'profile') {
              _moduleVisibility[parts[0]] = parts[1] == 'true';
            }
          }
          _moduleVisibility['profile'] = true;
        }
        await _persist();
        notifyListeners();
      }
    } catch (_) {
      // 如果未登录或服务器不可用，保持本地设置
    }
  }

  Future<void> syncToServer() async {
    try {
      await _api.put('/user-settings', {
        'theme_mode': _themeMode.name,
        'theme_color': '#${_themeColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
        'module_order': _moduleOrder.join(','),
        'module_visibility': _moduleVisibility.entries.map((e) => '${e.key}:${e.value}').join(','),
      });
    } catch (_) {
      // 静默失败，保持本地设置
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    await _persist();
    await syncToServer();
    notifyListeners();
  }

  Future<void> setThemeColor(Color color) async {
    _themeColor = color;
    await _persist();
    await syncToServer();
    notifyListeners();
  }

  Future<void> setModuleOrder(List<String> order) async {
    _moduleOrder = _normalizeModuleOrder(order);
    await _persist();
    await syncToServer();
    notifyListeners();
  }

  List<String> _normalizeModuleOrder(List<String> order) {
    final validIds = _defaultModules.map((m) => m.id).toSet();
    final normalized = <String>[];
    for (final id in order) {
      if (validIds.contains(id) && !normalized.contains(id)) {
        normalized.add(id);
      }
    }
    for (final module in _defaultModules) {
      if (!normalized.contains(module.id)) {
        normalized.add(module.id);
      }
    }
    return normalized;
  }

  Future<void> setModuleVisibility(String moduleId, bool visible) async {
    if (moduleId == 'profile') return;
    if (_moduleVisibility.containsKey(moduleId)) {
      _moduleVisibility[moduleId] = visible;
      await _persist();
      await syncToServer();
      notifyListeners();
    }
  }

  Future<void> resetToDefault() async {
    _themeMode = AppThemeMode.system;
    _themeColor = _themeColors.first;
    _moduleOrder = _defaultModules.map((m) => m.id).toList();
    _moduleVisibility = Map.from(_defaultModuleVisibility);
    await _persist();
    await syncToServer();
    notifyListeners();
  }
}
