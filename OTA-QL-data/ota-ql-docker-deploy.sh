#!/bin/bash

###############################################################################
# OTA-QL Docker 自动部署与管理脚本
# 文件名: ota-ql-docker-deploy.sh
# 用途: 首次部署、滚动更新、备份恢复、密码重置、存储卷检查、日志管理、SSL证书管理
# 作者: WiseFido Technologies
# 版本: v5.2
# 更新: 2026-03-08
#
# 一键部署（推荐）:
#   wget -O ota-ql-docker-deploy.sh "https://raw.githubusercontent.com/hhtbing-wisefido/public-data/main/OTA-QL-data/ota-ql-docker-deploy.sh" && chmod +x ota-ql-docker-deploy.sh && sudo ./ota-ql-docker-deploy.sh
#
# 服务端口（v4.6 五端口架构）:
#   HTTPS 10088 — Web管理面板 + API + 固件下载（统一HTTPS）
#   HTTP  10089 — ESP32 OTA明文固件下载
#   GW    10086 — cmux设备网关（TCP+TLS自动识别）
#   MQTT   1883 — MQTT Broker（明文）
#   MQTTS  8883 — MQTT Broker（TLS加密）
###############################################################################

# ============================================================================
# 颜色与格式
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'

# ============================================================================
# 配置变量
# ============================================================================
IMAGE_NAME="ghcr.io/hhtbing-wisefido/ota-ql:latest"
CONTAINER_NAME="ota-ql"
DATA_DIR="/opt/ota-ql"
FIRMWARE_DIR="${DATA_DIR}/firmware"
APP_DATA_DIR="${DATA_DIR}/data"
CERTS_DIR="${DATA_DIR}/certs"
LOGS_DIR="${DATA_DIR}/logs"
DEPLOY_MODE_FILE="${DATA_DIR}/.deploy_mode"
CALLBACK_ADDR_FILE="${DATA_DIR}/.callback_addr"
BACKUP_BASE_DIR="/backup/ota-ql"
BACKUP_LIST_FILE="${BACKUP_BASE_DIR}/.backup_list"

# 服务端口（v4.6 五端口架构）
HTTPS_PORT="10088"       # Web管理面板 + API + 固件下载（统一HTTPS）
HTTP_FW_PORT="10089"     # v4.6: ESP32 OTA明文固件下载
GW_PORT="10086"          # cmux设备网关（TCP+TLS自动识别）
MQTT_PORT="1883"         # MQTT Broker（明文）
MQTTS_PORT="8883"        # MQTT Broker（TLS加密）

# 环境变量覆盖（OTA_SERVER_ADDR 优先级最高，其次是下面的默认值，留空则自动检测本机IP）
SERVER_ADDR="${OTA_SERVER_ADDR:-}"
LOG_LEVEL="${OTA_LOG_LEVEL:-info}"

# ============================================================================
# SSL 证书搜索路径数据库（支持多种面板和发行版）
# ============================================================================
# 格式: "面板名称|证书路径模板|私钥路径模板"
# <DOMAIN> 占位符将被替换为实际域名
CERT_SEARCH_PATHS=(
    "宝塔面板(BaoTa)|/www/server/panel/vhost/cert/<DOMAIN>/fullchain.pem|/www/server/panel/vhost/cert/<DOMAIN>/privkey.pem"
    "宝塔面板(SSL)|/www/server/panel/vhost/ssl/<DOMAIN>/fullchain.pem|/www/server/panel/vhost/ssl/<DOMAIN>/privkey.pem"
    "1Panel|/opt/1panel/core/apps/openresty/openresty/www/sites/<DOMAIN>/ssl/fullchain.pem|/opt/1panel/core/apps/openresty/openresty/www/sites/<DOMAIN>/ssl/privkey.pem"
    "1Panel(Nginx)|/opt/1panel/core/apps/nginx/nginx/www/sites/<DOMAIN>/ssl/fullchain.pem|/opt/1panel/core/apps/nginx/nginx/www/sites/<DOMAIN>/ssl/privkey.pem"
    "aaPanel|/www/server/panel/vhost/cert/<DOMAIN>/fullchain.pem|/www/server/panel/vhost/cert/<DOMAIN>/privkey.pem"
    "Let's Encrypt(Certbot)|/etc/letsencrypt/live/<DOMAIN>/fullchain.pem|/etc/letsencrypt/live/<DOMAIN>/privkey.pem"
    "acme.sh|/root/.acme.sh/<DOMAIN>/fullchain.cer|/root/.acme.sh/<DOMAIN>/<DOMAIN>.key"
    "acme.sh(ECC)|/root/.acme.sh/<DOMAIN>_ecc/fullchain.cer|/root/.acme.sh/<DOMAIN>_ecc/<DOMAIN>.key"
    "CyberPanel|/etc/letsencrypt/live/<DOMAIN>/fullchain.pem|/etc/letsencrypt/live/<DOMAIN>/privkey.pem"
    "AppNode|/usr/local/appnode/nginx/conf/ssl/<DOMAIN>/fullchain.pem|/usr/local/appnode/nginx/conf/ssl/<DOMAIN>/privkey.pem"
    "Nginx默认|/etc/nginx/ssl/<DOMAIN>/fullchain.pem|/etc/nginx/ssl/<DOMAIN>/privkey.pem"
    "Nginx(conf.d)|/etc/nginx/conf.d/ssl/<DOMAIN>/fullchain.pem|/etc/nginx/conf.d/ssl/<DOMAIN>/privkey.pem"
    "Apache(Debian)|/etc/apache2/ssl/<DOMAIN>/fullchain.pem|/etc/apache2/ssl/<DOMAIN>/privkey.pem"
    "Apache(RHEL)|/etc/httpd/ssl/<DOMAIN>/fullchain.pem|/etc/httpd/ssl/<DOMAIN>/privkey.pem"
    "Caddy|/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/<DOMAIN>/<DOMAIN>.crt|/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/<DOMAIN>/<DOMAIN>.key"
    "cPanel|/var/cpanel/ssl/installed/certs/<DOMAIN>.crt|/var/cpanel/ssl/installed/keys/<DOMAIN>.key"
    "Plesk|/usr/local/psa/var/certificates/<DOMAIN>/fullchain.pem|/usr/local/psa/var/certificates/<DOMAIN>/privkey.pem"
)

# ============================================================================
# 日志函数
# ============================================================================
log_info()     { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success()  { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning()  { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()    { echo -e "${RED}[ERROR]${NC} $1"; }
log_highlight(){ echo -e "${CYAN}$1${NC}"; }

# ============================================================================
# 基础检查函数
# ============================================================================

check_docker() {
    log_info "检查Docker服务状态..."
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker服务未运行或无权限访问"
        echo ""
        echo "解决方案:"
        echo "  1. 启动Docker: sudo systemctl start docker"
        echo "  2. 用sudo运行: sudo ./deploy.sh"
        exit 1
    fi
    log_success "Docker服务正常"
}

check_container_installed() {
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo ""
        log_error "OTA-QL 尚未安装！"
        echo ""
        echo "请先选择菜单 [1. 一键部署] 进行安装"
        echo ""
        return 1
    fi
    return 0
}

check_container_running() {
    if ! check_container_installed; then
        return 1
    fi
    if ! docker ps --filter "name=${CONTAINER_NAME}" --filter "status=running" | grep -q "${CONTAINER_NAME}"; then
        echo ""
        log_warning "容器已停止，正在尝试启动..."
        docker start ${CONTAINER_NAME} 2>/dev/null
        sleep 3
        if ! docker ps --filter "name=${CONTAINER_NAME}" --filter "status=running" | grep -q "${CONTAINER_NAME}"; then
            log_error "容器启动失败！"
            echo "  查看日志: docker logs --tail 50 ${CONTAINER_NAME}"
            return 1
        fi
        log_success "容器已启动"
    fi
    return 0
}

# ============================================================================
# 部署类型检测
# ============================================================================

detect_deployment_type() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "update"
    else
        echo "fresh"
    fi
}

# ============================================================================
# 部署核心流程
# ============================================================================

create_data_directories() {
    log_info "检查数据目录..."
    for dir in "${DATA_DIR}" "${FIRMWARE_DIR}" "${APP_DATA_DIR}" "${CERTS_DIR}" "${LOGS_DIR}"; do
        if [ ! -d "${dir}" ]; then
            log_info "创建目录: ${dir}"
            mkdir -p "${dir}"
            chmod 755 "${dir}"
        fi
    done
    log_success "数据目录就绪"
}

backup_current_image() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        local CURRENT_IMAGE=$(docker inspect --format='{{.Config.Image}}' ${CONTAINER_NAME} 2>/dev/null)
        local CURRENT_IMAGE_ID=$(docker inspect --format='{{.Image}}' ${CONTAINER_NAME} 2>/dev/null)
        if [ -n "${CURRENT_IMAGE}" ]; then
            log_info "记录当前镜像: ${CURRENT_IMAGE} (${CURRENT_IMAGE_ID:7:12})"
            echo "$(date '+%Y-%m-%d %H:%M:%S') | ${CURRENT_IMAGE} | ${CURRENT_IMAGE_ID:7:12}" >> "${DATA_DIR}/.image_history"
        fi
    fi
}

stop_old_container() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_info "停止旧容器: ${CONTAINER_NAME}"
        docker stop ${CONTAINER_NAME} 2>/dev/null || true
        log_info "删除旧容器: ${CONTAINER_NAME}"
        docker rm ${CONTAINER_NAME} 2>/dev/null || true
        log_success "旧容器已清理"
    else
        log_info "无旧容器需要清理"
    fi
}

pull_latest_image() {
    log_info "拉取最新镜像: ${IMAGE_NAME}"
    if docker pull ${IMAGE_NAME}; then
        log_success "镜像拉取成功"
    else
        log_error "镜像拉取失败"
        echo ""
        echo "可能原因:"
        echo "  1. 网络问题 — 检查服务器网络"
        echo "  2. 认证失败 — 私有仓库需要 docker login ghcr.io"
        echo "  3. 镜像不存在 — 确认 GitHub Actions 已构建成功"
        echo ""
        echo "手动认证: echo YOUR_TOKEN | docker login ghcr.io -u hhtbing-wisefido --password-stdin"
        return 1
    fi
}

# 端口冲突检测（区分自身服务与外部服务）
check_port_conflicts() {
    local SELF_CONFLICT=false
    local EXT_CONFLICT=false
    local PORTS=("${HTTPS_PORT}" "${HTTP_FW_PORT}" "${GW_PORT}" "${MQTT_PORT}" "${MQTTS_PORT}")
    local NAMES=("HTTPS统一" "HTTP固件" "cmux网关" "MQTT" "MQTTS")

    log_info "检查端口占用..."
    for i in "${!PORTS[@]}"; do
        local PORT="${PORTS[$i]}"
        local NAME="${NAMES[$i]}"
        # 使用 ss 或 netstat 检测端口
        local IN_USE=false
        if command -v ss &>/dev/null; then
            if ss -tlnp 2>/dev/null | grep -qE ":${PORT}\b"; then
                IN_USE=true
            fi
        elif command -v netstat &>/dev/null; then
            if netstat -tlnp 2>/dev/null | grep -qE ":${PORT}\b"; then
                IN_USE=true
            fi
        fi

        if $IN_USE; then
            local OCCUPIER=$(ss -tlnp 2>/dev/null | grep -E ":${PORT}\b" | head -1 | sed -n 's/.*users:(("\([^"]*\)".*/\1/p')
            [ -z "$OCCUPIER" ] && OCCUPIER="未知进程"

            # 判断是否是 ota-ql 自身容器占用（docker-proxy 映射或容器名匹配）
            local IS_SELF=false
            if echo "$OCCUPIER" | grep -qiE "docker-proxy|docker"; then
                # docker-proxy 占用 = 可能是 ota-ql 自身容器的端口映射
                local CONTAINER_PORT_CHECK=$(docker port ${CONTAINER_NAME} 2>/dev/null | grep -E ":${PORT}$" || true)
                if [ -n "$CONTAINER_PORT_CHECK" ]; then
                    IS_SELF=true
                fi
            fi

            if $IS_SELF; then
                SELF_CONFLICT=true
                echo -e "  ${YELLOW}⚡${NC} 端口 ${PORT} (${NAME}) — ota-ql 自身容器占用（将自动释放）"
            else
                EXT_CONFLICT=true
                echo -e "  ${RED}✗${NC} 端口 ${PORT} (${NAME}) — 已被 ${OCCUPIER} 占用"
            fi
        else
            echo -e "  ${GREEN}✓${NC} 端口 ${PORT} (${NAME}) — 可用"
        fi
    done

    # 自身容器冲突: 仅提示，自动继续（后续 stop_old_container 会释放端口）
    if $SELF_CONFLICT && ! $EXT_CONFLICT; then
        echo ""
        log_info "检测到 ota-ql 自身容器占用端口，后续步骤会自动停止旧容器并释放端口"
        log_success "端口检查通过（自身占用可忽略）"
        return 0
    fi

    # 外部服务冲突: 需要用户确认
    if $EXT_CONFLICT; then
        echo ""
        log_error "存在端口冲突！其他服务占用了 ota-ql 需要的端口"
        echo ""
        echo "解决方案:"
        echo "  1. 停止占用端口的服务: sudo systemctl stop <服务名>"
        echo "  2. 查看占用详情: sudo ss -tlnp | grep -E '10088|10089|10086|1883|8883'"
        echo "  3. 或修改本脚本中的端口变量后重试"
        echo ""
        read -p "是否强制继续部署？(可能失败) [y/N]: " FORCE
        if [[ ! "$FORCE" =~ ^[Yy]$ ]]; then
            log_info "部署已取消，请先释放端口后重试"
            return 1
        fi
        log_warning "用户选择强制继续..."
    else
        log_success "所有端口可用"
    fi
    return 0
}

