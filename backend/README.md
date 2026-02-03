# 基金投资分析工具 - 后端服务

基于 Go + Gin 框架的 RESTful API 后端服务。

## 技术栈

- **语言**: Go 1.21+
- **框架**: Gin
- **数据库**: PostgreSQL 15+
- **缓存**: Redis 7+ (可选，支持内存缓存降级)
- **日志**: Zap
- **配置**: Viper

## 项目结构

```
backend/
├── cmd/
│   └── server/
│       └── main.go          # 应用入口
├── internal/
│   ├── config/              # 配置管理
│   ├── controller/          # HTTP 控制器
│   ├── middleware/          # 中间件
│   ├── model/               # 数据模型
│   ├── repository/          # 数据访问层
│   ├── service/             # 业务逻辑层
│   ├── crawler/             # 数据爬取模块
│   └── cache/               # 缓存模块
├── pkg/
│   └── response/            # 统一响应格式
├── migrations/              # 数据库迁移文件
├── config.example.yaml      # 配置文件示例
├── go.mod
└── go.sum
```

## 快速开始

### 1. 安装依赖

```bash
# 安装 Go 1.21+
# macOS
brew install go

# Ubuntu/Debian
sudo apt install golang-go

# 或从官网下载: https://go.dev/dl/
```

### 2. 配置数据库

```bash
# 创建 PostgreSQL 数据库
createdb fund_analyzer

# 运行迁移
psql -d fund_analyzer -f migrations/001_init.up.sql
```

### 3. 配置应用

```bash
# 复制配置文件
cp config.example.yaml config.yaml

# 编辑配置文件，设置数据库密码、JWT 密钥等
```

### 4. 运行服务

```bash
# 下载依赖
go mod tidy

# 运行服务
go run cmd/server/main.go
```

## 环境变量

支持通过环境变量覆盖配置：

```bash
export FUND_SERVER_PORT=8080
export FUND_DATABASE_HOST=localhost
export FUND_DATABASE_PASSWORD=your_password
export FUND_JWT_SECRET=your_jwt_secret
export FUND_REDIS_HOST=localhost
```

## API 文档

### 认证接口

| 方法 | 路径 | 描述 |
|------|------|------|
| POST | /api/v1/auth/register | 用户注册 |
| POST | /api/v1/auth/verify-email | 验证邮箱 |
| POST | /api/v1/auth/login | 用户登录 |
| POST | /api/v1/auth/logout | 用户登出 |
| POST | /api/v1/auth/refresh | 刷新 Token |
| POST | /api/v1/auth/forgot-password | 忘记密码 |
| POST | /api/v1/auth/reset-password | 重置密码 |
| GET | /api/v1/auth/me | 获取当前用户 |

### 健康检查

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | /health | 健康检查 |

## 开发指南

### 代码规范

- 遵循 Go 官方代码规范
- 使用 `gofmt` 格式化代码
- 使用 `golint` 检查代码质量

### 测试

```bash
# 运行所有测试
go test ./...

# 运行带覆盖率的测试
go test -cover ./...
```

## License

MIT
