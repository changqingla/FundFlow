package service

import (
	"context"
	"crypto/tls"
	"fmt"
	"net/smtp"
	"strings"

	"fund-analyzer/internal/config"
)

// SMTPEmailService SMTP 邮件服务实现
type SMTPEmailService struct {
	config config.EmailConfig
}

// NewSMTPEmailService 创建 SMTP 邮件服务
func NewSMTPEmailService(cfg config.EmailConfig) EmailService {
	return &SMTPEmailService{
		config: cfg,
	}
}

func (s *SMTPEmailService) SendVerificationCode(ctx context.Context, email, code string) error {
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

func (s *SMTPEmailService) SendPasswordResetCode(ctx context.Context, email, code string) error {
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

// sendEmail 通过 SMTP 发送邮件
func (s *SMTPEmailService) sendEmail(ctx context.Context, to, subject, htmlBody string) error {
	// 开发模式：如果未配置 SMTP，只打印日志
	if s.config.SMTPHost == "" || s.config.SMTPUsername == "" {
		fmt.Printf("[Email-Dev] To: %s, Subject: %s\n", to, subject)
		return nil
	}

	// 构建邮件内容
	from := s.config.SMTPUsername
	fromName := s.config.FromAlias
	if fromName == "" {
		fromName = "基金分析助手"
	}

	// 构建邮件头
	headers := make(map[string]string)
	headers["From"] = fmt.Sprintf("%s <%s>", fromName, from)
	headers["To"] = to
	headers["Subject"] = subject
	headers["MIME-Version"] = "1.0"
	headers["Content-Type"] = "text/html; charset=UTF-8"

	// 组装邮件
	message := ""
	for k, v := range headers {
		message += fmt.Sprintf("%s: %s\r\n", k, v)
	}
	message += "\r\n" + htmlBody

	// SMTP 认证
	auth := smtp.PlainAuth("", s.config.SMTPUsername, s.config.SMTPPassword, s.config.SMTPHost)

	// 发送邮件
	addr := fmt.Sprintf("%s:%d", s.config.SMTPHost, s.config.SMTPPort)

	// 如果使用 SSL (端口 465)
	if s.config.SMTPUseSSL {
		return s.sendMailSSL(addr, auth, from, []string{to}, []byte(message))
	}

	// 使用 STARTTLS (端口 25 或 587)
	return smtp.SendMail(addr, auth, from, []string{to}, []byte(message))
}

// sendMailSSL 使用 SSL/TLS 发送邮件（用于端口 465）
func (s *SMTPEmailService) sendMailSSL(addr string, auth smtp.Auth, from string, to []string, msg []byte) error {
	// 解析主机名
	host := strings.Split(addr, ":")[0]

	// 创建 TLS 配置
	tlsConfig := &tls.Config{
		ServerName: host,
	}

	// 建立 TLS 连接
	conn, err := tls.Dial("tcp", addr, tlsConfig)
	if err != nil {
		return fmt.Errorf("TLS dial failed: %w", err)
	}
	defer conn.Close()

	// 创建 SMTP 客户端
	client, err := smtp.NewClient(conn, host)
	if err != nil {
		return fmt.Errorf("create SMTP client failed: %w", err)
	}
	defer client.Close()

	// 认证
	if auth != nil {
		if err = client.Auth(auth); err != nil {
			return fmt.Errorf("SMTP auth failed: %w", err)
		}
	}

	// 设置发件人
	if err = client.Mail(from); err != nil {
		return fmt.Errorf("set sender failed: %w", err)
	}

	// 设置收件人
	for _, addr := range to {
		if err = client.Rcpt(addr); err != nil {
			return fmt.Errorf("set recipient failed: %w", err)
		}
	}

	// 发送邮件内容
	w, err := client.Data()
	if err != nil {
		return fmt.Errorf("get data writer failed: %w", err)
	}

	_, err = w.Write(msg)
	if err != nil {
		return fmt.Errorf("write message failed: %w", err)
	}

	err = w.Close()
	if err != nil {
		return fmt.Errorf("close writer failed: %w", err)
	}

	return client.Quit()
}
