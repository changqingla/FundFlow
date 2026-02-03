# 基金投资分析 - Flutter 移动端

基金投资分析工具的 Flutter 移动端应用，支持 iOS 和 Android 平台。

## 功能特性

- 📈 全球市场指数监控
- 💰 贵金属价格追踪
- 📊 行业板块分析
- 📰 7×24 快讯
- 💼 自选基金管理
- 🤖 AI 智能分析

## 技术栈

- **框架**: Flutter 3.x
- **状态管理**: Riverpod
- **HTTP 客户端**: Dio
- **本地存储**: Hive + SharedPreferences
- **路由**: go_router
- **代码生成**: freezed + json_serializable
- **图表**: fl_chart
- **Markdown**: flutter_markdown

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── app.dart                  # App 配置
├── core/                     # 核心模块
│   ├── config/              # 配置
│   ├── theme/               # 主题
│   └── utils/               # 工具类
├── data/                     # 数据层
│   ├── models/              # 数据模型
│   └── repositories/        # 仓库接口
└── presentation/             # 展示层
    ├── providers/           # 状态管理
    ├── pages/               # 页面
    └── widgets/             # 组件
```

## 开始使用

### 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0

### 安装依赖

```bash
flutter pub get
```

### 生成代码

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 运行应用

```bash
# 开发模式
flutter run

# 发布模式
flutter run --release
```

### 构建应用

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

## 配置

### API 地址配置

修改 `lib/core/config/app_config.dart` 中的 API 地址：

```dart
static const String devApiBaseUrl = 'http://localhost:8080/api/v1';
static const String prodApiBaseUrl = 'https://api.example.com/api/v1';
```

## 开发指南

### 添加新页面

1. 在 `lib/presentation/pages/` 下创建页面文件
2. 在 `lib/presentation/providers/` 下创建对应的 Provider
3. 在路由配置中注册页面

### 添加新数据模型

1. 在 `lib/data/models/` 下创建模型文件
2. 使用 `@freezed` 注解定义模型
3. 运行 `flutter pub run build_runner build` 生成代码

### 代码规范

- 遵循 Dart 官方代码风格指南
- 使用 `flutter analyze` 检查代码问题
- 使用 `flutter format .` 格式化代码

## 测试

```bash
# 运行所有测试
flutter test

# 运行特定测试
flutter test test/unit/

# 生成覆盖率报告
flutter test --coverage
```

## License

MIT License
