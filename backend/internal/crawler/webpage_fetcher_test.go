package crawler

import (
	"strings"
	"testing"
)

func TestShouldSkipTag(t *testing.T) {
	tests := []struct {
		tagName  string
		expected bool
	}{
		{"script", true},
		{"style", true},
		{"noscript", true},
		{"nav", true},
		{"header", true},
		{"footer", true},
		{"aside", true},
		{"form", true},
		{"head", true},
		{"div", false},
		{"p", false},
		{"article", false},
		{"span", false},
		{"a", false},
	}

	for _, tt := range tests {
		t.Run(tt.tagName, func(t *testing.T) {
			result := shouldSkipTag(tt.tagName)
			if result != tt.expected {
				t.Errorf("shouldSkipTag(%q) = %v, want %v", tt.tagName, result, tt.expected)
			}
		})
	}
}

func TestIsBlockElement(t *testing.T) {
	tests := []struct {
		tagName  string
		expected bool
	}{
		{"div", true},
		{"p", true},
		{"h1", true},
		{"h2", true},
		{"article", true},
		{"section", true},
		{"ul", true},
		{"li", true},
		{"br", true},
		{"span", false},
		{"a", false},
		{"strong", false},
		{"em", false},
	}

	for _, tt := range tests {
		t.Run(tt.tagName, func(t *testing.T) {
			result := isBlockElement(tt.tagName)
			if result != tt.expected {
				t.Errorf("isBlockElement(%q) = %v, want %v", tt.tagName, result, tt.expected)
			}
		})
	}
}

