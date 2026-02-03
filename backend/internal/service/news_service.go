package service

import (
	"context"

	"fund-analyzer/internal/crawler"
	"fund-analyzer/internal/model"
)

// NewsService 快讯服务接口
type NewsService interface {
	GetNewsList(ctx context.Context, count int) ([]model.NewsItem, error)
}

type newsService struct {
	baiduCrawler *crawler.BaiduCrawler
	cache        CacheService
}

// NewNewsService 创建快讯服务
func NewNewsService(baiduCrawler *crawler.BaiduCrawler, cache CacheService) NewsService {
	return &newsService{
		baiduCrawler: baiduCrawler,
		cache:        cache,
	}
}

// GetNewsList 获取快讯列表
func (s *newsService) GetNewsList(ctx context.Context, count int) ([]model.NewsItem, error) {
	if count <= 0 {
		count = 50
	}

	// 尝试从缓存获取
	var news []model.NewsItem
	err := s.cache.GetJSON(ctx, CacheKeyNews, &news)
	if err == nil && len(news) > 0 {
		// 如果缓存数量足够，直接返回
		if len(news) >= count {
			return news[:count], nil
		}
	}

	// 从百度股市通获取
	news, err = s.baiduCrawler.GetNewsFlash(ctx, count)
	if err != nil {
		// 如果获取失败但有缓存，返回缓存数据
		if len(news) > 0 {
			return news, nil
		}
		return nil, err
	}

	// 缓存结果
	_ = s.cache.SetJSON(ctx, CacheKeyNews, news, TTLNews)

	return news, nil
}