# 启动新容器
# 参数: $1 = 部署模式 (production 或 test)
# 生产模式: 设备网关/MQTT 绑定 0.0.0.0 (设备直连), HTTPS管理 绑定 127.0.0.1 (反代)
# 测试模式: 全部绑定 0.0.0.0
start_new_container() {
    local MODE="${1:-production}"
    log_info "启动新容器..."

    if [ "$MODE" = "test" ]; then
        log_info "端口绑定模式: 0.0.0.0 (全部暴露)"
        local HTTPS_BIND="0.0.0.0"
        local GW_BIND="0.0.0.0"
        local MQTT_BIND="0.0.0.0"
        local MQTTS_BIND="0.0.0.0"
    else
        log_info "端口绑定模式: 混合 (GW/MQTT/MQTTS=0.0.0.0, HTTPS管理=127.0.0.1)"
        local HTTPS_BIND="127.0.0.1"  # Web管理/API/固件走反代
        local GW_BIND="0.0.0.0"       # cmux设备网关，设备直连必须暴露
        local MQTT_BIND="0.0.0.0"     # MQTT设备直连，必须暴露
        local MQTTS_BIND="0.0.0.0"    # MQTTS设备直连，必须暴露
    fi

    local ENV_ARGS=""
    if [ -n "${SERVER_ADDR}" ]; then
        ENV_ARGS="-e OTA_SERVER_ADDR=${SERVER_ADDR}"
    fi

    # v5.0: 自动检测并加载TLS证书（解决ESP32 esp-x509-crt-bundle验证自签名证书失败）
    # 证书用于: cmux设备网关(10086) + MQTTS(8883) + HTTPS(10088) 的TLS握手
    # 宝塔Nginx的证书只管浏览器访问，设备直连端口需要Go服务器自己的证书
    # 证书由 deploy_container() → auto_detect_and_deploy_certs() 自动搜索部署
    local TLS_ENV_ARGS=""
    local CERT_FILE="${CERTS_DIR}/fullchain.pem"
    local KEY_FILE="${CERTS_DIR}/privkey.pem"
    if [ -f "${CERT_FILE}" ] && [ -f "${KEY_FILE}" ]; then
        TLS_ENV_ARGS="-e OTA_TLS_CERT_FILE=/app/certs/fullchain.pem -e OTA_TLS_KEY_FILE=/app/certs/privkey.pem"
        log_success "检测到TLS证书: ${CERT_FILE}"
        log_info "Go服务器将使用CA签名证书（ESP32设备可通过证书验证）"
    else
        log_warning "未检测到TLS证书文件: ${CERT_FILE}"
        log_warning "Go服务器将使用自签名证书（ESP32设备可能无法通过证书验证）"
        echo ""
        echo -e "  ${YELLOW}如需ESP32设备正常连接，请使用菜单 [11. SSL证书管理] 配置证书${NC}"
        echo ""
    fi

    docker run -d \
        --name ${CONTAINER_NAME} \
        --restart unless-stopped \
        -p ${HTTPS_BIND}:${HTTPS_PORT}:10088 \
        -p ${HTTP_FW_BIND}:${HTTP_FW_PORT}:10089 \
        -p ${GW_BIND}:${GW_PORT}:10086 \
        -p ${MQTT_BIND}:${MQTT_PORT}:1883 \
        -p ${MQTTS_BIND}:${MQTTS_PORT}:8883 \
        -v ${FIRMWARE_DIR}:/app/firmware \
        -v ${APP_DATA_DIR}:/app/data \
        -v ${CERTS_DIR}:/app/certs:ro \
        -v ${LOGS_DIR}:/app/logs \
        ${ENV_ARGS} \
        ${TLS_ENV_ARGS} \
        --health-cmd="wget -q --no-check-certificate --spider https://localhost:10088/api/health || exit 1" \
        --health-interval=30s \
        --health-timeout=5s \
        --health-retries=3 \
        --health-start-period=10s \
        ${IMAGE_NAME}

    if [ $? -eq 0 ]; then
        log_success "容器启动成功: ${CONTAINER_NAME}"
    else
        log_error "容器启动失败"
        return 1
    fi
}

health_check() {
    log_info "等待服务启动..."
    sleep 3

    log_info "执行健康检查（HTTPS API + 设备网关）..."
    local MAX_RETRIES=20
    local RETRY_COUNT=0
    local API_OK=false
    local GW_OK=false

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        # 检查容器是否还在运行
        if ! docker ps --filter "name=${CONTAINER_NAME}" --filter "status=running" | grep -q "${CONTAINER_NAME}"; then
            log_error "容器未运行！"
            echo "  查看日志: docker logs --tail 50 ${CONTAINER_NAME}"
            return 1
        fi

        # 检查 HTTPS API 端点
        if ! $API_OK; then
            if curl -skf https://localhost:${HTTPS_PORT}/api/health > /dev/null 2>&1; then
                API_OK=true
            fi
        fi

        # 检查 cmux 设备网关端口
        if ! $GW_OK; then
            if (echo > /dev/tcp/localhost/${GW_PORT}) 2>/dev/null; then
                GW_OK=true
            fi
        fi

        # 两个都通过则成功
        if $API_OK && $GW_OK; then
            echo ""
            echo -e "  ${GREEN}✓${NC} HTTPS API (${HTTPS_PORT})  — 正常"
            echo -e "  ${GREEN}✓${NC} 设备网关  (${GW_PORT})  — 正常"
            echo ""
            log_success "健康检查全部通过 ✓"
            return 0
        fi

        RETRY_COUNT=$((RETRY_COUNT + 1))
        log_info "健康检查中... ($RETRY_COUNT/$MAX_RETRIES)"
        sleep 3
    done

    echo ""
    if $API_OK; then
        echo -e "  ${GREEN}✓${NC} HTTPS API (${HTTPS_PORT})  — 正常"
    else
        echo -e "  ${RED}✗${NC} HTTPS API (${HTTPS_PORT})  — 失败"
    fi
    if $GW_OK; then
        echo -e "  ${GREEN}✓${NC} 设备网关  (${GW_PORT})  — 正常"
    else
        echo -e "  ${RED}✗${NC} 设备网关  (${GW_PORT})  — 失败"
    fi
    echo ""
    log_error "健康检查超时（部分服务未通过）"
    echo "  查看容器日志: docker logs --tail 100 ${CONTAINER_NAME}"
    return 1
}

show_container_status() {
    echo ""
    echo "[容器状态]"
    docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
    echo ""
}

# ============================================================================
# 密码管理函数
# ============================================================================

# 检测密码是否已修改
# 通过 admin.json 文件的修改时间 vs 创建时间判断
check_password_changed() {
    local ADMIN_FILE="${APP_DATA_DIR}/admin.json"
    if [ ! -f "${ADMIN_FILE}" ]; then
        echo "no_file"
        return
    fi
    # 检查文件是否近期被修改过（对比创建时间与修改时间）
    local FILE_SIZE=$(stat -c%s "${ADMIN_FILE}" 2>/dev/null || echo "0")
    if [ "${FILE_SIZE}" -gt 500 ]; then
        # 文件较大 = 可能添加了用户或修改过密码
        echo "likely_changed"
    else
        echo "default"
    fi
}

# 从容器日志获取最后一次生成的初始密码
get_current_password() {
    local PASSWORD=""
    PASSWORD=$(docker logs ${CONTAINER_NAME} 2>&1 | grep "初始密码:" | tail -n 1 | sed 's/.*初始密码: //' | xargs 2>/dev/null)
    echo "${PASSWORD}"
}

show_initial_password() {
    local IS_FIRST="${1:-false}"

    if [ "$IS_FIRST" != "true" ]; then
        return
    fi

    echo ""
    echo "=========================================="
    log_highlight "🔐 首次部署 — 管理员初始凭据"
    echo "=========================================="
    echo ""
    log_info "等待系统初始化..."
    sleep 5

    local INIT_PASSWORD=$(get_current_password)

    if [ -n "$INIT_PASSWORD" ] && [ "$INIT_PASSWORD" != "" ]; then
        echo ""
        echo "┌────────────────────────────────────────────┐"
        echo "│  🔐 管理员初始登录凭据（仅显示一次！）     │"
        echo "├────────────────────────────────────────────┤"
        log_highlight "│  👤 用户名: admin"
        log_highlight "│  🔑 密码:   ${INIT_PASSWORD}"
        echo "├────────────────────────────────────────────┤"
        echo -e "│  ${RED}⚠️  请立即记录此密码！此后不再显示${NC}      │"
        echo -e "│  ${YELLOW}⚠️  首次登录Web管理面板后请立即修改密码${NC} │"
        echo "├────────────────────────────────────────────┤"
        echo -e "│  ${GREEN}管理面板: https://localhost:${HTTPS_PORT}/${NC}      │"
        echo "└────────────────────────────────────────────┘"
        echo ""
        echo -e "${RED}🔴 安全提示: 如忘记密码，请使用菜单 [4. 重置管理员密码]${NC}"
        echo ""
    else
        log_warning "无法自动获取初始密码"
        echo "  如需重置: 使用菜单选项 [4. 重置管理员密码]"
    fi
}

# 在摘要中智能显示密码信息（不再显示明文密码）
show_password_info() {
    local PWD_STATUS=$(check_password_changed)

    case $PWD_STATUS in
        "no_file")
            echo -e "  ${YELLOW}!${NC} 管理员配置: 未初始化（等待首次启动）"
            ;;
        "likely_changed")
            echo -e "  ${GREEN}✓${NC} 管理员密码: 已修改（安全）"
            ;;
        "default")
            echo -e "  ${YELLOW}!${NC} 管理员密码: ${RED}未修改！请尽快登录Web管理面板修改密码${NC}"
            echo -e "  ${YELLOW}!${NC} 如忘记初始密码，请使用菜单 [4. 重置管理员密码]"
            ;;
    esac
}

cleanup_old_images() {
    log_info "清理悬空镜像..."
    local DANGLING=$(docker images -f "dangling=true" -q)
    if [ -n "$DANGLING" ]; then
        docker rmi $DANGLING 2>/dev/null || true
        log_success "悬空镜像已清理"
    else
        log_info "无需清理"
    fi
}

get_deploy_mode() {
    if [ -f "${DEPLOY_MODE_FILE}" ]; then
        cat "${DEPLOY_MODE_FILE}"
    else
        echo "unknown"
    fi
}

save_deploy_mode() {
    echo "$1" > "${DEPLOY_MODE_FILE}"
}

# ============================================================================
# 设备回调地址管理
# ============================================================================

# 读取已保存的设备回调地址
get_callback_addr() {
    if [ -f "${CALLBACK_ADDR_FILE}" ]; then
        cat "${CALLBACK_ADDR_FILE}" | tr -d '\n\r'
    else
        echo ""
    fi
}

# 保存设备回调地址
save_callback_addr() {
    echo "$1" > "${CALLBACK_ADDR_FILE}"
}

# 交互式输入设备回调地址（部署时和菜单中复用）
prompt_callback_addr() {
    local CURRENT_ADDR=$(get_callback_addr)

    echo ""
    echo "========================================="
    echo "  设备回调地址设置/修改"
    echo "========================================="
    echo ""
    echo "什么是设备回调地址？"
    echo "  设备通过网关(:${GW_PORT})连接服务器并认证后，"
    echo "  服务器会返回此地址告诉设备："
    echo "    1. MQTT Broker 连接到哪里 (此地址:${MQTTS_PORT})"
    echo "    2. OTA 固件从哪里下载 (http://此地址:${HTTP_FW_PORT}/firmware)"
    echo ""
    echo "  简单理解：设备认证后\"回拨\"到这个地址获取服务"
    echo ""
    echo "地址格式：域名(推荐) 或 IP 均可"
    echo "  域名示例: ota.wisefido.com"
    echo "  IP示例:   166.1.190.154"
    echo ""

    if [ -n "${CURRENT_ADDR}" ]; then
        log_info "当前设备回调地址: ${CURRENT_ADDR}"
        read -p "输入新地址 (回车保留当前值): " NEW_ADDR
        if [ -z "${NEW_ADDR}" ]; then
            NEW_ADDR="${CURRENT_ADDR}"
            log_info "保留当前地址: ${NEW_ADDR}"
        fi
    else
        log_warning "尚未配置设备回调地址"
        read -p "请输入设备回调地址 (域名或IP): " NEW_ADDR
        if [ -z "${NEW_ADDR}" ]; then
            log_warning "未输入地址，将使用服务器自动检测IP"
            return 0
        fi
    fi

    save_callback_addr "${NEW_ADDR}"
    SERVER_ADDR="${NEW_ADDR}"
    log_success "设备回调地址已设置: ${NEW_ADDR}"
    return 0
}

# 查看设备回调地址详情
show_callback_addr() {
    local CB_ADDR=$(get_callback_addr)
    echo ""
    echo "========================================="
    echo "  设备回调地址查看"
    echo "========================================="
    echo ""

    if [ -n "${CB_ADDR}" ]; then
        echo -e "  ${GREEN}✓${NC} 回调地址:   ${CB_ADDR}"
        echo ""
        echo "  派生服务地址:"
        echo "  ────────────────────────────────────"
        echo "  MQTT Broker:  ${CB_ADDR}:${MQTTS_PORT} (MQTTS/TLS)"
        echo "  MQTT明文:     ${CB_ADDR}:${MQTT_PORT} (MQTT)"
        echo "  固件下载:     http://${CB_ADDR}:${HTTP_FW_PORT}/firmware"
        echo ""
        echo "  存储位置: ${CALLBACK_ADDR_FILE}"
        echo "  环境变量: OTA_SERVER_ADDR=${CB_ADDR}"
    else
        log_warning "尚未配置设备回调地址"
        echo ""
        echo "  服务器将使用自动检测的公网IP作为回调地址"
        local AUTO_IP=$(get_public_ip)
        if [ -n "${AUTO_IP}" ]; then
            echo -e "  自动检测IP: ${YELLOW}${AUTO_IP}${NC}"
        else
            echo -e "  ${RED}!${NC} 无法自动检测公网IP"
        fi
        echo ""
        echo "  建议通过菜单 10 → 1 设置域名或固定IP"
    fi
    echo ""
}

# 设置设备回调地址（含重启Docker选项）
set_callback_addr_with_restart() {
    prompt_callback_addr

    local NEW_ADDR=$(get_callback_addr)
    if [ -z "${NEW_ADDR}" ]; then
        return 0
    fi

    # 检查容器是否在运行，提示重启
    if docker ps --filter "name=${CONTAINER_NAME}" --filter "status=running" | grep -q "${CONTAINER_NAME}"; then
        echo ""
        log_warning "设备回调地址是容器启动时的环境变量，修改后需要重启容器才能生效"
        read -p "是否立即重启容器？[Y/n]: " RESTART
        if [[ ! "$RESTART" =~ ^[Nn]$ ]]; then
            log_info "正在重启容器..."
            docker stop ${CONTAINER_NAME} > /dev/null 2>&1
            docker rm ${CONTAINER_NAME} > /dev/null 2>&1

            # 读取当前部署模式重新启动
            local CURRENT_MODE=$(get_deploy_mode)
            if [ "${CURRENT_MODE}" = "unknown" ]; then
                CURRENT_MODE="production"
            fi
            SERVER_ADDR="${NEW_ADDR}"
            start_new_container "${CURRENT_MODE}"
            sleep 3

            if docker ps --filter "name=${CONTAINER_NAME}" --filter "status=running" | grep -q "${CONTAINER_NAME}"; then
                log_success "容器已重启，新的设备回调地址已生效: ${NEW_ADDR}"
            else
                log_error "容器重启失败，请检查日志: docker logs --tail 50 ${CONTAINER_NAME}"
            fi
        else
            log_warning "容器未重启，新地址将在下次部署时生效"
        fi
    else
        log_info "容器未运行，新地址将在下次部署时生效"
    fi
}

# 菜单: 设备回调地址设置与查看（含子菜单）
menu_set_callback_addr() {
    echo ""
    echo "========================================="
    echo "  设备回调地址设置与查看"
    echo "========================================="
    echo ""
    echo "  1. 设置/修改设备回调地址"
    echo "  2. 查看当前设备回调地址"
    echo "  0. 返回主菜单"
    echo ""
    read -p "请选择 [0-2]: " sub_choice

    case $sub_choice in
        1)
            set_callback_addr_with_restart
            ;;
        2)
            show_callback_addr
            ;;
        0)
            return 0
            ;;
        *)
            log_warning "无效选择"
            ;;
    esac
}

# ============================================================================
# SSL 证书自动搜索与管理（v5.0 新增）
# ============================================================================

