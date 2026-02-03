package crawler

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"regexp"
	"strings"
	"unicode/utf8"

	"golang.org/x/net/html"
	"golang.org/x/net/html/charset"
	"golang.org/x/text/encoding"
	"golang.org/x/text/encoding/htmlindex"
	"golang.org/x/text/transform"
)

// WebpageFetcher 网页内容获取器接口
type WebpageFetcher interface {
	// Fetch 获取网页内容并提取主要文本
	// url: 网页 URL
	// 返回: 提取的文本内容
	Fetch(ctx context.Context, url string) (string, error)
}

// webpageFetcherImpl 网页内容获取器实现
type webpageFetcherImpl struct {
	client  *HTTPClient
	breaker *CircuitBreaker
}

// NewWebpageFetcher 创建网页内容获取器
func NewWebpageFetcher(client *HTTPClient, breaker *CircuitBreaker) WebpageFetcher {
	return &webpageFetcherImpl{
		client:  client,
		breaker: breaker,
	}
}

// Fetch 获取网页内容并提取主要文本
func (f *webpageFetcherImpl) Fetch(ctx context.Context, url string) (string, error) {
	var content string

	err := f.breaker.Execute(func() error {
		headers := map[string]string{
			"Accept":          "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
			"Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
			"Accept-Charset":  "utf-8, gb2312, gbk, gb18030, big5",
		}

		data, err := f.client.Get(ctx, url, headers)
		if err != nil {
			return fmt.Errorf("fetch webpage failed: %w", err)
		}

		// 检测并转换字符编码
		utf8Data, err := convertToUTF8(data)
		if err != nil {
			// 如果编码转换失败，尝试直接使用原始数据
			utf8Data = data
		}

		// 提取主要文本内容
		content, err = extractMainContent(string(utf8Data))
		if err != nil {
			return fmt.Errorf("extract content failed: %w", err)
		}

		return nil
	})

	return content, err
}

// convertToUTF8 将内容转换为 UTF-8 编码
func convertToUTF8(data []byte) ([]byte, error) {
	// 如果已经是有效的 UTF-8，直接返回
	if utf8.Valid(data) {
		return data, nil
	}

	// 尝试从 HTML 中检测编码
	enc, _, _ := charset.DetermineEncoding(data, "text/html")
	if enc != nil && enc != encoding.Nop {
		reader := transform.NewReader(bytes.NewReader(data), enc.NewDecoder())
		decoded, err := io.ReadAll(reader)
		if err == nil && utf8.Valid(decoded) {
			return decoded, nil
		}
	}

	// 尝试常见的中文编码
	encodings := []string{"gbk", "gb2312", "gb18030", "big5"}
	for _, encName := range encodings {
		enc, err := htmlindex.Get(encName)
		if err != nil {
			continue
		}
		reader := transform.NewReader(bytes.NewReader(data), enc.NewDecoder())
		decoded, err := io.ReadAll(reader)
		if err == nil && utf8.Valid(decoded) {
			return decoded, nil
		}
	}

	// 如果所有尝试都失败，返回原始数据
	return data, nil
}

// extractMainContent 从 HTML 中提取主要文本内容
func extractMainContent(htmlContent string) (string, error) {
	doc, err := html.Parse(strings.NewReader(htmlContent))
	if err != nil {
		return "", fmt.Errorf("parse HTML failed: %w", err)
	}

	var textBuilder strings.Builder

	// 递归遍历 DOM 树，提取文本
	var extractText func(*html.Node)
	extractText = func(n *html.Node) {
		// 跳过不需要的标签
		if n.Type == html.ElementNode {
			tagName := strings.ToLower(n.Data)
			if shouldSkipTag(tagName) {
				return
			}
		}

		// 提取文本节点
		if n.Type == html.TextNode {
			text := strings.TrimSpace(n.Data)
			if text != "" {
				textBuilder.WriteString(text)
				textBuilder.WriteString(" ")
			}
		}

		// 在块级元素后添加换行
		if n.Type == html.ElementNode && isBlockElement(n.Data) {
			if textBuilder.Len() > 0 {
				textBuilder.WriteString("\n")
			}
		}

		// 递归处理子节点
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			extractText(c)
		}

		// 在块级元素结束后添加换行
		if n.Type == html.ElementNode && isBlockElement(n.Data) {
			textBuilder.WriteString("\n")
		}
	}

	extractText(doc)

	// 清理和格式化文本
	content := cleanExtractedText(textBuilder.String())

	return content, nil
}

