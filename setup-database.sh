#!/bin/bash
# 在现有 PostgreSQL 服务中创建基金分析项目的数据库

echo "连接到 PostgreSQL 服务器..."

# 连接到现有数据库并创建新数据库
docker exec -it reader_postgres psql -U reader -d reader_qaq -c "CREATE DATABASE fund_analyzer;"

echo "创建数据库成功！"
echo ""
echo "现在运行迁移脚本..."

# 运行迁移脚本
docker exec -i reader_postgres psql -U reader -d fund_analyzer < backend/migrations/001_init.up.sql

echo ""
echo "✅ 数据库设置完成！"
echo ""
echo "数据库信息："
echo "  主机: 101.126.153.146"
echo "  端口: 5433"
echo "  数据库: fund_analyzer"
echo "  用户: reader"
echo "  密码: reader_dev_password"