# 从回调地址或用户输入提取域名列表
# 返回: 空格分隔的域名列表（排除IP地址）
get_domains_for_cert() {
    local domains=()

    # 优先从回调地址文件读取
    local cb_addr=$(get_callback_addr)
    if [ -n "$cb_addr" ]; then
        # 排除纯IP地址，只取域名
        if ! echo "$cb_addr" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
            domains+=("$cb_addr")
        fi
    fi

    echo "${domains[*]}"
}

# 搜索指定域名的SSL证书
# 参数: $1 = 域名
# 返回: 找到的证书路径列表（存入全局数组 FOUND_CERTS）
# FOUND_CERTS 格式: "面板名称|证书路径|私钥路径"
search_certs_for_domain() {
    local domain="$1"
    FOUND_CERTS=()

    if [ -z "$domain" ]; then
        return 1
    fi

    log_info "搜索域名 ${domain} 的SSL证书..."
    echo ""

    # v5.1: 全局去重数组 — 按真实路径(realpath)去重，避免同一文件被不同面板名称重复报告
    # 根因: 宝塔/aaPanel共用cert/路径; ssl/通常是cert/的软链接
    local seen_real_paths=()

    local found_count=0
    for entry in "${CERT_SEARCH_PATHS[@]}"; do
        local panel_name=$(echo "$entry" | cut -d'|' -f1)
        local cert_template=$(echo "$entry" | cut -d'|' -f2)
        local key_template=$(echo "$entry" | cut -d'|' -f3)

        # 替换 <DOMAIN> 占位符
        local cert_path="${cert_template//<DOMAIN>/$domain}"
        local key_path="${key_template//<DOMAIN>/$domain}"

        if [ -f "$cert_path" ] && [ -f "$key_path" ]; then
            # v5.1 去重: 解析软链接后获取真实路径，跳过重复
            local real_cert=$(realpath "$cert_path" 2>/dev/null || readlink -f "$cert_path" 2>/dev/null || echo "$cert_path")
            local real_key=$(realpath "$key_path" 2>/dev/null || readlink -f "$key_path" 2>/dev/null || echo "$key_path")
            local dedup_key="${real_cert}|${real_key}"

            local is_dup=false
            for seen in "${seen_real_paths[@]}"; do
                if [ "$seen" = "$dedup_key" ]; then
                    is_dup=true
                    break
                fi
            done
            if [ "$is_dup" = "true" ]; then
                continue  # 跳过重复路径（不同面板名称指向同一文件）
            fi
            seen_real_paths+=("$dedup_key")

            found_count=$((found_count + 1))
            FOUND_CERTS+=("${panel_name}|${cert_path}|${key_path}")

            # 获取证书信息
            local cert_expiry=""
            local cert_cn=""
            local cert_sans=""
            if command -v openssl &> /dev/null; then
                cert_expiry=$(openssl x509 -in "$cert_path" -noout -enddate 2>/dev/null | sed 's/notAfter=//')
                cert_cn=$(openssl x509 -in "$cert_path" -noout -subject 2>/dev/null | sed 's/.*CN\s*=\s*//' | cut -d'/' -f1)
                cert_sans=$(openssl x509 -in "$cert_path" -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/DNS://g; s/,//g; s/^\s*//')
            fi

            echo -e "  ${GREEN}✓${NC} [${found_count}] ${panel_name}"
            echo -e "      证书: ${cert_path}"
            echo -e "      私钥: ${key_path}"
            if [ -n "$cert_cn" ]; then
                echo -e "      域名: ${cert_cn}"
            fi
            if [ -n "$cert_sans" ]; then
                echo -e "      SAN:  ${cert_sans}"
            fi
            if [ -n "$cert_expiry" ]; then
                # 检查是否即将过期（30天内）
                local expiry_epoch=$(date -d "$cert_expiry" +%s 2>/dev/null || echo "0")
                local now_epoch=$(date +%s)
                local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
                if [ "$days_left" -lt 0 ]; then
                    echo -e "      过期: ${RED}已过期!${NC}"
                elif [ "$days_left" -lt 30 ]; then
                    echo -e "      过期: ${YELLOW}${cert_expiry} (仅剩${days_left}天!)${NC}"
                else
                    echo -e "      过期: ${GREEN}${cert_expiry} (${days_left}天)${NC}"
                fi
            fi
            echo ""
        fi
    done

    # 额外: 通配符搜索常见目录（兜底）
    local extra_dirs=(
        "/www/server/panel/vhost/cert"
        "/www/server/panel/vhost/ssl"
        "/etc/letsencrypt/live"
        "/root/.acme.sh"
        "/etc/nginx/ssl"
        "/opt/1panel"
    )
    for search_dir in "${extra_dirs[@]}"; do
        if [ -d "$search_dir" ]; then
            # 搜索包含域名的证书文件
            local extra_certs=$(find "$search_dir" -name "fullchain.pem" -o -name "fullchain.cer" -o -name "*.crt" 2>/dev/null | grep -i "$domain" 2>/dev/null)
            for extra_cert in $extra_certs; do
                # v5.1: 用realpath去重（替代旧的字符串匹配）
                local real_extra=$(realpath "$extra_cert" 2>/dev/null || readlink -f "$extra_cert" 2>/dev/null || echo "$extra_cert")
                local already_found=false
                for seen in "${seen_real_paths[@]}"; do
                    if echo "$seen" | grep -q "^${real_extra}|"; then
                        already_found=true
                        break
                    fi
                done
                if [ "$already_found" = "false" ]; then
                    local extra_dir=$(dirname "$extra_cert")
                    local extra_key=""
                    # 尝试找配对私钥
                    for key_name in "privkey.pem" "*.key" "${domain}.key"; do
                        local possible_key=$(find "$extra_dir" -name "$key_name" 2>/dev/null | head -1)
                        if [ -n "$possible_key" ] && [ -f "$possible_key" ]; then
                            extra_key="$possible_key"
                            break
                        fi
                    done
                    if [ -n "$extra_key" ]; then
                        local real_extra_key=$(realpath "$extra_key" 2>/dev/null || readlink -f "$extra_key" 2>/dev/null || echo "$extra_key")
                        local extra_dedup="${real_extra}|${real_extra_key}"
                        seen_real_paths+=("$extra_dedup")
                        found_count=$((found_count + 1))
                        FOUND_CERTS+=("发现于${search_dir}|${extra_cert}|${extra_key}")
                        echo -e "  ${GREEN}✓${NC} [${found_count}] 额外发现 (${search_dir})"
                        echo -e "      证书: ${extra_cert}"
                        echo -e "      私钥: ${extra_key}"
                        echo ""
                    fi
                fi
            done
        fi
    done

    if [ $found_count -eq 0 ]; then
        echo -e "  ${RED}✗${NC} 未找到域名 ${domain} 的证书"
        echo ""
        return 1
    fi

    log_success "共找到 ${found_count} 个证书"
    return 0
}

# 部署证书到 OTA-QL 的 certs 目录
# 参数: $1 = 源证书路径, $2 = 源私钥路径, $3 = 面板名称（可选，用于日志）
deploy_cert_to_ota() {
    local src_cert="$1"
    local src_key="$2"
    local panel_name="${3:-未知来源}"

    local dest_cert="${CERTS_DIR}/fullchain.pem"
    local dest_key="${CERTS_DIR}/privkey.pem"

    # 验证源文件
    if [ ! -f "$src_cert" ]; then
        log_error "证书文件不存在: $src_cert"
        return 1
    fi
    if [ ! -f "$src_key" ]; then
        log_error "私钥文件不存在: $src_key"
        return 1
    fi

    # 验证证书和私钥匹配
    if command -v openssl &> /dev/null; then
        local cert_md5=$(openssl x509 -in "$src_cert" -noout -modulus 2>/dev/null | openssl md5 2>/dev/null)
        local key_md5=$(openssl rsa -in "$src_key" -noout -modulus 2>/dev/null | openssl md5 2>/dev/null)
        if [ -n "$cert_md5" ] && [ -n "$key_md5" ] && [ "$cert_md5" != "$key_md5" ]; then
            log_error "证书和私钥不匹配！"
            echo "  证书modulus MD5: $cert_md5"
            echo "  私钥modulus MD5: $key_md5"
            return 1
        fi
        log_success "证书和私钥验证匹配"
    fi

    # 备份已有证书
    if [ -f "$dest_cert" ]; then
        local backup_suffix=$(date +%Y%m%d_%H%M%S)
        cp "$dest_cert" "${dest_cert}.backup.${backup_suffix}"
        cp "$dest_key" "${dest_key}.backup.${backup_suffix}"
        log_info "已备份原证书"
    fi

    # 创建目录
    sudo mkdir -p "${CERTS_DIR}"

    # 复制证书
    sudo cp "$src_cert" "$dest_cert"
    sudo cp "$src_key" "$dest_key"
    sudo chmod 644 "$dest_cert"
    sudo chmod 600 "$dest_key"

    log_success "证书已部署到 ${CERTS_DIR}/"
    echo -e "  来源:     ${panel_name}"
    echo -e "  证书文件: ${dest_cert}"
    echo -e "  私钥文件: ${dest_key}"

    # 显示证书信息
    if command -v openssl &> /dev/null; then
        local cert_subject=$(openssl x509 -in "$dest_cert" -noout -subject 2>/dev/null | sed 's/subject=//')
        local cert_expiry=$(openssl x509 -in "$dest_cert" -noout -enddate 2>/dev/null | sed 's/notAfter=//')
        local cert_sans=$(openssl x509 -in "$dest_cert" -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/DNS://g; s/,//g; s/^\s*//')
        echo -e "  主体:     ${cert_subject}"
        echo -e "  SAN:      ${cert_sans}"
        echo -e "  到期:     ${cert_expiry}"
    fi
    echo ""

    return 0
}

# 部署时自动搜索并安装证书
# 在 deploy_container() 中调用
# 参数: 无（自动从回调地址提取域名）
auto_detect_and_deploy_certs() {
    echo ""
    echo "=========================================="
    echo "  SSL 证书自动检测"
    echo "=========================================="
    echo ""

    # 检查是否已有证书
    if [ -f "${CERTS_DIR}/fullchain.pem" ] && [ -f "${CERTS_DIR}/privkey.pem" ]; then
        log_success "已有证书文件: ${CERTS_DIR}/"

        # 显示已有证书信息
        if command -v openssl &> /dev/null; then
            local existing_cn=$(openssl x509 -in "${CERTS_DIR}/fullchain.pem" -noout -subject 2>/dev/null | sed 's/.*CN\s*=\s*//' | cut -d'/' -f1)
            local existing_expiry=$(openssl x509 -in "${CERTS_DIR}/fullchain.pem" -noout -enddate 2>/dev/null | sed 's/notAfter=//')
            local existing_sans=$(openssl x509 -in "${CERTS_DIR}/fullchain.pem" -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/DNS://g; s/,//g; s/^\s*//')
            echo -e "  域名: ${existing_cn}"
            echo -e "  SAN:  ${existing_sans}"
            echo -e "  到期: ${existing_expiry}"
        fi
        echo ""

        read -p "是否重新搜索并替换证书? [y/N]: " replace_confirm
        if [[ ! "$replace_confirm" =~ ^[Yy]$ ]]; then
            log_info "保留现有证书"
            return 0
        fi
    fi

    # 提取域名
    local domains=$(get_domains_for_cert)
    if [ -z "$domains" ]; then
        log_warning "未检测到域名（回调地址为IP或未设置）"
        echo ""
        echo "  SSL证书需要域名才能搜索"
        echo "  如需手动配置，请使用菜单中的 [证书管理] 功能"
        echo ""
        read -p "是否手动输入域名? [y/N]: " manual_confirm
        if [[ "$manual_confirm" =~ ^[Yy]$ ]]; then
            read -p "请输入域名 (多个用空格分隔): " manual_domains
            domains="$manual_domains"
        fi
        if [ -z "$domains" ]; then
            log_info "跳过证书配置（将使用自签名证书）"
            return 0
        fi
    fi

    log_info "搜索域名: ${domains}"
    echo ""

    # 对每个域名搜索
    local all_found=()
    for domain in $domains; do
        search_certs_for_domain "$domain"
        if [ ${#FOUND_CERTS[@]} -gt 0 ]; then
            for cert_entry in "${FOUND_CERTS[@]}"; do
                all_found+=("${domain}|${cert_entry}")
            done
        fi
    done

    if [ ${#all_found[@]} -eq 0 ]; then
        echo ""
        log_warning "未找到任何SSL证书"
        echo ""
        echo "  可能原因:"
        echo "  1. 尚未为此域名申请SSL证书"
        echo "  2. 证书存放在非标准路径"
        echo "  3. 证书文件名不是标准格式"
        echo ""
        echo "  解决方案:"
        echo -e "  ${CYAN}方案A:${NC} 在面板(宝塔/1Panel等)中为域名申请Let's Encrypt证书"
        echo -e "  ${CYAN}方案B:${NC} 手动复制证书文件到 ${CERTS_DIR}/"
        echo -e "         cp /path/to/fullchain.pem ${CERTS_DIR}/fullchain.pem"
        echo -e "         cp /path/to/privkey.pem ${CERTS_DIR}/privkey.pem"
        echo -e "  ${CYAN}方案C:${NC} 部署后使用菜单中的 [证书管理] 功能手动指定路径"
        echo ""
        echo -e "  ${YELLOW}提示: 没有CA证书时，Go服务器将使用自签名证书${NC}"
        echo -e "  ${YELLOW}      ESP32设备可能无法通过TLS证书验证${NC}"
        echo ""
        read -p "按Enter键继续部署..." dummy
        return 0
    fi

    # 只找到一个，直接使用
    if [ ${#all_found[@]} -eq 1 ]; then
        local entry="${all_found[0]}"
        local cert_domain=$(echo "$entry" | cut -d'|' -f1)
        local panel_name=$(echo "$entry" | cut -d'|' -f2)
        local cert_path=$(echo "$entry" | cut -d'|' -f3)
        local key_path=$(echo "$entry" | cut -d'|' -f4)

        echo ""
        read -p "是否使用此证书? [Y/n]: " use_confirm
        if [[ "$use_confirm" =~ ^[Nn]$ ]]; then
            log_info "跳过证书部署"
            return 0
        fi

        deploy_cert_to_ota "$cert_path" "$key_path" "$panel_name"
        return $?
    fi

    # 找到多个，让用户选择
    echo ""
    echo "找到多个证书，请选择:"
    echo ""
    local idx=0
    for entry in "${all_found[@]}"; do
        idx=$((idx + 1))
        local cert_domain=$(echo "$entry" | cut -d'|' -f1)
        local panel_name=$(echo "$entry" | cut -d'|' -f2)
        local cert_path=$(echo "$entry" | cut -d'|' -f3)
        echo "  [${idx}] ${panel_name} — 域名: ${cert_domain}"
        echo "       ${cert_path}"
    done
    echo "  [0] 跳过，不部署证书"
    echo ""
    read -p "请选择 [0-${idx}]: " cert_choice

    if [ "$cert_choice" = "0" ] || [ -z "$cert_choice" ]; then
        log_info "跳过证书部署"
        return 0
    fi

    if [ "$cert_choice" -ge 1 ] 2>/dev/null && [ "$cert_choice" -le $idx ] 2>/dev/null; then
        local selected="${all_found[$((cert_choice-1))]}"
        local sel_domain=$(echo "$selected" | cut -d'|' -f1)
        local sel_panel=$(echo "$selected" | cut -d'|' -f2)
        local sel_cert=$(echo "$selected" | cut -d'|' -f3)
        local sel_key=$(echo "$selected" | cut -d'|' -f4)

        deploy_cert_to_ota "$sel_cert" "$sel_key" "$sel_panel"
        return $?
    else
        log_warning "无效选择，跳过证书部署"
        return 0
    fi
}

# 查看当前已部署的证书信息
show_deployed_cert_info() {
    echo ""
    echo "=========================================="
    echo "  当前SSL证书状态"
    echo "=========================================="
    echo ""

    local cert_file="${CERTS_DIR}/fullchain.pem"
    local key_file="${CERTS_DIR}/privkey.pem"

    if [ ! -f "$cert_file" ]; then
        echo -e "  ${RED}✗${NC} 未部署证书"
        echo -e "  ${YELLOW}Go服务器正在使用自签名证书${NC}"
        echo ""
        echo "  ESP32设备连接可能遇到:"
        echo "  • esp-x509-crt-bundle: Failed to verify certificate"
        echo ""
        echo "  请通过 [证书管理 → 搜索并部署] 配置CA签名证书"
        echo ""
        return 1
    fi

    echo -e "  ${GREEN}✓${NC} 证书文件: ${cert_file}"
    echo -e "  ${GREEN}✓${NC} 私钥文件: ${key_file}"

    local cert_size=$(stat -c%s "$cert_file" 2>/dev/null || echo "?")
    local key_size=$(stat -c%s "$key_file" 2>/dev/null || echo "?")
    local cert_time=$(stat -c%y "$cert_file" 2>/dev/null | cut -d. -f1 || echo "?")
    echo -e "  证书大小: ${cert_size} bytes"
    echo -e "  部署时间: ${cert_time}"
    echo ""

    if command -v openssl &> /dev/null; then
        echo "[证书详细信息]"
        local subject=$(openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | sed 's/subject=//')
        local issuer=$(openssl x509 -in "$cert_file" -noout -issuer 2>/dev/null | sed 's/issuer=//')
        local start_date=$(openssl x509 -in "$cert_file" -noout -startdate 2>/dev/null | sed 's/notBefore=//')
        local end_date=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | sed 's/notAfter=//')
        local sans=$(openssl x509 -in "$cert_file" -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/DNS://g; s/,//g; s/^\s*//')
        local serial=$(openssl x509 -in "$cert_file" -noout -serial 2>/dev/null | sed 's/serial=//')

        echo -e "  主体:   ${subject}"
        echo -e "  颁发者: ${issuer}"
        echo -e "  域名:   ${sans}"
        echo -e "  序列号: ${serial}"
        echo -e "  生效:   ${start_date}"

        # 计算剩余天数
        local expiry_epoch=$(date -d "$end_date" +%s 2>/dev/null || echo "0")
        local now_epoch=$(date +%s)
        local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
        if [ "$days_left" -lt 0 ]; then
            echo -e "  到期:   ${RED}${end_date} (已过期!)${NC}"
        elif [ "$days_left" -lt 30 ]; then
            echo -e "  到期:   ${YELLOW}${end_date} (仅剩${days_left}天!)${NC}"
        else
            echo -e "  到期:   ${GREEN}${end_date} (${days_left}天)${NC}"
        fi

        # 验证证书链
        echo ""
        echo "[证书链验证]"
        local chain_count=$(openssl crl2pkcs7 -nocrl -certfile "$cert_file" 2>/dev/null | openssl pkcs7 -print_certs -noout 2>/dev/null | grep -c "subject=")
        echo -e "  证书链长度: ${chain_count:-未知} 个证书"

        # 验证私钥匹配
        local cert_md5=$(openssl x509 -in "$cert_file" -noout -modulus 2>/dev/null | openssl md5 2>/dev/null)
        local key_md5=$(openssl rsa -in "$key_file" -noout -modulus 2>/dev/null | openssl md5 2>/dev/null)
        if [ -n "$cert_md5" ] && [ -n "$key_md5" ]; then
            if [ "$cert_md5" = "$key_md5" ]; then
                echo -e "  证书/私钥: ${GREEN}✓ 匹配${NC}"
            else
                echo -e "  证书/私钥: ${RED}✗ 不匹配!${NC}"
            fi
        fi
    else
        echo -e "  ${YELLOW}提示: 安装 openssl 可查看详细证书信息${NC}"
    fi

    echo ""
}

# 手动指定证书路径部署
manual_deploy_cert() {
    echo ""
    echo "=========================================="
    echo "  手动指定证书路径"
    echo "=========================================="
    echo ""

    echo "请提供证书和私钥文件的完整路径"
    echo ""

    read -p "证书文件路径 (fullchain.pem): " manual_cert
    if [ -z "$manual_cert" ] || [ ! -f "$manual_cert" ]; then
        log_error "证书文件不存在: $manual_cert"
        return 1
    fi

    read -p "私钥文件路径 (privkey.pem): " manual_key
    if [ -z "$manual_key" ] || [ ! -f "$manual_key" ]; then
        log_error "私钥文件不存在: $manual_key"
        return 1
    fi

    deploy_cert_to_ota "$manual_cert" "$manual_key" "手动指定"

    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${YELLOW}提示: 证书已部署，需要重启容器生效${NC}"
        read -p "是否立即重启容器? [Y/n]: " restart_confirm
        if [[ ! "$restart_confirm" =~ ^[Nn]$ ]]; then
            docker restart ${CONTAINER_NAME} > /dev/null 2>&1
            sleep 3
            log_success "容器已重启，新证书生效"
        fi
    fi
}

# 搜索所有面板的证书（不限域名）
search_all_certs() {
    echo ""
    echo "=========================================="
    echo "  全局SSL证书搜索"
    echo "=========================================="
    echo ""
    log_info "搜索系统中所有SSL证书..."
    echo ""

    local search_dirs=(
        "/www/server/panel/vhost/cert"
        "/www/server/panel/vhost/ssl"
        "/etc/letsencrypt/live"
        "/root/.acme.sh"
        "/opt/1panel"
        "/etc/nginx/ssl"
        "/etc/nginx/conf.d/ssl"
        "/etc/apache2/ssl"
        "/etc/httpd/ssl"
        "/usr/local/appnode/nginx/conf/ssl"
        "/var/lib/caddy"
    )

    local total_found=0
    ALL_SEARCH_RESULTS=()
    # v5.1: 全局去重 — 按realpath去重，避免同一文件重复列出
    local seen_real_paths=()

    for search_dir in "${search_dirs[@]}"; do
        if [ -d "$search_dir" ]; then
            local certs=$(find "$search_dir" -name "fullchain.pem" -o -name "fullchain.cer" -o -name "cert.pem" 2>/dev/null)
            if [ -n "$certs" ]; then
                echo -e "  ${GREEN}📂${NC} ${search_dir}/"
                while IFS= read -r cert_file; do
                    local cert_dir=$(dirname "$cert_file")
                    local domain_guess=$(basename "$cert_dir")

                    # 查找配对私钥
                    local key_file=""
                    for kn in "privkey.pem" "private.key" "${domain_guess}.key"; do
                        if [ -f "${cert_dir}/${kn}" ]; then
                            key_file="${cert_dir}/${kn}"
                            break
                        fi
                    done

                    if [ -n "$key_file" ]; then
                        # v5.1 去重: 解析真实路径
                        local real_cert=$(realpath "$cert_file" 2>/dev/null || readlink -f "$cert_file" 2>/dev/null || echo "$cert_file")
                        local real_key=$(realpath "$key_file" 2>/dev/null || readlink -f "$key_file" 2>/dev/null || echo "$key_file")
                        local dedup_key="${real_cert}|${real_key}"
                        local is_dup=false
                        for seen in "${seen_real_paths[@]}"; do
                            if [ "$seen" = "$dedup_key" ]; then
                                is_dup=true
                                break
                            fi
                        done
                        if [ "$is_dup" = "true" ]; then
                            continue
                        fi
                        seen_real_paths+=("$dedup_key")

                        total_found=$((total_found + 1))
                        ALL_SEARCH_RESULTS+=("${domain_guess}|${cert_file}|${key_file}")

                        local cert_info=""
                        if command -v openssl &> /dev/null; then
                            local cn=$(openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | sed 's/.*CN\s*=\s*//' | cut -d'/' -f1)
                            local expiry=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | sed 's/notAfter=//')
                            cert_info=" (CN=${cn}, 到期: ${expiry})"
                        fi

                        echo -e "    ${GREEN}✓${NC} [${total_found}] ${domain_guess}${cert_info}"
                        echo -e "        证书: ${cert_file}"
                        echo -e "        私钥: ${key_file}"
                    fi
                done <<< "$certs"
                echo ""
            fi
        fi
    done

    if [ $total_found -eq 0 ]; then
        echo -e "  ${RED}✗${NC} 未在系统中找到任何SSL证书"
        echo ""
        echo "  建议:"
        echo "  1. 在面板(宝塔/1Panel等)中为域名申请SSL证书"
        echo "  2. 使用 certbot/acme.sh 命令行工具申请"
        echo "  3. 手动上传证书文件"
        echo ""
        return 1
    fi

    echo ""
    log_success "共找到 ${total_found} 个证书"
    echo ""

    echo "操作:"
    echo "  输入编号 [1-${total_found}] 部署指定证书到 OTA-QL"
    echo "  输入 0 返回"
    echo ""
    read -p "请选择: " deploy_choice

    if [ "$deploy_choice" = "0" ] || [ -z "$deploy_choice" ]; then
        return 0
    fi

    if [ "$deploy_choice" -ge 1 ] 2>/dev/null && [ "$deploy_choice" -le $total_found ] 2>/dev/null; then
        local selected="${ALL_SEARCH_RESULTS[$((deploy_choice-1))]}"
        local sel_domain=$(echo "$selected" | cut -d'|' -f1)
        local sel_cert=$(echo "$selected" | cut -d'|' -f2)
        local sel_key=$(echo "$selected" | cut -d'|' -f3)

        deploy_cert_to_ota "$sel_cert" "$sel_key" "全局搜索 (${sel_domain})"

        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${YELLOW}提示: 证书已部署，需要重启容器生效${NC}"
            read -p "是否立即重启容器? [Y/n]: " restart_confirm
            if [[ ! "$restart_confirm" =~ ^[Nn]$ ]]; then
                docker restart ${CONTAINER_NAME} > /dev/null 2>&1
                sleep 3
                log_success "容器已重启，新证书生效"
            fi
        fi
    else
        log_warning "无效选择"
    fi
}

# 获取证书申请指导
show_cert_guide() {
    echo ""
    echo "=========================================="
    echo "  SSL证书申请指南"
    echo "=========================================="
    echo ""

    local cb_addr=$(get_callback_addr)
    local domain_hint=""
    if [ -n "$cb_addr" ] && ! echo "$cb_addr" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        domain_hint="$cb_addr"
    fi

    echo -e "${BOLD}为什么需要SSL证书？${NC}"
    echo "  ESP32设备通过 cmux网关(${GW_PORT}) 和 MQTTS(${MQTTS_PORT}) 直连Docker容器"
    echo "  这些连接不经过Nginx反向代理，Go服务器需要自己的CA签名证书"
    echo "  ESP32使用 esp-x509-crt-bundle (Mozilla CA) 验证证书"
    echo "  自签名证书会导致: Failed to verify certificate"
    echo ""

    echo -e "${BOLD}方案1: 宝塔面板（推荐）${NC}"
    echo "  1. 登录宝塔面板"
    echo "  2. 网站 → 选择站点 → SSL → Let's Encrypt → 申请"
    if [ -n "$domain_hint" ]; then
        echo "  3. 证书路径: /www/server/panel/vhost/cert/${domain_hint}/"
        echo "  4. 部署命令:"
        echo -e "     ${CYAN}cp /www/server/panel/vhost/cert/${domain_hint}/fullchain.pem ${CERTS_DIR}/${NC}"
        echo -e "     ${CYAN}cp /www/server/panel/vhost/cert/${domain_hint}/privkey.pem ${CERTS_DIR}/${NC}"
    else
        echo "  3. 证书路径: /www/server/panel/vhost/cert/<域名>/"
    fi
    echo ""

    echo -e "${BOLD}方案2: 1Panel 面板${NC}"
    echo "  1. 登录1Panel面板"
    echo "  2. 网站 → 证书 → 申请证书"
    if [ -n "$domain_hint" ]; then
        echo "  3. 使用菜单中的 [搜索并部署] 自动查找"
    fi
    echo ""

    echo -e "${BOLD}方案3: Certbot 命令行${NC}"
    if [ -n "$domain_hint" ]; then
        echo -e "  ${CYAN}sudo certbot certonly --standalone -d ${domain_hint}${NC}"
        echo "  或使用DNS验证（推荐，不占用80端口）:"
        echo -e "  ${CYAN}sudo certbot certonly --manual --preferred-challenges dns -d ${domain_hint}${NC}"
    else
        echo -e "  ${CYAN}sudo certbot certonly --standalone -d <域名>${NC}"
    fi
    echo ""

    echo -e "${BOLD}方案4: acme.sh 命令行${NC}"
    if [ -n "$domain_hint" ]; then
        echo -e "  ${CYAN}curl https://get.acme.sh | sh${NC}"
        echo -e "  ${CYAN}~/.acme.sh/acme.sh --issue -d ${domain_hint} --standalone${NC}"
    else
        echo -e "  ${CYAN}curl https://get.acme.sh | sh${NC}"
        echo -e "  ${CYAN}~/.acme.sh/acme.sh --issue -d <域名> --standalone${NC}"
    fi
    echo ""

    echo -e "${BOLD}方案5: 手动上传${NC}"
    echo "  将证书文件复制到以下位置:"
    echo -e "  ${CYAN}${CERTS_DIR}/fullchain.pem${NC}  ← 证书（含中间证书链）"
    echo -e "  ${CYAN}${CERTS_DIR}/privkey.pem${NC}    ← 私钥"
    echo "  然后重启容器:"
    echo -e "  ${CYAN}docker restart ${CONTAINER_NAME}${NC}"
    echo ""

    echo -e "${BOLD}多域名证书${NC}"
    echo "  如果有多个域名，申请时添加多个 -d 参数:"
    echo -e "  ${CYAN}sudo certbot certonly --standalone -d domain1.com -d domain2.com${NC}"
    echo "  一个证书可以覆盖多个域名（SAN证书）"
    echo ""
}

# 跨域名证书部署（单证书覆盖多域名）
# v5.1: 搜索所有域名的证书，检查SAN覆盖范围，用一个证书同时服务多个域名
# 典型场景: 生产(ota.wisefido.com)和测试(ota.wisefido.work)共用同一证书（通配符或SAN证书）
deploy_cert_cross_domain() {
    echo ""
    echo "=========================================="
    echo "  跨域名证书部署 (v5.1)"
    echo "=========================================="
    echo ""

    echo -e "${BOLD}功能说明:${NC}"
    echo "  搜索系统中的证书，检查其SAN（主题备用名称）是否覆盖多个域名"
    echo "  部署一个证书即可同时服务生产域名和测试域名"
    echo ""
    echo -e "${BOLD}适用场景:${NC}"
    echo "  • 通配符证书 (*.wisefido.com 覆盖所有子域名)"
    echo "  • SAN证书 (ota.wisefido.com + ota.wisefido.work 写在同一张证书)"
    echo "  • 单域名证书部署到多域名环境（证书只匹配一个域名）"
    echo ""

    # 先搜索系统中所有证书
    echo "[步骤1] 搜索系统中所有可用证书..."
    echo ""

    local search_dirs=(
        "/www/server/panel/vhost/cert"
        "/etc/letsencrypt/live"
        "/root/.acme.sh"
        "/opt/1panel"
        "/etc/nginx/ssl"
    )

    local total_found=0
    local cert_list=()
    local seen_real_paths=()

    for search_dir in "${search_dirs[@]}"; do
        if [ -d "$search_dir" ]; then
            local certs=$(find "$search_dir" -name "fullchain.pem" -o -name "fullchain.cer" 2>/dev/null)
            if [ -n "$certs" ]; then
                while IFS= read -r cert_file; do
                    local cert_dir=$(dirname "$cert_file")
                    local key_file=""
                    local domain_guess=$(basename "$cert_dir")
                    for kn in "privkey.pem" "private.key" "${domain_guess}.key"; do
                        if [ -f "${cert_dir}/${kn}" ]; then
                            key_file="${cert_dir}/${kn}"
                            break
                        fi
                    done

                    if [ -n "$key_file" ]; then
                        # 去重
                        local real_cert=$(realpath "$cert_file" 2>/dev/null || readlink -f "$cert_file" 2>/dev/null || echo "$cert_file")
                        local real_key=$(realpath "$key_file" 2>/dev/null || readlink -f "$key_file" 2>/dev/null || echo "$key_file")
                        local dedup_key="${real_cert}|${real_key}"
                        local is_dup=false
                        for seen in "${seen_real_paths[@]}"; do
                            if [ "$seen" = "$dedup_key" ]; then
                                is_dup=true
                                break
                            fi
                        done
                        if [ "$is_dup" = "true" ]; then continue; fi
                        seen_real_paths+=("$dedup_key")

                        total_found=$((total_found + 1))

                        # 获取证书详情
                        local cn="" sans="" expiry="" san_list=""
                        if command -v openssl &> /dev/null; then
                            cn=$(openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | sed 's/.*CN\s*=\s*//' | cut -d'/' -f1)
                            sans=$(openssl x509 -in "$cert_file" -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/^\s*//')
                            san_list=$(echo "$sans" | sed 's/DNS://g; s/,/ /g; s/  */ /g')
                            expiry=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | sed 's/notAfter=//')
                        fi

                        cert_list+=("${cert_file}|${key_file}|${cn}|${san_list}|${expiry}")

                        echo -e "  ${GREEN}✓${NC} [${total_found}] CN=${cn}"
                        echo -e "      SAN: ${san_list:-无}"
                        echo -e "      到期: ${expiry}"
                        echo -e "      路径: ${cert_file}"
                        echo ""
                    fi
                done <<< "$certs"
            fi
        fi
    done

    if [ $total_found -eq 0 ]; then
        echo -e "  ${RED}✗${NC} 未找到任何证书"
        echo ""
        echo "  请先为域名申请SSL证书（参考 [5. SSL证书申请指南]）"
        echo ""
        echo -e "  ${BOLD}申请多域名证书示例:${NC}"
        echo -e "  ${CYAN}sudo certbot certonly --standalone -d ota.wisefido.com -d ota.wisefido.work${NC}"
        echo ""
        return 1
    fi

    # 让用户选择
    echo ""
    echo "[步骤2] 选择要部署的证书"
    echo ""
    echo "  输入编号 [1-${total_found}] 选择证书"
    echo "  输入 0 返回"
    echo ""
    read -p "请选择: " choice

    if [ "$choice" = "0" ] || [ -z "$choice" ]; then
        return 0
    fi

    if ! ([ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le $total_found ] 2>/dev/null); then
        log_warning "无效选择"
        return 1
    fi

    local selected="${cert_list[$((choice-1))]}"
    local sel_cert=$(echo "$selected" | cut -d'|' -f1)
    local sel_key=$(echo "$selected" | cut -d'|' -f2)
    local sel_cn=$(echo "$selected" | cut -d'|' -f3)
    local sel_sans=$(echo "$selected" | cut -d'|' -f4)
    local sel_expiry=$(echo "$selected" | cut -d'|' -f5)

    echo ""
    echo "=========================================="
    echo "  选中证书详情"
    echo "=========================================="
    echo ""
    echo -e "  CN:   ${sel_cn}"
    echo -e "  SAN:  ${sel_sans:-无}"
    echo -e "  到期: ${sel_expiry}"
    echo -e "  路径: ${sel_cert}"
    echo ""

    # 分析SAN覆盖情况
    echo "[步骤3] 域名覆盖分析"
    echo ""

    # 获取当前回调域名
    local cb_addr=$(get_callback_addr)
    local cb_domain=""
    if [ -n "$cb_addr" ] && ! echo "$cb_addr" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        cb_domain="$cb_addr"
    fi

    # 检查SAN中包含哪些域名
    local san_count=0
    local covered_domains=()
    if [ -n "$sel_sans" ]; then
        for san_entry in $sel_sans; do
            san_entry=$(echo "$san_entry" | tr -d ' ')
            if [ -n "$san_entry" ]; then
                san_count=$((san_count + 1))
                covered_domains+=("$san_entry")
                local match_icon="  "
                if [ -n "$cb_domain" ]; then
                    # 检查是否匹配回调域名（支持通配符匹配）
                    if [ "$san_entry" = "$cb_domain" ]; then
                        match_icon="${GREEN}✓${NC}"
                    elif echo "$san_entry" | grep -q '^\*\.'; then
                        local wildcard_base="${san_entry#\*.}"
                        if echo "$cb_domain" | grep -qE "\.${wildcard_base}$"; then
                            match_icon="${GREEN}✓${NC}"
                        fi
                    fi
                fi
                echo -e "  ${match_icon} ${san_entry}"
            fi
        done
    fi
    echo ""

    if [ -n "$cb_domain" ]; then
        echo -e "  当前回调域名: ${CYAN}${cb_domain}${NC}"
        # 检查是否被覆盖
        local is_covered=false
        for cd in "${covered_domains[@]}"; do
            if [ "$cd" = "$cb_domain" ]; then
                is_covered=true
                break
            fi
            if echo "$cd" | grep -q '^\*\.'; then
                local wc_base="${cd#\*.}"
                if echo "$cb_domain" | grep -qE "\.${wc_base}$"; then
                    is_covered=true
                    break
                fi
            fi
        done
        if [ "$is_covered" = "true" ]; then
            echo -e "  覆盖状态: ${GREEN}✓ 回调域名已被证书覆盖${NC}"
        else
            echo -e "  覆盖状态: ${YELLOW}⚠ 回调域名未在证书SAN中${NC}"
            echo -e "  ${YELLOW}  ESP32设备可能因域名不匹配而拒绝连接${NC}"
        fi
    else
        echo -e "  ${YELLOW}未设置回调域名（或为IP），跳过覆盖检查${NC}"
    fi
    echo ""

    if [ $san_count -gt 1 ]; then
        echo -e "  ${GREEN}💡 此证书覆盖 ${san_count} 个域名，一次部署即可服务所有域名${NC}"
    elif [ $san_count -eq 1 ]; then
        echo -e "  ${YELLOW}💡 此证书仅覆盖 1 个域名${NC}"
        echo -e "  ${YELLOW}   如需覆盖多域名，请申请SAN证书或通配符证书${NC}"
        echo -e "  ${CYAN}   示例: sudo certbot certonly --standalone -d domain1.com -d domain2.com${NC}"
    fi
    echo ""

    # 确认部署
    read -p "是否将此证书部署到 OTA-QL? [Y/n]: " deploy_confirm
    if [[ "$deploy_confirm" =~ ^[Nn]$ ]]; then
        log_info "已取消部署"
        return 0
    fi

    deploy_cert_to_ota "$sel_cert" "$sel_key" "跨域名部署 (CN=${sel_cn})"

    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${YELLOW}提示: 证书已部署，需要重启容器生效${NC}"
        read -p "是否立即重启容器? [Y/n]: " restart_confirm
        if [[ ! "$restart_confirm" =~ ^[Nn]$ ]]; then
            docker restart ${CONTAINER_NAME} > /dev/null 2>&1
            sleep 3
            log_success "容器已重启，新证书生效"
        fi

        echo ""
        echo "=========================================="
        echo "  部署完成总结"
        echo "=========================================="
        echo ""
        echo -e "  证书CN:  ${sel_cn}"
        echo -e "  覆盖域名: ${sel_sans}"
        echo ""
        echo -e "  ${GREEN}Go服务器将在以下端口使用此证书:${NC}"
        echo -e "    • cmux设备网关  :${GW_PORT}   (ESP32直连认证)"
        echo -e "    • MQTTS Broker  :${MQTTS_PORT}  (ESP32 MQTT TLS)"
        echo -e "    • HTTPS统一服务 :${HTTPS_PORT} (Web管理面板)"
        echo ""
        if [ $san_count -gt 1 ]; then
            echo -e "  ${GREEN}✓ 单证书覆盖 ${san_count} 个域名，无需为每个域名单独配置${NC}"
        fi
        echo ""
    fi
}

# 证书管理子菜单
menu_cert_management() {
    echo ""
    echo "=========================================="
    echo "  SSL 证书管理"
    echo "=========================================="
    echo ""

    echo "  1. 查看当前证书状态"
    echo "  2. 按域名搜索并部署证书"
    echo "  3. 全局搜索系统中所有证书"
    echo "  4. 手动指定证书路径"
    echo "  5. SSL证书申请指南"
    echo "  6. 跨域名证书部署（单证书覆盖多域名）"
    echo "  0. 返回主菜单"
    echo ""
    read -p "请选择 [0-6]: " cert_choice

    case $cert_choice in
        1)
            show_deployed_cert_info
            ;;
        2)
            local domains=$(get_domains_for_cert)
            if [ -z "$domains" ]; then
                read -p "请输入域名 (多个用空格分隔): " domains
            fi
            if [ -n "$domains" ]; then
                for domain in $domains; do
                    search_certs_for_domain "$domain"
                done

                if [ ${#FOUND_CERTS[@]} -gt 0 ]; then
                    echo ""
                    echo "选择要部署的证书:"
                    local idx=0
                    for entry in "${FOUND_CERTS[@]}"; do
                        idx=$((idx + 1))
                        local pname=$(echo "$entry" | cut -d'|' -f1)
                        local cpath=$(echo "$entry" | cut -d'|' -f2)
                        echo "  [${idx}] ${pname} — ${cpath}"
                    done
                    echo "  [0] 取消"
                    echo ""
                    read -p "请选择 [0-${idx}]: " sel

                    if [ "$sel" -ge 1 ] 2>/dev/null && [ "$sel" -le $idx ] 2>/dev/null; then
                        local chosen="${FOUND_CERTS[$((sel-1))]}"
                        local ch_panel=$(echo "$chosen" | cut -d'|' -f1)
                        local ch_cert=$(echo "$chosen" | cut -d'|' -f2)
                        local ch_key=$(echo "$chosen" | cut -d'|' -f3)

                        deploy_cert_to_ota "$ch_cert" "$ch_key" "$ch_panel"

                        if [ $? -eq 0 ]; then
                            echo ""
                            read -p "是否立即重启容器生效? [Y/n]: " restart_confirm
                            if [[ ! "$restart_confirm" =~ ^[Nn]$ ]]; then
                                docker restart ${CONTAINER_NAME} > /dev/null 2>&1
                                sleep 3
                                log_success "容器已重启，新证书生效"
                            fi
                        fi
                    fi
                fi
            else
                log_warning "未输入域名"
            fi
            ;;
        3)
            search_all_certs
            ;;
        4)
            manual_deploy_cert
            ;;
        5)
            show_cert_guide
            ;;
        6)
            deploy_cert_cross_domain
            ;;
        0)
            return 0
            ;;
        *)
            log_warning "无效选择"
            ;;
    esac
}

get_public_ip() {
    local PUBLIC_IP=""
    PUBLIC_IP=$(curl -4 -s --connect-timeout 5 ifconfig.me 2>/dev/null || \
                curl -4 -s --connect-timeout 5 ip.sb 2>/dev/null || \
                curl -4 -s --connect-timeout 5 api.ipify.org 2>/dev/null || \
                echo "")
    if echo "$PUBLIC_IP" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        echo "$PUBLIC_IP"
    else
        echo ""
    fi
}

# ============================================================================
# v5.2: 部署时SSL证书交互式菜单（替代v5.0的auto_detect_and_deploy_certs）
# ============================================================================

# 使用certbot申请通配符证书（需DNS验证）
apply_wildcard_cert() {
    echo ""
    echo "=========================================="
    echo "  申请通配符证书 (*.domain.com)"
    echo "=========================================="
    echo ""

    local cb_addr=$(get_callback_addr)
    local base_domain=""

    # 从回调地址推断基础域名（如 ota.wisefido.com → wisefido.com）
    if [ -n "$cb_addr" ] && ! echo "$cb_addr" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        base_domain=$(echo "$cb_addr" | awk -F. '{if(NF>=2) print $(NF-1)"."$NF}')
    fi

    echo -e "${BOLD}通配符证书说明:${NC}"
    echo "  • 一张证书覆盖 *.domain.com 下所有子域名"
    echo "  • 例如: *.wisefido.com 同时覆盖 ota.wisefido.com 和 api.wisefido.com"
    echo "  • 必须使用 DNS 验证方式（需要到域名管理面板添加 TXT 记录）"
    echo ""

    if [ -n "$base_domain" ]; then
        echo -e "  推测基础域名: ${CYAN}${base_domain}${NC}"
        echo ""
    fi

    read -p "请输入基础域名 (如 wisefido.com): " input_domain
    if [ -z "$input_domain" ] && [ -n "$base_domain" ]; then
        input_domain="$base_domain"
        echo "  使用推测域名: $input_domain"
    fi
    if [ -z "$input_domain" ]; then
        log_warning "未输入域名，取消操作"
        return 1
    fi

    echo ""
    echo -e "${BOLD}即将执行:${NC}"
    echo -e "  ${CYAN}sudo certbot certonly --manual --preferred-challenges dns -d \"*.${input_domain}\" -d \"${input_domain}\"${NC}"
    echo ""
    echo -e "${YELLOW}注意: certbot 会要求你在域名管理面板添加 TXT 记录${NC}"
    echo -e "${YELLOW}      请在另一个终端或浏览器中完成 DNS 验证${NC}"
    echo ""
    read -p "是否继续? [Y/n]: " proceed
    if [[ "$proceed" =~ ^[Nn]$ ]]; then
        return 1
    fi

    # 检查certbot是否安装
    if ! command -v certbot &> /dev/null; then
        log_warning "certbot 未安装，正在安装..."
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y certbot
        elif command -v yum &> /dev/null; then
            sudo yum install -y certbot
        else
            log_error "无法自动安装 certbot，请手动安装后重试"
            echo -e "  ${CYAN}Ubuntu/Debian: sudo apt install certbot${NC}"
            echo -e "  ${CYAN}CentOS/RHEL:   sudo yum install certbot${NC}"
            return 1
        fi
    fi

    # 执行certbot（通配符必须用DNS验证）
    sudo certbot certonly --manual --preferred-challenges dns \
        -d "*.${input_domain}" -d "${input_domain}"

    if [ $? -eq 0 ]; then
        log_success "通配符证书申请成功！"

        # 查找生成的证书
        local cert_path="/etc/letsencrypt/live/${input_domain}/fullchain.pem"
        local key_path="/etc/letsencrypt/live/${input_domain}/privkey.pem"

        if [ -f "$cert_path" ] && [ -f "$key_path" ]; then
            echo ""
            echo -e "  证书: ${cert_path}"
            echo -e "  私钥: ${key_path}"

            # 显示SAN信息
            if command -v openssl &> /dev/null; then
                local sans=$(openssl x509 -in "$cert_path" -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/DNS://g; s/,//g; s/^\s*//')
                echo -e "  SAN:  ${sans}"
            fi

            echo ""
            read -p "是否部署此证书到 OTA-QL? [Y/n]: " deploy_confirm
            if [[ ! "$deploy_confirm" =~ ^[Nn]$ ]]; then
                deploy_cert_to_ota "$cert_path" "$key_path" "通配符证书 (*.${input_domain})"
                return $?
            fi
        else
            log_warning "证书文件未在预期路径找到，请手动检查 /etc/letsencrypt/live/"
            return 1
        fi
    else
        log_error "证书申请失败！"
        echo ""
        echo "  常见原因:"
        echo "  1. DNS TXT 记录未添加或未生效"
        echo "  2. 域名解析有问题"
        echo "  3. certbot 版本过旧"
        echo ""
        return 1
    fi
}

# 使用certbot申请SAN多域名证书
apply_san_cert() {
    echo ""
    echo "=========================================="
    echo "  申请 SAN 多域名证书"
    echo "=========================================="
    echo ""

    local cb_addr=$(get_callback_addr)

    echo -e "${BOLD}SAN 多域名证书说明:${NC}"
    echo "  • 一张证书包含多个指定域名（SAN = Subject Alternative Name）"
    echo "  • 例如: ota.wisefido.com + ota.wisefido.work 在同一张证书"
    echo "  • 可以使用 HTTP 验证（端口80）或 DNS 验证"
    echo ""

    if [ -n "$cb_addr" ] && ! echo "$cb_addr" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        echo -e "  当前回调域名: ${CYAN}${cb_addr}${NC}"
        echo ""
    fi

    echo "请输入要包含的域名（空格分隔，至少2个）"
    echo -e "  示例: ${CYAN}ota.wisefido.com ota.wisefido.work${NC}"
    echo ""
    read -p "域名列表: " domain_list

    if [ -z "$domain_list" ]; then
        log_warning "未输入域名，取消操作"
        return 1
    fi

    # 构建 -d 参数
    local certbot_args=""
    local first_domain=""
    local domain_count=0
    for d in $domain_list; do
        certbot_args="${certbot_args} -d ${d}"
        if [ -z "$first_domain" ]; then
            first_domain="$d"
        fi
        domain_count=$((domain_count + 1))
    done

    if [ $domain_count -lt 1 ]; then
        log_warning "请输入至少一个域名"
        return 1
    fi

    echo ""
    echo -e "${BOLD}选择验证方式:${NC}"
    echo "  1. HTTP 验证（--standalone，需要端口80空闲）"
    echo "  2. DNS 验证（--manual --preferred-challenges dns，需手动添加TXT记录）"
    echo "  3. Nginx 插件（--nginx，需已安装 certbot-nginx）"
    echo ""
    read -p "请选择 [1-3]: " verify_method

    local verify_args=""
    case $verify_method in
        1)
            verify_args="--standalone"
            echo ""
            echo -e "${YELLOW}注意: HTTP 验证需要端口 80 空闲${NC}"
            echo -e "${YELLOW}      如 Nginx 占用端口 80，请先停止: sudo systemctl stop nginx${NC}"
            ;;
        2)
            verify_args="--manual --preferred-challenges dns"
            echo ""
            echo -e "${YELLOW}注意: DNS 验证需要手动在域名管理面板添加 TXT 记录${NC}"
            ;;
        3)
            verify_args="--nginx"
            ;;
        *)
            verify_args="--standalone"
            ;;
    esac

    echo ""
    echo -e "${BOLD}即将执行:${NC}"
    echo -e "  ${CYAN}sudo certbot certonly ${verify_args}${certbot_args}${NC}"
    echo ""
    read -p "是否继续? [Y/n]: " proceed
    if [[ "$proceed" =~ ^[Nn]$ ]]; then
        return 1
    fi

    # 检查certbot
    if ! command -v certbot &> /dev/null; then
        log_warning "certbot 未安装，正在安装..."
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y certbot
        elif command -v yum &> /dev/null; then
            sudo yum install -y certbot
        else
            log_error "无法自动安装 certbot，请手动安装"
            return 1
        fi
    fi

    # 执行certbot
    sudo certbot certonly ${verify_args} ${certbot_args}

    if [ $? -eq 0 ]; then
        log_success "SAN 多域名证书申请成功！"

        # 查找证书
        local cert_path="/etc/letsencrypt/live/${first_domain}/fullchain.pem"
        local key_path="/etc/letsencrypt/live/${first_domain}/privkey.pem"

        if [ -f "$cert_path" ] && [ -f "$key_path" ]; then
            echo ""
            echo -e "  证书: ${cert_path}"
            echo -e "  私钥: ${key_path}"

            if command -v openssl &> /dev/null; then
                local sans=$(openssl x509 -in "$cert_path" -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/DNS://g; s/,//g; s/^\s*//')
                echo -e "  SAN:  ${sans}"
            fi

            echo ""
            read -p "是否部署此证书到 OTA-QL? [Y/n]: " deploy_confirm
            if [[ ! "$deploy_confirm" =~ ^[Nn]$ ]]; then
                deploy_cert_to_ota "$cert_path" "$key_path" "SAN多域名证书 (${domain_list})"
                return $?
            fi
        else
            # 尝试查找其他可能的路径
            log_warning "证书未在预期路径 ${cert_path} 找到"
            echo "  正在搜索 /etc/letsencrypt/live/ 目录..."
            ls -la /etc/letsencrypt/live/ 2>/dev/null
            return 1
        fi
    else
        log_error "证书申请失败！"
        echo ""
        echo "  常见原因:"
        echo "  1. 端口80被占用（HTTP验证）"
        echo "  2. DNS TXT 记录未添加（DNS验证）"
        echo "  3. 域名未指向本服务器IP"
        echo ""
        return 1
    fi
}