func TestCleanExtractedText(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "remove multiple spaces",
			input:    "hello    world",
			expected: "hello world",
		},
		{
			name:     "remove multiple newlines",
			input:    "hello\n\n\n\nworld",
			expected: "hello\nworld",
		},
		{
			name:     "trim whitespace",
			input:    "  hello world  ",
			expected: "hello world",
		},
		{
			name:     "remove empty lines",
			input:    "hello\n\n\nworld\n\n\ntest",
			expected: "hello\nworld\ntest",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := cleanExtractedText(tt.input)
			if result != tt.expected {
				t.Errorf("cleanExtractedText(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestExtractMainContent(t *testing.T) {
	tests := []struct {
		name        string
		html        string
		shouldHave  []string
		shouldNotHave []string
	}{
		{
			name: "basic text extraction",
			html: `<html><body><p>Hello World</p></body></html>`,
			shouldHave: []string{"Hello World"},
		},
		{
			name: "skip script tags",
			html: `<html><body><p>Hello</p><script>alert('test');</script><p>World</p></body></html>`,
			shouldHave:    []string{"Hello", "World"},
			shouldNotHave: []string{"alert", "test"},
		},
		{
			name: "skip style tags",
			html: `<html><body><p>Hello</p><style>.test { color: red; }</style><p>World</p></body></html>`,
			shouldHave:    []string{"Hello", "World"},
			shouldNotHave: []string{"color", "red"},
		},
		{
			name: "skip nav tags",
			html: `<html><body><nav><a href="/">Home</a></nav><article><p>Main Content</p></article></body></html>`,
			shouldHave:    []string{"Main Content"},
			shouldNotHave: []string{"Home"},
		},
		{
			name: "skip header and footer",
			html: `<html><body><header>Header Content</header><main><p>Main Content</p></main><footer>Footer Content</footer></body></html>`,
			shouldHave:    []string{"Main Content"},
			shouldNotHave: []string{"Header Content", "Footer Content"},
		},
		{
			name: "extract nested content",
			html: `<html><body><div><div><p>Nested <strong>Content</strong></p></div></div></body></html>`,
			shouldHave: []string{"Nested", "Content"},
		},
		{
			name: "handle multiple paragraphs",
			html: `<html><body><p>First paragraph</p><p>Second paragraph</p></body></html>`,
			shouldHave: []string{"First paragraph", "Second paragraph"},
		},
		{
			name: "skip form elements",
			html: `<html><body><p>Content</p><form><input type="text" value="test"/><button>Submit</button></form></body></html>`,
			shouldHave:    []string{"Content"},
			shouldNotHave: []string{"Submit"},
		},
		{
			name: "handle headings",
			html: `<html><body><h1>Title</h1><h2>Subtitle</h2><p>Content</p></body></html>`,
			shouldHave: []string{"Title", "Subtitle", "Content"},
		},
		{
			name: "handle lists",
			html: `<html><body><ul><li>Item 1</li><li>Item 2</li></ul></body></html>`,
			shouldHave: []string{"Item 1", "Item 2"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := extractMainContent(tt.html)
			if err != nil {
				t.Fatalf("extractMainContent() error = %v", err)
			}

			for _, s := range tt.shouldHave {
				if !strings.Contains(result, s) {
					t.Errorf("extractMainContent() result should contain %q, got %q", s, result)
				}
			}

			for _, s := range tt.shouldNotHave {
				if strings.Contains(result, s) {
					t.Errorf("extractMainContent() result should not contain %q, got %q", s, result)
				}
			}
		})
	}
}

func TestConvertToUTF8(t *testing.T) {
	tests := []struct {
		name     string
		input    []byte
		expected string
	}{
		{
			name:     "valid UTF-8",
			input:    []byte("Hello World 你好世界"),
			expected: "Hello World 你好世界",
		},
		{
			name:     "ASCII only",
			input:    []byte("Hello World"),
			expected: "Hello World",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := convertToUTF8(tt.input)
			if err != nil {
				t.Fatalf("convertToUTF8() error = %v", err)
			}
			if string(result) != tt.expected {
				t.Errorf("convertToUTF8() = %q, want %q", string(result), tt.expected)
			}
		})
	}
}

func TestRemoveBoilerplate(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "remove copyright",
			input:    "Content Copyright © 2024 Company",
			expected: "Content  Company",
		},
		{
			name:     "remove ICP",
			input:    "Content 京ICP备12345678号 More",
			expected: "Content  More",
		},
		{
			name:     "remove all rights reserved",
			input:    "Content All Rights Reserved",
			expected: "Content ",
		},
		{
			name:     "remove Chinese copyright",
			input:    "Content 版权所有 Company",
			expected: "Content  Company",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := removeBoilerplate(tt.input)
			if result != tt.expected {
				t.Errorf("removeBoilerplate(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestExtractMainContent_ComplexHTML(t *testing.T) {
	complexHTML := `
<!DOCTYPE html>
<html>
<head>
    <title>Test Page</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial; }
        .hidden { display: none; }
    </style>
    <script>
        console.log('This should not appear');
        function test() { return 'hidden'; }
    </script>
</head>
<body>
    <header>
        <nav>
            <a href="/">Home</a>
            <a href="/about">About</a>
        </nav>
    </header>
    
    <main>
        <article>
            <h1>Main Article Title</h1>
            <p>This is the first paragraph of the main content.</p>
            <p>This is the second paragraph with <strong>bold</strong> and <em>italic</em> text.</p>
            <div class="content">
                <h2>Section Title</h2>
                <p>More content here.</p>
                <ul>
                    <li>List item one</li>
                    <li>List item two</li>
                </ul>
            </div>
        </article>
    </main>
    
    <aside>
        <h3>Related Links</h3>
        <a href="/link1">Link 1</a>
    </aside>
    
    <footer>
        <p>Copyright © 2024 Test Company. All rights reserved.</p>
        <p>京ICP备12345678号</p>
    </footer>
    
    <script>
        // More JavaScript that should be ignored
        document.addEventListener('DOMContentLoaded', function() {
            console.log('loaded');
        });
    </script>
</body>
</html>
`

	result, err := extractMainContent(complexHTML)
	if err != nil {
		t.Fatalf("extractMainContent() error = %v", err)
	}

	// Should contain main content
	shouldContain := []string{
		"Main Article Title",
		"first paragraph",
		"second paragraph",
		"bold",
		"italic",
		"Section Title",
		"More content here",
		"List item one",
		"List item two",
	}

	for _, s := range shouldContain {
		if !strings.Contains(result, s) {
			t.Errorf("Result should contain %q", s)
		}
	}

	// Should NOT contain
	shouldNotContain := []string{
		"console.log",
		"font-family",
		"display: none",
		"Home",
		"About",
		"Related Links",
		"Link 1",
		"DOMContentLoaded",
	}

	for _, s := range shouldNotContain {
		if strings.Contains(result, s) {
			t.Errorf("Result should NOT contain %q, but got: %s", s, result)
		}
	}
}

func TestExtractMainContent_ChineseContent(t *testing.T) {
	chineseHTML := `
<!DOCTYPE html>
<html>
<head>
    <title>中文测试页面</title>
</head>
<body>
    <header>
        <nav>导航栏</nav>
    </header>
    <main>
        <article>
            <h1>文章标题</h1>
            <p>这是一段中文内容，包含一些重要信息。</p>
            <p>第二段内容，继续测试中文提取功能。</p>
        </article>
    </main>
    <footer>
        <p>版权所有 © 2024</p>
    </footer>
</body>
</html>
`

	result, err := extractMainContent(chineseHTML)
	if err != nil {
		t.Fatalf("extractMainContent() error = %v", err)
	}

	// Should contain main Chinese content
	shouldContain := []string{
		"文章标题",
		"中文内容",
		"重要信息",
		"第二段内容",
	}

	for _, s := range shouldContain {
		if !strings.Contains(result, s) {
			t.Errorf("Result should contain %q", s)
		}
	}

	// Should NOT contain navigation
	if strings.Contains(result, "导航栏") {
		t.Error("Result should NOT contain navigation content")
	}
}

func TestCleanExtractedText_MaxLength(t *testing.T) {
	// Create a very long string
	longText := strings.Repeat("This is a test sentence. ", 5000)
	
	result := cleanExtractedText(longText)
	
	// Should be truncated to max length + "..."
	maxLength := 50000
	if len(result) > maxLength+3 {
		t.Errorf("Result length %d exceeds max length %d", len(result), maxLength+3)
	}
	
	if len(longText) > maxLength && !strings.HasSuffix(result, "...") {
		t.Error("Long text should be truncated with '...'")
	}
}
