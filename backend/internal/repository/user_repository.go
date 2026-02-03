package repository

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"fund-analyzer/internal/model"

	"github.com/jmoiron/sqlx"
)

var (
	ErrUserNotFound = errors.New("user not found")
	ErrUserExists   = errors.New("user already exists")
)

// UserRepository 用户仓库接口
type UserRepository interface {
	CreateUser(ctx context.Context, user *model.User) error
	GetUserByEmail(ctx context.Context, email string) (*model.User, error)
	GetUserByID(ctx context.Context, id int64) (*model.User, error)
	UpdateUser(ctx context.Context, user *model.User) error
	UpdateLoginAttempts(ctx context.Context, userID int64, attempts int, lockedUntil *time.Time) error

	// 验证码相关
	CreateVerificationCode(ctx context.Context, code *model.VerificationCode) error
	GetVerificationCode(ctx context.Context, email string, codeType model.VerificationCodeType) (*model.VerificationCode, error)
	MarkVerificationCodeUsed(ctx context.Context, id int64) error

	// Token 黑名单
	AddToBlacklist(ctx context.Context, tokenHash string, userID int64, expiresAt time.Time) error
	IsTokenBlacklisted(ctx context.Context, tokenHash string) (bool, error)
	CleanExpiredBlacklist(ctx context.Context) error
}

type userRepository struct {
	db *sqlx.DB
}

// NewUserRepository 创建用户仓库
func NewUserRepository(db *sqlx.DB) UserRepository {
	return &userRepository{db: db}
}

func (r *userRepository) CreateUser(ctx context.Context, user *model.User) error {
	query := `
		INSERT INTO users (email, password_hash, nickname, avatar_url, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id`

	now := time.Now()
	user.CreatedAt = now
	user.UpdatedAt = now
	user.Status = model.UserStatusActive

	return r.db.QueryRowContext(ctx, query,
		user.Email, user.PasswordHash, user.Nickname, user.AvatarURL, user.Status, user.CreatedAt, user.UpdatedAt,
	).Scan(&user.ID)
}

func (r *userRepository) GetUserByEmail(ctx context.Context, email string) (*model.User, error) {
	var user model.User
	query := `SELECT * FROM users WHERE email = $1`
	err := r.db.GetContext(ctx, &user, query, email)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	return &user, nil
}

func (r *userRepository) GetUserByID(ctx context.Context, id int64) (*model.User, error) {
	var user model.User
	query := `SELECT * FROM users WHERE id = $1`
	err := r.db.GetContext(ctx, &user, query, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	return &user, nil
}

func (r *userRepository) UpdateUser(ctx context.Context, user *model.User) error {
	query := `
		UPDATE users 
		SET nickname = $1, avatar_url = $2, password_hash = $3, status = $4, updated_at = $5
		WHERE id = $6`

	user.UpdatedAt = time.Now()
	_, err := r.db.ExecContext(ctx, query,
		user.Nickname, user.AvatarURL, user.PasswordHash, user.Status, user.UpdatedAt, user.ID,
	)
	return err
}

func (r *userRepository) UpdateLoginAttempts(ctx context.Context, userID int64, attempts int, lockedUntil *time.Time) error {
	var query string
	var args []interface{}

	if lockedUntil != nil {
		query = `UPDATE users SET login_attempts = $1, locked_until = $2, status = $3, updated_at = $4 WHERE id = $5`
		args = []interface{}{attempts, lockedUntil, model.UserStatusLocked, time.Now(), userID}
	} else {
		query = `UPDATE users SET login_attempts = $1, locked_until = NULL, status = $2, updated_at = $3 WHERE id = $4`
		args = []interface{}{attempts, model.UserStatusActive, time.Now(), userID}
	}

	_, err := r.db.ExecContext(ctx, query, args...)
	return err
}

// 验证码相关方法
func (r *userRepository) CreateVerificationCode(ctx context.Context, code *model.VerificationCode) error {
	// 先使之前的验证码失效
	_, _ = r.db.ExecContext(ctx,
		`UPDATE verification_codes SET used = true WHERE email = $1 AND type = $2 AND used = false`,
		code.Email, code.Type,
	)

	query := `
		INSERT INTO verification_codes (email, code, type, expires_at, created_at)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id`

	code.CreatedAt = time.Now()
	return r.db.QueryRowContext(ctx, query,
		code.Email, code.Code, code.Type, code.ExpiresAt, code.CreatedAt,
	).Scan(&code.ID)
}

func (r *userRepository) GetVerificationCode(ctx context.Context, email string, codeType model.VerificationCodeType) (*model.VerificationCode, error) {
	var code model.VerificationCode
	query := `
		SELECT * FROM verification_codes 
		WHERE email = $1 AND type = $2 AND used = false 
		ORDER BY created_at DESC 
		LIMIT 1`

	err := r.db.GetContext(ctx, &code, query, email, codeType)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, errors.New("verification code not found")
		}
		return nil, err
	}
	return &code, nil
}

func (r *userRepository) MarkVerificationCodeUsed(ctx context.Context, id int64) error {
	_, err := r.db.ExecContext(ctx, `UPDATE verification_codes SET used = true WHERE id = $1`, id)
	return err
}

// Token 黑名单方法
func (r *userRepository) AddToBlacklist(ctx context.Context, tokenHash string, userID int64, expiresAt time.Time) error {
	query := `
		INSERT INTO token_blacklist (token_hash, user_id, expires_at, created_at)
		VALUES ($1, $2, $3, $4)`

	_, err := r.db.ExecContext(ctx, query, tokenHash, userID, expiresAt, time.Now())
	return err
}

func (r *userRepository) IsTokenBlacklisted(ctx context.Context, tokenHash string) (bool, error) {
	var count int
	query := `SELECT COUNT(*) FROM token_blacklist WHERE token_hash = $1 AND expires_at > $2`
	err := r.db.GetContext(ctx, &count, query, tokenHash, time.Now())
	if err != nil {
		return false, err
	}
	return count > 0, nil
}

func (r *userRepository) CleanExpiredBlacklist(ctx context.Context) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM token_blacklist WHERE expires_at < $1`, time.Now())
	return err
}
