package model

import (
	"time"

	"github.com/lib/pq"
)

// UserStatus 用户状态
type UserStatus int

const (
	UserStatusDisabled UserStatus = 0 // 禁用
	UserStatusActive   UserStatus = 1 // 正常
	UserStatusLocked   UserStatus = 2 // 锁定
)

// User 用户模型
type User struct {
	ID            int64      `json:"id" db:"id"`
	Email         string     `json:"email" db:"email"`
	PasswordHash  string     `json:"-" db:"password_hash"`
	Nickname      string     `json:"nickname" db:"nickname"`
	AvatarURL     string     `json:"avatarUrl" db:"avatar_url"`
	Status        UserStatus `json:"status" db:"status"`
	LoginAttempts int        `json:"-" db:"login_attempts"`
	LockedUntil   *time.Time `json:"-" db:"locked_until"`
	CreatedAt     time.Time  `json:"createdAt" db:"created_at"`
	UpdatedAt     time.Time  `json:"updatedAt" db:"updated_at"`
}

// IsLocked 检查用户是否被锁定
func (u *User) IsLocked() bool {
	if u.Status == UserStatusLocked && u.LockedUntil != nil {
		return time.Now().Before(*u.LockedUntil)
	}
	return false
}

// VerificationCodeType 验证码类型
type VerificationCodeType int

const (
	VerificationCodeTypeRegister      VerificationCodeType = 1 // 注册
	VerificationCodeTypeResetPassword VerificationCodeType = 2 // 重置密码
)

// VerificationCode 验证码模型
type VerificationCode struct {
	ID        int64                `db:"id"`
	Email     string               `db:"email"`
	Code      string               `db:"code"`
	Type      VerificationCodeType `db:"type"`
	ExpiresAt time.Time            `db:"expires_at"`
	Used      bool                 `db:"used"`
	CreatedAt time.Time            `db:"created_at"`
}

// IsExpired 检查验证码是否过期
func (v *VerificationCode) IsExpired() bool {
	return time.Now().After(v.ExpiresAt)
}

// TokenBlacklist Token 黑名单
type TokenBlacklist struct {
	ID        int64     `db:"id"`
	TokenHash string    `db:"token_hash"`
	UserID    int64     `db:"user_id"`
	ExpiresAt time.Time `db:"expires_at"`
	CreatedAt time.Time `db:"created_at"`
}

// UserFund 用户自选基金
type UserFund struct {
	ID        int64          `json:"id" db:"id"`
	UserID    int64          `json:"userId" db:"user_id"`
	FundCode  string         `json:"fundCode" db:"fund_code"`
	FundName  string         `json:"fundName" db:"fund_name"`
	FundKey   string         `json:"fundKey" db:"fund_key"`
	IsHold    bool           `json:"isHold" db:"is_hold"`
	Sectors   pq.StringArray `json:"sectors" db:"sectors"`
	CreatedAt time.Time      `json:"createdAt" db:"created_at"`
	UpdatedAt time.Time      `json:"updatedAt" db:"updated_at"`
}