# v5.2: 部署时的SSL证书交互式菜单
# 替代v5.0的auto_detect_and_deploy_certs，由用户主动选择证书获取方式
deploy_cert_interactive_menu() {
    echo ""
    echo "=========================================="
    echo "  SSL 证书配置 (v5.2)"
    echo "=========================================="
    echo ""

    # 检查是否已有证书
    if [ -f "${CERTS_DIR}/fullchain.pem" ] && [ -f "${CERTS_DIR}/privkey.pem" ]; then
        echo -e "  ${GREEN}✓${NC} 已有证书文件: ${CERTS_DIR}/"
        if command -v openssl &> /dev/null; then
            local existing_cn=$(openssl x509 -in "${CERTS_DIR}/fullchain.pem" -noout -subject 2>/dev/null | sed 's/.*CN\s*=\s*//' | cut -d'/' -f1)
            local existing_sans=$(openssl x509 -in "${CERTS_DIR}/fullchain.pem" -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/DNS://g; s/,//g; s/^\s*//')
            local existing_expiry=$(openssl x509 -in "${CERTS_DIR}/fullchain.pem" -noout -enddate 2>/dev/null | sed 's/notAfter=//')
            echo -e "  域名: ${existing_cn}"
            echo -e "  SAN:  ${existing_sans}"
            echo -e "  到期: ${existing_expiry}"
        fi
        echo ""
        read -p "是否重新配置证书? [y/N]: " reconfig
        if [[ ! "$reconfig" =~ ^[Yy]$ ]]; then
            log_info "保留现有证书，继续部署"
            return 0
        fi
    fi

    echo -e "${BOLD}ESP32 设备需要 CA 签发证书才能通过 TLS 验证${NC}"
    echo -e "${BOLD}请选择证书配置方式:${NC}"
    echo ""
    echo "  1. 搜索已有证书（从宝塔/1Panel/Certbot等面板路径搜索）"
    echo "  2. 申请通配符证书（*.domain.com，覆盖所有子域名）"
    echo "  3. 申请 SAN 多域名证书（指定多个域名写入一张证书）"
    echo "  0. 跳过（使用自签名证书，ESP32设备可能无法连接）"
    echo ""
    read -p "请选择 [0-3]: " cert_menu_choice

    case $cert_menu_choice in
        1)
            # 搜索已有证书（复用原 auto_detect_and_deploy_certs 的搜索逻辑）
            auto_detect_and_deploy_certs
            # 搜索完毕后检查是否成功部署
            if [ ! -f "${CERTS_DIR}/fullchain.pem" ] || [ ! -f "${CERTS_DIR}/privkey.pem" ]; then
                echo ""
                log_warning "未成功部署证书"
                echo ""
                echo "  是否尝试其他方式？"
                echo "  2. 申请通配符证书"
                echo "  3. 申请 SAN 多域名证书"
                echo "  0. 跳过"
                echo ""
                read -p "请选择 [0/2/3]: " retry_choice
                case $retry_choice in
                    2) apply_wildcard_cert ;;
                    3) apply_san_cert ;;
                    *) log_info "跳过证书配置（将使用自签名证书）" ;;
                esac
            fi
            ;;
        2)
            apply_wildcard_cert
            if [ $? -ne 0 ]; then
                echo ""
                log_warning "通配符证书申请失败"
                echo "  是否尝试其他方式？"
                echo "  1. 搜索已有证书"
                echo "  3. 申请 SAN 多域名证书"
                echo "  0. 跳过"
                echo ""
                read -p "请选择 [0/1/3]: " retry_choice
                case $retry_choice in
                    1) auto_detect_and_deploy_certs ;;
                    3) apply_san_cert ;;
                    *) log_info "跳过证书配置（将使用自签名证书）" ;;
                esac
            fi
            ;;
        3)
            apply_san_cert
            if [ $? -ne 0 ]; then
                echo ""
                log_warning "SAN 多域名证书申请失败"
                echo "  是否尝试其他方式？"
                echo "  1. 搜索已有证书"
                echo "  2. 申请通配符证书"
                echo "  0. 跳过"
                echo ""
                read -p "请选择 [0/1/2]: " retry_choice
                case $retry_choice in
                    1) auto_detect_and_deploy_certs ;;
                    2) apply_wildcard_cert ;;
                    *) log_info "跳过证书配置（将使用自签名证书）" ;;
                esac
            fi
            ;;
        0|"")
            log_info "跳过证书配置（将使用自签名证书）"
            echo -e "  ${YELLOW}ESP32设备可能无法通过TLS证书验证${NC}"
            echo -e "  ${YELLOW}部署后可通过菜单 [11. SSL证书管理] 配置证书${NC}"
            echo ""
            ;;
        *)
            log_warning "无效选择，跳过证书配置"
            ;;
    esac
}

