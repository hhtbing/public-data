#!/bin/bash

###############################################################################
# OTA-QL Docker 自动部署与管理脚本
# 文件名: ota-ql-docker-deploy.sh
# 用途: 首次部署、滚动更新、备份恢复、密码重置、存储卷检查、日志管理
# 作者: WiseFido Technologies
# 版本: v3.0
# 更新: 2026-02-26
#
# 一键部署（推荐）:
#   wget -O ota-ql-docker-deploy.sh "https://raw.githubusercontent.com/hhtbing-wisefido/public-data/main/OTA-QL-data/ota-ql-docker-deploy.sh" && chmod +x ota-ql-docker-deploy.sh && sudo ./ota-ql-docker-deploy.sh
#
# 服务端口:
#   TCP  1060 — V2 TCP调度/注册（设备直连）
#   HTTP 8688 — 固件下载（Range/206）
#   API  8690 — Web管理面板/RESTful API
#   HTTPS 8443 — V3 HTTPS认证
#   MQTT 1883 — V3 MQTT Broker
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
BACKUP_BASE_DIR="/backup/ota-ql"
BACKUP_LIST_FILE="${BACKUP_BASE_DIR}/.backup_list"

# 服务端口
TCP_PORT="1060"          # V2 TCP调度/注册
HTTP_PORT="8688"         # HTTP固件下载
API_PORT="8690"          # Web管理面板/API
HTTPS_PORT="8443"         # V3 HTTPS认证
MQTT_PORT="1883"         # V3 MQTT Broker

