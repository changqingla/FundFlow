package service

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"time"

	"fund-analyzer/internal/config"

	"github.com/go-redis/redis/v8"
)

// 缓存 Key 常量
const (
	CacheKeyMarketIndices  = "market:indices"
	CacheKeyPreciousMetals = "market:precious_metals"
	CacheKeySectorList     = "sector:list"
	CacheKeyNews           = "news:list"
	CacheKeyFundInfo       = "fund:info:%s"      // %s = fund code
	CacheKeyFundValuation  = "fund:valuation:%s" // %s = fund code
)

// 缓存 TTL 配置
const (
	TTLMarketIndices  = 30 * time.Second
	TTLPreciousMetals = 30 * time.Second
	TTLSectorList     = 5 * time.Minute
	TTLNews           = 1 * time.Minute
	TTLFundInfo       = 1 * time.Hour
	TTLFundValuation  = 30 * time.Second
)

var (
	ErrCacheMiss = errors.New("cache miss")
)

// CacheService 缓存服务接口
type CacheService interface {
	Get(ctx context.Context, key string) ([]byte, error)
	Set(ctx context.Context, key string, value []byte, ttl time.Duration) error
	Delete(ctx context.Context, key string) error
	GetOrSet(ctx context.Context, key string, ttl time.Duration, fn func() ([]byte, error)) ([]byte, error)
	GetJSON(ctx context.Context, key string, dest interface{}) error
	SetJSON(ctx context.Context, key string, value interface{}, ttl time.Duration) error
}

// RedisCache Redis 缓存实现
type RedisCache struct {
	client *redis.Client
}

// NewCacheService 创建 Redis 缓存服务
func NewCacheService(cfg config.RedisConfig) (CacheService, error) {
	client := redis.NewClient(&redis.Options{
		Addr:     cfg.Addr(),
		Password: cfg.Password,
		DB:       cfg.DB,
	})

	// 测试连接
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return nil, err
	}

	return &RedisCache{client: client}, nil
}

func (c *RedisCache) Get(ctx context.Context, key string) ([]byte, error) {
	val, err := c.client.Get(ctx, key).Bytes()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return nil, ErrCacheMiss
		}
		return nil, err
	}
	return val, nil
}

func (c *RedisCache) Set(ctx context.Context, key string, value []byte, ttl time.Duration) error {
	return c.client.Set(ctx, key, value, ttl).Err()
}

func (c *RedisCache) Delete(ctx context.Context, key string) error {
	return c.client.Del(ctx, key).Err()
}

func (c *RedisCache) GetOrSet(ctx context.Context, key string, ttl time.Duration, fn func() ([]byte, error)) ([]byte, error) {
	// 先尝试从缓存获取
	val, err := c.Get(ctx, key)
	if err == nil {
		return val, nil
	}

	// 缓存未命中，执行函数获取数据
	val, err = fn()
	if err != nil {
		return nil, err
	}

	// 存入缓存（忽略错误）
	_ = c.Set(ctx, key, val, ttl)

	return val, nil
}

func (c *RedisCache) GetJSON(ctx context.Context, key string, dest interface{}) error {
	val, err := c.Get(ctx, key)
	if err != nil {
		return err
	}
	return json.Unmarshal(val, dest)
}

func (c *RedisCache) SetJSON(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	return c.Set(ctx, key, data, ttl)
}

// MemoryCache 内存缓存实现（Redis 不可用时的降级方案）
type MemoryCache struct {
	data  map[string]cacheItem
	mutex sync.RWMutex
}

type cacheItem struct {
	value     []byte
	expiresAt time.Time
}

// NewMemoryCache 创建内存缓存
func NewMemoryCache() CacheService {
	cache := &MemoryCache{
		data: make(map[string]cacheItem),
	}
	// 启动清理协程
	go cache.cleanup()
	return cache
}

func (c *MemoryCache) Get(ctx context.Context, key string) ([]byte, error) {
	c.mutex.RLock()
	defer c.mutex.RUnlock()

	item, ok := c.data[key]
	if !ok {
		return nil, ErrCacheMiss
	}

	if time.Now().After(item.expiresAt) {
		return nil, ErrCacheMiss
	}

	return item.value, nil
}

func (c *MemoryCache) Set(ctx context.Context, key string, value []byte, ttl time.Duration) error {
	c.mutex.Lock()
	defer c.mutex.Unlock()

	c.data[key] = cacheItem{
		value:     value,
		expiresAt: time.Now().Add(ttl),
	}
	return nil
}

func (c *MemoryCache) Delete(ctx context.Context, key string) error {
	c.mutex.Lock()
	defer c.mutex.Unlock()

	delete(c.data, key)
	return nil
}

func (c *MemoryCache) GetOrSet(ctx context.Context, key string, ttl time.Duration, fn func() ([]byte, error)) ([]byte, error) {
	val, err := c.Get(ctx, key)
	if err == nil {
		return val, nil
	}

	val, err = fn()
	if err != nil {
		return nil, err
	}

	_ = c.Set(ctx, key, val, ttl)
	return val, nil
}

func (c *MemoryCache) GetJSON(ctx context.Context, key string, dest interface{}) error {
	val, err := c.Get(ctx, key)
	if err != nil {
		return err
	}
	return json.Unmarshal(val, dest)
}

func (c *MemoryCache) SetJSON(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	return c.Set(ctx, key, data, ttl)
}

// cleanup 定期清理过期缓存
func (c *MemoryCache) cleanup() {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		c.mutex.Lock()
		now := time.Now()
		for key, item := range c.data {
			if now.After(item.expiresAt) {
				delete(c.data, key)
			}
		}
		c.mutex.Unlock()
	}
}