# ============================================================================
# 部署入口
# ============================================================================

deploy_container() {
    local mode="${1:-production}"

    if [ "$mode" = "test" ]; then
        echo ""
        echo -e "${BG_RED}${BOLD}  ⚠️  测试环境部署模式  ${NC}"
        echo ""
        log_warning "此模式将所有端口暴露到所有网络接口（含公网！）"
        log_warning "HTTPS(${HTTPS_PORT}) GW(${GW_PORT}) MQTT(${MQTT_PORT}) MQTTS(${MQTTS_PORT})"
        echo ""
        read -p "确认继续? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "已取消部署"
            return 1
        fi
    else
        echo ""
        echo -e "${BG_GREEN}${BOLD}  🔒 生产环境部署模式  ${NC}"
        echo ""
        log_info "混合端口绑定: GW/MQTT/MQTTS=0.0.0.0(设备直连), HTTPS管理=127.0.0.1(反代)"
        log_info "推荐通过反向代理(Nginx/Caddy)对外提供 Web 管理和固件下载"
        echo ""
    fi

    # 检测部署类型
    local DEPLOY_TYPE=$(detect_deployment_type)
    local IS_FIRST="false"
    if [ "$DEPLOY_TYPE" = "fresh" ] && [ ! -f "${APP_DATA_DIR}/admin.json" ]; then
        IS_FIRST="true"
        log_info "检测到首次部署"
    else
        log_info "检测到更新部署"
    fi

    create_data_directories

    # 交互式设置设备回调地址
    prompt_callback_addr
    # 同步回调地址到 SERVER_ADDR（供 start_new_container 使用）
    local SAVED_ADDR=$(get_callback_addr)
    if [ -n "${SAVED_ADDR}" ]; then
        SERVER_ADDR="${SAVED_ADDR}"
    fi

    # v5.2: SSL证书配置（交互式菜单，替代v5.0的自动搜索）
    deploy_cert_interactive_menu

    if ! check_port_conflicts; then
        return 1
    fi

    backup_current_image
    stop_old_container

    if ! pull_latest_image; then
        return 1
    fi

    start_new_container "$mode"
    save_deploy_mode "$mode"

    if health_check; then
        cleanup_old_images
        show_initial_password "$IS_FIRST"
        show_container_status

        if [ "$mode" = "production" ]; then
            show_production_deploy_success
        else
            show_test_deploy_success
        fi

        show_commands
        return 0
    else
        log_error "部署可能存在问题"
        show_initial_password "$IS_FIRST"
        return 1
    fi
}

