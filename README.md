# LeeviNote

LeeviNote 是一个 Flutter + Spring Boot 的本地优先个人信息应用，包含笔记、文件夹、闹钟、媒体、日程、记账和健康记录。

## 目录

- `frontend/`：Flutter 客户端
- `backend/`：Spring Boot API
- `flutter_local_notifications_windows/`：Windows 通知插件

## 本地运行

### 后端

需要 JDK 21 和 PostgreSQL 16。创建 `leevinote` 数据库后执行：

```bash
cd backend
export DB_PASSWORD='你的数据库密码'
export JWT_SECRET='至少 64 字节的随机字符串'
./gradlew bootRun
```

API 地址为 `http://localhost:8080/api`。

### Linux 客户端

```bash
cd frontend
flutter pub get
flutter run -d linux --dart-define=API_BASE_URL=http://localhost:8080/api
```

## 数据与同步边界

- 笔记、文件夹、闹钟、媒体、日程、记账和设置支持登录后手动同步。
- 健康记录当前仅保存在本机，界面会明确显示这一状态。
- 客户端离线修改会保留为待同步状态，删除操作同步成功后才会物理清理。

## 质量检查

```bash
cd backend && DB_PASSWORD=... JWT_SECRET=... ./gradlew test
cd frontend && flutter analyze && flutter test
```

每次推送和拉取请求都会通过 GitHub Actions 执行上述检查。
