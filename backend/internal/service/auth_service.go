package service

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"math/rand"
	"regexp"
	"time"

	"fund-analyzer/internal/config"
	"fund-analyzer/internal/model"
	"fund-analyzer/internal/repository"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrUserLocked         = errors.New("user account is locked")
	ErrInvalidToken       = errors.New("invalid token")
	ErrTokenExpired       = errors.New("token expired")
	ErrTokenBlacklisted   = errors.New("token is blacklisted")
	ErrInvalidCode        = errors.New("invalid verification code")
	ErrCodeExpired        = errors.New("verification code expired")
	ErrWeakPassword       = errors.New("password does not meet strength requirements")
	ErrInvalidEmail       = errors.New("invalid email format")
)

const (
	MaxLoginAttempts = 5
	LockDuration     = 15 * time.Minute
	CodeExpiration   = 10 * time.Minute
)

// AuthService 认证服务接口
type AuthService interface {
	Register(ctx context.Context, req *model.RegisterRequest) error
	SendVerificationCode(ctx context.Context, email string, codeType model.VerificationCodeType) error
	VerifyEmail(ctx context.Context, email, code string) (*model.User, error)
	Login(ctx context.Context, email, password string) (*model.LoginResponse, error)
	Logout(ctx context.Context, userID int64, token string) error
	RefreshToken(ctx context.Context, refreshToken string) (*model.TokenPair, error)
	ForgotPassword(ctx context.Context, email string) error
	ResetPassword(ctx context.Context, email, code, newPassword string) error
	GetUserByID(ctx context.Context, userID int64) (*model.User, error)
	ValidateToken(ctx context.Context, token string) (*model.Claims, error)
}

type authService struct {
	userRepo     repository.UserRepository
	jwtConfig    config.JWTConfig
	emailConfig  config.EmailConfig
	emailService EmailService
}

// NewAuthService 创建认证服务
func NewAuthService(userRepo repository.UserRepository, jwtConfig config.JWTConfig, emailConfig config.EmailConfig) AuthService {
	return &authService{
		userRepo:     userRepo,
		jwtConfig:    jwtConfig,
		emailConfig:  emailConfig,
		emailService: NewEmailService(emailConfig),
	}
}

// ValidateEmail 验证邮箱格式
func ValidateEmail(email string) bool {
	pattern := `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`
	re := regexp.MustCompile(pattern)
	return re.MatchString(email)
}

// ValidatePassword 验证密码强度
func ValidatePassword(password string) bool {
	if len(password) < 8 {
		return false
	}
	hasLetter := regexp.MustCompile(`[a-zA-Z]`).MatchString(password)
	hasNumber := regexp.MustCompile(`[0-9]`).MatchString(password)
	return hasLetter && hasNumber
}

// HashPassword 加密密码
func HashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	return string(bytes), err
}

