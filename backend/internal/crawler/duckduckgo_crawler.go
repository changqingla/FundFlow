package crawler

import (
	"context"
	"fmt"
	"net/url"
	"regexp"
	"strings"

	"fund-analyzer/internal/model"

	"golang.org/x/net/html"
)

const (
	duckduckgoBaseURL = "https://html.duckduckgo.com/html/"
)

// DuckDuckGoCrawler DuckDuckGo 搜索爬虫接口
type DuckDuckGoCrawler interface {
	Search(ctx context.Context, query string, count int) ([]model.SearchResult, error)
}

// duckDuckGoCrawlerImpl DuckDuckGo 搜索爬虫实现
type duckDuckGoCrawlerImpl struct {
	client  *HTTPClient
	breaker *CircuitBreaker
}

// NewDuckDuckGoCrawler 创建 DuckDuckGo 搜索爬虫
func NewDuckDuckGoCrawler(client *HTTPClient, breaker *CircuitBreaker) DuckDuckGoCrawler {
	return &duckDuckGoCrawlerImpl{
		client:  client,
		breaker: breaker,
	}
}

// Search 搜索新闻
// query: 搜索关键词
// count: 返回结果数量（最多返回 count 条结果）
func (c *duckDuckGoCrawlerImpl) Search(ctx context.Context, query string, count int) ([]model.SearchResult, error) {
	if count <= 0 {
		count = 10
	}

	var results []model.SearchResult

	err := c.breaker.Execute(func() error {
		// 构建搜索 URL，使用 POST 请求
		searchURL := duckduckgoBaseURL

		// 构建表单数据
		formData := url.Values{}
		formData.Set("q", query)
		formData.Set("b", "") // 起始位置
		formData.Set("kl", "cn-zh") // 中国区域，中文

		headers := map[string]string{
			"Content-Type": "application/x-www-form-urlencoded",
			"Referer":      "https://duckduckgo.com/",
			"Accept":       "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
			"Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
		}

		data, err := c.client.Post(ctx, searchURL, strings.NewReader(formData.Encode()), headers)
		if err != nil {
			return fmt.Errorf("search request failed: %w", err)
		}

		// 解析 HTML 响应
		results, err = parseSearchResults(string(data), count)
		if err != nil {
			return fmt.Errorf("parse search results failed: %w", err)
		}

		return nil
	})

	return results, err
}

// parseSearchResults 解析 DuckDuckGo HTML 搜索结果
func parseSearchResults(htmlContent string, maxCount int) ([]model.SearchResult, error) {
	var results []model.SearchResult

	doc, err := html.Parse(strings.NewReader(htmlContent))
	if err != nil {
		return nil, fmt.Errorf("parse HTML failed: %w", err)
	}

	// 查找所有搜索结果
	var findResults func(*html.Node)
	findResults = func(n *html.Node) {
		if len(results) >= maxCount {
			return
		}

		// DuckDuckGo HTML 版本的搜索结果在 class="result" 的 div 中
		if n.Type == html.ElementNode && n.Data == "div" {
			for _, attr := range n.Attr {
				if attr.Key == "class" && containsClass(attr.Val, "result") && !containsClass(attr.Val, "result--ad") {
					result := extractResult(n)
					if result.Title != "" && result.URL != "" {
						results = append(results, result)
					}
					return
				}
			}
		}

		for c := n.FirstChild; c != nil; c = c.NextSibling {
			findResults(c)
		}
	}

	findResults(doc)

	return results, nil
}

// containsClass 检查 class 属性是否包含指定的类名
func containsClass(classAttr, className string) bool {
	classes := strings.Fields(classAttr)
	for _, c := range classes {
		if c == className {
			return true
		}
	}
	return false
}

// extractResult 从结果节点中提取搜索结果
func extractResult(n *html.Node) model.SearchResult {
	var result model.SearchResult

	var extract func(*html.Node)
	extract = func(node *html.Node) {
		if node.Type == html.ElementNode {
			// 提取标题和 URL（在 a.result__a 中）
			if node.Data == "a" {
				for _, attr := range node.Attr {
					if attr.Key == "class" && containsClass(attr.Val, "result__a") {
						// 获取 href
						for _, a := range node.Attr {
							if a.Key == "href" {
								result.URL = extractRealURL(a.Val)
								break
							}
						}
						// 获取标题文本
						result.Title = cleanText(getTextContent(node))
						return
					}
				}
			}

			// 提取摘要（在 a.result__snippet 中）
			if node.Data == "a" {
				for _, attr := range node.Attr {
					if attr.Key == "class" && containsClass(attr.Val, "result__snippet") {
						result.Snippet = cleanText(getTextContent(node))
						return
					}
				}
			}
		}

		for c := node.FirstChild; c != nil; c = c.NextSibling {
			extract(c)
		}
	}

	extract(n)

	return result
}

// extractRealURL 从 DuckDuckGo 重定向 URL 中提取真实 URL
func extractRealURL(ddgURL string) string {
	// DuckDuckGo 的链接格式可能是：
	// 1. //duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2F...
	// 2. 直接的 URL

	if strings.Contains(ddgURL, "uddg=") {
		// 解析 uddg 参数
		if idx := strings.Index(ddgURL, "uddg="); idx != -1 {
			encoded := ddgURL[idx+5:]
			// 处理可能的 & 后缀
			if ampIdx := strings.Index(encoded, "&"); ampIdx != -1 {
				encoded = encoded[:ampIdx]
			}
			decoded, err := url.QueryUnescape(encoded)
			if err == nil {
				return decoded
			}
		}
	}

	// 如果是相对 URL，添加协议
	if strings.HasPrefix(ddgURL, "//") {
		return "https:" + ddgURL
	}

	return ddgURL
}

// getTextContent 获取节点的文本内容
func getTextContent(n *html.Node) string {
	var text strings.Builder

	var extract func(*html.Node)
	extract = func(node *html.Node) {
		if node.Type == html.TextNode {
			text.WriteString(node.Data)
		}
		for c := node.FirstChild; c != nil; c = c.NextSibling {
			extract(c)
		}
	}

	extract(n)

	return text.String()
}

// cleanText 清理文本（去除多余空白）
func cleanText(s string) string {
	// 替换多个空白字符为单个空格
	re := regexp.MustCompile(`\s+`)
	s = re.ReplaceAllString(s, " ")
	return strings.TrimSpace(s)
}
