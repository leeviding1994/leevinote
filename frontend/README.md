# Leevinote Flutter Client

跨平台客户端，支持iOS、Android、Windows、Linux、Mac、Web

## 技术栈

- **Flutter 3.16+**
- **Dart 3.2+**
- **Provider** - 状态管理
- **Dio** - HTTP客户端
- **flutter_secure_storage** - 安全存储JWT
- **just_audio** - 音乐播放
- **video_player** - 视频播放
- **table_calendar** - 日程日历
- **go_router** - 路由管理

## 快速开始

### 前置要求

1. **安装Flutter SDK**
   ```bash
   # 按照官方文档安装：https://docs.flutter.dev/get-started/install
   flutter doctor
   ```

2. **配置后端地址**
   编辑 `lib/utils/constants.dart`，修改 `baseUrl`：
   ```dart
   static const String baseUrl = 'http://your-backend-url:8080/api';
   ```

### 运行项目

```bash
cd frontend

# 获取依赖
flutter pub get

# 运行在Chrome（Web）
flutter run -d chrome

# 运行在Android
flutter run -d android

# 运行在iOS
flutter run -d ios

# 运行在Windows
flutter run -d windows

# 运行在Linux
flutter run -d linux

# 运行在Mac
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
│   └── schedule.dart
├── screens/              # 页面
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── notes_screen.dart
│   ├── alarms_screen.dart
│   ├── music_screen.dart
│   ├── videos_screen.dart
│   └── schedules_screen.dart
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
- 🚧 笔记管理（开发中）
- 🚧 闹钟提醒（开发中）
- 🚧 音乐播放（开发中）
- 🚧 视频播放（开发中）
- 🚧 日程安排（开发中）

## 平台支持

| 平台 | 状态 |
|------|------|
| iOS | ✅ 支持 |
| Android | ✅ 支持 |
| Web | ✅ 支持 |
| Windows | ✅ 支持 |
| Linux | ✅ 支持 |
| macOS | ✅ 支持 |

## 下一步

1. 完善各功能模块的UI和服务调用
2. 实现音乐/视频播放器
3. 添加本地通知（闹钟提醒）
4. 实现文件上传功能
5. 添加离线缓存
