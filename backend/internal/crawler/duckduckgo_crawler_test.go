package crawler

import (
	"testing"

	"fund-analyzer/internal/model"
)

func TestParseSearchResults(t *testing.T) {
	// 模拟 DuckDuckGo HTML 搜索结果
	htmlContent := `
<!DOCTYPE html>
<html>
<head><title>DuckDuckGo</title></head>
<body>
<div class="results">
	<div class="result results_links results_links_deep web-result">
		<div class="links_main links_deep result__body">
			<h2 class="result__title">
				<a rel="nofollow" class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fnews%2F1">
					测试新闻标题 1
				</a>
			</h2>
			<a class="result__snippet" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fnews%2F1">
				这是测试新闻 1 的摘要内容，包含一些关键信息。
			</a>
		</div>
	</div>
	<div class="result results_links results_links_deep web-result">
		<div class="links_main links_deep result__body">
			<h2 class="result__title">
				<a rel="nofollow" class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fnews%2F2">
					测试新闻标题 2
				</a>
			</h2>
			<a class="result__snippet" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fnews%2F2">
				这是测试新闻 2 的摘要内容。
			</a>
		</div>
	</div>
	<div class="result result--ad">
		<div class="links_main links_deep result__body">
			<h2 class="result__title">
				<a rel="nofollow" class="result__a" href="https://ad.example.com">
					广告标题
				</a>
			</h2>
		</div>
	</div>
</div>
</body>
</html>
`

	results, err := parseSearchResults(htmlContent, 10)
	if err != nil {
		t.Fatalf("parseSearchResults failed: %v", err)
	}

	// 应该有 2 个结果（广告被过滤）
	if len(results) != 2 {
		t.Errorf("expected 2 results, got %d", len(results))
	}

	// 验证第一个结果
	if len(results) > 0 {
		if results[0].Title != "测试新闻标题 1" {
			t.Errorf("expected title '测试新闻标题 1', got '%s'", results[0].Title)
		}
		if results[0].URL != "https://example.com/news/1" {
			t.Errorf("expected URL 'https://example.com/news/1', got '%s'", results[0].URL)
		}
		if results[0].Snippet == "" {
			t.Error("expected non-empty snippet")
		}
	}

	// 验证第二个结果
	if len(results) > 1 {
		if results[1].Title != "测试新闻标题 2" {
			t.Errorf("expected title '测试新闻标题 2', got '%s'", results[1].Title)
		}
		if results[1].URL != "https://example.com/news/2" {
			t.Errorf("expected URL 'https://example.com/news/2', got '%s'", results[1].URL)
		}
	}
}

func TestParseSearchResults_MaxCount(t *testing.T) {
	// 模拟多个搜索结果
	htmlContent := `
<!DOCTYPE html>
<html>
<body>
<div class="results">
	<div class="result">
		<a class="result__a" href="https://example.com/1">标题 1</a>
		<a class="result__snippet">摘要 1</a>
	</div>
	<div class="result">
		<a class="result__a" href="https://example.com/2">标题 2</a>
		<a class="result__snippet">摘要 2</a>
	</div>
	<div class="result">
		<a class="result__a" href="https://example.com/3">标题 3</a>
		<a class="result__snippet">摘要 3</a>
	</div>
</div>
</body>
</html>
`

	// 限制只返回 2 个结果
	results, err := parseSearchResults(htmlContent, 2)
	if err != nil {
		t.Fatalf("parseSearchResults failed: %v", err)
	}

	if len(results) > 2 {
		t.Errorf("expected at most 2 results, got %d", len(results))
	}
}

func TestExtractRealURL(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "DuckDuckGo redirect URL",
			input:    "//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fnews%2F1&rut=abc",
			expected: "https://example.com/news/1",
		},
		{
			name:     "DuckDuckGo redirect URL without extra params",
			input:    "//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fpath",
			expected: "https://example.com/path",
		},
		{
			name:     "Direct URL",
			input:    "https://example.com/direct",
			expected: "https://example.com/direct",
		},
		{
			name:     "Protocol-relative URL",
			input:    "//example.com/path",
			expected: "https://example.com/path",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := extractRealURL(tt.input)
			if result != tt.expected {
				t.Errorf("extractRealURL(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestCleanText(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "Multiple spaces",
			input:    "hello    world",
			expected: "hello world",
		},
		{
			name:     "Newlines and tabs",
			input:    "hello\n\t\tworld",
			expected: "hello world",
		},
		{
			name:     "Leading and trailing spaces",
			input:    "  hello world  ",
			expected: "hello world",
		},
		{
			name:     "Mixed whitespace",
			input:    "\n  hello   \t  world  \n",
			expected: "hello world",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := cleanText(tt.input)
			if result != tt.expected {
				t.Errorf("cleanText(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestContainsClass(t *testing.T) {
	tests := []struct {
		name      string
		classAttr string
		className string
		expected  bool
	}{
		{
			name:      "Single class match",
			classAttr: "result",
			className: "result",
			expected:  true,
		},
		{
			name:      "Multiple classes with match",
			classAttr: "result results_links web-result",
			className: "result",
			expected:  true,
		},
		{
			name:      "No match",
			classAttr: "result results_links",
			className: "result--ad",
			expected:  false,
		},
		{
			name:      "Partial match should not match",
			classAttr: "result--ad",
			className: "result",
			expected:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := containsClass(tt.classAttr, tt.className)
			if result != tt.expected {
				t.Errorf("containsClass(%q, %q) = %v, want %v", tt.classAttr, tt.className, result, tt.expected)
			}
		})
	}
}

func TestSearchResult_Model(t *testing.T) {
	// 验证 SearchResult 模型结构
	result := model.SearchResult{
		Title:   "Test Title",
		URL:     "https://example.com",
		Snippet: "Test snippet",
	}

	if result.Title != "Test Title" {
		t.Errorf("expected Title 'Test Title', got '%s'", result.Title)
	}
	if result.URL != "https://example.com" {
		t.Errorf("expected URL 'https://example.com', got '%s'", result.URL)
	}
	if result.Snippet != "Test snippet" {
		t.Errorf("expected Snippet 'Test snippet', got '%s'", result.Snippet)
	}
}
