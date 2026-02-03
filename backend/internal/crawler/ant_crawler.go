package crawler

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"fund-analyzer/internal/model"
)

const (
	antBaseURL = "https://www.fund123.cn"
)

// AntCrawler 蚂蚁财富爬虫
type AntCrawler struct {
	client  *HTTPClient
	breaker *CircuitBreaker
}

// NewAntCrawler 创建蚂蚁财富爬虫
func NewAntCrawler(client *HTTPClient, breaker *CircuitBreaker) *AntCrawler {
	return &AntCrawler{
		client:  client,
		breaker: breaker,
	}
}

// SearchFund 搜索基金
func (c *AntCrawler) SearchFund(ctx context.Context, code string) (*model.FundInfo, error) {
	var result *model.FundInfo

	err := c.breaker.Execute(func() error {
		url := fmt.Sprintf("%s/api/fund/search?key=%s", antBaseURL, code)

		data, err := c.client.Get(ctx, url, map[string]string{
			"Referer": "https://www.fund123.cn/",
		})
		if err != nil {
			return err
		}

		var resp antSearchResponse
		if err := json.Unmarshal(data, &resp); err != nil {
			return fmt.Errorf("parse response failed: %w", err)
		}

		if !resp.Success || len(resp.Data) == 0 {
			return fmt.Errorf("fund not found: %s", code)
		}

		// 查找精确匹配的基金
		for _, fund := range resp.Data {
			if fund.FundCode == code {
				result = &model.FundInfo{
					Code:    fund.FundCode,
					Name:    fund.FundName,
					FundKey: fund.ProductId,
				}
				return nil
			}
		}

		// 如果没有精确匹配，返回第一个
		fund := resp.Data[0]
		result = &model.FundInfo{
			Code:    fund.FundCode,
			Name:    fund.FundName,
			FundKey: fund.ProductId,
		}

		return nil
	})

	return result, err
}

// GetFundValuation 获取基金估值
func (c *AntCrawler) GetFundValuation(ctx context.Context, productID string) (*model.FundValuation, error) {
	var result *model.FundValuation

	err := c.breaker.Execute(func() error {
		url := fmt.Sprintf("%s/api/fund/detail/valuation?productId=%s", antBaseURL, productID)

		data, err := c.client.Get(ctx, url, map[string]string{
			"Referer": "https://www.fund123.cn/",
		})
		if err != nil {
			return err
		}

		var resp antValuationResponse
		if err := json.Unmarshal(data, &resp); err != nil {
			return fmt.Errorf("parse response failed: %w", err)
		}

		if !resp.Success {
			return fmt.Errorf("get valuation failed")
		}

		result = &model.FundValuation{
			Code:              resp.Data.FundCode,
			Name:              resp.Data.FundName,
			ValuationTime:     resp.Data.ValuationTime,
			Valuation:         resp.Data.Valuation,
			DayGrowth:         resp.Data.DayGrowth,
			ConsecutiveDays:   resp.Data.ConsecutiveDays,
			ConsecutiveGrowth: resp.Data.ConsecutiveGrowth,
			MonthlyStats:      resp.Data.MonthlyStats,
			MonthlyGrowth:     resp.Data.MonthlyGrowth,
		}

		return nil
	})

	return result, err
}

// GetFundCurves 获取基金历史曲线
func (c *AntCrawler) GetFundCurves(ctx context.Context, productID string, interval string) ([]model.FundPoint, error) {
	var result []model.FundPoint

	err := c.breaker.Execute(func() error {
		// interval: 1m, 3m, 6m, 1y, 3y, 5y, all
		url := fmt.Sprintf("%s/api/fund/detail/curves?productId=%s&period=%s", antBaseURL, productID, interval)

		data, err := c.client.Get(ctx, url, map[string]string{
			"Referer": "https://www.fund123.cn/",
		})
		if err != nil {
			return err
		}

		var resp antCurvesResponse
		if err := json.Unmarshal(data, &resp); err != nil {
			return fmt.Errorf("parse response failed: %w", err)
		}

		if !resp.Success {
			return fmt.Errorf("get curves failed")
		}

		for _, point := range resp.Data.Curves {
			result = append(result, model.FundPoint{
				Date:  point.Date,
				Value: point.Value,
			})
		}

		return nil
	})

	return result, err
}

// GetFundDetail 获取基金详情（包含估值和历史数据）
func (c *AntCrawler) GetFundDetail(ctx context.Context, code string) (*FundDetailResult, error) {
	// 先搜索基金获取 productId
	fundInfo, err := c.SearchFund(ctx, code)
	if err != nil {
		return nil, err
	}

	// 获取估值
	valuation, err := c.GetFundValuation(ctx, fundInfo.FundKey)
	if err != nil {
		return nil, err
	}

	// 获取近 30 天历史
	curves, err := c.GetFundCurves(ctx, fundInfo.FundKey, "1m")
	if err != nil {
		// 历史数据获取失败不影响主流程
		curves = nil
	}

	return &FundDetailResult{
		Info:      fundInfo,
		Valuation: valuation,
		History:   curves,
	}, nil
}

// FundDetailResult 基金详情结果
type FundDetailResult struct {
	Info      *model.FundInfo
	Valuation *model.FundValuation
	History   []model.FundPoint
}

// CalculateConsecutiveDays 计算连涨/跌天数
func CalculateConsecutiveDays(history []model.FundPoint) int {
	if len(history) < 2 {
		return 0
	}

	// 从最近一天开始计算
	consecutive := 0
	var direction int // 1: 上涨, -1: 下跌

	for i := len(history) - 1; i > 0; i-- {
		current := parseFloat(history[i].Value)
		previous := parseFloat(history[i-1].Value)

		if current > previous {
			if direction == 0 {
				direction = 1
			}
			if direction == 1 {
				consecutive++
			} else {
				break
			}
		} else if current < previous {
			if direction == 0 {
				direction = -1
			}
			if direction == -1 {
				consecutive++
			} else {
				break
			}
		} else {
			break
		}
	}

	return consecutive * direction
}

func parseFloat(s string) float64 {
	s = strings.TrimSpace(s)
	var f float64
	fmt.Sscanf(s, "%f", &f)
	return f
}

// 蚂蚁财富 API 响应结构
type antSearchResponse struct {
	Success bool `json:"success"`
	Data    []struct {
		FundCode  string `json:"fundCode"`
		FundName  string `json:"fundName"`
		ProductId string `json:"productId"`
	} `json:"data"`
}

type antValuationResponse struct {
	Success bool `json:"success"`
	Data    struct {
		FundCode          string `json:"fundCode"`
		FundName          string `json:"fundName"`
		ValuationTime     string `json:"valuationTime"`
		Valuation         string `json:"valuation"`
		DayGrowth         string `json:"dayGrowth"`
		ConsecutiveDays   int    `json:"consecutiveDays"`
		ConsecutiveGrowth string `json:"consecutiveGrowth"`
		MonthlyStats      string `json:"monthlyStats"`
		MonthlyGrowth     string `json:"monthlyGrowth"`
	} `json:"data"`
}

type antCurvesResponse struct {
	Success bool `json:"success"`
	Data    struct {
		Curves []struct {
			Date  string `json:"date"`
			Value string `json:"value"`
		} `json:"curves"`
	} `json:"data"`
}