show_production_deploy_success() {
    local PUBLIC_IP=$(get_public_ip)

    echo ""
    echo "=========================================="
    log_success "OTA-QL 部署完成！(生产环境)"
    echo "=========================================="
    echo ""
    echo "[基本信息]"
    echo "  镜像: ${IMAGE_NAME}"
    echo "  容器: ${CONTAINER_NAME}"
    echo "  数据: ${DATA_DIR}"
    echo ""

    echo "[服务端口] (混合绑定 — 安全模式)"
    echo "  HTTPS统一:  ${HTTPS_PORT}  — 127.0.0.1 (Web管理+API+固件,走反代)"
    echo "  cmux网关:   ${GW_PORT}  — 0.0.0.0 (TCP+TLS设备直连)"
    echo "  MQTT:       ${MQTT_PORT}  — 0.0.0.0 (设备直连)"
    echo "  MQTTS:      ${MQTTS_PORT}  — 0.0.0.0 (设备TLS直连)"
    echo ""

    local CB_ADDR=$(get_callback_addr)
    echo "[设备回调地址]"
    if [ -n "$CB_ADDR" ]; then
        echo -e "  ${GREEN}✓${NC} 回调地址:   ${CB_ADDR}"
        echo "  MQTT地址:    ${CB_ADDR}:${MQTTS_PORT} (MQTTS/TLS)"
        echo "  固件下载:    http://${CB_ADDR}:${HTTP_FW_PORT}/firmware"
    else
        echo -e "  ${YELLOW}!${NC} 未配置，使用服务器自动检测IP"
    fi
    echo ""

    echo "[访问地址]"
    echo -e "  ${GREEN}✓${NC} 管理面板:  https://localhost:${HTTPS_PORT}/"
    echo -e "  ${GREEN}✓${NC} 健康检查:  https://localhost:${HTTPS_PORT}/api/health"
    if [ -n "$PUBLIC_IP" ]; then
        echo -e "  ${RED}✗${NC} 公网访问:  https://${PUBLIC_IP}:${HTTPS_PORT}/ ${GREEN}(不可访问-安全)${NC}"
    fi
    echo ""

    echo "[管理员账户]"
    show_password_info
    echo ""

    echo -e "${BG_GREEN}${BOLD}  安全说明  ${NC}"
    echo -e "  ${GREEN}✓${NC} cmux网关/MQTT/MQTTS 绑定 0.0.0.0 (设备必须直连)"
    echo -e "  ${GREEN}✓${NC} HTTPS管理+固件 绑定 127.0.0.1 (仅反代可访问)"
    echo -e "  ${GREEN}✓${NC} 建议通过 Nginx/Caddy 反向代理 Web 管理和固件下载"

    # 显示TLS证书状态
    if [ -f "${CERTS_DIR}/fullchain.pem" ] && [ -f "${CERTS_DIR}/privkey.pem" ]; then
        echo -e "  ${GREEN}✓${NC} TLS证书已部署（CA签名，ESP32设备可验证）"
    else
        echo -e "  ${YELLOW}!${NC} 使用自签名证书，建议菜单 [11] 配置CA证书"
    fi
    echo ""
}

