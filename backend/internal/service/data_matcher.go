package service

import (
	"strings"
	"unicode"
)

// DataModule 数据模块类型
type DataModule string

const (
	ModuleMarketIndices  DataModule = "market_indices"
	ModulePreciousMetals DataModule = "precious_metals"
	ModuleNews           DataModule = "news"
	ModuleSectors        DataModule = "sectors"
	ModuleFunds          DataModule = "funds"
	ModuleVolumeTrend    DataModule = "volume_trend"
	ModuleMinuteData     DataModule = "minute_data"
)

// AllDataModules 所有数据模块列表
var AllDataModules = []DataModule{
	ModuleMarketIndices,
	ModulePreciousMetals,
	ModuleNews,
	ModuleSectors,
	ModuleFunds,
	ModuleVolumeTrend,
	ModuleMinuteData,
}

// DataMatcher 数据模块匹配器接口
type DataMatcher interface {
	// Match 根据用户问题匹配相关数据模块
	// question: 用户问题
	// 返回: 匹配的数据模块名称列表
	Match(question string) []DataModule
}

// moduleKeywords 模块关键词映射
type moduleKeywords struct {
	module   DataModule
	keywords []string
}

// dataMatcher 数据模块匹配器实现
type dataMatcher struct {
	keywordMap []moduleKeywords
}

// NewDataMatcher 创建数据模块匹配器
func NewDataMatcher() DataMatcher {
	return &dataMatcher{
		keywordMap: initKeywordMap(),
	}
}

// initKeywordMap 初始化关键词映射
func initKeywordMap() []moduleKeywords {
	return []moduleKeywords{
		{
			module: ModuleMarketIndices,
			keywords: []string{
				// 中文关键词
				"指数", "大盘", "上证", "深证", "创业板", "恒生", "纳斯达克", "道琼斯",
				"标普", "沪深", "股市", "市场", "行情", "走势", "涨跌", "点位",
				"a股", "美股", "港股", "股指", "综指", "成分股", "蓝筹",
				// 英文关键词
				"index", "indices", "market", "shanghai", "shenzhen", "nasdaq",
				"dow", "s&p", "hang seng", "stock market", "bull", "bear",
			},
		},
		{
			module: ModulePreciousMetals,
			keywords: []string{
				// 中文关键词
				"黄金", "白银", "贵金属", "金价", "银价", "金投", "现货金",
				"现货银", "金条", "金饰", "周大福", "中国黄金", "避险",
				// 英文关键词
				"gold", "silver", "precious metal", "bullion", "xau", "xag",
				"spot gold", "spot silver", "gold price", "silver price",
			},
		},
		{
			module: ModuleNews,
			keywords: []string{
				// 中文关键词
				"快讯", "新闻", "消息", "资讯", "公告", "利好", "利空",
				"政策", "事件", "动态", "热点", "头条", "最新", "今日",
				"发生", "什么事", "怎么了", "为什么", "原因",
				// 英文关键词
				"news", "flash", "announcement", "headline", "breaking",
				"update", "latest", "today", "what happened", "why",
			},
		},
		{
			module: ModuleSectors,
			keywords: []string{
				// 中文关键词
				"板块", "行业", "概念", "题材", "科技", "医药", "消费",
				"金融", "能源", "新能源", "半导体", "芯片", "人工智能",
				"ai", "军工", "白酒", "银行", "保险", "证券", "地产",
				"汽车", "光伏", "锂电", "储能", "资金流", "主力",
				"龙头", "热门板块", "强势板块",
				// 英文关键词
				"sector", "industry", "concept", "theme", "tech", "healthcare",
				"consumer", "finance", "energy", "semiconductor", "chip",
				"artificial intelligence", "defense", "banking", "insurance",
				"real estate", "auto", "solar", "battery", "fund flow",
			},
		},
		{
			module: ModuleFunds,
			keywords: []string{
				// 中文关键词
				"基金", "自选", "持仓", "净值", "估值", "收益", "回报",
				"定投", "赎回", "申购", "基金经理", "规模", "仓位",
				"我的基金", "持有", "买入", "卖出", "调仓",
				// 英文关键词
				"fund", "portfolio", "holding", "nav", "valuation", "return",
				"yield", "investment", "my fund", "position", "buy", "sell",
			},
		},
		{
			module: ModuleVolumeTrend,
			keywords: []string{
				// 中文关键词
				"成交量", "成交额", "交易量", "量能", "放量", "缩量",
				"天量", "地量", "换手", "活跃度", "交易活跃",
				"上交所", "深交所", "北交所", "两市",
				// 英文关键词
				"volume", "turnover", "trading volume", "liquidity",
				"high volume", "low volume", "activity", "exchange",
			},
		},
		{
			module: ModuleMinuteData,
			keywords: []string{
				// 中文关键词
				"分时", "分钟", "实时", "盘中", "今天", "当日",
				"开盘", "收盘", "盘面", "走势图", "k线", "日内",
				// 英文关键词
				"minute", "intraday", "real-time", "realtime", "today",
				"opening", "closing", "chart", "tick", "live",
			},
		},
	}
}