// shouldSkipTag 判断是否应该跳过该标签
func shouldSkipTag(tagName string) bool {
	skipTags := map[string]bool{
		"script":   true,
		"style":    true,
		"noscript": true,
		"iframe":   true,
		"object":   true,
		"embed":    true,
		"applet":   true,
		"nav":      true,
		"header":   true,
		"footer":   true,
		"aside":    true,
		"form":     true,
		"input":    true,
		"button":   true,
		"select":   true,
		"textarea": true,
		"svg":      true,
		"canvas":   true,
		"video":    true,
		"audio":    true,
		"map":      true,
		"area":     true,
		"template": true,
		"head":     true,
		"meta":     true,
		"link":     true,
		"base":     true,
		"comment":  true,
	}
	return skipTags[tagName]
}

// isBlockElement 判断是否是块级元素
func isBlockElement(tagName string) bool {
	blockElements := map[string]bool{
		"div":        true,
		"p":          true,
		"h1":         true,
		"h2":         true,
		"h3":         true,
		"h4":         true,
		"h5":         true,
		"h6":         true,
		"article":    true,
		"section":    true,
		"main":       true,
		"blockquote": true,
		"pre":        true,
		"ul":         true,
		"ol":         true,
		"li":         true,
		"table":      true,
		"tr":         true,
		"td":         true,
		"th":         true,
		"br":         true,
		"hr":         true,
		"dl":         true,
		"dt":         true,
		"dd":         true,
		"figure":     true,
		"figcaption": true,
		"address":    true,
	}
	return blockElements[strings.ToLower(tagName)]
}

// cleanExtractedText 清理提取的文本
func cleanExtractedText(text string) string {
	// 移除多余的空白字符
	spaceRegex := regexp.MustCompile(`[ \t]+`)
	text = spaceRegex.ReplaceAllString(text, " ")

	// 移除多余的换行符（保留最多两个连续换行）
	newlineRegex := regexp.MustCompile(`\n{3,}`)
	text = newlineRegex.ReplaceAllString(text, "\n\n")

	// 移除行首行尾的空白
	lines := strings.Split(text, "\n")
	var cleanedLines []string
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed != "" {
			cleanedLines = append(cleanedLines, trimmed)
		}
	}

	// 重新组合文本
	text = strings.Join(cleanedLines, "\n")

	// 移除常见的无意义内容
	text = removeBoilerplate(text)

	// 最终修剪
	text = strings.TrimSpace(text)

	// 限制最大长度（防止内容过长）
	maxLength := 50000 // 约 50KB 文本
	if len(text) > maxLength {
		text = text[:maxLength] + "..."
	}

	return text
}

// removeBoilerplate 移除常见的模板内容
func removeBoilerplate(text string) string {
	// 移除常见的版权声明、广告等模板内容
	// 注意：更具体的模式应该放在前面，通用模式放在后面
	boilerplatePatterns := []string{
		`(?i)copyright\s*©?\s*\d{4}`,
		`(?i)all\s+rights\s+reserved`,
		`(?i)版权所有`,
		`(?i)备案号[：:]\s*[\w-]+`,
		// 省份特定的ICP备案号模式（放在通用模式之前）
		`(?i)京ICP[备证]\d+号`,
		`(?i)粤ICP备\d+号`,
		`(?i)沪ICP备\d+号`,
		`(?i)浙ICP备\d+号`,
		`(?i)苏ICP备\d+号`,
		`(?i)鲁ICP备\d+号`,
		`(?i)闽ICP备\d+号`,
		`(?i)川ICP备\d+号`,
		`(?i)皖ICP备\d+号`,
		`(?i)赣ICP备\d+号`,
		`(?i)湘ICP备\d+号`,
		`(?i)鄂ICP备\d+号`,
		`(?i)豫ICP备\d+号`,
		`(?i)冀ICP备\d+号`,
		`(?i)晋ICP备\d+号`,
		`(?i)陕ICP备\d+号`,
		`(?i)甘ICP备\d+号`,
		`(?i)青ICP备\d+号`,
		`(?i)黑ICP备\d+号`,
		`(?i)吉ICP备\d+号`,
		`(?i)辽ICP备\d+号`,
		`(?i)津ICP备\d+号`,
		`(?i)渝ICP备\d+号`,
		`(?i)桂ICP备\d+号`,
		`(?i)琼ICP备\d+号`,
		`(?i)云ICP备\d+号`,
		`(?i)贵ICP备\d+号`,
		`(?i)藏ICP备\d+号`,
		`(?i)新ICP备\d+号`,
		`(?i)宁ICP备\d+号`,
		`(?i)蒙ICP备\d+号`,
		// 通用ICP备案号模式（放在最后作为兜底）
		`(?i)ICP备\d+号`,
	}

	for _, pattern := range boilerplatePatterns {
		re := regexp.MustCompile(pattern)
		text = re.ReplaceAllString(text, "")
	}

	return text
}
