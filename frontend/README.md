# Leevinote Flutter Client

跨平台客户端，主要支持 Android、Windows、Linux 和 macOS。Web 端仍处于实验阶段。

## 技术栈

- **Flutter 3.16+**
- **Dart 3.2+**
- **Provider** - 状态管理
- **Dio** - HTTP客户端
- **flutter_secure_storage** - 安全存储JWT
- **just_audio** - 音乐播放
- **video_player** - 视频播放
- **table_calendar** - 日程日历

## 快速开始

### 前置要求

1. **安装Flutter SDK**
   ```bash
   # 按照官方文档安装：https://docs.flutter.dev/get-started/install
   flutter doctor
   ```

2. **配置后端地址**
   - 默认：`http://backend.leevinote.leeviding.cn/api`
   - 可用 `--dart-define=API_BASE_URL=...` 覆盖

### 运行项目

```bash
cd frontend

# 获取依赖
flutter pub get

# 默认连线上 HTTP API
flutter run -d linux

# 指定其他后端地址
flutter run -d linux --dart-define=API_BASE_URL=http://localhost:8080/api

# 其他平台
flutter run -d chrome
flutter run -d android
flutter run -d windows
flutter run -d macos
```

## 项目结构

```
lib/
├── main.dart              # 应用入口
├── models/               # 数据模型
│   ├── note.dart
│   ├── alarm.dart
│   ├── music.dart
│   ├── video.dart
│   ├── schedule.dart
│   ├── transaction.dart
│   ├── transaction_category.dart
│   └── health_entry.dart
├── screens/              # 页面
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── notes_screen.dart
│   ├── alarms_screen.dart
│   ├── music_screen.dart
│   ├── videos_screen.dart
│   ├── schedules_screen.dart
│   ├── transactions_screen.dart
│   ├── transaction_editor_screen.dart
│   ├── transaction_category_manager_screen.dart
│   └── health_screen.dart
├── services/             # 服务层
│   ├── api_service.dart  # API调用
│   └── auth_service.dart # 认证管理
├── widgets/              # 通用组件
└── utils/                # 工具类
    ├── constants.dart
    └── theme.dart
```

## 功能模块

- ✅ 用户认证（登录/注册）
- ✅ 本地优先笔记与文件夹
- ✅ 本地闹钟提醒
- ✅ 音乐和视频管理
- ✅ 日程安排
- ✅ 记账管理（支出/收入、分类、日/月/年统计）
- ✅ 本地健康和饮食记录（当前不进行云同步）

## 平台支持

| 平台 | 状态 |
|------|------|
| iOS | ⚠️ 未持续验证 |
| Android | ✅ 支持 |
| Web | ⚠️ 实验性支持，本地 SQLite 能力尚未完整适配 |
| Windows | ✅ 支持 |
| Linux | ✅ 支持 |
| macOS | ✅ 支持 |

## 检查

```bash
flutter analyze
flutter test
```
