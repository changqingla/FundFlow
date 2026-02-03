package crawler

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"fund-analyzer/internal/model"
)

const (
	eastmoneyBaseURL = "https://push2.eastmoney.com"
	fundEastURL      = "https://fundapi.eastmoney.com"
)

// EastMoneyCrawler 东方财富爬虫
type EastMoneyCrawler struct {
	client  *HTTPClient
	breaker *CircuitBreaker
}

// NewEastMoneyCrawler 创建东方财富爬虫
func NewEastMoneyCrawler(client *HTTPClient, breaker *CircuitBreaker) *EastMoneyCrawler {
	return &EastMoneyCrawler{
		client:  client,
		breaker: breaker,
	}
}

// GetSectorList 获取板块列表
func (c *EastMoneyCrawler) GetSectorList(ctx context.Context) ([]model.Sector, error) {
	var result []model.Sector

	err := c.breaker.Execute(func() error {
		url := fmt.Sprintf("%s/api/qt/clist/get?pn=1&pz=100&po=1&np=1&fltt=2&invt=2&fid=f3&fs=m:90+t:2&fields=f1,f2,f3,f4,f12,f13,f14,f62,f184,f66,f69,f72,f75,f78,f81,f84,f87,f204,f205,f124", eastmoneyBaseURL)

		data, err := c.client.Get(ctx, url, map[string]string{
			"Referer": "https://data.eastmoney.com/",
		})
		if err != nil {
			return err
		}

		var resp eastmoneySectorResponse
		if err := json.Unmarshal(data, &resp); err != nil {
			return fmt.Errorf("parse response failed: %w", err)
		}

		if resp.Data == nil {
			return fmt.Errorf("no data returned")
		}

		for _, item := range resp.Data.Diff {
			result = append(result, model.Sector{
				ID:               item.F12,
				Name:             item.F14,
				ChangeRate:       formatPercent(item.F3),
				MainNetInflow:    formatMoney(item.F62),
				MainInflowRatio:  formatPercent(item.F184),
				SmallNetInflow:   formatMoney(item.F81),
				SmallInflowRatio: formatPercent(item.F87),
			})
		}

		return nil
	})

	return result, err
}

// GetSectorFunds 获取板块基金
func (c *EastMoneyCrawler) GetSectorFunds(ctx context.Context, sectorCode string) ([]model.SectorFund, error) {
	var result []model.SectorFund

	err := c.breaker.Execute(func() error {
		// 获取板块相关基金
		url := fmt.Sprintf("%s/FundMNewApi/FundMNRank?fundtype=0&bzdm=%s&pageindex=1&pagesize=50&sort=SYL_1N&sorttype=desc", fundEastURL, sectorCode)

		data, err := c.client.Get(ctx, url, map[string]string{
			"Referer": "https://fund.eastmoney.com/",
		})
		if err != nil {
			return err
		}

		var resp eastmoneyFundResponse
		if err := json.Unmarshal(data, &resp); err != nil {
			return fmt.Errorf("parse response failed: %w", err)
		}

		for _, item := range resp.Datas {
			result = append(result, model.SectorFund{
				Code:       item.FCODE,
				Name:       item.SHORTNAME,
				Type:       item.FTYPE,
				Date:       item.FSRQ,
				NetValue:   item.NAV,
				Week1:      item.SYL_Z,
				Month1:     item.SYL_Y,
				Month3:     item.SYL_3Y,
				Month6:     item.SYL_6Y,
				YearToDate: item.SYL_JN,
				Year1:      item.SYL_1N,
				Year2:      item.SYL_2N,
				Year3:      item.SYL_3N,
				SinceStart: item.SYL_LN,
			})
		}

		return nil
	})

	return result, err
}

