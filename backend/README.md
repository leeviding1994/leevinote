# Leevinote Backend

Leevinote平台后端服务 - 支持笔记、闹钟、音乐播放、视频播放、日程安排

## 技术栈

- **Java 17** + **Spring Boot 3.2.1**
- **PostgreSQL** 数据库
- **Redis** 缓存
- **JWT** 认证
- **Spring Security** 安全框架
- **Spring Data JPA** ORM
- **Swagger/OpenAPI** API文档

## 快速开始

### 前置要求

- JDK 17+
- Maven 3.6+
- PostgreSQL 16+
- Redis 7+

### 使用Docker启动（推荐）

```bash
cd backend
docker-compose up -d
```

### 本地开发

1. 创建数据库：
```sql
CREATE DATABASE leevinote;
CREATE USER leevinote WITH PASSWORD 'leevinote123';
GRANT ALL PRIVILEGES ON DATABASE leevinote TO leevinote;
```

2. 修改 `src/main/resources/application.yml` 中的数据库配置

3. 启动应用：
```bash
mvn spring-boot:run
```

4. 访问API文档：http://localhost:8080/api/swagger-ui.html

## API端点

### 认证
- `POST /api/auth/signup` - 用户注册
- `POST /api/auth/login` - 用户登录

### 笔记
- `GET /api/notes` - 获取笔记列表
- `POST /api/notes` - 创建笔记
- `DELETE /api/notes/{id}` - 删除笔记

### 闹钟
- `GET /api/alarms` - 获取闹钟列表
- `POST /api/alarms` - 创建闹钟
- `DELETE /api/alarms/{id}` - 删除闹钟

### 音乐
- `GET /api/music` - 获取音乐列表
- `POST /api/music` - 添加音乐
- `DELETE /api/music/{id}` - 删除音乐

### 视频
- `GET /api/videos` - 获取视频列表
- `POST /api/videos` - 添加视频
- `DELETE /api/videos/{id}` - 删除视频

### 日程
- `GET /api/schedules` - 获取日程列表
- `POST /api/schedules` - 创建日程
- `GET /api/schedules/{id}` - 获取日程详情
- `DELETE /api/schedules/{id}` - 删除日程

## 项目结构

```
src/main/java/com/leevinote/backend/
├── config/          # 配置类
├── controller/      # 控制器
├── service/         # 业务逻辑
├── repository/      # 数据访问
├── entity/          # 实体类
├── dto/             # 数据传输对象
├── security/        # 安全相关
└── exception/       # 异常处理
```

## TODO

- [ ] 完善用户ID获取逻辑（从SecurityContext）
- [ ] 添加文件上传功能（音乐/视频）
- [ ] 实现闹钟推送通知
- [ ] 添加单元测试
- [ ] 添加数据校验
- [ ] 实现分页查询
