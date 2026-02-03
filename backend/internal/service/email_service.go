package service

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"time"

	"fund-analyzer/internal/config"
)

// EmailService 邮件服务接口
type EmailService interface {
	SendVerificationCode(ctx context.Context, email, code string) error
	SendPasswordResetCode(ctx context.Context, email, code string) error
}

type emailService struct {
	config     config.EmailConfig
	httpClient *http.Client
}

// NewEmailService 创建邮件服务
func NewEmailService(cfg config.EmailConfig) EmailService {
	return &emailService{
		config: cfg,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

func (s *emailService) SendVerificationCode(ctx context.Context, email, code string) error {
	subject := "验证您的邮箱 - 基金分析助手"
	body := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
	<h2 style="color: #333;">欢迎注册基金分析助手</h2>
	<p>您的验证码是：</p>
	<div style="background: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0;">
		<span style="font-size: 32px; font-weight: bold; color: #1890ff; letter-spacing: 5px;">%s</span>
	</div>
	<p>验证码有效期为 <strong>10 分钟</strong>，请尽快完成验证。</p>
	<p style="color: #999; font-size: 12px;">如果这不是您的操作，请忽略此邮件。</p>
</body>
</html>`, code)

	return s.sendEmail(ctx, email, subject, body)
}

func (s *emailService) SendPasswordResetCode(ctx context.Context, email, code string) error {
	subject := "重置您的密码 - 基金分析助手"
	body := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
	<h2 style="color: #333;">密码重置请求</h2>
	<p>您的验证码是：</p>
	<div style="background: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0;">
		<span style="font-size: 32px; font-weight: bold; color: #ff4d4f; letter-spacing: 5px;">%s</span>
	</div>
	<p>验证码有效期为 <strong>10 分钟</strong>。</p>
	<p style="color: #999; font-size: 12px;">如果这不是您的操作，请忽略此邮件并确保您的账号安全。</p>
</body>
</html>`, code)

	return s.sendEmail(ctx, email, subject, body)
}

// sendEmail 发送邮件（阿里云邮件推送服务）
func (s *emailService) sendEmail(ctx context.Context, to, subject, body string) error {
	// 如果未配置阿里云，使用开发模式
	if s.config.AccessKeyID == "" || s.config.AccessKeySecret == "" {
		fmt.Printf("[Email-Dev] To: %s, Subject: %s\n", to, subject)
		return nil
	}

	// 构建请求参数
	params := map[string]string{
		"Action":           "SingleSendMail",
		"AccountName":      s.config.AccountName,
		"AddressType":      "1",
		"ReplyToAddress":   "false",
		"ToAddress":        to,
		"Subject":          subject,
		"HtmlBody":         body,
		"Format":           "JSON",
		"Version":          "2015-11-23",
		"AccessKeyId":      s.config.AccessKeyID,
		"SignatureMethod":  "HMAC-SHA1",
		"Timestamp":        time.Now().UTC().Format("2006-01-02T15:04:05Z"),
		"SignatureVersion": "1.0",
		"SignatureNonce":   fmt.Sprintf("%d", time.Now().UnixNano()),
	}

	if s.config.FromAlias != "" {
		params["FromAlias"] = s.config.FromAlias
	}

	// 计算签名
	signature := s.calculateSignature(params)
	params["Signature"] = signature

	// 构建请求 URL
	region := s.config.Region
	if region == "" {
		region = "cn-hangzhou"
	}
	endpoint := fmt.Sprintf("https://dm.%s.aliyuncs.com/", region)

	// 发送请求
	values := url.Values{}
	for k, v := range params {
		values.Set(k, v)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", endpoint, bytes.NewBufferString(values.Encode()))
	if err != nil {
		return fmt.Errorf("create request failed: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("send request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("email send failed: %s", string(respBody))
	}

	// 解析响应
	var result struct {
		RequestId string `json:"RequestId"`
		EnvId     string `json:"EnvId"`
		Code      string `json:"Code"`
		Message   string `json:"Message"`
	}
	if err := json.Unmarshal(respBody, &result); err != nil {
		return fmt.Errorf("parse response failed: %w", err)
	}

	if result.Code != "" && result.Code != "OK" {
		return fmt.Errorf("email send failed: %s - %s", result.Code, result.Message)
	}

	return nil
}

// calculateSignature 计算阿里云 API 签名
func (s *emailService) calculateSignature(params map[string]string) string {
	// 排序参数
	keys := make([]string, 0, len(params))
	for k := range params {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	// 构建待签名字符串
	var queryParts []string
	for _, k := range keys {
		queryParts = append(queryParts, fmt.Sprintf("%s=%s",
			specialURLEncode(k),
			specialURLEncode(params[k]),
		))
	}
	canonicalizedQueryString := strings.Join(queryParts, "&")

	stringToSign := fmt.Sprintf("POST&%s&%s",
		specialURLEncode("/"),
		specialURLEncode(canonicalizedQueryString),
	)

	// HMAC-SHA1 签名
	mac := hmac.New(sha1.New, []byte(s.config.AccessKeySecret+"&"))
	mac.Write([]byte(stringToSign))
	signature := base64.StdEncoding.EncodeToString(mac.Sum(nil))

	return signature
}

// specialURLEncode 阿里云特殊 URL 编码
func specialURLEncode(s string) string {
	encoded := url.QueryEscape(s)
	encoded = strings.ReplaceAll(encoded, "+", "%20")
	encoded = strings.ReplaceAll(encoded, "*", "%2A")
	encoded = strings.ReplaceAll(encoded, "%7E", "~")
	return encoded
}
