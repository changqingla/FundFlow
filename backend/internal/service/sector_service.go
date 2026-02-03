package service

import (
	"context"
	"sort"
	"strconv"
	"strings"

	"fund-analyzer/internal/crawler"
	"fund-analyzer/internal/model"
)

// SectorService 板块服务接口
type SectorService interface {
	GetSectorList(ctx context.Context) ([]model.Sector, error)
	GetSectorFunds(ctx context.Context, sectorID string) ([]model.SectorFund, error)
	GetSectorCategories() map[string][]string
	SortSectors(sectors []model.Sector, field string, descending bool) []model.Sector
}

type sectorService struct {
	eastMoneyCrawler *crawler.EastMoneyCrawler
	cache            CacheService
}

// NewSectorService 创建板块服务
func NewSectorService(eastMoneyCrawler *crawler.EastMoneyCrawler, cache CacheService) SectorService {
	return &sectorService{
		eastMoneyCrawler: eastMoneyCrawler,
		cache:            cache,
	}
}

// GetSectorList 获取板块列表
func (s *sectorService) GetSectorList(ctx context.Context) ([]model.Sector, error) {
	// 尝试从缓存获取
	var sectors []model.Sector
	err := s.cache.GetJSON(ctx, CacheKeySectorList, &sectors)
	if err == nil && len(sectors) > 0 {
		return sectors, nil
	}

	// 从东方财富获取
	sectors, err = s.eastMoneyCrawler.GetSectorList(ctx)
	if err != nil {
		return nil, err
	}

	// 缓存结果
	_ = s.cache.SetJSON(ctx, CacheKeySectorList, sectors, TTLSectorList)

	return sectors, nil
}

// GetSectorFunds 获取板块基金
func (s *sectorService) GetSectorFunds(ctx context.Context, sectorID string) ([]model.SectorFund, error) {
	cacheKey := "sector:funds:" + sectorID

	// 尝试从缓存获取
	var funds []model.SectorFund
	err := s.cache.GetJSON(ctx, cacheKey, &funds)
	if err == nil && len(funds) > 0 {
		return funds, nil
	}

	// 从东方财富获取
	funds, err = s.eastMoneyCrawler.GetSectorFunds(ctx, sectorID)
	if err != nil {
		return nil, err
	}

	// 缓存结果
	_ = s.cache.SetJSON(ctx, cacheKey, funds, TTLSectorList)

	return funds, nil
}

// GetSectorCategories 获取板块分类
func (s *sectorService) GetSectorCategories() map[string][]string {
	return crawler.GetSectorCategories()
}

// SortSectors 排序板块列表
func (s *sectorService) SortSectors(sectors []model.Sector, field string, descending bool) []model.Sector {
	result := make([]model.Sector, len(sectors))
	copy(result, sectors)

	sort.Slice(result, func(i, j int) bool {
		var vi, vj float64

		switch field {
		case "changeRate":
			vi = parsePercentage(result[i].ChangeRate)
			vj = parsePercentage(result[j].ChangeRate)
		case "mainNetInflow":
			vi = parseMoney(result[i].MainNetInflow)
			vj = parseMoney(result[j].MainNetInflow)
		case "mainInflowRatio":
			vi = parsePercentage(result[i].MainInflowRatio)
			vj = parsePercentage(result[j].MainInflowRatio)
		default:
			vi = parsePercentage(result[i].ChangeRate)
			vj = parsePercentage(result[j].ChangeRate)
		}

		if descending {
			return vi > vj
		}
		return vi < vj
	})

	return result
}

// SortSectorFunds 排序板块基金
func SortSectorFunds(funds []model.SectorFund, field string, descending bool) []model.SectorFund {
	result := make([]model.SectorFund, len(funds))
	copy(result, funds)

	sort.Slice(result, func(i, j int) bool {
		var vi, vj float64

		switch field {
		case "week1":
			vi = parsePercentage(result[i].Week1)
			vj = parsePercentage(result[j].Week1)
		case "month1":
			vi = parsePercentage(result[i].Month1)
			vj = parsePercentage(result[j].Month1)
		case "month3":
			vi = parsePercentage(result[i].Month3)
			vj = parsePercentage(result[j].Month3)
		case "month6":
			vi = parsePercentage(result[i].Month6)
			vj = parsePercentage(result[j].Month6)
		case "year1":
			vi = parsePercentage(result[i].Year1)
			vj = parsePercentage(result[j].Year1)
		default:
			vi = parsePercentage(result[i].Year1)
			vj = parsePercentage(result[j].Year1)
		}

		if descending {
			return vi > vj
		}
		return vi < vj
	})

	return result
}

// parsePercentage 解析百分比字符串
func parsePercentage(s string) float64 {
	s = strings.TrimSpace(s)
	s = strings.TrimSuffix(s, "%")
	f, _ := strconv.ParseFloat(s, 64)
	return f
}

// parseMoney 解析金额字符串
func parseMoney(s string) float64 {
	s = strings.TrimSpace(s)

	multiplier := 1.0
	if strings.HasSuffix(s, "亿") {
		multiplier = 100000000
		s = strings.TrimSuffix(s, "亿")
	} else if strings.HasSuffix(s, "万") {
		multiplier = 10000
		s = strings.TrimSuffix(s, "万")
	}

	f, _ := strconv.ParseFloat(s, 64)
	return f * multiplier
}
