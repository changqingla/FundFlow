package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"sync/atomic"
	"syscall"
	"time"

	"fund-analyzer/internal/config"
	"fund-analyzer/internal/controller"
	"fund-analyzer/internal/crawler"
	"fund-analyzer/internal/middleware"
	"fund-analyzer/internal/repository"
	"fund-analyzer/internal/service"
	"fund-analyzer/pkg/response"

	"github.com/gin-gonic/gin"
	"github.com/jmoiron/sqlx"
	"go.uber.org/zap"
)

// HealthStatus 健康状态
type HealthStatus struct {
	Status   string            `json:"status"`
	Time     string            `json:"time"`
	Uptime   string            `json:"uptime"`
	Version  string            `json:"version"`
	Services map[string]string `json:"services"`
}

// 全局变量用于跟踪服务状态
var (
	startTime      time.Time
	isShuttingDown atomic.Bool
	activeRequests atomic.Int64
)

func main() {
	startTime = time.Now()

	// 初始化配置
	cfg, err := config.Load()
	if err != nil {
		fmt.Printf("Failed to load config: %v\n", err)
		os.Exit(1)
	}

	// 初始化日志
	logger, err := config.InitLogger(cfg.Log.Level, cfg.Log.Format)
	if err != nil {
		fmt.Printf("Failed to init logger: %v\n", err)
		os.Exit(1)
	}
	defer logger.Sync()

	// 设置 Gin 模式
	if cfg.Server.Mode == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	// 初始化数据库
	db, err := repository.NewPostgresDB(cfg.Database)
	if err != nil {
		logger.Fatal("Failed to connect to database", zap.Error(err))
	}
	defer db.Close()
	logger.Info("Database connected successfully")

	// 初始化 Redis 缓存
	var cacheService service.CacheService
	var redisConnected bool
	cacheService, err = service.NewCacheService(cfg.Redis)
	if err != nil {
		logger.Warn("Failed to connect to Redis, using memory cache", zap.Error(err))
		cacheService = service.NewMemoryCache()
		redisConnected = false
	} else {
		logger.Info("Redis connected successfully")
		redisConnected = true
	}

	// 初始化 HTTP 客户端和熔断器
	httpClient := crawler.NewHTTPClient(crawler.DefaultHTTPClientConfig())
	cbManager := crawler.NewCircuitBreakerManager(crawler.DefaultCircuitBreakerConfig())

	// 创建各数据源的熔断器
	baiduBreaker := cbManager.Get("baidu")
	antBreaker := cbManager.Get("ant")
	eastmoneyBreaker := cbManager.Get("eastmoney")
	goldBreaker := cbManager.Get("gold")
	ddgBreaker := cbManager.Get("duckduckgo")
	webpageBreaker := cbManager.Get("webpage")

	// 初始化爬虫
	baiduCrawler := crawler.NewBaiduCrawler(httpClient, baiduBreaker)
	antCrawler := crawler.NewAntCrawler(httpClient, antBreaker)
	eastMoneyCrawler := crawler.NewEastMoneyCrawler(httpClient, eastmoneyBreaker)
	goldCrawler := crawler.NewGoldCrawler(httpClient, goldBreaker)
	ddgCrawler := crawler.NewDuckDuckGoCrawler(httpClient, ddgBreaker)
	webpageFetcher := crawler.NewWebpageFetcher(httpClient, webpageBreaker)

	// 初始化 Repository
	userRepo := repository.NewUserRepository(db)
	fundRepo := repository.NewUserFundRepository(db)

	// 初始化 Service
	authService := service.NewAuthService(userRepo, cfg.JWT, cfg.Email)
	marketService := service.NewMarketService(baiduCrawler, goldCrawler, cacheService)
	newsService := service.NewNewsService(baiduCrawler, cacheService)
	sectorService := service.NewSectorService(eastMoneyCrawler, cacheService)
	fundService := service.NewFundService(fundRepo, antCrawler, cacheService)
	dataMatcher := service.NewDataMatcher()

	// 初始化 AI 服务
	var aiService service.AIService
	if cfg.LLM.APIKey != "" {
		aiService, err = service.NewAIService(
			&cfg.LLM,
			ddgCrawler,
			webpageFetcher,
			dataMatcher,
			marketService,
			newsService,
			sectorService,
			fundService,
		)
		if err != nil {
			logger.Warn("Failed to initialize AI service", zap.Error(err))
		} else {
			logger.Info("AI service initialized successfully")
		}
	} else {
		logger.Warn("LLM API key not configured, AI service disabled")
	}

	// 初始化降级服务
	degradationService := service.NewDegradationService(cacheService, cbManager, logger)
	_ = degradationService // 可用于后续增强

	// 初始化限流器
	defaultLimiter := middleware.NewTokenBucketLimiter(middleware.DefaultRateLimitConfig())
	strictLimiter := middleware.NewTokenBucketLimiter(middleware.StrictRateLimitConfig())
	defer defaultLimiter.Stop()
	defer strictLimiter.Stop()

	// 初始化 SSE 连接限制器
	sseConnectionLimiter := middleware.NewSSEConnectionLimiter(100) // 最大 100 个 SSE 连接

	// 创建 Gin 引擎
	r := gin.New()

	// 全局中间件
	r.Use(middleware.Logger(logger))
	r.Use(middleware.Recovery(logger))
	r.Use(middleware.CORS())
	r.Use(middleware.RequestID())
	r.Use(requestTracker()) // 请求跟踪中间件

	// 健康检查（增强版）
	r.GET("/health", func(c *gin.Context) {
		healthCheck(c, db, cacheService, redisConnected)
	})

	// API v1 路由组
	v1 := r.Group("/api/v1")
	{
		// 认证路由（无需登录）
		authCtrl := controller.NewAuthController(authService, logger)
		auth := v1.Group("/auth")
		auth.Use(middleware.RateLimitByIP(strictLimiter)) // 认证接口使用严格限流
		{
			auth.POST("/register", authCtrl.Register)
			auth.POST("/verify-email", authCtrl.VerifyEmail)
			auth.POST("/login", authCtrl.Login)
			auth.POST("/forgot-password", authCtrl.ForgotPassword)
			auth.POST("/reset-password", authCtrl.ResetPassword)
		}

		// 需要认证的路由
		authorized := v1.Group("")
		authorized.Use(middleware.Auth(authService))
		authorized.Use(middleware.RateLimitByUser(defaultLimiter)) // 使用默认限流
		{
			// 认证相关（需要登录）
			authAuthorized := authorized.Group("/auth")
			{
				authAuthorized.POST("/logout", authCtrl.Logout)
				authAuthorized.POST("/refresh", authCtrl.RefreshToken)
				authAuthorized.GET("/me", authCtrl.GetCurrentUser)
			}

			// 市场数据路由
			marketCtrl := controller.NewMarketController(marketService, logger)
			market := authorized.Group("/market")
			{
				market.GET("/indices", marketCtrl.GetIndices)
				market.GET("/precious-metals", marketCtrl.GetPreciousMetals)
				market.GET("/gold-history", marketCtrl.GetGoldHistory)
				market.GET("/volume", marketCtrl.GetVolumeTrend)
				market.GET("/minute-data", marketCtrl.GetMinuteData)
			}

			// 快讯路由
			newsCtrl := controller.NewNewsController(newsService, logger)
			news := authorized.Group("/news")
			{
				news.GET("", newsCtrl.GetNews)
			}

			// 板块路由
			sectorCtrl := controller.NewSectorController(sectorService, logger)
			sectors := authorized.Group("/sectors")
			{
				sectors.GET("", sectorCtrl.GetSectors)
				sectors.GET("/categories", sectorCtrl.GetCategories)
				sectors.GET("/:id/funds", sectorCtrl.GetSectorFunds)
			}

			// 基金路由
			fundCtrl := controller.NewFundController(fundService, logger)
			funds := authorized.Group("/funds")
			{
				funds.GET("", fundCtrl.GetFunds)
				funds.POST("", fundCtrl.AddFund)
				funds.DELETE("/:code", fundCtrl.DeleteFund)
				funds.PUT("/:code/hold", fundCtrl.UpdateHoldStatus)
				funds.PUT("/:code/sectors", fundCtrl.UpdateSectors)
				funds.GET("/:code/valuation", fundCtrl.GetValuation)
			}

			// AI 路由（如果 AI 服务可用）
			if aiService != nil {
				aiCtrl := controller.NewAIController(
					aiService,
					marketService,
					newsService,
					sectorService,
					fundService,
					logger,
				)
				ai := authorized.Group("/ai")
				ai.Use(middleware.RateLimitByUser(strictLimiter)) // AI 接口使用严格限流
				{
					ai.POST("/chat", wrapSSEWithLimit(sseConnectionLimiter, aiCtrl.Chat))
					ai.POST("/analyze/standard", wrapSSEWithLimit(sseConnectionLimiter, aiCtrl.AnalyzeStandard))
					ai.POST("/analyze/fast", wrapSSEWithLimit(sseConnectionLimiter, aiCtrl.AnalyzeFast))
					ai.POST("/analyze/deep", wrapSSEWithLimit(sseConnectionLimiter, aiCtrl.AnalyzeDeep))
				}
			}
		}
	}

	// 创建 HTTP 服务器
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Server.Port),
		Handler:      r,
		ReadTimeout:  time.Duration(cfg.Server.ReadTimeout) * time.Second,
		WriteTimeout: time.Duration(cfg.Server.WriteTimeout) * time.Second,
	}

	// 启动服务器
	go func() {
		logger.Info("Server starting", zap.Int("port", cfg.Server.Port))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("Server failed to start", zap.Error(err))
		}
	}()

	// 优雅关闭
	gracefulShutdown(srv, logger)
}

