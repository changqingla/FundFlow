package service

import (
	"fund-analyzer/internal/config"
	"net/http"
	"time"
)

// NewEmailService 根据配置创建邮件服务
// 支持两种类型:
// - "smtp": 使用 SMTP 协议（推荐，适用于阿里云邮件推送）
// - "api": 使用阿里云 DirectMail API
func NewEmailService(cfg config.EmailConfig) EmailService {
	// 根据配置类型选择邮件服务实现
	switch cfg.Type {
	case "api":
		// 使用阿里云 DirectMail API
		return newDirectMailService(cfg)
	case "smtp", "":
		// 默认使用 SMTP（更通用）
		return NewSMTPEmailService(cfg)
	default:
		// 未知类型，默认使用 SMTP
		return NewSMTPEmailService(cfg)
	}
}

// newDirectMailService 创建阿里云 DirectMail API 服务
// 这是原来的 emailService 实现
func newDirectMailService(cfg config.EmailConfig) EmailService {
	return &emailService{
		config: cfg,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}
