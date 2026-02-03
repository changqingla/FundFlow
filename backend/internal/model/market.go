package model

// ChangeStatus 涨跌状态
type ChangeStatus int

const (
	StatusDown ChangeStatus = -1 // 下跌
	StatusFlat ChangeStatus = 0  // 持平
	StatusUp   ChangeStatus = 1  // 上涨
)

// MarketIndex 市场指数
type MarketIndex struct {
	Name      string `json:"name"`
	Price     string `json:"price"`
	Change    string `json:"change"`
	IsUp      bool   `json:"isUp"`
	UpdatedAt string `json:"updatedAt"`
}

// PreciousMetal 贵金属
type PreciousMetal struct {
	Name       string  `json:"name"`
	Price      float64 `json:"price"`
	Change     float64 `json:"change"`
	ChangeRate string  `json:"changeRate"`
	Open       float64 `json:"open"`
	High       float64 `json:"high"`
	Low        float64 `json:"low"`
	Close      float64 `json:"close"`
	Unit       string  `json:"unit"`
	UpdatedAt  string  `json:"updatedAt"`
}

// GoldPrice 历史金价
type GoldPrice struct {
	Date           string `json:"date"`
	ChinaGoldPrice string `json:"chinaGoldPrice"`
	ChowTaiFook    string `json:"chowTaiFook"`
	ChinaChange    string `json:"chinaChange"`
	ChowChange     string `json:"chowChange"`
}

// VolumeTrend 成交量趋势
type VolumeTrend struct {
	Date        string `json:"date"`
	TotalVolume string `json:"totalVolume"`
	Shanghai    string `json:"shanghai"`
	Shenzhen    string `json:"shenzhen"`
	Beijing     string `json:"beijing"`
}

// MinuteData 分时数据
type MinuteData struct {
	Time       string `json:"time"`
	Price      string `json:"price"`
	Change     string `json:"change"`
	ChangeRate string `json:"changeRate"`
	Volume     string `json:"volume"`
	Amount     string `json:"amount"`
}

// Sector 行业板块
type Sector struct {
	ID               string `json:"id"`
	Name             string `json:"name"`
	ChangeRate       string `json:"changeRate"`
	MainNetInflow    string `json:"mainNetInflow"`
	MainInflowRatio  string `json:"mainInflowRatio"`
	SmallNetInflow   string `json:"smallNetInflow"`
	SmallInflowRatio string `json:"smallInflowRatio"`
}

// SectorFund 板块基金
type SectorFund struct {
	Code       string `json:"code"`
	Name       string `json:"name"`
	Type       string `json:"type"`
	Date       string `json:"date"`
	NetValue   string `json:"netValue"`
	Week1      string `json:"week1"`
	Month1     string `json:"month1"`
	Month3     string `json:"month3"`
	Month6     string `json:"month6"`
	YearToDate string `json:"yearToDate"`
	Year1      string `json:"year1"`
	Year2      string `json:"year2"`
	Year3      string `json:"year3"`
	SinceStart string `json:"sinceStart"`
}

// NewsItem 快讯
type NewsItem struct {
	ID          string       `json:"id"`
	Title       string       `json:"title"`
	Content     string       `json:"content"`
	Evaluate    string       `json:"evaluate"` // 利好/利空/空
	PublishTime int64        `json:"publishTime"`
	Entities    []NewsEntity `json:"entities"`
}

// NewsEntity 快讯关联股票
type NewsEntity struct {
	Code  string `json:"code"`
	Name  string `json:"name"`
	Ratio string `json:"ratio"`
}

// FundInfo 基金信息
type FundInfo struct {
	Code    string   `json:"code"`
	Name    string   `json:"name"`
	FundKey string   `json:"fundKey"`
	IsHold  bool     `json:"isHold"`
	Sectors []string `json:"sectors"`
}

// FundValuation 基金估值
type FundValuation struct {
	Code              string `json:"code"`
	Name              string `json:"name"`
	ValuationTime     string `json:"valuationTime"`
	Valuation         string `json:"valuation"`
	DayGrowth         string `json:"dayGrowth"`
	ConsecutiveDays   int    `json:"consecutiveDays"`
	ConsecutiveGrowth string `json:"consecutiveGrowth"`
	MonthlyStats      string `json:"monthlyStats"`
	MonthlyGrowth     string `json:"monthlyGrowth"`
}

// FundPoint 基金历史数据点
type FundPoint struct {
	Date  string `json:"date"`
	Value string `json:"value"`
}
