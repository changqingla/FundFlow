package crawler

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"fund-analyzer/internal/model"
)

const (
	baiduBaseURL = "https://gushitong.baidu.com"
)

// BaiduCrawler 百度股市通爬虫
type BaiduCrawler struct {
	client  *HTTPClient
	breaker *CircuitBreaker
}

// NewBaiduCrawler 创建百度股市通爬虫
func NewBaiduCrawler(client *HTTPClient, breaker *CircuitBreaker) *BaiduCrawler {
	return &BaiduCrawler{
		client:  client,
		breaker: breaker,
	}
}

// GetMarketIndices 获取市场指数
func (c *BaiduCrawler) GetMarketIndices(ctx context.Context, market string) ([]model.MarketIndex, error) {
	var result []model.MarketIndex

	err := c.breaker.Execute(func() error {
		// 根据市场类型选择不同的 API
		var url string
		switch market {
		case "asia":
			url = fmt.Sprintf("%s/opendata?resource_id=5352&query=亚洲股市&code=global_asia&name=亚洲股市&market=ab&pn=0&rn=20&finClientType=pc", baiduBaseURL)
		case "america":
			url = fmt.Sprintf("%s/opendata?resource_id=5352&query=美洲股市&code=global_america&name=美洲股市&market=ab&pn=0&rn=20&finClientType=pc", baiduBaseURL)
		default:
			url = fmt.Sprintf("%s/opendata?resource_id=5352&query=亚洲股市&code=global_asia&name=亚洲股市&market=ab&pn=0&rn=20&finClientType=pc", baiduBaseURL)
		}

		data, err := c.client.Get(ctx, url, map[string]string{
			"Referer": "https://gushitong.baidu.com/",
		})
		if err != nil {
			return err
		}

		var resp baiduResponse
		if err := json.Unmarshal(data, &resp); err != nil {
			return fmt.Errorf("parse response failed: %w", err)
		}

		if resp.ResultCode != "0" {
			return fmt.Errorf("API error: %s", resp.ResultCode)
		}

		for _, item := range resp.Result {
			for _, stock := range item.List {
				isUp := !strings.HasPrefix(stock.Increase, "-")
				result = append(result, model.MarketIndex{
					Name:      stock.Name,
					Price:     stock.Price,
					Change:    stock.Increase,
					IsUp:      isUp,
					UpdatedAt: time.Now().Format("15:04:05"),
				})
			}
		}

		return nil
	})

	return result, err
}

// GetNewsFlash 获取 7×24 快讯
func (c *BaiduCrawler) GetNewsFlash(ctx context.Context, count int) ([]model.NewsItem, error) {
	var result []model.NewsItem

	err := c.breaker.Execute(func() error {
		url := fmt.Sprintf("%s/opendata?resource_id=5388&query=7x24&pn=0&rn=%d&finClientType=pc", baiduBaseURL, count)

		data, err := c.client.Get(ctx, url, map[string]string{
			"Referer": "https://gushitong.baidu.com/",
		})
		if err != nil {
			return err
		}

		var resp baiduNewsResponse
		if err := json.Unmarshal(data, &resp); err != nil {
			return fmt.Errorf("parse response failed: %w", err)
		}

		if resp.ResultCode != "0" {
			return fmt.Errorf("API error: %s", resp.ResultCode)
		}

		for _, item := range resp.Result {
			for _, news := range item.Content {
				var entities []model.NewsEntity
				for _, entity := range news.Entities {
					entities = append(entities, model.NewsEntity{
						Code:  entity.Code,
						Name:  entity.Name,
						Ratio: entity.Ratio,
					})
				}

				publishTime, _ := strconv.ParseInt(news.PublishTime, 10, 64)

				result = append(result, model.NewsItem{
					ID:          news.ID,
					Title:       news.Title,
					Content:     news.Content,
					Evaluate:    news.Evaluate,
					PublishTime: publishTime,
					Entities:    entities,
				})
			}
		}

		return nil
	})

	return result, err
}