show_test_deploy_success() {
    local PUBLIC_IP=$(get_public_ip)

    echo ""
    echo "=========================================="
    log_success "OTA-QL 部署完成！(测试环境)"
    echo "=========================================="
    echo ""
    echo "[基本信息]"
    echo "  镜像: ${IMAGE_NAME}"
    echo "  容器: ${CONTAINER_NAME}"
    echo "  数据: ${DATA_DIR}"
    echo ""

    echo "[服务端口] (绑定 0.0.0.0 — 全部暴露!)"
    echo -e "  HTTPS统一:  ${HTTPS_PORT}  — ${RED}公网可访问${NC}"
    echo -e "  cmux网关:   ${GW_PORT}  — ${RED}公网可访问${NC}"
    echo -e "  MQTT:       ${MQTT_PORT}  — ${RED}公网可访问${NC}"
    echo -e "  MQTTS:      ${MQTTS_PORT}  — ${RED}公网可访问${NC}"
    echo ""

    local CB_ADDR=$(get_callback_addr)
    echo "[设备回调地址]"
    if [ -n "$CB_ADDR" ]; then
        echo -e "  ${GREEN}✓${NC} 回调地址:   ${CB_ADDR}"
        echo "  MQTT地址:    ${CB_ADDR}:${MQTTS_PORT} (MQTTS/TLS)"
        echo "  固件下载:    http://${CB_ADDR}:${HTTP_FW_PORT}/firmware"
    else
        echo -e "  ${YELLOW}!${NC} 未配置，使用服务器自动检测IP"
    fi
    echo ""

    echo "[访问地址]"
    echo -e "  ${GREEN}✓${NC} 管理面板:  https://localhost:${HTTPS_PORT}/"
    if [ -n "$PUBLIC_IP" ]; then
        echo -e "  ${GREEN}✓${NC} 公网管理:  https://${PUBLIC_IP}:${HTTPS_PORT}/ ${RED}(公网可访问!)${NC}"
    fi
    echo ""

    echo "[管理员账户]"
    show_password_info
    echo ""

    echo -e "${BG_RED}${BOLD}  ⚠️ 安全警告  ${NC}"
    echo -e "  ${RED}✗${NC} 所有端口暴露到公网，仅供测试使用"
    echo -e "  ${YELLOW}!${NC} 测试完成后请使用菜单 [1] 重新部署为生产环境"
    echo ""
}

show_commands() {
    echo "[常用命令]"
    echo "  查看日志:     docker logs -f ${CONTAINER_NAME}"
    echo "  重启容器:     docker restart ${CONTAINER_NAME}"
    echo "  停止容器:     docker stop ${CONTAINER_NAME}"
    echo "  查看状态:     docker ps -f name=${CONTAINER_NAME}"
    echo "  重置密码:     sudo ./ota-ql-docker-deploy.sh (菜单选项4)"
    echo ""
}

# ============================================================================
# 存储卷检查
# ============================================================================

check_volumes() {
    echo ""
    echo "=========================================="
    echo "  OTA-QL 存储卷检查"
    echo "=========================================="
    echo ""

    # 方法1: 检查数据目录
    echo "[1. 数据目录检查]"
    for dir_name in "firmware" "data" "certs" "logs"; do
        local dir_path="${DATA_DIR}/${dir_name}"
        if [ -d "${dir_path}" ]; then
            local dir_size=$(du -sh "${dir_path}" 2>/dev/null | cut -f1)
            local file_count=$(find "${dir_path}" -type f 2>/dev/null | wc -l)
            echo -e "  ${GREEN}✓${NC} ${dir_path} (${dir_size}, ${file_count}个文件)"
        else
            echo -e "  ${RED}✗${NC} ${dir_path} — 目录不存在"
        fi
    done
    echo ""

    # 方法2: 检查容器挂载
    echo "[2. 容器挂载检查]"
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        docker inspect --format='{{range .Mounts}}  {{.Source}} → {{.Destination}} ({{.Type}}){{println}}{{end}}' ${CONTAINER_NAME} 2>/dev/null
    else
        echo "  容器未安装，跳过"
    fi
    echo ""

    # 方法3: Docker Volume 检查
    echo "[3. Docker Volume 检查]"
    local VOLUMES=$(docker volume ls -q --filter "name=ota" 2>/dev/null)
    if [ -n "${VOLUMES}" ]; then
        echo "${VOLUMES}" | while read vol; do
            echo "  ${vol}"
        done
    else
        echo "  使用 bind mount（推荐），无 Docker Volume"
    fi
    echo ""

    # 方法4: 磁盘空间
    echo "[4. 磁盘空间]"
    df -h "${DATA_DIR}" 2>/dev/null | tail -1 | awk '{printf "  总容量: %s  已用: %s (%s)  可用: %s\n", $2, $3, $5, $4}'
    echo ""

    # 方法5: 关键文件
    echo "[5. 关键文件检查]"
    local ADMIN_FILE="${APP_DATA_DIR}/admin.json"
    if [ -f "${ADMIN_FILE}" ]; then
        local admin_size=$(stat -c%s "${ADMIN_FILE}" 2>/dev/null || echo "?")
        local admin_time=$(stat -c%y "${ADMIN_FILE}" 2>/dev/null | cut -d. -f1 || echo "?")
        echo -e "  ${GREEN}✓${NC} admin.json (${admin_size}B, 修改: ${admin_time})"
    else
        echo -e "  ${YELLOW}!${NC} admin.json — 不存在（首次启动会自动创建）"
    fi

    local FW_COUNT=$(find "${FIRMWARE_DIR}" -name "*.bin" -type f 2>/dev/null | wc -l)
    echo -e "  ${GREEN}✓${NC} 固件文件: ${FW_COUNT}个 .bin 文件"
    if [ "${FW_COUNT}" -gt 0 ]; then
        find "${FIRMWARE_DIR}" -name "*.bin" -type f -exec ls -lh {} \; 2>/dev/null | awk '{printf "    %s (%s)\n", $NF, $5}'
    fi
    echo ""
}

# ============================================================================
# 密码重置
# ============================================================================

reset_admin_password() {
    local ADMIN_FILE="${APP_DATA_DIR}/admin.json"

    echo ""
    echo "=========================================="
    echo "  OTA-QL 管理员密码重置"
    echo "=========================================="
    echo ""

    if [ ! -f "${ADMIN_FILE}" ]; then
        log_warning "管理员配置文件不存在"
        echo "  容器可能尚未初始化"
        echo "  如需重置: 使用菜单选项 [4. 重置管理员密码]"
        return 0
    fi

    echo -e "${YELLOW}警告：此操作将删除所有用户配置并重置为默认管理员${NC}"
    echo "  • admin.json 将被删除"
    echo "  • 系统会重新生成随机密码"
    echo "  • 所有已添加的用户将丢失"
    echo ""
    read -p "确定要重置密码吗？(输入 yes 确认): " CONFIRM

    if [ "$CONFIRM" != "yes" ]; then
        log_info "操作已取消"
        return 0
    fi

    # 备份配置
    local BACKUP_FILE="${ADMIN_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "${ADMIN_FILE}" "${BACKUP_FILE}"
    log_info "配置已备份: ${BACKUP_FILE}"

    # 删除配置并重启
    rm "${ADMIN_FILE}"
    docker restart ${CONTAINER_NAME} > /dev/null
    log_info "等待服务重启..."
    sleep 8

    local NEW_PASSWORD=$(get_current_password)

    if [ -n "$NEW_PASSWORD" ] && [ "$NEW_PASSWORD" != "" ]; then
        echo ""
        echo "=========================================="
        log_success "密码重置成功！"
        echo "=========================================="
        echo ""
        echo "┌────────────────────────────────────────────┐"
        echo "│  🔐 新的管理员登录凭据（仅显示一次！）     │"
        echo "├────────────────────────────────────────────┤"
        log_highlight "│  👤 用户名: admin"
        log_highlight "│  🔑 密码:   ${NEW_PASSWORD}"
        echo "├────────────────────────────────────────────┤"
        echo -e "│  ${RED}⚠️  请立即记录此密码！此后不再显示${NC}      │"
        echo -e "│  ${YELLOW}⚠️  登录后请立即修改密码！${NC}              │"
        echo "└────────────────────────────────────────────┘"
        echo ""
        log_highlight "管理面板: https://localhost:${HTTPS_PORT}/"
        echo ""
    else
        log_error "无法获取新密码"
        echo "  恢复原配置: cp ${BACKUP_FILE} ${ADMIN_FILE} && docker restart ${CONTAINER_NAME}"
    fi
}

# ============================================================================
# 检查更新
# ============================================================================

check_for_updates() {
    echo ""
    echo "=========================================="
    echo "  检查镜像更新"
    echo "=========================================="
    echo ""

    local LOCAL_IMAGE_ID=$(docker images ${IMAGE_NAME} --format "{{.ID}}" 2>/dev/null | head -n 1)

    if [ -z "${LOCAL_IMAGE_ID}" ]; then
        log_warning "本地未找到镜像，需要首次部署"
        return 1
    fi

    log_info "拉取远程镜像信息..."
    docker pull ${IMAGE_NAME} > /dev/null 2>&1

    local REMOTE_IMAGE_ID=$(docker images ${IMAGE_NAME} --format "{{.ID}}" 2>/dev/null | head -n 1)

    echo ""
    echo "镜像对比:"
    echo "   本地: ${LOCAL_IMAGE_ID:0:12}"
    echo "   远程: ${REMOTE_IMAGE_ID:0:12}"
    echo ""

    if [ "${LOCAL_IMAGE_ID}" = "${REMOTE_IMAGE_ID}" ]; then
        log_success "当前已是最新版本！"
        return 0
    else
        log_info "发现新版本可用！"
        echo ""
        read -p "是否立即更新？(输入 yes 确认): " UPDATE_CONFIRM
        if [ "${UPDATE_CONFIRM}" = "yes" ]; then
            local CURRENT_MODE=$(get_deploy_mode)
            if [ "${CURRENT_MODE}" = "unknown" ]; then
                CURRENT_MODE="production"
            fi
            deploy_container "${CURRENT_MODE}"
        else
            log_info "更新已取消"
        fi
    fi
}

# ============================================================================
# 备份与恢复
# ============================================================================

backup_data() {
    echo ""
    echo "=========================================="
    echo "  一键备份 OTA-QL 数据"
    echo "=========================================="
    echo ""

    if [ ! -d "${DATA_DIR}" ]; then
        log_error "数据目录不存在: ${DATA_DIR}"
        return 1
    fi

    sudo mkdir -p ${BACKUP_BASE_DIR}

    local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local BACKUP_FILE="${BACKUP_BASE_DIR}/ota-ql-data-${TIMESTAMP}.tar.gz"
    local DATA_SIZE=$(du -sh ${DATA_DIR} 2>/dev/null | cut -f1)

    echo "备份信息:"
    log_highlight "  源目录:   ${DATA_DIR}"
    log_highlight "  数据大小: ${DATA_SIZE}"
    log_highlight "  备份文件: ${BACKUP_FILE}"
    echo ""

    read -p "确认开始备份？[y/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        log_info "备份已取消"
        return 0
    fi

    log_info "开始备份..."
    if sudo tar -czf ${BACKUP_FILE} -C /opt ota-ql/ 2>&1; then
        local BACKUP_SIZE=$(du -sh ${BACKUP_FILE} | cut -f1)
        echo ""
        log_success "备份完成！"
        echo "  文件: ${BACKUP_FILE}"
        echo "  压缩前: ${DATA_SIZE} → 压缩后: ${BACKUP_SIZE}"
        echo ""

        # 记录到备份历史
        echo "$(date '+%Y-%m-%d %H:%M:%S') | ${BACKUP_FILE} | ${BACKUP_SIZE}" >> "${BACKUP_LIST_FILE}"

        # 预览备份内容
        echo "[备份内容预览]"
        tar -tzf ${BACKUP_FILE} | head -20
        local TOTAL_FILES=$(tar -tzf ${BACKUP_FILE} | wc -l)
        echo "  ... 共 ${TOTAL_FILES} 个文件/目录"
        echo ""

        echo "下载到本地: scp user@server:${BACKUP_FILE} ~/Downloads/"
    else
        log_error "备份失败！"
        return 1
    fi
}