// CheckPassword 验证密码
func CheckPassword(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

// GenerateCode 生成 6 位数字验证码
func GenerateCode() string {
	return fmt.Sprintf("%06d", rand.Intn(1000000))
}

// HashToken 计算 Token 哈希
func HashToken(token string) string {
	hash := sha256.Sum256([]byte(token))
	return hex.EncodeToString(hash[:])
}

func (s *authService) Register(ctx context.Context, req *model.RegisterRequest) error {
	// 验证邮箱格式
	if !ValidateEmail(req.Email) {
		return ErrInvalidEmail
	}

	// 验证密码强度
	if !ValidatePassword(req.Password) {
		return ErrWeakPassword
	}

	// 检查邮箱是否已注册
	_, err := s.userRepo.GetUserByEmail(ctx, req.Email)
	if err == nil {
		return repository.ErrUserExists
	}
	if !errors.Is(err, repository.ErrUserNotFound) {
		return err
	}

	// 发送验证码
	return s.SendVerificationCode(ctx, req.Email, model.VerificationCodeTypeRegister)
}

func (s *authService) SendVerificationCode(ctx context.Context, email string, codeType model.VerificationCodeType) error {
	code := GenerateCode()

	// 保存验证码
	verificationCode := &model.VerificationCode{
		Email:     email,
		Code:      code,
		Type:      codeType,
		ExpiresAt: time.Now().Add(CodeExpiration),
	}

	if err := s.userRepo.CreateVerificationCode(ctx, verificationCode); err != nil {
		return err
	}

	// 发送邮件
	if codeType == model.VerificationCodeTypeRegister {
		return s.emailService.SendVerificationCode(ctx, email, code)
	}
	return s.emailService.SendPasswordResetCode(ctx, email, code)
}

func (s *authService) VerifyEmail(ctx context.Context, email, code string) (*model.User, error) {
	// 获取验证码
	verificationCode, err := s.userRepo.GetVerificationCode(ctx, email, model.VerificationCodeTypeRegister)
	if err != nil {
		return nil, ErrInvalidCode
	}

	// 检查验证码是否过期
	if verificationCode.IsExpired() {
		return nil, ErrCodeExpired
	}

	// 检查验证码是否正确
	if verificationCode.Code != code {
		return nil, ErrInvalidCode
	}

	// 标记验证码已使用
	if err := s.userRepo.MarkVerificationCodeUsed(ctx, verificationCode.ID); err != nil {
		return nil, err
	}

	// 这里需要从临时存储获取注册信息，简化处理：返回 nil 表示验证成功
	// 实际实现中应该在 Register 时临时存储用户信息
	return nil, nil
}

func (s *authService) Login(ctx context.Context, email, password string) (*model.LoginResponse, error) {
	// 获取用户
	user, err := s.userRepo.GetUserByEmail(ctx, email)
	if err != nil {
		if errors.Is(err, repository.ErrUserNotFound) {
			return nil, ErrInvalidCredentials
		}
		return nil, err
	}

	// 检查是否被锁定
	if user.IsLocked() {
		return nil, ErrUserLocked
	}

	// 验证密码
	if !CheckPassword(password, user.PasswordHash) {
		// 增加失败次数
		attempts := user.LoginAttempts + 1
		var lockedUntil *time.Time
		if attempts >= MaxLoginAttempts {
			t := time.Now().Add(LockDuration)
			lockedUntil = &t
		}
		_ = s.userRepo.UpdateLoginAttempts(ctx, user.ID, attempts, lockedUntil)
		return nil, ErrInvalidCredentials
	}

	// 重置登录失败次数
	if user.LoginAttempts > 0 {
		_ = s.userRepo.UpdateLoginAttempts(ctx, user.ID, 0, nil)
	}

	// 生成 Token
	tokenPair, err := s.generateTokenPair(user)
	if err != nil {
		return nil, err
	}

	return &model.LoginResponse{
		User:         user,
		AccessToken:  tokenPair.AccessToken,
		RefreshToken: tokenPair.RefreshToken,
		ExpiresIn:    tokenPair.ExpiresIn,
	}, nil
}

func (s *authService) Logout(ctx context.Context, userID int64, token string) error {
	// 解析 Token 获取过期时间
	claims, err := s.parseToken(token)
	if err != nil {
		return err
	}

	// 将 Token 加入黑名单
	return s.userRepo.AddToBlacklist(ctx, HashToken(token), userID, claims.ExpiresAt.Time)
}

func (s *authService) RefreshToken(ctx context.Context, refreshToken string) (*model.TokenPair, error) {
	// 解析刷新 Token
	claims, err := s.parseRefreshToken(refreshToken)
	if err != nil {
		return nil, err
	}

	// 获取用户
	user, err := s.userRepo.GetUserByID(ctx, claims.UserID)
	if err != nil {
		return nil, err
	}

	// 生成新的 Token 对
	return s.generateTokenPair(user)
}

func (s *authService) ForgotPassword(ctx context.Context, email string) error {
	// 检查用户是否存在
	_, err := s.userRepo.GetUserByEmail(ctx, email)
	if err != nil {
		if errors.Is(err, repository.ErrUserNotFound) {
			// 为了安全，不暴露用户是否存在
			return nil
		}
		return err
	}

	// 发送重置密码验证码
	return s.SendVerificationCode(ctx, email, model.VerificationCodeTypeResetPassword)
}

func (s *authService) ResetPassword(ctx context.Context, email, code, newPassword string) error {
	// 验证密码强度
	if !ValidatePassword(newPassword) {
		return ErrWeakPassword
	}

	// 获取验证码
	verificationCode, err := s.userRepo.GetVerificationCode(ctx, email, model.VerificationCodeTypeResetPassword)
	if err != nil {
		return ErrInvalidCode
	}

	// 检查验证码是否过期
	if verificationCode.IsExpired() {
		return ErrCodeExpired
	}

	// 检查验证码是否正确
	if verificationCode.Code != code {
		return ErrInvalidCode
	}

	// 获取用户
	user, err := s.userRepo.GetUserByEmail(ctx, email)
	if err != nil {
		return err
	}

	// 加密新密码
	hash, err := HashPassword(newPassword)
	if err != nil {
		return err
	}

	// 更新密码
	user.PasswordHash = hash
	if err := s.userRepo.UpdateUser(ctx, user); err != nil {
		return err
	}

	// 标记验证码已使用
	return s.userRepo.MarkVerificationCodeUsed(ctx, verificationCode.ID)
}

func (s *authService) GetUserByID(ctx context.Context, userID int64) (*model.User, error) {
	return s.userRepo.GetUserByID(ctx, userID)
}

func (s *authService) ValidateToken(ctx context.Context, token string) (*model.Claims, error) {
	// 解析 Token
	claims, err := s.parseToken(token)
	if err != nil {
		return nil, err
	}

	// 检查是否在黑名单中
	blacklisted, err := s.userRepo.IsTokenBlacklisted(ctx, HashToken(token))
	if err != nil {
		return nil, err
	}
	if blacklisted {
		return nil, ErrTokenBlacklisted
	}

	return claims, nil
}

// generateTokenPair 生成 Token 对
func (s *authService) generateTokenPair(user *model.User) (*model.TokenPair, error) {
	now := time.Now()
	accessExpire := now.Add(time.Duration(s.jwtConfig.AccessExpireMin) * time.Minute)
	refreshExpire := now.Add(time.Duration(s.jwtConfig.RefreshExpireDay) * 24 * time.Hour)

	// 生成 Access Token
	accessClaims := &model.Claims{
		UserID: user.ID,
		Email:  user.Email,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(accessExpire),
			IssuedAt:  jwt.NewNumericDate(now),
			Issuer:    s.jwtConfig.Issuer,
		},
	}

	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessTokenString, err := accessToken.SignedString([]byte(s.jwtConfig.Secret))
	if err != nil {
		return nil, err
	}

	// 生成 Refresh Token
	refreshClaims := &model.RefreshClaims{
		UserID: user.ID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(refreshExpire),
			IssuedAt:  jwt.NewNumericDate(now),
			Issuer:    s.jwtConfig.Issuer,
		},
	}

	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshTokenString, err := refreshToken.SignedString([]byte(s.jwtConfig.Secret))
	if err != nil {
		return nil, err
	}

	return &model.TokenPair{
		AccessToken:  accessTokenString,
		RefreshToken: refreshTokenString,
		ExpiresIn:    int64(s.jwtConfig.AccessExpireMin * 60),
	}, nil
}

// parseToken 解析 Access Token
func (s *authService) parseToken(tokenString string) (*model.Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &model.Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, ErrInvalidToken
		}
		return []byte(s.jwtConfig.Secret), nil
	})

	if err != nil {
		if errors.Is(err, jwt.ErrTokenExpired) {
			return nil, ErrTokenExpired
		}
		return nil, ErrInvalidToken
	}

	claims, ok := token.Claims.(*model.Claims)
	if !ok || !token.Valid {
		return nil, ErrInvalidToken
	}

	return claims, nil
}

// parseRefreshToken 解析 Refresh Token
func (s *authService) parseRefreshToken(tokenString string) (*model.RefreshClaims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &model.RefreshClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, ErrInvalidToken
		}
		return []byte(s.jwtConfig.Secret), nil
	})

	if err != nil {
		if errors.Is(err, jwt.ErrTokenExpired) {
			return nil, ErrTokenExpired
		}
		return nil, ErrInvalidToken
	}

	claims, ok := token.Claims.(*model.RefreshClaims)
	if !ok || !token.Valid {
		return nil, ErrInvalidToken
	}

	return claims, nil
}
