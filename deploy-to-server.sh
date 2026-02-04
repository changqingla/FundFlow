#!/bin/bash
# 部署基金分析项目到服务器（使用现有数据库和 Redis）

set -e  # 遇到错误立即退出

echo "========================================="
echo "基金分析项目 - 服务器部署脚本"
echo "========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 检查是否在服务器上
if [ ! -f "/root/data/postgres" ]; then
    echo -e "${YELLOW}警告: 似乎不在服务器环境中${NC}"
    echo "请确认你在正确的服务器上运行此脚本"
    read -p "是否继续? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 步骤 1: 创建数据库
echo -e "${GREEN}步骤 1/5: 创建数据库${NC}"
echo "连接到 PostgreSQL 创建 fund_analyzer 数据库..."

# 检查数据库是否已存在
DB_EXISTS=$(docker exec reader_postgres psql -U reader -d reader_qaq -tAc "SELECT 1 FROM pg_database WHERE datname='fund_analyzer'" 2>/dev/null || echo "")

if [ "$DB_EXISTS" = "1" ]; then
    echo -e "${YELLOW}数据库 fund_analyzer 已存在，跳过创建${NC}"
else
    docker exec reader_postgres psql -U reader -d reader_qaq -c "CREATE DATABASE fund_analyzer;" || {
        echo -e "${RED}创建数据库失败！${NC}"
        exit 1
    }
    echo -e "${GREEN}✓ 数据库创建成功${NC}"
fi

# 步骤 2: 运行数据库迁移
echo ""
echo -e "${GREEN}步骤 2/5: 运行数据库迁移${NC}"
if [ -f "backend/migrations/001_init.up.sql" ]; then
    docker exec -i reader_postgres psql -U reader -d fund_analyzer < backend/migrations/001_init.up.sql || {
        echo -e "${YELLOW}迁移可能已经运行过，继续...${NC}"
    }
    echo -e "${GREEN}✓ 数据库迁移完成${NC}"
else
    echo -e "${RED}错误: 找不到迁移文件 backend/migrations/001_init.up.sql${NC}"
    exit 1
fi

# 步骤 3: 检查配置文件
echo ""
echo -e "${GREEN}步骤 3/5: 检查配置文件${NC}"
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}未找到 .env 文件，从模板创建...${NC}"
    cp .env.example .env
    echo -e "${RED}请编辑 .env 文件配置必要的参数！${NC}"
    echo "必须配置:"
    echo "  - JWT_SECRET"
    echo "  - SMTP_USERNAME"
    echo "  - SMTP_PASSWORD"
    echo "  - LLM_API_KEY"
    read -p "配置完成后按回车继续..."
fi
echo -e "${GREEN}✓ 配置文件检查完成${NC}"

# 步骤 4: 构建 Docker 镜像
echo ""
echo -e "${GREEN}步骤 4/5: 构建 Docker 镜像${NC}"
docker-compose build || {
    echo -e "${RED}Docker 镜像构建失败！${NC}"
    exit 1
}
echo -e "${GREEN}✓ Docker 镜像构建成功${NC}"

# 步骤 5: 启动服务
echo ""
echo -e "${GREEN}步骤 5/5: 启动服务${NC}"
docker-compose up -d || {
    echo -e "${RED}服务启动失败！${NC}"
    exit 1
}

# 等待服务启动
echo "等待服务启动..."
sleep 5

# 检查服务状态
echo ""
echo -e "${GREEN}检查服务状态...${NC}"
docker-compose ps

# 检查健康状态
echo ""
echo "检查 API 健康状态..."
for i in {1..10}; do
    if curl -s http://localhost:8080/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ API 服务正常运行！${NC}"
        break
    fi
    if [ $i -eq 10 ]; then
        echo -e "${RED}API 服务启动超时${NC}"
        echo "查看日志: docker-compose logs backend"
        exit 1
    fi
    echo "等待 API 启动... ($i/10)"
    sleep 3
done

# 显示服务信息
echo ""
echo "========================================="
echo -e "${GREEN}部署成功！${NC}"
echo "========================================="
echo ""
echo "服务信息:"
echo "  API 地址: http://101.126.153.146:8080"
echo "  健康检查: http://101.126.153.146:8080/health"
echo ""
echo "数据库信息:"
echo "  主机: 101.126.153.146:5433"
echo "  数据库: fund_analyzer"
echo "  用户: reader"
echo ""
echo "Redis 信息:"
echo "  主机: 101.126.153.146:6378"
echo "  数据库: 1 (独立的 DB，不影响其他项目)"
echo ""
echo "常用命令:"
echo "  查看日志: docker-compose logs -f backend"
echo "  重启服务: docker-compose restart"
echo "  停止服务: docker-compose down"
echo "  查看状态: docker-compose ps"
echo ""
echo -e "${GREEN}部署完成！${NC}"