// SectorCategories 板块分类映射
var SectorCategories = map[string][]string{
	"科技": {
		"半导体", "芯片", "软件开发", "计算机应用", "通信设备", "消费电子",
		"光学光电子", "电子元件", "互联网服务", "IT服务", "游戏", "数字媒体",
		"人工智能", "云计算", "大数据", "物联网", "5G", "区块链",
	},
	"医药健康": {
		"化学制药", "中药", "生物制品", "医疗器械", "医疗服务", "医药商业",
		"疫苗", "创新药", "CXO", "医美", "养老", "健康管理",
	},
	"消费": {
		"白酒", "食品加工", "饮料制造", "家用电器", "纺织服装", "商业百货",
		"酒店餐饮", "旅游", "教育", "传媒", "零售", "电商",
	},
	"金融": {
		"银行", "保险", "证券", "多元金融", "信托", "期货",
	},
	"能源": {
		"石油石化", "煤炭", "电力", "燃气", "新能源", "光伏",
		"风电", "储能", "氢能", "核电",
	},
	"制造": {
		"汽车整车", "汽车零部件", "新能源车", "工程机械", "航空航天",
		"船舶制造", "轨道交通", "军工", "电气设备", "仪器仪表",
	},
	"材料": {
		"钢铁", "有色金属", "化工", "建材", "造纸", "玻璃",
		"稀土", "锂电", "新材料",
	},
	"地产基建": {
		"房地产开发", "房地产服务", "建筑装饰", "建筑材料", "水泥",
		"基础建设", "园林工程",
	},
	"农业": {
		"种植业", "养殖业", "农产品加工", "农业服务", "饲料", "化肥",
	},
	"其他": {
		"环保", "公用事业", "交通运输", "物流", "航运", "机场",
	},
}

// GetSectorCategory 获取板块所属大类
func GetSectorCategory(sectorName string) string {
	for category, sectors := range SectorCategories {
		for _, s := range sectors {
			if strings.Contains(sectorName, s) {
				return category
			}
		}
	}
	return "其他"
}

// GetSectorCategories 获取所有板块分类
func GetSectorCategories() map[string][]string {
	return SectorCategories
}

// 格式化百分比
func formatPercent(v float64) string {
	return fmt.Sprintf("%.2f%%", v)
}

// 格式化金额（亿）
func formatMoney(v float64) string {
	if v >= 100000000 {
		return fmt.Sprintf("%.2f亿", v/100000000)
	} else if v >= 10000 {
		return fmt.Sprintf("%.2f万", v/10000)
	}
	return fmt.Sprintf("%.2f", v)
}

// 东方财富 API 响应结构
type eastmoneySectorResponse struct {
	Data *struct {
		Diff []struct {
			F3   float64 `json:"f3"`   // 涨跌幅
			F12  string  `json:"f12"`  // 板块代码
			F14  string  `json:"f14"`  // 板块名称
			F62  float64 `json:"f62"`  // 主力净流入
			F81  float64 `json:"f81"`  // 小单净流入
			F87  float64 `json:"f87"`  // 小单净流入占比
			F184 float64 `json:"f184"` // 主力净流入占比
		} `json:"diff"`
	} `json:"data"`
}

type eastmoneyFundResponse struct {
	Datas []struct {
		FCODE     string `json:"FCODE"`
		SHORTNAME string `json:"SHORTNAME"`
		FTYPE     string `json:"FTYPE"`
		FSRQ      string `json:"FSRQ"`
		NAV       string `json:"NAV"`
		SYL_Z     string `json:"SYL_Z"`
		SYL_Y     string `json:"SYL_Y"`
		SYL_3Y    string `json:"SYL_3Y"`
		SYL_6Y    string `json:"SYL_6Y"`
		SYL_JN    string `json:"SYL_JN"`
		SYL_1N    string `json:"SYL_1N"`
		SYL_2N    string `json:"SYL_2N"`
		SYL_3N    string `json:"SYL_3N"`
		SYL_LN    string `json:"SYL_LN"`
	} `json:"Datas"`
}