// healthCheck 增强版健康检查
// Validates: Requirements 22.4
func healthCheck(c *gin.Context, db *sqlx.DB, cache service.CacheService, redisConnected bool) {
	services := make(map[string]string)
	overallStatus := "healthy"

	// 检查数据库连接
	ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
	defer cancel()

	if err := db.PingContext(ctx); err != nil {
		services["database"] = "unhealthy: " + err.Error()
		overallStatus = "degraded"
	} else {
		services["database"] = "healthy"
	}

	// 检查 Redis 连接
	if redisConnected {
		// 尝试执行一个简单的缓存操作
		testKey := "health:check"
		testValue := []byte("ok")
		if err := cache.Set(ctx, testKey, testValue, 10*time.Second); err != nil {
			services["redis"] = "unhealthy: " + err.Error()
			overallStatus = "degraded"
		} else {
			services["redis"] = "healthy"
		}
	} else {
		services["redis"] = "not_configured (using memory cache)"
	}

	// 检查是否正在关闭
	if isShuttingDown.Load() {
		overallStatus = "shutting_down"
	}

	// 计算运行时间
	uptime := time.Since(startTime)
	uptimeStr := formatDuration(uptime)

	// 构建响应
	health := HealthStatus{
		Status:   overallStatus,
		Time:     time.Now().Format(time.RFC3339),
		Uptime:   uptimeStr,
		Version:  "1.0.0",
		Services: services,
	}

	// 根据状态返回不同的 HTTP 状态码
	if overallStatus == "healthy" {
		response.Success(c, health)
	} else if overallStatus == "shutting_down" {
		c.JSON(http.StatusServiceUnavailable, response.Response{
			Code:    503,
			Message: "Service is shutting down",
			Data:    health,
		})
	} else {
		c.JSON(http.StatusOK, response.Response{
			Code:    0,
			Message: "Service is degraded but operational",
			Data:    health,
		})
	}
}