restore_data() {
    echo ""
    echo "=========================================="
    echo "  一键恢复 OTA-QL 数据"
    echo "=========================================="
    echo ""

    if [ ! -d "${BACKUP_BASE_DIR}" ]; then
        log_warning "备份目录不存在: ${BACKUP_BASE_DIR}"
        read -p "指定备份文件路径 (或 n 取消): " CUSTOM_BACKUP
        if [ "${CUSTOM_BACKUP}" = "n" ] || [ -z "${CUSTOM_BACKUP}" ]; then
            return 0
        fi
        if [ ! -f "${CUSTOM_BACKUP}" ]; then
            log_error "文件不存在: ${CUSTOM_BACKUP}"
            return 1
        fi
        local BACKUP_FILE="${CUSTOM_BACKUP}"
    else
        local BACKUP_FILES=($(ls -t ${BACKUP_BASE_DIR}/ota-ql-data-*.tar.gz 2>/dev/null))

        if [ ${#BACKUP_FILES[@]} -eq 0 ]; then
            log_warning "未找到备份文件"
            return 0
        fi

        echo "可用的备份:"
        for i in "${!BACKUP_FILES[@]}"; do
            local BN=$(basename ${BACKUP_FILES[$i]})
            local BS=$(du -sh ${BACKUP_FILES[$i]} | cut -f1)
            echo "  [$((i+1))] ${BN} (${BS})"
        done
        echo "  [0] 指定其他路径"
        echo ""

        read -p "请选择 [0-${#BACKUP_FILES[@]}]: " CHOICE
        if [ "${CHOICE}" = "0" ]; then
            read -p "备份文件路径: " CUSTOM_BACKUP
            if [ ! -f "${CUSTOM_BACKUP}" ]; then
                log_error "文件不存在"
                return 1
            fi
            local BACKUP_FILE="${CUSTOM_BACKUP}"
        elif [ "${CHOICE}" -ge 1 ] 2>/dev/null && [ "${CHOICE}" -le ${#BACKUP_FILES[@]} ] 2>/dev/null; then
            local BACKUP_FILE="${BACKUP_FILES[$((CHOICE-1))]}"
        else
            log_warning "无效选择"
            return 0
        fi
    fi

    echo ""
    echo -e "${YELLOW}⚠️ 警告：此操作将覆盖当前所有数据！${NC}"
    echo "  包括: 用户配置、固件文件等"
    echo ""
    read -p "确认恢复？(输入 yes 确认): " CONFIRM
    if [ "${CONFIRM}" != "yes" ]; then
        log_info "操作已取消"
        return 0
    fi

    # 备份当前数据
    if [ -d "${DATA_DIR}" ]; then
        local CURRENT_BACKUP="${DATA_DIR}.pre-restore.$(date +%Y%m%d_%H%M%S)"
        log_info "备份当前数据到: ${CURRENT_BACKUP}"
        sudo cp -r ${DATA_DIR} ${CURRENT_BACKUP}
    fi

    log_info "恢复数据..."
    sudo rm -rf ${DATA_DIR}
    sudo mkdir -p /opt

    if sudo tar -xzf ${BACKUP_FILE} -C /opt/ 2>&1; then
        log_success "数据恢复完成！"
        echo ""

        # 显示恢复后的目录内容
        echo "[恢复后的数据]"
        ls -lah ${APP_DATA_DIR}/ 2>/dev/null
        echo ""

        if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            log_info "重启容器..."
            docker restart ${CONTAINER_NAME} > /dev/null
            sleep 3
            log_success "容器已重启"
        fi

        echo ""
        echo "后续操作:"
        echo "  1. 验证管理面板: https://localhost:${HTTPS_PORT}/"
        echo "  2. 检查固件文件: ls -la ${FIRMWARE_DIR}/"
        if [ -d "${CURRENT_BACKUP}" ]; then
            echo "  3. 如需回滚: sudo rm -rf ${DATA_DIR} && sudo mv ${CURRENT_BACKUP} ${DATA_DIR} && docker restart ${CONTAINER_NAME}"
        fi
        echo ""
    else
        log_error "恢复失败！"
        if [ -d "${CURRENT_BACKUP}" ]; then
            log_info "恢复原数据..."
            sudo rm -rf ${DATA_DIR}
            sudo mv ${CURRENT_BACKUP} ${DATA_DIR}
        fi
        return 1
    fi
}

view_backups() {
    echo ""
    echo "=========================================="
    echo "  备份管理"
    echo "=========================================="
    echo ""

    if [ ! -d "${BACKUP_BASE_DIR}" ]; then
        log_warning "备份目录不存在: ${BACKUP_BASE_DIR}"
        return 0
    fi

    local BACKUP_FILES=($(ls -t ${BACKUP_BASE_DIR}/ota-ql-data-*.tar.gz 2>/dev/null))
    if [ ${#BACKUP_FILES[@]} -eq 0 ]; then
        log_warning "未找到备份文件"
        return 0
    fi

    echo "备份文件列表 (共 ${#BACKUP_FILES[@]} 个):"
    echo ""
    for i in "${!BACKUP_FILES[@]}"; do
        local BN=$(basename ${BACKUP_FILES[$i]})
        local BS=$(du -sh ${BACKUP_FILES[$i]} | cut -f1)
        echo "  [$((i+1))] ${BN} (${BS})"
    done
    echo ""

    echo "操作:"
    echo "  1. 查看某个备份的内容"
    echo "  2. 删除指定备份"
    echo "  3. 清理旧备份（保留最新3个）"
    echo "  0. 返回"
    echo ""
    read -p "请选择 [0-3]: " ACTION

    case $ACTION in
        1)
            read -p "查看第几个备份? [1-${#BACKUP_FILES[@]}]: " VIEW_IDX
            if [ "${VIEW_IDX}" -ge 1 ] 2>/dev/null && [ "${VIEW_IDX}" -le ${#BACKUP_FILES[@]} ] 2>/dev/null; then
                local FILE="${BACKUP_FILES[$((VIEW_IDX-1))]}"
                echo ""
                echo "备份内容 ($(basename ${FILE})):"
                tar -tzf ${FILE} | head -30
                local TOTAL=$(tar -tzf ${FILE} | wc -l)
                echo "... 共 ${TOTAL} 个文件/目录"
            else
                log_warning "无效选择"
            fi
            ;;
        2)
            read -p "删除第几个备份? [1-${#BACKUP_FILES[@]}]: " DEL_IDX
            if [ "${DEL_IDX}" -ge 1 ] 2>/dev/null && [ "${DEL_IDX}" -le ${#BACKUP_FILES[@]} ] 2>/dev/null; then
                local FILE="${BACKUP_FILES[$((DEL_IDX-1))]}"
                read -p "确认删除 $(basename ${FILE})? [y/N]: " CONFIRM
                if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                    rm -f "${FILE}"
                    log_success "已删除: $(basename ${FILE})"
                fi
            else
                log_warning "无效选择"
            fi
            ;;
        3)
            if [ ${#BACKUP_FILES[@]} -le 3 ]; then
                log_info "备份不超过3个，无需清理"
            else
                local TO_DELETE=$((${#BACKUP_FILES[@]} - 3))
                echo "将删除 ${TO_DELETE} 个旧备份，保留最新3个"
                read -p "确认? [y/N]: " CONFIRM
                if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                    for ((i=3; i<${#BACKUP_FILES[@]}; i++)); do
                        rm -f "${BACKUP_FILES[$i]}"
                        echo "  已删除: $(basename ${BACKUP_FILES[$i]})"
                    done
                    log_success "旧备份已清理"
                fi
            fi
            ;;
        0) return 0 ;;
    esac
    echo ""
}

# ============================================================================
# 日志查看
# ============================================================================

view_logs() {
    echo ""
    echo "=========================================="
    echo "  查看容器日志"
    echo "=========================================="
    echo ""

    echo "选择查看方式:"
    echo "  1. 最近 50 行"
    echo "  2. 最近 200 行"
    echo "  3. 最近 500 行"
    echo "  4. 实时跟踪 (Ctrl+C 退出)"
    echo "  5. 搜索关键词"
    echo "  6. 只看错误/警告"
    echo "  7. 查看 OTA 推送记录"
    echo "  8. 查看设备连接记录"
    echo "  0. 返回"
    echo ""
    read -p "请选择 [0-8]: " LOG_CHOICE

    case ${LOG_CHOICE} in
        1) docker logs --tail 50 ${CONTAINER_NAME} 2>&1 ;;
        2) docker logs --tail 200 ${CONTAINER_NAME} 2>&1 ;;
        3) docker logs --tail 500 ${CONTAINER_NAME} 2>&1 ;;
        4)
            log_highlight "===== 实时日志 (Ctrl+C 退出) ====="
            trap 'echo ""; log_info "已退出实时日志"; trap - SIGINT' SIGINT
            docker logs -f --tail 20 ${CONTAINER_NAME} 2>&1
            trap - SIGINT
            ;;
        5)
            read -p "输入搜索关键词: " KEYWORD
            if [ -n "${KEYWORD}" ]; then
                docker logs ${CONTAINER_NAME} 2>&1 | grep -i --color=always "${KEYWORD}" | tail -50
            fi
            ;;
        6)
            docker logs ${CONTAINER_NAME} 2>&1 | grep -iE "error|fail|fatal|panic|warn" | tail -50 || log_info "未发现错误日志"
            ;;
        7)
            docker logs ${CONTAINER_NAME} 2>&1 | grep -i "ota\|推送\|firmware\|固件" | tail -50 || log_info "未发现OTA记录"
            ;;
        8)
            docker logs ${CONTAINER_NAME} 2>&1 | grep -i "连接\|注册\|connect\|register\|设备" | tail -50 || log_info "未发现设备记录"
            ;;
        0) return 0 ;;
        *) log_warning "无效选择" ;;
    esac
    echo ""
}

# ============================================================================
# 查看部署信息
# ============================================================================

show_deployment_info() {
    local deploy_mode=$(get_deploy_mode)
    local PUBLIC_IP=$(get_public_ip)

    echo ""
    echo "=========================================="
    echo "  OTA-QL 部署信息"
    echo "=========================================="
    echo ""

    echo "[部署模式]"
    if [ "$deploy_mode" = "test" ]; then
        echo -e "  ${BG_RED}${BOLD} ⚠️ 测试环境 (端口暴露-不安全) ${NC}"
    elif [ "$deploy_mode" = "production" ]; then
        echo -e "  ${BG_GREEN}${BOLD} 🔒 生产环境 (端口受限-安全) ${NC}"
    else
        echo -e "  ${YELLOW}部署模式: 未知${NC}"
    fi
    echo ""

    echo "[基本配置]"
    log_highlight "  容器名称: ${CONTAINER_NAME}"
    log_highlight "  镜像地址: ${IMAGE_NAME}"
    log_highlight "  数据目录: ${DATA_DIR}"
    echo ""

    echo "[容器状态]"
    docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || log_warning "容器未运行"
    echo ""

    echo "[镜像信息]"
    docker images "${IMAGE_NAME%%:*}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" 2>/dev/null || log_warning "无法获取镜像信息"
    echo ""

    echo "[存储卷]"
    docker inspect --format='{{range .Mounts}}  {{.Source}} → {{.Destination}} ({{.Type}}){{println}}{{end}}' ${CONTAINER_NAME} 2>/dev/null || log_warning "无法获取存储卷"
    echo ""

    local CB_ADDR=$(get_callback_addr)
    echo "[设备回调地址]"
    if [ -n "$CB_ADDR" ]; then
        echo -e "  ${GREEN}✓${NC} 回调地址:   ${CB_ADDR}"
        echo "  MQTT地址:    ${CB_ADDR}:${MQTTS_PORT} (MQTTS/TLS)"
        echo "  固件下载:    http://${CB_ADDR}:${HTTP_FW_PORT}/firmware"
    else
        echo -e "  ${YELLOW}!${NC} 未配置，使用服务器自动检测IP"
    fi
    echo ""

    echo "[管理员账户]"
    show_password_info
    echo ""

    echo "[访问地址]"
    echo -e "  ${GREEN}✓${NC} 管理面板:  https://localhost:${HTTPS_PORT}/"
    echo -e "  ${GREEN}✓${NC} 健康检查:  https://localhost:${HTTPS_PORT}/api/health"
    if [ -n "$PUBLIC_IP" ]; then
        if [ "$deploy_mode" = "test" ]; then
            echo -e "  ${GREEN}✓${NC} 公网管理:  https://${PUBLIC_IP}:${HTTPS_PORT}/ ${RED}(可访问)${NC}"
        else
            echo -e "  ${RED}✗${NC} 公网管理:  https://${PUBLIC_IP}:${HTTPS_PORT}/ ${GREEN}(不可访问)${NC}"
        fi
    fi
    echo ""

    echo "[资源使用]"
    docker stats ${CONTAINER_NAME} --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null || log_warning "容器未运行"
    echo ""
}

# ============================================================================
# 交互式菜单
# ============================================================================

interactive_menu() {
    trap 'echo ""; log_info "返回主菜单..."; echo ""' SIGINT

    while true; do
        echo ""
        echo "=========================================="
        echo "  OTA-QL 管理工具 (v5.2)"
        echo "=========================================="
        echo ""
        echo -e "  ${GREEN}1.${NC}  一键部署 ${GREEN}(生产环境-安全)${NC}"
        echo "  2.  检查存储卷"
        echo "  3.  查看部署信息"
        echo "  4.  重置管理员密码"
        echo "  5.  检查更新"
        echo "  6.  一键备份数据"
        echo "  7.  一键恢复数据"
        echo "  8.  备份管理"
        echo "  9.  查看日志"
        echo -e "  ${CYAN}10.${NC} 设备回调地址设置与查看"
        echo -e "  ${CYAN}11.${NC} SSL证书管理"
        echo "  12. 退出"
        echo -e "  ${RED}13.${NC} 一键部署 ${RED}(仅测试-不安全)${NC}"
        echo ""
        read -p "请选择操作 [1-13]: " choice

        case $choice in
            1)
                deploy_container "production"
                read -p "按Enter键返回菜单..." dummy
                ;;
            2)
                check_volumes
                read -p "按Enter键返回菜单..." dummy
                ;;
            3)
                if check_container_installed; then
                    show_deployment_info
                fi
                read -p "按Enter键返回菜单..." dummy
                ;;
            4)
                if check_container_running; then
                    reset_admin_password
                fi
                read -p "按Enter键返回菜单..." dummy
                ;;
            5)
                if check_container_installed; then
                    check_for_updates
                fi
                read -p "按Enter键返回菜单..." dummy
                ;;
            6)
                backup_data
                read -p "按Enter键返回菜单..." dummy
                ;;
            7)
                restore_data
                read -p "按Enter键返回菜单..." dummy
                ;;
            8)
                view_backups
                read -p "按Enter键返回菜单..." dummy
                ;;
            9)
                if check_container_installed; then
                    view_logs
                fi
                read -p "按Enter键返回菜单..." dummy
                ;;
            10)
                menu_set_callback_addr
                read -p "按Enter键返回菜单..." dummy
                ;;
            11)
                menu_cert_management
                read -p "按Enter键返回菜单..." dummy
                ;;
            12)
                echo ""
                log_info "退出管理工具"
                echo ""
                exit 0
                ;;
            13)
                echo ""
                echo -e "${BG_RED}${BOLD}  ⚠️ 警告：测试环境部署  ${NC}"
                echo ""
                echo "此选项会将所有端口暴露到所有网络接口（含公网！）"
                echo -e "${YELLOW}仅建议用于临时测试，测试完成后请用菜单 [1] 重新部署${NC}"
                echo ""
                deploy_container "test"
                read -p "按Enter键返回菜单..." dummy
                ;;
            *)
                log_warning "无效选择，请输入 1-13"
                sleep 1
                ;;
        esac
    done
}

# ============================================================================
# 主流程
# ============================================================================

main() {
    echo ""
    echo "=========================================="
    echo "  OTA-QL Docker 部署管理工具"
    echo "  版本: v5.2 | 清澜雷达 OTA 升级系统"
    echo "  服务: HTTPS/HTTP_FW/GW/MQTT/MQTTS (5端口)"
    echo "=========================================="
    echo ""

    check_docker

    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        if docker ps --filter "name=${CONTAINER_NAME}" --filter "status=running" | grep -q "${CONTAINER_NAME}"; then
            log_success "OTA-QL 状态: 已安装并运行中"
            local deploy_mode=$(get_deploy_mode)
            if [ "$deploy_mode" = "test" ]; then
                echo -e "  ${RED}部署模式: 测试环境 (端口暴露-不安全)${NC}"
            elif [ "$deploy_mode" = "production" ]; then
                echo -e "  ${GREEN}部署模式: 生产环境 (端口受限-安全)${NC}"
            fi
        else
            log_warning "OTA-QL 状态: 已安装但未运行"
        fi
    else
        log_info "OTA-QL 状态: 未安装"
        echo ""
        echo "提示: 请选择菜单 [1. 一键部署] 开始安装"
    fi

    echo ""
    interactive_menu
}

# 脚本入口
main "$@"
