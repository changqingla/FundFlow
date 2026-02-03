package service

import (
	"testing"
)

func TestNewDataMatcher(t *testing.T) {
	matcher := NewDataMatcher()
	if matcher == nil {
		t.Error("NewDataMatcher should return a non-nil matcher")
	}
}

func TestDataMatcher_Match_MarketIndices(t *testing.T) {
	matcher := NewDataMatcher()

	testCases := []struct {
		name     string
		question string
		expected DataModule
	}{
		{"Chinese - 指数", "今天大盘指数怎么样", ModuleMarketIndices},
		{"Chinese - 上证", "上证指数涨了多少", ModuleMarketIndices},
		{"Chinese - 纳斯达克", "纳斯达克最新行情", ModuleMarketIndices},
		{"Chinese - 股市", "股市走势如何", ModuleMarketIndices},
		{"English - index", "What is the market index today", ModuleMarketIndices},
		{"English - nasdaq", "How is nasdaq performing", ModuleMarketIndices},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			modules := matcher.Match(tc.question)
			if !containsModule(modules, tc.expected) {
				t.Errorf("Expected %s to match %s, got %v", tc.question, tc.expected, modules)
			}
		})
	}
}

func TestDataMatcher_Match_PreciousMetals(t *testing.T) {
	matcher := NewDataMatcher()

	testCases := []struct {
		name     string
		question string
		expected DataModule
	}{
		{"Chinese - 黄金", "黄金价格多少", ModulePreciousMetals},
		{"Chinese - 白银", "白银今天涨了吗", ModulePreciousMetals},
		{"Chinese - 贵金属", "贵金属行情怎么样", ModulePreciousMetals},
		{"Chinese - 金价", "今日金价", ModulePreciousMetals},
		{"English - gold", "What is the gold price", ModulePreciousMetals},
		{"English - silver", "Silver price today", ModulePreciousMetals},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			modules := matcher.Match(tc.question)
			if !containsModule(modules, tc.expected) {
				t.Errorf("Expected %s to match %s, got %v", tc.question, tc.expected, modules)
			}
		})
	}
}

func TestDataMatcher_Match_News(t *testing.T) {
	matcher := NewDataMatcher()

	testCases := []struct {
		name     string
		question string
		expected DataModule
	}{
		{"Chinese - 快讯", "最新快讯有哪些", ModuleNews},
		{"Chinese - 新闻", "今天有什么新闻", ModuleNews},
		{"Chinese - 利好", "有什么利好消息", ModuleNews},
		{"Chinese - 为什么", "股市为什么跌了", ModuleNews},
		{"English - news", "What is the latest news", ModuleNews},
		{"English - headline", "Today's headline", ModuleNews},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			modules := matcher.Match(tc.question)
			if !containsModule(modules, tc.expected) {
				t.Errorf("Expected %s to match %s, got %v", tc.question, tc.expected, modules)
			}
		})
	}
}

func TestDataMatcher_Match_Sectors(t *testing.T) {
	matcher := NewDataMatcher()

	testCases := []struct {
		name     string
		question string
		expected DataModule
	}{
		{"Chinese - 板块", "哪个板块涨得好", ModuleSectors},
		{"Chinese - 行业", "科技行业怎么样", ModuleSectors},
		{"Chinese - 半导体", "半导体概念股", ModuleSectors},
		{"Chinese - 资金流", "主力资金流向", ModuleSectors},
		{"English - sector", "Which sector is hot", ModuleSectors},
		{"English - industry", "Tech industry performance", ModuleSectors},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			modules := matcher.Match(tc.question)
			if !containsModule(modules, tc.expected) {
				t.Errorf("Expected %s to match %s, got %v", tc.question, tc.expected, modules)
			}
		})
	}
}

func TestDataMatcher_Match_Funds(t *testing.T) {
	matcher := NewDataMatcher()

	testCases := []struct {
		name     string
		question string
		expected DataModule
	}{
		{"Chinese - 基金", "我的基金收益怎么样", ModuleFunds},
		{"Chinese - 持仓", "持仓情况如何", ModuleFunds},
		{"Chinese - 净值", "基金净值多少", ModuleFunds},
		{"Chinese - 估值", "今天估值涨了吗", ModuleFunds},
		{"English - fund", "How is my fund doing", ModuleFunds},
		{"English - portfolio", "My portfolio performance", ModuleFunds},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			modules := matcher.Match(tc.question)
			if !containsModule(modules, tc.expected) {
				t.Errorf("Expected %s to match %s, got %v", tc.question, tc.expected, modules)
			}
		})
	}
}

