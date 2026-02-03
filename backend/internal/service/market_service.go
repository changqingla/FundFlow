package service

import (
	"context"
	"encoding/json"

	"fund-analyzer/internal/crawler"
	"fund-analyzer/internal/model"
)

// MarketService 市场数据服务接口
type MarketService interface {
	GetGlobalIndices(ctx context.Context) ([]model.MarketIndex, error)
	GetPreciousMetals(ctx context.Context) ([]model.PreciousMetal, error)
	GetGoldHistory(ctx context.Context, days int) ([]model.GoldPrice, error)
	GetVolumeTrend(ctx context.Context, days int) ([]model.VolumeTrend, error)
	GetMinuteData(ctx context.Context, minutes int) ([]model.MinuteData, error)
}

type marketService struct {
	baiduCrawler *crawler.BaiduCrawler
	goldCrawler  *crawler.GoldCrawler
	cache        CacheService
}

// NewMarketService 创建市场数据服务
func NewMarketService(
	baiduCrawler *crawler.BaiduCrawler,
	goldCrawler *crawler.GoldCrawler,
	cache CacheService,
) MarketService {
	return &marketService{
		baiduCrawler: baiduCrawler,
		goldCrawler:  goldCrawler,
		cache:        cache,
	}
}

// GetGlobalIndices 获取全球市场指数
func (s *marketService) GetGlobalIndices(ctx context.Context) ([]model.MarketIndex, error) {
	// 尝试从缓存获取
	var indices []model.MarketIndex
	err := s.cache.GetJSON(ctx, CacheKeyMarketIndices, &indices)
	if err == nil && len(indices) > 0 {
		return indices, nil
	}

	// 获取亚洲市场
	asiaIndices, err := s.baiduCrawler.GetMarketIndices(ctx, "asia")
	if err != nil {
		return nil, err
	}

	// 获取美洲市场
	americaIndices, err := s.baiduCrawler.GetMarketIndices(ctx, "america")
	if err != nil {
		// 美洲市场获取失败不影响返回亚洲数据
		indices = asiaIndices
	} else {
		indices = append(asiaIndices, americaIndices...)
	}

	// 缓存结果
	_ = s.cache.SetJSON(ctx, CacheKeyMarketIndices, indices, TTLMarketIndices)

	return indices, nil
}

// GetPreciousMetals 获取贵金属实时价格
func (s *marketService) GetPreciousMetals(ctx context.Context) ([]model.PreciousMetal, error) {
	// 尝试从缓存获取
	var metals []model.PreciousMetal
	err := s.cache.GetJSON(ctx, CacheKeyPreciousMetals, &metals)
	if err == nil && len(metals) > 0 {
		return metals, nil
	}

	// 从金投网获取
	metals, err = s.goldCrawler.GetRealTimeGold(ctx)
	if err != nil {
		return nil, err
	}

	// 缓存结果
	_ = s.cache.SetJSON(ctx, CacheKeyPreciousMetals, metals, TTLPreciousMetals)

	return metals, nil
}

// GetGoldHistory 获取历史金价
func (s *marketService) GetGoldHistory(ctx context.Context, days int) ([]model.GoldPrice, error) {
	if days <= 0 {
		days = 30
	}

	// 缓存 key 包含天数
	cacheKey := CacheKeyPreciousMetals + ":history"

	// 尝试从缓存获取
	var history []model.GoldPrice
	err := s.cache.GetJSON(ctx, cacheKey, &history)
	if err == nil && len(history) > 0 {
		return history, nil
	}

	// 从金投网获取
	history, err = s.goldCrawler.GetGoldHistory(ctx, days)
	if err != nil {
		return nil, err
	}

	// 缓存结果（历史数据缓存时间长一些）
	_ = s.cache.SetJSON(ctx, cacheKey, history, TTLFundInfo)

	return history, nil
}

// GetVolumeTrend 获取成交量趋势
func (s *marketService) GetVolumeTrend(ctx context.Context, days int) ([]model.VolumeTrend, error) {
	cacheKey := "market:volume"

	// 尝试从缓存获取
	var volumes []model.VolumeTrend
	err := s.cache.GetJSON(ctx, cacheKey, &volumes)
	if err == nil && len(volumes) > 0 {
		return volumes, nil
	}

	// 从百度股市通获取
	volumes, err = s.baiduCrawler.GetVolumeTrend(ctx)
	if err != nil {
		return nil, err
	}

	// 缓存结果
	_ = s.cache.SetJSON(ctx, cacheKey, volumes, TTLNews)

	return volumes, nil
}

// GetMinuteData 获取上证分时数据
func (s *marketService) GetMinuteData(ctx context.Context, minutes int) ([]model.MinuteData, error) {
	cacheKey := "market:minute"

	// 尝试从缓存获取
	var data []model.MinuteData
	err := s.cache.GetJSON(ctx, cacheKey, &data)
	if err == nil && len(data) > 0 {
		return data, nil
	}

	// 从百度股市通获取
	data, err = s.baiduCrawler.GetMinuteData(ctx, "sh000001")
	if err != nil {
		return nil, err
	}

	// 限制返回数量
	if minutes > 0 && len(data) > minutes {
		data = data[len(data)-minutes:]
	}

	// 缓存结果（分时数据缓存时间短）
	_ = s.cache.SetJSON(ctx, cacheKey, data, TTLFundValuation)

	return data, nil
}

// GetChangeStatus 获取涨跌状态
func GetChangeStatus(change float64) model.ChangeStatus {
	if change > 0 {
		return model.StatusUp
	} else if change < 0 {
		return model.StatusDown
	}
	return model.StatusFlat
}

// ParseChangeRate 解析涨跌幅字符串
func ParseChangeRate(changeStr string) (float64, model.ChangeStatus) {
	var change float64
	_ = json.Unmarshal([]byte(changeStr), &change)

	return change, GetChangeStatus(change)
}
