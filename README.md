# 基金投资分析工具

一款面向个人投资者的基金投资分析工具，提供市场数据监控、AI 智能分析、自选基金管理等功能。

## 功能特性

- 📈 **全球市场指数** - 实时监控 A 股、港股、美股等主要市场指数
- 💰 **贵金属追踪** - 黄金、白银等贵金属实时价格与历史走势
- 📊 **行业板块分析** - 板块涨跌排行、板块内基金筛选
- 📰 **7×24 快讯** - 财经新闻实时推送
- 💼 **自选基金管理** - 添加、删除、标记持有状态
- 🤖 **AI 智能分析** - 基于 LLM 的市场分析与投资建议（支持流式输出）


## 项目结构

```
.
├── backend/                 # Go 后端服务
│   ├── cmd/server/         # 应用入口
│   ├── internal/
│   │   ├── config/         # 配置管理
│   │   ├── controller/     # HTTP 控制器
│   │   ├── middleware/     # 中间件 (认证/限流/CORS/SSE)
│   │   ├── model/          # 数据模型
│   │   ├── repository/     # 数据访问层
│   │   ├── service/        # 业务逻辑层
│   │   └── crawler/        # 数据爬取模块
│   ├── pkg/                # 公共包
│   └── migrations/         # 数据库迁移
│
├── mobile/                  # Flutter 移动端
│   └── lib/
│       ├── core/           # 核心模块 (配置/主题/路由)
│       ├── data/           # 数据层 (模型/仓库/网络)
│       └── presentation/   # 展示层 (页面/组件/状态)
│
└── cache/                   # 缓存数据
```

## 快速开始

### 环境要求

- Go 1.21+
- Flutter 3.0+
- PostgreSQL 15+
- Redis 7+ (可选，支持内存缓存降级)

### 后端部署

```bash
cd backend

# 1. 创建数据库
createdb fund_analyzer
psql -d fund_analyzer -f migrations/001_init.up.sql

# 2. 配置
cp config.example.yaml config.yaml
# 编辑 config.yaml 设置数据库密码、JWT 密钥等

# 3. 运行
go mod tidy
go run cmd/server/main.go
```

### 移动端运行

```bash
cd mobile

# 1. 安装依赖
flutter pub get

# 2. 生成代码
flutter pub run build_runner build --delete-conflicting-outputs

# 3. 配置 API 地址
# 编辑 lib/core/config/app_config.dart

# 4. 运行
flutter run
```

## API 概览

| 模块 | 端点 | 描述 |
|------|------|------|
| 认证 | `POST /api/v1/auth/register` | 用户注册 |
| 认证 | `POST /api/v1/auth/login` | 用户登录 |
| 市场 | `GET /api/v1/market/indices` | 全球市场指数 |
| 市场 | `GET /api/v1/market/precious-metals` | 贵金属价格 |
| 市场 | `GET /api/v1/market/gold-history` | 历史金价 |
| 市场 | `GET /api/v1/market/volume` | 成交量趋势 |
| 快讯 | `GET /api/v1/news` | 财经快讯 |
| 板块 | `GET /api/v1/sectors` | 板块列表 |
| 板块 | `GET /api/v1/sectors/:id/funds` | 板块基金 |
| 基金 | `GET /api/v1/funds` | 自选基金列表 |
| 基金 | `POST /api/v1/funds` | 添加基金 |
| 基金 | `GET /api/v1/funds/:code/valuation` | 基金估值 |
| AI | `POST /api/v1/ai/chat` | AI 对话 (SSE) |
| AI | `POST /api/v1/ai/analyze/standard` | 标准分析 (SSE) |
| AI | `POST /api/v1/ai/analyze/fast` | 快速分析 (SSE) |
| AI | `POST /api/v1/ai/analyze/deep` | 深度研究 (SSE) |

## 环境变量

```bash
# 服务器配置
FUND_SERVER_PORT=8080

# 数据库配置
FUND_DATABASE_HOST=localhost
FUND_DATABASE_PASSWORD=your_password

# JWT 配置
FUND_JWT_SECRET=your_jwt_secret

# Redis 配置 (可选)
FUND_REDIS_HOST=localhost

# LLM 配置 (可选，启用 AI 功能)
FUND_LLM_API_KEY=your_api_key
```

## 特性说明

### 熔断器保护
所有外部数据源请求都配置了熔断器，当某个数据源不可用时自动降级，保证服务稳定性。

### 限流机制
- 认证接口：严格限流
- AI 接口：严格限流
- 其他接口：默认限流
- SSE 连接数限制：最大 100 个并发连接

### 缓存策略
- 优先使用 Redis 缓存
- Redis 不可用时自动降级为内存缓存
- 市场数据、板块数据等支持缓存

### 优雅关闭
服务支持优雅关闭，收到终止信号后会等待正在处理的请求完成。

## License

MIT
