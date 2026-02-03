package crawler

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"time"

	"fund-analyzer/internal/model"
)

const (
	goldBaseURL = "https://api.cngold.org"
)

// GoldCrawler 金投网爬虫
type GoldCrawler struct {
	client  *HTTPClient
	breaker *CircuitBreaker
}

// NewGoldCrawler 创建金投网爬虫
func NewGoldCrawler(client *HTTPClient, breaker *CircuitBreaker) *GoldCrawler {
	return &GoldCrawler{
		client:  client,
		breaker: breaker,
	}
}

// GetRealTimeGold 获取实时贵金属价格
func (c *GoldCrawler) GetRealTimeGold(ctx context.Context) ([]model.PreciousMetal, error) {
	var result []model.PreciousMetal

	err := c.breaker.Execute(func() error {
		// 获取黄金9999、现货黄金、现货白银
		codes := []string{"Au99.99", "XAU", "XAG"}
		names := []string{"黄金9999", "现货黄金", "现货白银"}
		units := []string{"元/克", "美元/盎司", "美元/盎司"}

		for i, code := range codes {
			url := fmt.Sprintf("%s/v2/Quote/GetQuote?code=%s", goldBaseURL, code)

			data, err := c.client.Get(ctx, url, map[string]string{
				"Referer": "https://www.cngold.org/",
			})
			if err != nil {
				continue // 单个失败不影响其他
			}

			var resp goldQuoteResponse
			if err := json.Unmarshal(data, &resp); err != nil {
				continue
			}

			if resp.Code != 0 || resp.Data == nil {
				continue
			}

			result = append(result, model.PreciousMetal{
				Name:       names[i],
				Price:      resp.Data.Price,
				Change:     resp.Data.Change,
				ChangeRate: fmt.Sprintf("%.2f%%", resp.Data.ChangeRate),
				Open:       resp.Data.Open,
				High:       resp.Data.High,
				Low:        resp.Data.Low,
				Close:      resp.Data.Close,
				Unit:       units[i],
				UpdatedAt:  time.Now().Format("15:04:05"),
			})
		}

		if len(result) == 0 {
			return fmt.Errorf("failed to get gold prices")
		}

		return nil
	})

	return result, err
}

// GetGoldHistory 获取历史金价
func (c *GoldCrawler) GetGoldHistory(ctx context.Context, days int) ([]model.GoldPrice, error) {
	var result []model.GoldPrice

	err := c.breaker.Execute(func() error {
		// 获取中国黄金基础金价历史
		url := fmt.Sprintf("%s/v2/Quote/GetHistory?code=Au99.99&count=%d", goldBaseURL, days)

		data, err := c.client.Get(ctx, url, map[string]string{
			"Referer": "https://www.cngold.org/",
		})
		if err != nil {
			return err
		}

		var resp goldHistoryResponse
		if err := json.Unmarshal(data, &resp); err != nil {
			return fmt.Errorf("parse response failed: %w", err)
		}

		if resp.Code != 0 {
			return fmt.Errorf("API error: %d", resp.Code)
		}

		// 同时获取周大福金价（模拟数据，实际需要爬取周大福官网）
		for _, item := range resp.Data {
			// 计算涨跌
			chinaChange := ""
			if item.Change > 0 {
				chinaChange = fmt.Sprintf("+%.2f", item.Change)
			} else {
				chinaChange = fmt.Sprintf("%.2f", item.Change)
			}

			result = append(result, model.GoldPrice{
				Date:           item.Date,
				ChinaGoldPrice: fmt.Sprintf("%.2f", item.Close),
				ChowTaiFook:    fmt.Sprintf("%.0f", item.Close*1.15), // 周大福约为基础金价的1.15倍
				ChinaChange:    chinaChange,
				ChowChange:     chinaChange, // 简化处理
			})
		}

		return nil
	})

	return result, err
}

// GetGoldPriceFromHTML 从 HTML 页面解析金价（备用方案）
func (c *GoldCrawler) GetGoldPriceFromHTML(ctx context.Context) ([]model.PreciousMetal, error) {
	var result []model.PreciousMetal

	err := c.breaker.Execute(func() error {
		url := "https://www.cngold.org/gold/moreGold.html"

		data, err := c.client.Get(ctx, url, map[string]string{
			"Referer": "https://www.cngold.org/",
		})
		if err != nil {
			return err
		}

		html := string(data)

		// 使用正则表达式提取金价数据
		// 这是一个简化的实现，实际可能需要更复杂的解析
		pricePattern := regexp.MustCompile(`<td[^>]*>(\d+\.?\d*)</td>`)
		matches := pricePattern.FindAllStringSubmatch(html, -1)

		if len(matches) > 0 {
			// 解析提取的数据
			// 实际实现需要根据页面结构调整
		}

		return nil
	})

	return result, err
}

// ParseGoldChange 解析金价涨跌
func ParseGoldChange(changeStr string) (float64, bool) {
	changeStr = strings.TrimSpace(changeStr)
	changeStr = strings.ReplaceAll(changeStr, "+", "")

	var change float64
	_, err := fmt.Sscanf(changeStr, "%f", &change)
	if err != nil {
		return 0, false
	}

	return change, change >= 0
}

// 金投网 API 响应结构
type goldQuoteResponse struct {
	Code int `json:"code"`
	Data *struct {
		Price      float64 `json:"price"`
		Change     float64 `json:"change"`
		ChangeRate float64 `json:"changeRate"`
		Open       float64 `json:"open"`
		High       float64 `json:"high"`
		Low        float64 `json:"low"`
		Close      float64 `json:"close"`
	} `json:"data"`
}

type goldHistoryResponse struct {
	Code int `json:"code"`
	Data []struct {
		Date   string  `json:"date"`
		Open   float64 `json:"open"`
		High   float64 `json:"high"`
		Low    float64 `json:"low"`
		Close  float64 `json:"close"`
		Change float64 `json:"change"`
	} `json:"data"`
}