// Match 根据用户问题匹配相关数据模块
func (m *dataMatcher) Match(question string) []DataModule {
	if question == "" {
		return nil
	}

	// 转换为小写进行匹配
	lowerQuestion := strings.ToLower(question)

	// 存储匹配结果和匹配分数
	matchScores := make(map[DataModule]int)

	// 遍历所有模块的关键词
	for _, mk := range m.keywordMap {
		score := 0
		for _, keyword := range mk.keywords {
			if containsKeyword(lowerQuestion, strings.ToLower(keyword)) {
				score++
			}
		}
		if score > 0 {
			matchScores[mk.module] = score
		}
	}

	// 如果没有匹配到任何模块，返回默认模块（快讯和板块）
	if len(matchScores) == 0 {
		return getDefaultModules(lowerQuestion)
	}

	// 按匹配分数排序返回结果
	return sortModulesByScore(matchScores)
}

// containsKeyword 检查问题是否包含关键词
func containsKeyword(question, keyword string) bool {
	// 直接包含检查
	if strings.Contains(question, keyword) {
		return true
	}

	// 对于英文关键词，检查单词边界
	if isASCII(keyword) {
		words := strings.Fields(question)
		for _, word := range words {
			// 移除标点符号
			cleanWord := strings.TrimFunc(word, func(r rune) bool {
				return !unicode.IsLetter(r) && !unicode.IsNumber(r)
			})
			if strings.EqualFold(cleanWord, keyword) {
				return true
			}
		}
	}

	return false
}

// isASCII 检查字符串是否全为 ASCII 字符
func isASCII(s string) bool {
	for _, r := range s {
		if r > unicode.MaxASCII {
			return false
		}
	}
	return true
}

// getDefaultModules 获取默认模块（当没有匹配到任何关键词时）
func getDefaultModules(question string) []DataModule {
	// 检查是否是一般性问题
	generalKeywords := []string{
		"怎么样", "如何", "建议", "分析", "看法", "观点", "预测",
		"how", "what", "should", "recommend", "analysis", "opinion",
	}

	for _, keyword := range generalKeywords {
		if strings.Contains(question, keyword) {
			// 返回综合数据模块
			return []DataModule{
				ModuleNews,
				ModuleSectors,
				ModuleMarketIndices,
			}
		}
	}

	// 默认返回快讯和市场指数
	return []DataModule{
		ModuleNews,
		ModuleMarketIndices,
	}
}

// sortModulesByScore 按匹配分数排序模块
func sortModulesByScore(scores map[DataModule]int) []DataModule {
	// 创建结果切片
	result := make([]DataModule, 0, len(scores))
	for module := range scores {
		result = append(result, module)
	}

	// 按分数降序排序
	for i := 0; i < len(result)-1; i++ {
		for j := i + 1; j < len(result); j++ {
			if scores[result[i]] < scores[result[j]] {
				result[i], result[j] = result[j], result[i]
			}
		}
	}

	return result
}

// GetModuleDisplayName 获取模块显示名称
func GetModuleDisplayName(module DataModule) string {
	switch module {
	case ModuleMarketIndices:
		return "市场指数"
	case ModulePreciousMetals:
		return "贵金属"
	case ModuleNews:
		return "快讯"
	case ModuleSectors:
		return "板块"
	case ModuleFunds:
		return "基金"
	case ModuleVolumeTrend:
		return "成交量"
	case ModuleMinuteData:
		return "分时数据"
	default:
		return string(module)
	}
}

// GetModuleDescription 获取模块描述
func GetModuleDescription(module DataModule) string {
	switch module {
	case ModuleMarketIndices:
		return "全球主要市场指数数据，包括上证、深证、恒生、纳斯达克等"
	case ModulePreciousMetals:
		return "贵金属实时价格，包括黄金、白银等"
	case ModuleNews:
		return "A股市场7×24快讯，包含利好利空评价"
	case ModuleSectors:
		return "行业板块数据，包括涨跌幅和资金流向"
	case ModuleFunds:
		return "用户自选基金数据，包括估值和收益"
	case ModuleVolumeTrend:
		return "A股市场成交量趋势数据"
	case ModuleMinuteData:
		return "上证指数分时走势数据"
	default:
		return ""
	}
}
