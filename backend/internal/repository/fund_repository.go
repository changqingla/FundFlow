package repository

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"fund-analyzer/internal/model"

	"github.com/jmoiron/sqlx"
	"github.com/lib/pq"
)

var (
	ErrFundNotFound = errors.New("fund not found")
	ErrFundExists   = errors.New("fund already exists")
)

// UserFundRepository 用户基金仓库接口
type UserFundRepository interface {
	GetFundsByUserID(ctx context.Context, userID int64) ([]model.UserFund, error)
	GetFundByCode(ctx context.Context, userID int64, fundCode string) (*model.UserFund, error)
	AddFund(ctx context.Context, fund *model.UserFund) error
	DeleteFund(ctx context.Context, userID int64, fundCode string) error
	UpdateHoldStatus(ctx context.Context, userID int64, fundCode string, isHold bool) error
	UpdateSectors(ctx context.Context, userID int64, fundCode string, sectors []string) error
}

type userFundRepository struct {
	db *sqlx.DB
}

// NewUserFundRepository 创建用户基金仓库
func NewUserFundRepository(db *sqlx.DB) UserFundRepository {
	return &userFundRepository{db: db}
}

func (r *userFundRepository) GetFundsByUserID(ctx context.Context, userID int64) ([]model.UserFund, error) {
	var funds []model.UserFund
	query := `SELECT * FROM user_funds WHERE user_id = $1 ORDER BY created_at DESC`
	err := r.db.SelectContext(ctx, &funds, query, userID)
	if err != nil {
		return nil, err
	}
	return funds, nil
}

func (r *userFundRepository) GetFundByCode(ctx context.Context, userID int64, fundCode string) (*model.UserFund, error) {
	var fund model.UserFund
	query := `SELECT * FROM user_funds WHERE user_id = $1 AND fund_code = $2`
	err := r.db.GetContext(ctx, &fund, query, userID, fundCode)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrFundNotFound
		}
		return nil, err
	}
	return &fund, nil
}

func (r *userFundRepository) AddFund(ctx context.Context, fund *model.UserFund) error {
	query := `
		INSERT INTO user_funds (user_id, fund_code, fund_name, fund_key, is_hold, sectors, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id`

	now := time.Now()
	fund.CreatedAt = now
	fund.UpdatedAt = now

	if fund.Sectors == nil {
		fund.Sectors = pq.StringArray{}
	}

	return r.db.QueryRowContext(ctx, query,
		fund.UserID, fund.FundCode, fund.FundName, fund.FundKey, fund.IsHold, fund.Sectors, fund.CreatedAt, fund.UpdatedAt,
	).Scan(&fund.ID)
}

func (r *userFundRepository) DeleteFund(ctx context.Context, userID int64, fundCode string) error {
	result, err := r.db.ExecContext(ctx,
		`DELETE FROM user_funds WHERE user_id = $1 AND fund_code = $2`,
		userID, fundCode,
	)
	if err != nil {
		return err
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrFundNotFound
	}
	return nil
}

func (r *userFundRepository) UpdateHoldStatus(ctx context.Context, userID int64, fundCode string, isHold bool) error {
	result, err := r.db.ExecContext(ctx,
		`UPDATE user_funds SET is_hold = $1, updated_at = $2 WHERE user_id = $3 AND fund_code = $4`,
		isHold, time.Now(), userID, fundCode,
	)
	if err != nil {
		return err
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrFundNotFound
	}
	return nil
}

func (r *userFundRepository) UpdateSectors(ctx context.Context, userID int64, fundCode string, sectors []string) error {
	result, err := r.db.ExecContext(ctx,
		`UPDATE user_funds SET sectors = $1, updated_at = $2 WHERE user_id = $3 AND fund_code = $4`,
		pq.StringArray(sectors), time.Now(), userID, fundCode,
	)
	if err != nil {
		return err
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrFundNotFound
	}
	return nil
}