# 环境变量覆盖
SERVER_ADDR="${OTA_SERVER_ADDR:-}"
LOG_LEVEL="${OTA_LOG_LEVEL:-info}"

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
    local PORTS=("${TCP_PORT}" "${HTTP_PORT}" "${API_PORT}" "${HTTPS_PORT}" "${MQTT_PORT}")
    local NAMES=("TCP调度" "HTTP固件" "Web管理" "HTTPS认证" "MQTT")

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
        echo "  2. 查看占用详情: sudo ss -tlnp | grep -E '8443|1060|8688|8690|1883'"
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
# 生产模式: TCP/MQTT 绑定 0.0.0.0 (设备直连), 其余绑定 127.0.0.1 (反代)
# 测试模式: 全部绑定 0.0.0.0
start_new_container() {
    local MODE="${1:-production}"
    log_info "启动新容器..."

    if [ "$MODE" = "test" ]; then
        log_info "端口绑定模式: 0.0.0.0 (全部暴露)"
        local TCP_BIND="0.0.0.0"
        local HTTP_BIND="0.0.0.0"
        local API_BIND="0.0.0.0"
        local HTTPS_BIND="0.0.0.0"
        local MQTT_BIND="0.0.0.0"
    else
        log_info "端口绑定模式: 混合 (TCP/MQTT=0.0.0.0, Web/HTTP/HTTPS=127.0.0.1)"
        local TCP_BIND="0.0.0.0"     # 设备直连，必须暴露
        local HTTP_BIND="127.0.0.1"  # 固件下载走反代
        local API_BIND="127.0.0.1"   # Web管理走反代
        local HTTPS_BIND="0.0.0.0"   # V3设备TLS直连，必须暴露
        local MQTT_BIND="0.0.0.0"    # V3设备MQTT直连，必须暴露
    fi

    local ENV_ARGS=""
    if [ -n "${SERVER_ADDR}" ]; then
        ENV_ARGS="-e OTA_SERVER_ADDR=${SERVER_ADDR}"
    fi

    docker run -d \
        --name ${CONTAINER_NAME} \
        --restart unless-stopped \
        -p ${TCP_BIND}:${TCP_PORT}:1060 \
        -p ${HTTP_BIND}:${HTTP_PORT}:8688 \
        -p ${API_BIND}:${API_PORT}:8690 \
        -p ${HTTPS_BIND}:${HTTPS_PORT}:8443 \
        -p ${MQTT_BIND}:${MQTT_PORT}:1883 \
        -v ${FIRMWARE_DIR}:/app/firmware \
        -v ${APP_DATA_DIR}:/app/data \
        -v ${CERTS_DIR}:/app/certs \
        -v ${LOGS_DIR}:/app/logs \
        ${ENV_ARGS} \
        --health-cmd="wget -q --spider http://localhost:8690/api/health || exit 1" \
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

    log_info "执行健康检查（API + 端口）..."
    local MAX_RETRIES=20
    local RETRY_COUNT=0
    local API_OK=false
    local TCP_OK=false

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        # 检查容器是否还在运行
        if ! docker ps --filter "name=${CONTAINER_NAME}" --filter "status=running" | grep -q "${CONTAINER_NAME}"; then
            log_error "容器未运行！"
            echo "  查看日志: docker logs --tail 50 ${CONTAINER_NAME}"
            return 1
        fi

        # 检查 API 端点
        if ! $API_OK; then
            if curl -sf http://localhost:${API_PORT}/api/health > /dev/null 2>&1; then
                API_OK=true
            fi
        fi

        # 检查 TCP 端口
        if ! $TCP_OK; then
            if (echo > /dev/tcp/localhost/${TCP_PORT}) 2>/dev/null; then
                TCP_OK=true
            fi
        fi

        # 两个都通过则成功
        if $API_OK && $TCP_OK; then
            echo ""
            echo -e "  ${GREEN}✓${NC} API端点 (${API_PORT})  — 正常"
            echo -e "  ${GREEN}✓${NC} TCP端口 (${TCP_PORT})  — 正常"
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
        echo -e "  ${GREEN}✓${NC} API端点 (${API_PORT})  — 正常"
    else
        echo -e "  ${RED}✗${NC} API端点 (${API_PORT})  — 失败"
    fi
    if $TCP_OK; then
        echo -e "  ${GREEN}✓${NC} TCP端口 (${TCP_PORT})  — 正常"
    else
        echo -e "  ${RED}✗${NC} TCP端口 (${TCP_PORT})  — 失败"
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
        echo -e "│  ${GREEN}管理面板: http://localhost:${API_PORT}/${NC}      │"
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
# 部署入口
# ============================================================================

deploy_container() {
    local mode="${1:-production}"

    if [ "$mode" = "test" ]; then
        echo ""
        echo -e "${BG_RED}${BOLD}  ⚠️  测试环境部署模式  ${NC}"
        echo ""
        log_warning "此模式将所有端口暴露到所有网络接口（含公网！）"
        log_warning "TCP(${TCP_PORT}) HTTP(${HTTP_PORT}) API(${API_PORT}) HTTPS(${HTTPS_PORT}) MQTT(${MQTT_PORT})"
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
        log_info "混合端口绑定: TCP/HTTPS/MQTT=0.0.0.0(设备直连), Web/HTTP=127.0.0.1(反代)"
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
    echo "  TCP调度:    ${TCP_PORT}  — 0.0.0.0 (设备直连)"
    echo "  HTTP固件:   ${HTTP_PORT}  — 127.0.0.1 (反代)"
    echo "  Web管理:    ${API_PORT}  — 127.0.0.1 (反代)"
    echo "  HTTPS认证:  ${HTTPS_PORT}   — 0.0.0.0 (设备TLS直连)"
    echo "  MQTT:       ${MQTT_PORT}  — 0.0.0.0 (设备直连)"
    echo ""

    echo "[访问地址]"
    echo -e "  ${GREEN}✓${NC} 管理面板:  http://localhost:${API_PORT}/"
    echo -e "  ${GREEN}✓${NC} 健康检查:  http://localhost:${API_PORT}/api/health"
    if [ -n "$PUBLIC_IP" ]; then
        echo -e "  ${RED}✗${NC} 公网访问:  http://${PUBLIC_IP}:${API_PORT}/ ${GREEN}(不可访问-安全)${NC}"
    fi
    echo ""

    echo "[管理员账户]"
    show_password_info
    echo ""

    echo -e "${BG_GREEN}${BOLD}  安全说明  ${NC}"
    echo -e "  ${GREEN}✓${NC} TCP/HTTPS/MQTT 绑定 0.0.0.0 (设备必须直连)"
    echo -e "  ${GREEN}✓${NC} Web管理/HTTP固件 绑定 127.0.0.1 (仅反代可访问)"
    echo -e "  ${GREEN}✓${NC} 建议通过 Nginx/Caddy 反向代理 Web 和固件服务"
    echo -e "  ${GREEN}✓${NC} 推荐启用 HTTPS (Let's Encrypt 免费证书)"
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
    echo -e "  TCP调度:    ${TCP_PORT}  — ${RED}公网可访问${NC}"
    echo -e "  HTTP固件:   ${HTTP_PORT}  — ${RED}公网可访问${NC}"
    echo -e "  Web管理:    ${API_PORT}  — ${RED}公网可访问${NC}"
    echo -e "  HTTPS认证:  ${HTTPS_PORT}   — ${RED}公网可访问${NC}"
    echo -e "  MQTT:       ${MQTT_PORT}  — ${RED}公网可访问${NC}"
    echo ""

    echo "[访问地址]"
    echo -e "  ${GREEN}✓${NC} 管理面板:  http://localhost:${API_PORT}/"
    if [ -n "$PUBLIC_IP" ]; then
        echo -e "  ${GREEN}✓${NC} 公网管理:  http://${PUBLIC_IP}:${API_PORT}/ ${RED}(公网可访问!)${NC}"
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
        log_highlight "管理面板: http://localhost:${API_PORT}/"
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
        echo "  1. 验证管理面板: http://localhost:${API_PORT}/"
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

    echo "[管理员账户]"
    show_password_info
    echo ""

    echo "[访问地址]"
    echo -e "  ${GREEN}✓${NC} 管理面板:  http://localhost:${API_PORT}/"
    echo -e "  ${GREEN}✓${NC} 健康检查:  http://localhost:${API_PORT}/api/health"
    if [ -n "$PUBLIC_IP" ]; then
        if [ "$deploy_mode" = "test" ]; then
            echo -e "  ${GREEN}✓${NC} 公网管理:  http://${PUBLIC_IP}:${API_PORT}/ ${RED}(可访问)${NC}"
        else
            echo -e "  ${RED}✗${NC} 公网管理:  http://${PUBLIC_IP}:${API_PORT}/ ${GREEN}(不可访问)${NC}"
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
        echo "  OTA-QL 管理工具 (v3.0)"
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
        echo "  10. 退出"
        echo -e "  ${RED}11.${NC} 一键部署 ${RED}(仅测试-不安全)${NC}"
        echo ""
        read -p "请选择操作 [1-11]: " choice

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
                echo ""
                log_info "退出管理工具"
                echo ""
                exit 0
                ;;
            11)
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
                log_warning "无效选择，请输入 1-11"
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
    echo "  版本: v3.0 | 清澜雷达 OTA 升级系统"
    echo "  服务: TCP/HTTP/API/HTTPS/MQTT (5端口)"
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
