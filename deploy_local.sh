#!/bin/bash
# ==========================================
# 闲鱼自动回复系统 - 源码构建一键部署（移除滑动验证版）
# 从本地源码构建 Docker 镜像，不依赖远程预构建镜像
# 用法: bash deploy_local.sh
# ==========================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$WORK_DIR/docker-compose.yml"
ENV_FILE="$WORK_DIR/.env"

echo "=========================================="
echo "  闲鱼自动回复系统 - 源码构建部署"
echo "  (已移除极验滑动验证)"
echo "=========================================="
echo ""

# ========== 检查环境 ==========
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker 未安装，请先安装 Docker${NC}"
    echo "安装教程: https://docs.docker.com/get-docker/"
    exit 1
fi

if docker compose version &> /dev/null; then
    DC="docker compose"
elif command -v docker-compose &> /dev/null; then
    DC="docker-compose"
else
    echo -e "${RED}错误: Docker Compose 未安装${NC}"
    exit 1
fi

export COMPOSE_PROJECT_NAME=xianyu-auto-reply
DC_CMD="$DC -f $COMPOSE_FILE --env-file $ENV_FILE"

echo -e "${CYAN}[信息] Docker: $(docker --version)${NC}"
echo -e "${CYAN}[信息] Compose: $DC${NC}"
echo -e "${CYAN}[信息] 项目目录: $WORK_DIR${NC}"
echo ""

# ========== 生成 .env 配置文件 ==========
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}[提示] 首次部署，生成默认配置文件 .env${NC}"
    cat > "$ENV_FILE" << 'ENVEOF'
# ==========================================
# 闲鱼自动回复系统 - 环境变量配置
# ==========================================

MYSQL_ROOT_PASSWORD=xianyu@2026
MYSQL_DATABASE=xianyu_data
MYSQL_USER=xianyu
MYSQL_PASSWORD=xianyu@2026

REDIS_PASSWORD=xianyu@2026
REDIS_DB=0

FRONTEND_PORT=9000
BACKEND_WEB_PORT=8089
WEBSOCKET_PORT=8090
SCHEDULER_PORT=8091

MYSQL_IMAGE=registry.cn-shanghai.aliyuncs.com/zhinian-software/xianyu-mysql:8.0
REDIS_IMAGE=registry.cn-shanghai.aliyuncs.com/zhinian-software/xianyu-redis:7-alpine

LOG_LEVEL=INFO
SQL_ECHO=false

TOKEN_CACHE_TTL_MIN_HOURS=5
TOKEN_CACHE_TTL_MAX_HOURS=10

ACCESS_TOKEN_EXPIRE_MINUTES=1440
REFRESH_TOKEN_EXPIRE_MINUTES=10080

REDELIVERY_INTERVAL=5
RATE_INTERVAL=20

MAX_CAPTCHA_CONCURRENT=3

AUTO_START_WEBSOCKET=true
CAPTCHA_DRISSIONPAGE_FALLBACK_ENABLED=false
CAPTCHA_DRISSIONPAGE_TIMEOUT=25
CAPTCHA_DRISSIONPAGE_HEADLESS=true

CARD_DOCK_BASE_URL=http://backend.zhinianboke.com
EXTERNAL_API_KEY=zhinian_bk

FRONTEND_PUBLIC_URL=
AUTO_START_CRAWL_JOBS=true
REMOTE_OFFICIAL_BASE_URL=https://xy.zhinianboke.com
ENABLE_REMOTE_ADS=true
ENABLE_REMOTE_ANNOUNCEMENTS=true
ENABLE_REMOTE_POPUP_ANNOUNCEMENTS=true
ENVEOF
    echo -e "${GREEN}✓ 已生成 .env 文件${NC}"
    echo -e "${YELLOW}[提示] 如需修改配置（如端口等），请编辑 $ENV_FILE 后重新运行${NC}"
    echo ""
fi

# ========== 创建挂载目录 ==========
mkdir -p \
    "$WORK_DIR/xianyu_auto_reply/mysql/data" \
    "$WORK_DIR/xianyu_auto_reply/redis/data" \
    "$WORK_DIR/xianyu_auto_reply/logs/backend_web" \
    "$WORK_DIR/xianyu_auto_reply/logs/websocket" \
    "$WORK_DIR/xianyu_auto_reply/logs/scheduler" \
    "$WORK_DIR/xianyu_auto_reply/static" \
    "$WORK_DIR/xianyu_auto_reply/backups" \
    "$WORK_DIR/xianyu_auto_reply/browser_data"

# ========== 部署 ==========
echo -e "${YELLOW}步骤 1/3: 从源码构建镜像（首次较慢，请耐心等待）...${NC}"
$DC_CMD build
echo -e "${GREEN}✓ 镜像构建完成${NC}"

echo ""
echo -e "${YELLOW}步骤 2/3: 停止旧容器（仅本项目）...${NC}"
$DC_CMD down 2>/dev/null || true
echo -e "${GREEN}✓ 旧容器已清理${NC}"

echo ""
echo -e "${YELLOW}步骤 3/3: 启动服务...${NC}"
$DC_CMD up -d
echo -e "${GREEN}✓ 服务已启动${NC}"

echo ""
echo "[信息] 等待服务启动..."
sleep 15
$DC_CMD ps

frontend_port=$(grep -E "^FRONTEND_PORT=" "$ENV_FILE" 2>/dev/null | cut -d '=' -f2 | tr -d '\r' || echo "9000")
backend_web_port=$(grep -E "^BACKEND_WEB_PORT=" "$ENV_FILE" 2>/dev/null | cut -d '=' -f2 | tr -d '\r' || echo "8089")
websocket_port=$(grep -E "^WEBSOCKET_PORT=" "$ENV_FILE" 2>/dev/null | cut -d '=' -f2 | tr -d '\r' || echo "8090")
scheduler_port=$(grep -E "^SCHEDULER_PORT=" "$ENV_FILE" 2>/dev/null | cut -d '=' -f2 | tr -d '\r' || echo "8091")

frontend_port="${frontend_port:-9000}"
backend_web_port="${backend_web_port:-8089}"
websocket_port="${websocket_port:-8090}"
scheduler_port="${scheduler_port:-8091}"

echo ""
echo -e "${GREEN}=========================================="
echo "  部署完成！（已移除滑动验证）"
echo "==========================================${NC}"
echo ""
echo "服务访问地址："
echo "  前端:        http://服务器IP:${frontend_port}"
echo "  Backend-Web: http://服务器IP:${backend_web_port}"
echo "  WebSocket:   http://服务器IP:${websocket_port}"
echo "  Scheduler:   http://服务器IP:${scheduler_port}"
echo ""
echo "常用命令："
echo "  查看日志: $DC_CMD logs -f"
echo "  停止服务: $DC_CMD down"
echo "  重启服务: $DC_CMD restart"
echo "  重新构建: $DC_CMD up -d --build"
echo ""
echo "默认管理员账号: admin / admin123"
echo ""