// GetMinuteData 获取上证分时数据
func (c *BaiduCrawler) GetMinuteData(ctx context.Context, code string) ([]model.MinuteData, error) {
	var result []model.MinuteData

	err := c.breaker.Execute(func() error {
		if code == "" {
			code = "sh000001" // 默认上证指数
		}

		url := fmt.Sprintf("%s/opendata?resource_id=5429&query=%s&code=%s&market=ab&finClientType=pc", baiduBaseURL, code, code)

		data, err := c.client.Get(ctx, url, map[string]string{
			"Referer": "https://gushitong.baidu.com/",
		})
		if err != nil {
			return err
		}

		var resp baiduMinuteResponse
		if err := json.Unmarshal(data, &resp); err != nil {
			return fmt.Errorf("parse response failed: %w", err)
		}

		if resp.ResultCode != "0" {
			return fmt.Errorf("API error: %s", resp.ResultCode)
		}

		for _, item := range resp.Result {
			for _, point := range item.MinuteData {
				result = append(result, model.MinuteData{
					Time:       point.Time,
					Price:      point.Price,
					Change:     point.Change,
					ChangeRate: point.ChangeRate,
					Volume:     point.Volume,
					Amount:     point.Amount,
				})
			}
		}

		return nil
	})

	return result, err
}

// GetVolumeTrend 获取成交量趋势
func (c *BaiduCrawler) GetVolumeTrend(ctx context.Context) ([]model.VolumeTrend, error) {
	var result []model.VolumeTrend

	err := c.breaker.Execute(func() error {
		url := fmt.Sprintf("%s/opendata?resource_id=5353&query=大盘资金&finClientType=pc", baiduBaseURL)

		data, err := c.client.Get(ctx, url, map[string]string{
			"Referer": "https://gushitong.baidu.com/",
		})
		if err != nil {
			return err
		}

		var resp baiduVolumeResponse
		if err := json.Unmarshal(data, &resp); err != nil {
			return fmt.Errorf("parse response failed: %w", err)
		}

		if resp.ResultCode != "0" {
			return fmt.Errorf("API error: %s", resp.ResultCode)
		}

		for _, item := range resp.Result {
			for _, vol := range item.VolumeList {
				result = append(result, model.VolumeTrend{
					Date:        vol.Date,
					TotalVolume: vol.Total,
					Shanghai:    vol.Shanghai,
					Shenzhen:    vol.Shenzhen,
					Beijing:     vol.Beijing,
				})
			}
		}

		return nil
	})

	return result, err
}

// 百度 API 响应结构
type baiduResponse struct {
	ResultCode string `json:"ResultCode"`
	Result     []struct {
		List []struct {
			Name     string `json:"name"`
			Code     string `json:"code"`
			Price    string `json:"price"`
			Increase string `json:"increase"`
		} `json:"list"`
	} `json:"Result"`
}

type baiduNewsResponse struct {
	ResultCode string `json:"ResultCode"`
	Result     []struct {
		Content []struct {
			ID          string `json:"id"`
			Title       string `json:"title"`
			Content     string `json:"content"`
			Evaluate    string `json:"evaluate"`
			PublishTime string `json:"publish_time"`
			Entities    []struct {
				Code  string `json:"code"`
				Name  string `json:"name"`
				Ratio string `json:"ratio"`
			} `json:"entities"`
		} `json:"content"`
	} `json:"Result"`
}

type baiduMinuteResponse struct {
	ResultCode string `json:"ResultCode"`
	Result     []struct {
		MinuteData []struct {
			Time       string `json:"time"`
			Price      string `json:"price"`
			Change     string `json:"change"`
			ChangeRate string `json:"change_rate"`
			Volume     string `json:"volume"`
			Amount     string `json:"amount"`
		} `json:"minute_data"`
	} `json:"Result"`
}

type baiduVolumeResponse struct {
	ResultCode string `json:"ResultCode"`
	Result     []struct {
		VolumeList []struct {
			Date     string `json:"date"`
			Total    string `json:"total"`
			Shanghai string `json:"shanghai"`
			Shenzhen string `json:"shenzhen"`
			Beijing  string `json:"beijing"`
		} `json:"volume_list"`
	} `json:"Result"`
}