// formatDuration 格式化持续时间
func formatDuration(d time.Duration) string {
	days := int(d.Hours()) / 24
	hours := int(d.Hours()) % 24
	minutes := int(d.Minutes()) % 60
	seconds := int(d.Seconds()) % 60

	if days > 0 {
		return fmt.Sprintf("%dd %dh %dm %ds", days, hours, minutes, seconds)
	}
	if hours > 0 {
		return fmt.Sprintf("%dh %dm %ds", hours, minutes, seconds)
	}
	if minutes > 0 {
		return fmt.Sprintf("%dm %ds", minutes, seconds)
	}
	return fmt.Sprintf("%ds", seconds)
}

// requestTracker 请求跟踪中间件
func requestTracker() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 如果正在关闭，拒绝新请求
		if isShuttingDown.Load() {
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"code":    503,
				"message": "Service is shutting down",
			})
			c.Abort()
			return
		}

		// 增加活跃请求计数
		activeRequests.Add(1)
		defer activeRequests.Add(-1)

		c.Next()
	}
}

// wrapSSEWithLimit 包装 SSE 处理器，添加连接数限制
func wrapSSEWithLimit(limiter *middleware.SSEConnectionLimiter, handler gin.HandlerFunc) gin.HandlerFunc {
	return func(c *gin.Context) {
		// 尝试获取连接许可
		if !limiter.Acquire() {
			c.JSON(http.StatusTooManyRequests, gin.H{
				"code":    429,
				"message": "Too many SSE connections",
			})
			return
		}

		// 确保释放连接许可
		defer limiter.Release()

		// 执行原始处理器
		handler(c)
	}
}

// gracefulShutdown 优雅关闭
// Validates: Requirements 22.1
func gracefulShutdown(srv *http.Server, logger *zap.Logger) {
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down server...")

	// 标记正在关闭
	isShuttingDown.Store(true)

	// 创建关闭超时上下文
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// 等待正在处理的请求完成
	logger.Info("Waiting for active requests to complete...", zap.Int64("activeRequests", activeRequests.Load()))

	// 轮询等待活跃请求完成（最多等待 25 秒）
	waitStart := time.Now()
	for activeRequests.Load() > 0 && time.Since(waitStart) < 25*time.Second {
		time.Sleep(100 * time.Millisecond)
	}

	if activeRequests.Load() > 0 {
		logger.Warn("Some requests did not complete in time", zap.Int64("remaining", activeRequests.Load()))
	} else {
		logger.Info("All active requests completed")
	}

	// 关闭 HTTP 服务器
	if err := srv.Shutdown(ctx); err != nil {
		logger.Error("Server forced to shutdown", zap.Error(err))
	}

	logger.Info("Server exited gracefully")
}