func TestDataMatcher_Match_VolumeTrend(t *testing.T) {
	matcher := NewDataMatcher()

	testCases := []struct {
		name     string
		question string
		expected DataModule
	}{
		{"Chinese - 成交量", "今天成交量多少", ModuleVolumeTrend},
		{"Chinese - 成交额", "两市成交额", ModuleVolumeTrend},
		{"Chinese - 量能", "量能怎么样", ModuleVolumeTrend},
		{"Chinese - 放量", "是否放量", ModuleVolumeTrend},
		{"English - volume", "What is the trading volume", ModuleVolumeTrend},
		{"English - turnover", "Market turnover today", ModuleVolumeTrend},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			modules := matcher.Match(tc.question)
			if !containsModule(modules, tc.expected) {
				t.Errorf("Expected %s to match %s, got %v", tc.question, tc.expected, modules)
			}
		})
	}
}

func TestDataMatcher_Match_MinuteData(t *testing.T) {
	matcher := NewDataMatcher()

	testCases := []struct {
		name     string
		question string
		expected DataModule
	}{
		{"Chinese - 分时", "分时走势图", ModuleMinuteData},
		{"Chinese - 实时", "实时行情", ModuleMinuteData},
		{"Chinese - 盘中", "盘中表现", ModuleMinuteData},
		{"Chinese - 日内", "日内走势", ModuleMinuteData},
		{"English - minute", "Minute chart", ModuleMinuteData},
		{"English - intraday", "Intraday performance", ModuleMinuteData},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			modules := matcher.Match(tc.question)
			if !containsModule(modules, tc.expected) {
				t.Errorf("Expected %s to match %s, got %v", tc.question, tc.expected, modules)
			}
		})
	}
}

func TestDataMatcher_Match_MultipleModules(t *testing.T) {
	matcher := NewDataMatcher()

	testCases := []struct {
		name     string
		question string
		expected []DataModule
	}{
		{
			"Market and News",
			"今天股市为什么跌了",
			[]DataModule{ModuleMarketIndices, ModuleNews},
		},
		{
			"Sectors and Funds",
			"科技板块的基金表现如何",
			[]DataModule{ModuleSectors, ModuleFunds},
		},
		{
			"Gold and Market",
			"黄金和股市的关系",
			[]DataModule{ModulePreciousMetals, ModuleMarketIndices},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			modules := matcher.Match(tc.question)
			for _, expected := range tc.expected {
				if !containsModule(modules, expected) {
					t.Errorf("Expected %s to match %s, got %v", tc.question, expected, modules)
				}
			}
		})
	}
}

func TestDataMatcher_Match_EmptyQuestion(t *testing.T) {
	matcher := NewDataMatcher()

	modules := matcher.Match("")
	if modules != nil {
		t.Errorf("Expected nil for empty question, got %v", modules)
	}
}

func TestDataMatcher_Match_DefaultModules(t *testing.T) {
	matcher := NewDataMatcher()

	// 测试没有明确关键词的问题
	testCases := []struct {
		name     string
		question string
	}{
		{"General question", "你好"},
		{"Random text", "随便聊聊"},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			modules := matcher.Match(tc.question)
			// 应该返回默认模块
			if len(modules) == 0 {
				t.Errorf("Expected default modules for %s, got empty", tc.question)
			}
		})
	}
}

func TestDataMatcher_Match_CaseInsensitive(t *testing.T) {
	matcher := NewDataMatcher()

	testCases := []struct {
		name     string
		question string
		expected DataModule
	}{
		{"Uppercase", "GOLD PRICE", ModulePreciousMetals},
		{"Mixed case", "NasDaq Index", ModuleMarketIndices},
		{"Lowercase", "silver price", ModulePreciousMetals},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			modules := matcher.Match(tc.question)
			if !containsModule(modules, tc.expected) {
				t.Errorf("Expected %s to match %s, got %v", tc.question, tc.expected, modules)
			}
		})
	}
}

func TestGetModuleDisplayName(t *testing.T) {
	testCases := []struct {
		module   DataModule
		expected string
	}{
		{ModuleMarketIndices, "市场指数"},
		{ModulePreciousMetals, "贵金属"},
		{ModuleNews, "快讯"},
		{ModuleSectors, "板块"},
		{ModuleFunds, "基金"},
		{ModuleVolumeTrend, "成交量"},
		{ModuleMinuteData, "分时数据"},
		{DataModule("unknown"), "unknown"},
	}

	for _, tc := range testCases {
		t.Run(string(tc.module), func(t *testing.T) {
			result := GetModuleDisplayName(tc.module)
			if result != tc.expected {
				t.Errorf("Expected %s, got %s", tc.expected, result)
			}
		})
	}
}

func TestGetModuleDescription(t *testing.T) {
	// 测试所有模块都有描述
	for _, module := range AllDataModules {
		desc := GetModuleDescription(module)
		if desc == "" {
			t.Errorf("Module %s should have a description", module)
		}
	}

	// 测试未知模块返回空字符串
	desc := GetModuleDescription(DataModule("unknown"))
	if desc != "" {
		t.Errorf("Unknown module should return empty description, got %s", desc)
	}
}

// containsModule 检查模块列表是否包含指定模块
func containsModule(modules []DataModule, target DataModule) bool {
	for _, m := range modules {
		if m == target {
			return true
		}
	}
	return false
}
