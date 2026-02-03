package service

import (
	"context"
	"errors"
	"fmt"

	"fund-analyzer/internal/crawler"
	"fund-analyzer/internal/model"
	"fund-analyzer/internal/repository"
)

var (
	ErrFundNotFound = errors.New("fund not found")
	ErrFundExists   = errors.New("fund already exists")
)

// FundService 基金服务接口
type FundService interface {
	GetFundList(ctx context.Context, userID int64) ([]FundWithValuation, error)
	AddFund(ctx context.Context, userID int64, code string) (*model.FundInfo, error)
	DeleteFund(ctx context.Context, userID int64, code string) error
	UpdateHoldStatus(ctx context.Context, userID int64, code string, isHold bool) error
	UpdateSectors(ctx context.Context, userID int64, code string, sectors []string) error
	SearchFund(ctx context.Context, code string) (*model.FundInfo, error)
	GetFundValuation(ctx context.Context, code string) (*model.FundValuation, error)
}

// FundWithValuation 带估值的基金信息
type FundWithValuation struct {
	model.UserFund
	Valuation *model.FundValuation `json:"valuation,omitempty"`
}

type fundService struct {
	fundRepo   repository.UserFundRepository
	antCrawler *crawler.AntCrawler
	cache      CacheService
}

// NewFundService 创建基金服务
func NewFundService(
	fundRepo repository.UserFundRepository,
	antCrawler *crawler.AntCrawler,
	cache CacheService,
) FundService {
	return &fundService{
		fundRepo:   fundRepo,
		antCrawler: antCrawler,
		cache:      cache,
	}
}

// GetFundList 获取用户自选基金列表
func (s *fundService) GetFundList(ctx context.Context, userID int64) ([]FundWithValuation, error) {
	// 获取用户基金列表
	funds, err := s.fundRepo.GetFundsByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}

	// 获取每只基金的估值
	result := make([]FundWithValuation, len(funds))
	for i, fund := range funds {
		result[i] = FundWithValuation{
			UserFund: fund,
		}

		// 尝试获取估值（失败不影响返回）
		valuation, err := s.GetFundValuation(ctx, fund.FundKey)
		if err == nil {
			result[i].Valuation = valuation
		}
	}

	return result, nil
}

// AddFund 添加基金
func (s *fundService) AddFund(ctx context.Context, userID int64, code string) (*model.FundInfo, error) {
	// 检查是否已存在
	_, err := s.fundRepo.GetFundByCode(ctx, userID, code)
	if err == nil {
		return nil, ErrFundExists
	}
	if !errors.Is(err, repository.ErrFundNotFound) {
		return nil, err
	}

	// 搜索基金信息
	fundInfo, err := s.antCrawler.SearchFund(ctx, code)
	if err != nil {
		return nil, fmt.Errorf("invalid fund code: %w", err)
	}

	// 添加到数据库
	userFund := &model.UserFund{
		UserID:   userID,
		FundCode: fundInfo.Code,
		FundName: fundInfo.Name,
		FundKey:  fundInfo.FundKey,
		IsHold:   false,
		Sectors:  nil,
	}

	if err := s.fundRepo.AddFund(ctx, userFund); err != nil {
		return nil, err
	}

	return fundInfo, nil
}

// DeleteFund 删除基金
func (s *fundService) DeleteFund(ctx context.Context, userID int64, code string) error {
	return s.fundRepo.DeleteFund(ctx, userID, code)
}

// UpdateHoldStatus 更新持有状态
func (s *fundService) UpdateHoldStatus(ctx context.Context, userID int64, code string, isHold bool) error {
	return s.fundRepo.UpdateHoldStatus(ctx, userID, code, isHold)
}

// UpdateSectors 更新板块标记
func (s *fundService) UpdateSectors(ctx context.Context, userID int64, code string, sectors []string) error {
	return s.fundRepo.UpdateSectors(ctx, userID, code, sectors)
}

// SearchFund 搜索基金
func (s *fundService) SearchFund(ctx context.Context, code string) (*model.FundInfo, error) {
	return s.antCrawler.SearchFund(ctx, code)
}

// GetFundValuation 获取基金估值
func (s *fundService) GetFundValuation(ctx context.Context, fundKey string) (*model.FundValuation, error) {
	cacheKey := fmt.Sprintf(CacheKeyFundValuation, fundKey)

	// 尝试从缓存获取
	var valuation model.FundValuation
	err := s.cache.GetJSON(ctx, cacheKey, &valuation)
	if err == nil {
		return &valuation, nil
	}

	// 从蚂蚁财富获取
	val, err := s.antCrawler.GetFundValuation(ctx, fundKey)
	if err != nil {
		return nil, err
	}

	// 缓存结果
	_ = s.cache.SetJSON(ctx, cacheKey, val, TTLFundValuation)

	return val, nil
}

// CalculateConsecutiveDays 计算连涨/跌天数
func CalculateConsecutiveDays(history []model.FundPoint) int {
	return crawler.CalculateConsecutiveDays(history)
}
