#!/bin/bash

###############################################################################
# 通用Linux自动化工具集
# 文件名: linux-tools.sh
# 用途: 提供系统信息查询、SSL证书管理、网络工具、抓包管理等通用Linux自动化功能
# 作者: WiseFido Technologies
# 版本: v2.0
# 更新: 2026-03-20
#
# 一键部署:
#   wget -O linux-tools.sh "https://raw.githubusercontent.com/hhtbing/public-data/main/linux-tools/linux-tools.sh" && chmod +x linux-tools.sh && sudo ./linux-tools.sh
#
# 版本历史:
#   v2.0 (2026-03-20): 增加版本化管理、抓包管理功能
#   v1.0 (2024-01-01): 初始版本，包含系统信息、SSL管理、网络工具、系统工具、文件管理
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
CERTS_DIR="/opt/certs"
LOG_DIR="/var/log/linux-tools"

# 权限管理变量
CURRENT_USER=$(whoami)
HAS_ROOT=false

# 创建必要目录
mkdir -p "${CERTS_DIR}" "${LOG_DIR}" 2>/dev/null

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
log_info()      { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success()   { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning()   { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()     { echo -e "${RED}[ERROR]${NC} $1"; }
log_highlight() { echo -e "${CYAN}$1${NC}"; }

# 检查当前权限
check_permission() {
    if [ "$(id -u)" -eq 0 ]; then
        HAS_ROOT=true
        log_success "当前用户: root (管理员权限)"
    else
        HAS_ROOT=false
        log_info "当前用户: $CURRENT_USER (普通用户权限)"
    fi
}

# 切换到root权限
switch_to_root() {
    if [ "$HAS_ROOT" = true ]; then
        log_warning "已经是管理员权限，无需切换"
        return 0
    fi

    log_info "正在尝试切换到管理员权限..."

    # 检查sudo是否可用
    if command -v sudo &>/dev/null; then
        log_info "使用sudo切换权限"
        # 重新以root权限执行脚本
        exec sudo "$0" "$@"
    else
        log_error "未找到sudo命令，无法切换权限"
        return 1
    fi
}

# 切换回普通用户权限
switch_to_user() {
    if [ "$HAS_ROOT" = false ]; then
        log_warning "已经是普通用户权限，无需切换"
        return 0
    fi

    if [ "$CURRENT_USER" = "root" ]; then
        log_error "无法从root切换到其他用户，因为原始用户未知"
        return 1
    fi

    log_info "正在切换回普通用户权限..."
    exec su - "$CURRENT_USER" -c "$0 $@"
}

# ============================================================================
# 系统信息查询
# ============================================================================

query_system_info() {
    echo ""
    echo "=========================================="
    echo "  🖥️  系统信息查询"
    echo "=========================================="
    echo ""

    # 基本系统信息
    echo -e "${GREEN}🔹 基本信息${NC}"
    echo "  ────────────────────────────────────"
    echo -e "  系统: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')"
    echo -e "  内核: $(uname -r)"
    echo -e "  架构: $(uname -m)"
    echo -e "  主机名: $(hostname)"
    echo -e "  IP地址: $(hostname -I | awk '{print $1}')"
    echo -e "  运行时间: $(uptime -p)"
    echo ""

    # CPU信息
    echo -e "${GREEN}🔹 CPU信息${NC}"
    echo "  ────────────────────────────────────"
    echo -e "  型号: $(lscpu 2>/dev/null | grep 'Model name' | cut -d':' -f2 | sed 's/^[ 	]*//')"
    echo -e "  核心数: $(nproc)"
    echo -e "  使用率: $(top -bn1 | grep 'Cpu(s)' | awk '{printf "%.1f%%", $2 + $4}')"
    echo ""

    # 内存信息
    echo -e "${GREEN}🔹 内存信息${NC}"
    echo "  ────────────────────────────────────"
    free -h | awk 'NR==2{printf "  总内存: %s\n  已使用: %s\n  可用: %s\n  使用率: %.1f%%\n", $2, $3, $7, ($3/$2)*100}'
    echo ""

    # 磁盘信息
    echo -e "${GREEN}🔹 磁盘信息${NC}"
    echo "  ────────────────────────────────────"
    df -h | grep -E '^/dev/' | awk '{printf "  %s: %s 已用: %s (%s) 可用: %s\n", $1, $2, $3, $5, $4}'
    echo ""

    # 网络信息
    echo -e "${GREEN}🔹 网络信息${NC}"
    echo "  ────────────────────────────────────"
    echo -e "  公网IP: $(curl -s ip.sb 2>/dev/null || echo '无法获取')"
    echo -e "  网关: $(ip route 2>/dev/null | grep default | awk '{print $3}')"
    echo -e "  DNS: $(cat /etc/resolv.conf 2>/dev/null | grep nameserver | awk '{print $2}' | tr '\n' ' ')"
    echo ""

    # 系统负载
    echo -e "${GREEN}🔹 系统负载${NC}"
    echo "  ────────────────────────────────────"
    uptime | awk '{print "  1分钟: " $10 "  5分钟: " $11 "  15分钟: " $12}'
    echo ""
}

# ============================================================================
# SSL 证书管理功能
# ============================================================================

# 查看当前证书状态
show_deployed_cert_info() {
    echo ""
    echo "=========================================="
    echo "  🔒 当前证书状态"
    echo "=========================================="
    echo ""

    local candidates=()

    # 首先检查统一路径
    if [ -f "${CERTS_DIR}/fullchain.pem" ] && [ -f "${CERTS_DIR}/privkey.pem" ]; then
        candidates+=("${CERTS_DIR}/fullchain.pem|${CERTS_DIR}/privkey.pem|本地目录")
    fi

    # 检查定义的面板路径
    for path_entry in "${CERT_SEARCH_PATHS[@]}"; do
        local cert_path=$(echo "$path_entry" | cut -d'|' -f2)
        local key_path=$(echo "$path_entry" | cut -d'|' -f3)
        if [ -f "$cert_path" ] && [ -f "$key_path" ]; then
            local panel=$(echo "$path_entry" | cut -d'|' -f1)
            candidates+=("$cert_path|$key_path|$panel")
        fi
    done

    # 兼容路径额外搜索
    local extra_paths=(
        "/etc/letsencrypt/live/*/fullchain.pem"
        "/root/.acme.sh/*/fullchain.cer"
        "/www/server/panel/vhost/cert/*/fullchain.pem"
        "/www/server/panel/vhost/ssl/*/fullchain.pem"
        "/etc/nginx/ssl/*/fullchain.pem"
        "/etc/apache2/ssl/*/fullchain.pem"
        "/etc/httpd/ssl/*/fullchain.pem"
        "/var/lib/caddy/.local/share/caddy/certificates/*/*/*.crt"
    )

    for pattern in "${extra_paths[@]}"; do
        for cert_file in $(find $pattern 2>/dev/null); do
            local key_file=""
            if [ "${cert_file##*.}" = "pem" ]; then
                key_file=$(echo "$cert_file" | sed 's/fullchain\.pem/privkey\.pem/')
            elif [ "${cert_file##*.}" = "cer" ]; then
                local domain=$(basename "$(dirname "$cert_file")")
                key_file=$(dirname "$cert_file")"/${domain}.key
            elif [ "${cert_file##*.}" = "crt" ]; then
                key_file="${cert_file%.crt}.key"
            fi

            if [ -n "${key_file}" ] && [ -f "$key_file" ]; then
                candidates+=("$cert_file|$key_file|自动搜索")
            fi
        done
    done

    if [ ${#candidates[@]} -eq 0 ]; then
        log_warning "未找到已部署证书，请先部署或手动指定路径"
        echo "  默认证书目录: ${CERTS_DIR}"
        echo "  你可以使用 SSL证书管理 -> 全局搜索系统证书 -> 手动指定路径"
        echo ""
        return 1
    fi

    log_success "找到 ${#candidates[@]} 个候选证书"

    local idx=0
    for item in "${candidates[@]}"; do
        idx=$((idx+1))
        local cert_path=$(echo "$item" | cut -d'|' -f1)
        local key_path=$(echo "$item" | cut -d'|' -f2)
        local src=$(echo "$item" | cut -d'|' -f3)
        echo "  [$idx] 源: $src"
        echo "      证书: $cert_path"
        echo "      私钥: $key_path"
    done

    if [ ${#candidates[@]} -gt 1 ]; then
        read -ep "请选择要展示详细状态的证书 (1-${#candidates[@]}, 0 取消, 默认1): " sel
        if [ -z "$sel" ]; then
            sel=1
        fi
        if [ "$sel" = "0" ]; then
            echo "已取消"
            echo ""
            return 0
        fi
        if ! [[ "$sel" =~ ^[0-9]+$ ]] || [ "$sel" -lt 1 ] || [ "$sel" -gt ${#candidates[@]} ]; then
            log_warning "选择无效，默认取第1个"
            sel=1
        fi
    else
        sel=1
    fi

    local choice=${candidates[$((sel-1))]}
    local chosen_cert=$(echo "$choice" | cut -d'|' -f1)
    local chosen_key=$(echo "$choice" | cut -d'|' -f2)

    echo ""
    echo "正在展示: $chosen_cert"
    echo ""

    log_success "已选证书：$chosen_cert"
    log_success "对应私钥：$chosen_key"

    if [ -f "$chosen_cert" ]; then
        local cert_info=$(openssl x509 -in "$chosen_cert" -noout -subject -issuer -dates -serial -sha256 -fingerprint 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "证书详细信息:"
            echo "  ────────────────────────────────────"
            echo "$cert_info" | sed 's/^/  /'
            echo ""

            local expire_date=$(openssl x509 -in "$chosen_cert" -noout -enddate 2>/dev/null | cut -d'=' -f2)
            local expire_seconds=$(date -d "$expire_date" +%s 2>/dev/null)
            local now_seconds=$(date +%s)
            local days_left=$(( (expire_seconds - now_seconds) / 86400 ))

            if [ "$expire_seconds" -gt 0 ]; then
                if [ $days_left -gt 30 ]; then
                    echo -e "  ${GREEN}✓${NC} 有效期: $days_left 天"
                elif [ $days_left -gt 7 ]; then
                    echo -e "  ${YELLOW}!${NC} 有效期: $days_left 天 (即将过期)"
                else
                    echo -e "  ${RED}✗${NC} 有效期: $days_left 天 (紧急过期)"
                fi
            else
                echo "  ${RED}✗${NC} 无法解析有效期";
            fi

            echo "  证书路径: $chosen_cert"
            echo "  私钥路径: $chosen_key"
            echo ""
            echo "  部署提示：可将此证书复制到 ${CERTS_DIR}/fullchain.pem 和 ${CERTS_DIR}/privkey.pem";
            echo "  示例: sudo cp -f $chosen_cert ${CERTS_DIR}/fullchain.pem && sudo cp -f $chosen_key ${CERTS_DIR}/privkey.pem"
            echo "  并设置 chmod 644/600"
        else
            log_warning "无法读取证书详情，请确认 openssl 是否可用及证书有效"
        fi
    else
        log_error "所选证书文件不存在: $chosen_cert"
    fi

    echo ""
}

# 按域名搜索证书
FOUND_CERTS=()
search_certs_for_domain() {
    local domain="$1"
    echo ""
    echo "=========================================="
    echo "  🔍 搜索域名 '$domain' 的证书"
    echo "=========================================="
    echo ""

    FOUND_CERTS=()
    local found=0

    for path_entry in "${CERT_SEARCH_PATHS[@]}"; do
        local panel=$(echo "$path_entry" | cut -d'|' -f1)
        local cert_path=$(echo "$path_entry" | cut -d'|' -f2 | sed "s/<DOMAIN>/$domain/g")
        local key_path=$(echo "$path_entry" | cut -d'|' -f3 | sed "s/<DOMAIN>/$domain/g")

        if [ -f "$cert_path" ] && [ -f "$key_path" ]; then
            echo -e "  ${GREEN}✓${NC} ${panel}"
            echo -e "    证书: $cert_path"
            echo -e "    私钥: $key_path"
            FOUND_CERTS+=("$panel|$cert_path|$key_path")
            found=1
        fi
    done

    if [ $found -eq 0 ]; then
        log_warning "未找到域名 '$domain' 的证书"
    fi
    echo ""
}

# 全局搜索系统中所有证书
global_search_certs() {
    echo ""
    echo "=========================================="
    echo "  🌐 全局搜索系统证书"
    echo "=========================================="
    echo ""
    echo "正在搜索常见位置的证书文件..."
    echo ""

    # 常见证书位置
    local search_paths=(
        "/etc/letsencrypt/live/*/fullchain.pem"
        "/root/.acme.sh/*/fullchain.cer"
        "/www/server/panel/vhost/cert/*/fullchain.pem"
        "/www/server/panel/vhost/ssl/*/fullchain.pem"
        "/etc/nginx/ssl/*/fullchain.pem"
        "/etc/apache2/ssl/*/fullchain.pem"
        "/etc/httpd/ssl/*/fullchain.pem"
        "/var/lib/caddy/.local/share/caddy/certificates/*/*/*.crt"
    )

    local found_certs=()
    for pattern in "${search_paths[@]}"; do
        for cert_file in $(find ${pattern} 2>/dev/null); do
            # 提取域名
            local domain=$(echo "$cert_file" | grep -oP '(?<=/)[^/]+(?=/fullchain\.pem$|/fullchain\.cer$|/[^/]+\.crt$)')
            if [ -n "$domain" ]; then
                # 查找对应的私钥
                local key_file=""
                if [ "${cert_file##*.}" = "pem" ]; then
                    key_file=$(echo "$cert_file" | sed 's/fullchain\.pem/privkey\.pem/')
                elif [ "${cert_file##*.}" = "cer" ]; then
                    key_file=$(echo "$cert_file" | sed 's/fullchain\.cer/'"$domain"'.key/')
                elif [ "${cert_file##*.}" = "crt" ]; then
                    key_file=$(echo "$cert_file" | sed 's/\.crt/\.key/')
                fi

                if [ -f "$key_file" ]; then
                    found_certs+=("$domain|$cert_file|$key_file")
                fi
            fi
        done
    done

    if [ ${#found_certs[@]} -eq 0 ]; then
        log_warning "未找到任何证书文件"
    else
        log_success "找到 ${#found_certs[@]} 个证书"
        echo ""
        for cert in "${found_certs[@]}"; do
            local domain=$(echo "$cert" | cut -d'|' -f1)
            local cert_file=$(echo "$cert" | cut -d'|' -f2)
            local key_file=$(echo "$cert" | cut -d'|' -f3)
            echo -e "  ${GREEN}✓${NC} 域名: $domain"
            echo -e "    证书: $cert_file"
            echo -e "    私钥: $key_file"
            echo ""
        done
    fi
}

# 手动指定证书路径
manual_deploy_cert() {
    echo ""
    echo "=========================================="
    echo "  📁 手动指定证书路径"
    echo "=========================================="
    echo ""

    read -ep "请输入证书文件路径: " cert_path
    read -ep "请输入私钥文件路径: " key_path

    if [ ! -f "$cert_path" ]; then
        log_error "证书文件不存在: $cert_path"
        return 1
    fi

    if [ ! -f "$key_path" ]; then
        log_error "私钥文件不存在: $key_path"
        return 1
    fi

    # 验证证书和私钥匹配
    local cert_mod=$(openssl x509 -noout -modulus -in "$cert_path" 2>/dev/null | openssl md5)
    local key_mod=$(openssl rsa -noout -modulus -in "$key_path" 2>/dev/null || openssl ec -noout -modulus -in "$key_path" 2>/dev/null)
    key_mod=$(echo "$key_mod" | openssl md5)

    if [ "$cert_mod" != "$key_mod" ]; then
        log_error "证书和私钥不匹配！"
        return 1
    fi

    # 复制证书到统一目录
    cp -f "$cert_path" "${CERTS_DIR}/fullchain.pem"
    cp -f "$key_path" "${CERTS_DIR}/privkey.pem"

    chmod 600 "${CERTS_DIR}/privkey.pem"
    chmod 644 "${CERTS_DIR}/fullchain.pem"

    log_success "证书部署成功！"
    echo "  证书已复制到: ${CERTS_DIR}/"
    show_deployed_cert_info
}

# SSL证书申请指南
show_cert_guide() {
    echo ""
    echo "=========================================="
    echo "  📚 SSL证书申请指南"
    echo "=========================================="
    echo ""
    echo "推荐使用 Let's Encrypt 免费证书，支持自动续期"
    echo ""
    echo "1. 使用 Certbot 申请证书:"
    echo "   sudo apt update && sudo apt install certbot -y"
    echo "   sudo certbot certonly --standalone -d your-domain.com"
    echo ""
    echo "2. 使用 acme.sh 申请证书:"
    echo "   curl https://get.acme.sh | sh"
    echo "   ~/.acme.sh/acme.sh --issue -d your-domain.com --standalone"
    echo ""
    echo "3. 通过面板申请:"
    echo "   - 宝塔面板: 网站 -> 设置 -> SSL -> Let's Encrypt"
    echo "   - 1Panel: 站点 -> SSL 证书 -> 申请证书"
    echo ""
    echo "4. 证书续期:"
    echo "   Certbot: sudo certbot renew"
    echo "   acme.sh: ~/.acme.sh/acme.sh --renew -d your-domain.com"
    echo ""
    echo "证书文件通常位于:"
    echo "   - Certbot: /etc/letsencrypt/live/your-domain.com/"
    echo "   - acme.sh: /root/.acme.sh/your-domain.com/"
    echo "   - 宝塔面板: /www/server/panel/vhost/cert/your-domain.com/"
    echo ""
}

# 检查Let's Encrypt客户端是否安装
check_letsencrypt_client() {
    if command -v certbot &>/dev/null; then
        echo "certbot"
        return 0
    elif command -v acme.sh &>/dev/null; then
        echo "acme.sh"
        return 0
    else
        echo "none"
        return 1
    fi
}

# 安装Let's Encrypt客户端
install_letsencrypt_client() {
    local client_choice

    echo ""
    echo "请选择要安装的Let's Encrypt客户端:"
    echo "  1. Certbot (推荐)"
    echo "  2. acme.sh"
    echo "  0. 取消"
    echo ""
    read -ep "请选择 [0-2]: " client_choice

    case $client_choice in
        1)
            log_info "正在安装Certbot..."
            if command -v apt &>/dev/null; then
                apt update && apt install -y certbot
            elif command -v yum &>/dev/null; then
                yum install -y certbot
            elif command -v dnf &>/dev/null; then
                dnf install -y certbot
            elif command -v pacman &>/dev/null; then
                pacman -S --noconfirm certbot
            else
                log_error "不支持的包管理器"
                return 1
            fi
            ;;
        2)
            log_info "正在安装acme.sh..."
            curl https://get.acme.sh | sh
            ;;
        0)
            return 0
            ;;
        *)
            log_warning "无效选择"
            return 1
            ;;
    esac

    if [ $? -eq 0 ]; then
        log_success "Let's Encrypt客户端安装成功"
        return 0
    else
        log_error "Let's Encrypt客户端安装失败"
        return 1
    fi
}

# 跨域名证书部署
deploy_cross_domain_cert() {
    echo ""
    echo "=========================================="
    echo "  🌐 跨域名证书部署"
    echo "=========================================="
    echo ""

    # 检查证书客户端
    local client=$(check_letsencrypt_client)
    if [ "$client" = "none" ]; then
        log_warning "未检测到Let's Encrypt客户端"
        install_letsencrypt_client
        client=$(check_letsencrypt_client)
        if [ "$client" = "none" ]; then
            return 1
        fi
    fi

    # 获取主域名
    read -ep "请输入主域名 (如 example.com): " main_domain
    if [ -z "$main_domain" ]; then
        log_warning "未输入主域名"
        return 1
    fi

    # 获取额外域名
    read -ep "请输入额外域名 (用空格分隔，如 www.example.com api.example.com): " extra_domains

    # 构建域名列表
    local domains=(-d "$main_domain")
    for domain in $extra_domains; do
        domains+=(-d "$domain")
    done

    log_info "正在使用 $client 申请证书..."

    if [ "$client" = "certbot" ]; then
        certbot certonly --standalone "${domains[@]}"
    elif [ "$client" = "acme.sh" ]; then
        ~/.acme.sh/acme.sh --issue "${domains[@]}" --standalone
    fi

    if [ $? -eq 0 ]; then
        log_success "证书申请成功！"
        search_certs_for_domain "$main_domain"
    else
        log_error "证书申请失败"
    fi
}

# 查询证书覆盖情况
query_cert_coverage() {
    echo ""
    echo "=========================================="
    echo "  📋 证书覆盖情况查询"
    echo "=========================================="
    echo ""

    # 获取域名列表
    read -ep "请输入要查询的域名 (用空格分隔): " domains
    if [ -z "$domains" ]; then
        log_warning "未输入域名"
        return 1
    fi

    echo ""
    echo "证书覆盖情况:"
    echo "────────────────────────────────────"

    for domain in $domains; do
        # 检查证书是否存在
        local found=false
        for path_entry in "${CERT_SEARCH_PATHS[@]}"; do
            local cert_path=$(echo "$path_entry" | cut -d'|' -f2 | sed "s/<DOMAIN>/$domain/g")
            if [ -f "$cert_path" ]; then
                echo -e "  ${GREEN}✓${NC} $domain - 已覆盖"
                found=true
                break
            fi
        done

        if [ "$found" = false ]; then
            echo -e "  ${RED}✗${NC} $domain - 未覆盖"
        fi
    done
    echo ""
}

# 交互式申请SAN证书
apply_san_cert() {
    echo ""
    echo "=========================================="
    echo "  📝 交互式申请SAN证书"
    echo "=========================================="
    echo ""
    echo "SAN (Subject Alternative Name) 证书允许在单个证书中包含多个域名"
    echo ""

    # 检查证书客户端
    local client=$(check_letsencrypt_client)
    if [ "$client" = "none" ]; then
        log_warning "未检测到Let's Encrypt客户端"
        install_letsencrypt_client
        client=$(check_letsencrypt_client)
        if [ "$client" = "none" ]; then
            return 1
        fi
    fi

    # 获取域名
    local domains=()
    local domain_count=0

    while true; do
        domain_count=$((domain_count + 1))
        read -ep "请输入第 $domain_count 个域名 (留空结束): " domain
        if [ -z "$domain" ]; then
            break
        fi
        domains+=(-d "$domain")
    done

    if [ ${#domains[@]} -eq 0 ]; then
        log_warning "未输入任何域名"
        return 1
    fi

    log_info "正在使用 $client 申请SAN证书..."

    if [ "$client" = "certbot" ]; then
        certbot certonly --standalone "${domains[@]}"
    elif [ "$client" = "acme.sh" ]; then
        ~/.acme.sh/acme.sh --issue "${domains[@]}" --standalone
    fi

    if [ $? -eq 0 ]; then
        log_success "SAN证书申请成功！"
        local main_domain=$(echo "${domains[0]}" | cut -d' ' -f2)
        search_certs_for_domain "$main_domain"
    else
        log_error "SAN证书申请失败"
    fi
}

# 交互式申请通配符证书
apply_wildcard_cert() {
    echo ""
    echo "=========================================="
    echo "  🌟 交互式申请通配符证书"
    echo "=========================================="
    echo ""
    echo "通配符证书允许保护所有子域名 (如 *.example.com)"
    echo "注意: 通配符证书需要DNS验证，需要手动配置DNS记录"
    echo ""

    # 检查证书客户端
    local client=$(check_letsencrypt_client)
    if [ "$client" = "none" ]; then
        log_warning "未检测到Let's Encrypt客户端"
        install_letsencrypt_client
        client=$(check_letsencrypt_client)
        if [ "$client" = "none" ]; then
            return 1
        fi
    fi

    # 获取域名
    read -ep "请输入域名 (如 example.com): " domain
    if [ -z "$domain" ]; then
        log_warning "未输入域名"
        return 1
    fi

    log_info "正在使用 $client 申请通配符证书..."

    if [ "$client" = "certbot" ]; then
        certbot certonly --manual --preferred-challenges=dns -d "*.${domain}" -d "${domain}"
    elif [ "$client" = "acme.sh" ]; then
        ~/.acme.sh/acme.sh --issue -d "*.${domain}" -d "${domain}" --dns --yes-I-know-dns-manual-mode-enough-go-ahead-please
    fi

    if [ $? -eq 0 ]; then
        log_success "通配符证书申请成功！"
        search_certs_for_domain "$domain"
    else
        log_error "通配符证书申请失败"
    fi
}

# 域名证书自动延期
auto_renew_cert() {
    echo ""
    echo "=========================================="
    echo "  🔄 域名证书自动延期"
    echo "=========================================="
    echo ""

    # 检查证书客户端
    local client=$(check_letsencrypt_client)
    if [ "$client" = "none" ]; then
        log_warning "未检测到Let's Encrypt客户端"
        return 1
    fi

    log_info "正在设置证书自动延期..."

    if [ "$client" = "certbot" ]; then
        # Certbot通常会自动设置定时任务
        if systemctl list-units --type=service | grep -q certbot; then
            log_success "Certbot自动延期服务已存在"
        else
            certbot renew --dry-run
            if [ $? -eq 0 ]; then
                log_success "Certbot自动延期已配置"
            else
                log_error "Certbot自动延期配置失败"
            fi
        fi
    elif [ "$client" = "acme.sh" ]; then
        ~/.acme.sh/acme.sh --install-cronjob
        if [ $? -eq 0 ]; then
            log_success "acme.sh自动延期已配置"
        else
            log_error "acme.sh自动延期配置失败"
        fi
    fi
}

# 域名证书手动延期
manual_renew_cert() {
    echo ""
    echo "=========================================="
    echo "  🖐️  域名证书手动延期"
    echo "=========================================="
    echo ""

    # 检查证书客户端
    local client=$(check_letsencrypt_client)
    if [ "$client" = "none" ]; then
        log_warning "未检测到Let's Encrypt客户端"
        return 1
    fi

    # 获取域名
    read -ep "请输入要延期的域名 (留空延期所有): " domain

    log_info "正在手动延期证书..."

    if [ "$client" = "certbot" ]; then
        if [ -n "$domain" ]; then
            certbot renew --cert-name "$domain"
        else
            certbot renew
        fi
    elif [ "$client" = "acme.sh" ]; then
        if [ -n "$domain" ]; then
            ~/.acme.sh/acme.sh --renew -d "$domain"
        else
            ~/.acme.sh/acme.sh --renew-all
        fi
    fi

    if [ $? -eq 0 ]; then
        log_success "证书延期成功！"
        [ -n "$domain" ] && search_certs_for_domain "$domain"
    else
        log_error "证书延期失败"
    fi
}

# 查询延期状态
query_renew_status() {
    echo ""
    echo "=========================================="
    echo "  📅 查询证书延期状态"
    echo "=========================================="
    echo ""

    # 检查证书客户端
    local client=$(check_letsencrypt_client)
    if [ "$client" = "none" ]; then
        log_warning "未检测到Let's Encrypt客户端"
        return 1
    fi

    log_info "正在查询证书延期状态..."

    if [ "$client" = "certbot" ]; then
        certbot certificates
    elif [ "$client" = "acme.sh" ]; then
        ~/.acme.sh/acme.sh --list
    fi

    echo ""
}

# 菜单: SSL证书管理
menu_cert_management() {
    while true; do
        echo ""
        echo "=========================================="
        echo "  🔒 SSL证书管理 (Let's Encrypt/多面板通用)"
        echo "=========================================="
        echo "  1. 查看当前证书状态（显示已部署证书详细信息，自动适配多面板路径）"
        echo "  2. 按域名搜索并部署证书（输入域名，自动查找并可一键部署）"
        echo "  3. 全局搜索系统中所有证书（自动遍历常见面板和路径）"
        echo "  4. 手动指定证书路径（输入证书和私钥路径，校验并部署）"
        echo "  5. 跨域名证书部署（支持多个域名一键申请和部署）"
        echo "  6. 查询证书覆盖情况（批量输入域名，检查哪些已覆盖）"
        echo "  7. 交互式申请SAN证书（多域名证书，交互输入）"
        echo "  8. 交互式申请通配符证书（如*.example.com，需DNS验证）"
        echo "  9. 域名证书自动延期（自动续期，支持certbot/acme.sh）"
        echo " 10. 域名证书手动延期（手动续期指定域名）"
        echo " 11. 查询证书延期状态（查看所有证书续期状态）"
        echo "  0. 返回主菜单"
        echo "  输入 b 或 返回 可随时回退主菜单。"
        read -ep "请选择 [0-11]，或输入b/返回: " cert_choice
        case "$cert_choice" in
            1) show_deployed_cert_info ;;
            2)
                read -ep "请输入域名（或b返回）: " domain
                [ "$domain" = "b" ] || [ "$domain" = "返回" ] && return 0
                if [ -n "$domain" ]; then
                    search_certs_for_domain "$domain"
                    if [ ${#FOUND_CERTS[@]} -gt 0 ]; then
                        echo "选择要部署的证书:"
                        local idx=0
                        for entry in "${FOUND_CERTS[@]}"; do
                            idx=$((idx + 1))
                            local pname=$(echo "$entry" | cut -d'|' -f1)
                            local cpath=$(echo "$entry" | cut -d'|' -f2)
                            echo "  [$idx] ${pname} — ${cpath}"
                        done
                        echo "  [0] 取消"
                        read -ep "请选择 [0-${idx}]: " sel
                        [ "$sel" = "b" ] || [ "$sel" = "返回" ] && return 0
                        if [ "$sel" -ge 1 ] 2>/dev/null && [ "$sel" -le $idx ] 2>/dev/null; then
                            local chosen="${FOUND_CERTS[$((sel-1))]}"
                            local ch_cert=$(echo "$chosen" | cut -d'|' -f2)
                            local ch_key=$(echo "$chosen" | cut -d'|' -f3)
                            cp -f "$ch_cert" "${CERTS_DIR}/fullchain.pem"
                            cp -f "$ch_key" "${CERTS_DIR}/privkey.pem"
                            chmod 600 "${CERTS_DIR}/privkey.pem"
                            chmod 644 "${CERTS_DIR}/fullchain.pem"
                            log_success "证书部署成功！"
                            show_deployed_cert_info
                        fi
                    fi
                else
                    log_warning "未输入域名"
                fi
                ;;
            3) global_search_certs ;;
            4) manual_deploy_cert ;;
            5) deploy_cross_domain_cert ;;
            6) query_cert_coverage ;;
            7) apply_san_cert ;;
            8) apply_wildcard_cert ;;
            9) auto_renew_cert ;;
            10) manual_renew_cert ;;
            11) query_renew_status ;;
            0|b|返回) return 0 ;;
            *) log_warning "无效选择，请输入 0-11 或 b/返回"; sleep 1 ;;
        esac
    done
}

# ============================================================================
# 网络工具
# ============================================================================

network_tools() {
    while true; do
        echo ""
        echo "=========================================="
        echo "  📡 网络工具"
        echo "=========================================="
        echo "  1. 网络连接状态（显示当前主机所有监听端口和连接）"
        echo "  2. 端口占用情况（可查进程并交互杀进程，支持倒计时和二次确认）"
        echo "  3. Ping 测试（输入目标IP或域名，测试连通性）"
        echo "  4. 路由表查看（显示主机路由表）"
        echo "  0. 返回主菜单"
        echo "  输入 b 或 返回 可随时回退主菜单。"
        read -ep "请选择 [0-4]，或输入b/返回: " net_choice
        case "$net_choice" in
            1) echo "\n网络连接状态:"; ss -tuln | head -20; echo "" ;;
            2) show_port_usage ;;
            3)
                read -ep "请输入目标地址（或b返回）: " target
                [ "$target" = "b" ] || [ "$target" = "返回" ] && return 0
                if [ -n "$target" ]; then
                    echo "\nPing 测试结果:"; ping -c 5 "$target"; echo ""
                else
                    log_warning "未输入目标地址"
                fi
                ;;
            4) echo "\n路由表:"; ip route; echo "" ;;
            0|b|返回) return 0 ;;
            *) log_warning "无效选择，请输入 0-4 或 b/返回"; sleep 1 ;;
        esac
    done
}

# ============================================================================
# 系统工具
# ============================================================================

system_tools() {
    while true; do
        echo ""
        echo "=========================================="
        echo "  🛠️  系统工具"
        echo "=========================================="
        echo "  1. 系统资源监控（top命令，显示CPU/内存/负载等）"
        echo "  2. 进程管理（按CPU排序，显示前20个进程）"
        echo "  3. 磁盘空间分析（根目录各子目录空间占用）"
        echo "  4. 系统日志查看（最新50行日志）"
        echo "  0. 返回主菜单"
        echo "  输入 b 或 返回 可随时回退主菜单。"
        read -ep "请选择 [0-4]，或输入b/返回: " sys_choice
        case "$sys_choice" in
            1) echo "\n系统资源监控:"; top -b -n 1 | head -20; echo "" ;;
            2) echo "\n进程列表(前20):"; ps aux --sort=-%cpu | head -21; echo "" ;;
            3) echo "\n磁盘空间分析:"; du -h --max-depth=1 / | sort -rh | head -20; echo "" ;;
            4) echo "\n系统日志(最新50行):"; journalctl -n 50; echo "" ;;
            0|b|返回) return 0 ;;
            *) log_warning "无效选择，请输入 0-4 或 b/返回"; sleep 1 ;;
        esac
    done
}

# ============================================================================
# 文件管理
# ============================================================================

file_tools() {
    while true; do
        echo ""
        echo "=========================================="
        echo "  📁 文件管理"
        echo "=========================================="
        echo "  1. 文件搜索（支持通配符，指定目录）"
        echo "  2. 文本内容搜索（递归查找目录下所有文件内容）"
        echo "  3. 文件权限管理（显示并修改文件权限）"
        echo "  4. 文件大小统计（目录下文件/子目录大小排序）"
        echo "  0. 返回主菜单"
        echo "  输入 b 或 返回 可随时回退主菜单。"
        read -ep "请选择 [0-4]，或输入b/返回: " file_choice
        case "$file_choice" in
            1)
                read -ep "请输入文件名搜索模式（如 *.log，或b返回）: " pattern
                [ "$pattern" = "b" ] || [ "$pattern" = "返回" ] && return 0
                read -ep "请输入搜索目录 (默认当前目录): " dir
                [ -z "$dir" ] && dir="."
                echo "\n搜索结果:"; find "$dir" -name "$pattern" 2>/dev/null | head -20; echo "" ;;
            2)
                read -ep "请输入要搜索的文本（或b返回）: " text
                [ "$text" = "b" ] || [ "$text" = "返回" ] && return 0
                read -ep "请输入搜索目录 (默认当前目录): " dir
                [ -z "$dir" ] && dir="."
                echo "\n搜索结果:"; grep -r "$text" "$dir" 2>/dev/null | head -20; echo "" ;;
            3)
                read -ep "请输入文件路径（或b返回）: " file
                [ "$file" = "b" ] || [ "$file" = "返回" ] && return 0
                if [ -f "$file" ]; then
                    echo "当前权限: $(stat -c '%a %A' "$file")"
                    read -ep "请输入新权限 (如 644): " perm
                    chmod "$perm" "$file" && log_success "权限已修改为 $perm"
                else
                    log_error "文件不存在: $file"
                fi
                echo "" ;;
            4)
                read -ep "请输入目录路径 (默认当前目录): " dir
                [ -z "$dir" ] && dir="."
                echo "\n文件大小统计:"; du -ah "$dir" | sort -rh | head -20; echo "" ;;
            0|b|返回) return 0 ;;
            *) log_warning "无效选择，请输入 0-4 或 b/返回"; sleep 1 ;;
        esac
    done
}

# ============================================================================
# 抓包管理
# ============================================================================

# 检查抓包工具是否安装
check_capture_tools() {
    local tools_available=()

    if command -v tcpdump &>/dev/null; then
        tools_available+=("tcpdump")
    fi

    if command -v tshark &>/dev/null; then
        tools_available+=("tshark")
    fi

    echo "${tools_available[@]}"
}

# 获取可用网口
get_available_interfaces() {
    local interfaces=()

    # 使用ip命令获取网口列表
    if command -v ip &>/dev/null; then
        interfaces=($(ip link show | grep "^[0-9]" | awk -F': ' '{print $2}' | cut -d'@' -f1))
    elif command -v ifconfig &>/dev/null; then
        interfaces=($(ifconfig -a | grep "^[a-zA-Z]" | awk '{print $1}'))
    fi

    echo "${interfaces[@]}"
}

# 抓包管理主菜单
capture_management() {
    while true; do
        echo ""
        echo "=========================================="
        echo "  🕵️  抓包管理"
        echo "=========================================="
        echo "  1. 开始抓包（选择网口、工具、过滤条件、保存文件名）"
        echo "  2. 分析已保存的包（统计、内容、协议过滤、关键词搜索）"
        echo "  3. 导入包文件（支持pcap/pcapng）"
        echo "  4. 导出包文件（导出到指定路径）"
        echo "  5. 抓包工具设置（检测/安装tcpdump、tshark等）"
        echo "  0. 返回主菜单"
        echo "  输入 b 或 返回 可随时回退主菜单。"
        read -ep "请选择 [0-5]，或输入b/返回: " capture_choice
        case "$capture_choice" in
            1) start_capture ;;
            2) analyze_capture ;;
            3) import_capture ;;
            4) export_capture ;;
            5) capture_settings ;;
            0|b|返回) return 0 ;;
            *) log_warning "无效选择，请输入 0-5 或 b/返回"; sleep 1 ;;
        esac
    done
}

# 开始抓包
start_capture() {
    echo ""
    echo "=========================================="
    echo "  🎯 开始抓包"
    echo "=========================================="
    echo ""

    # 检查抓包工具
    local available_tools=($(check_capture_tools))
    if [ ${#available_tools[@]} -eq 0 ]; then
        log_error "未检测到抓包工具（tcpdump/tshark）"
        echo "  请安装工具: sudo apt install tcpdump tshark -y 或 sudo yum install tcpdump wireshark-cli -y"
        return 1
    fi

    # 选择工具
    echo "可用的抓包工具:"
    for i in "${!available_tools[@]}"; do
        echo -e "  ${GREEN}$((i+1)).${NC} ${available_tools[$i]}"
    done
    echo ""
    read -ep "请选择工具 [1-${#available_tools[@]}]: " tool_choice

    if ! [[ "$tool_choice" =~ ^[0-9]+$ ]] || [ "$tool_choice" -lt 1 ] || [ "$tool_choice" -gt ${#available_tools[@]} ]; then
        log_error "无效的工具选择"
        return 1
    fi

    local selected_tool=${available_tools[$((tool_choice-1))]}

    # 选择网口
    local interfaces=($(get_available_interfaces))
    if [ ${#interfaces[@]} -eq 0 ]; then
        log_error "无法获取网口列表"
        return 1
    fi

    echo ""
    echo "可用的网口:"
    for i in "${!interfaces[@]}"; do
        echo -e "  ${GREEN}$((i+1)).${NC} ${interfaces[$i]}"
    done
    echo ""
    read -ep "请选择网口 [1-${#interfaces[@]}]: " iface_choice

    if ! [[ "$iface_choice" =~ ^[0-9]+$ ]] || [ "$iface_choice" -lt 1 ] || [ "$iface_choice" -gt ${#interfaces[@]} ]; then
        log_error "无效的网口选择"
        return 1
    fi

    local selected_iface=${interfaces[$((iface_choice-1))]}

    # 设置过滤条件
    echo ""
    read -ep "输入过滤条件 (如 tcp port 80, 留空表示不过滤): " filter

    # 设置抓包数量
    echo ""
    read -ep "输入抓包数量 (留空表示无限): " packet_count

    # 设置保存文件名
    echo ""
    local default_file="capture_$(date +%Y%m%d_%H%M%S).pcap"
    read -ep "输入保存文件名 (默认: $default_file): " save_file
    [ -z "$save_file" ] && save_file="$default_file"

    # 开始抓包
    echo ""
    echo -e "${YELLOW}💡 正在使用 ${selected_tool} 在 ${selected_iface} 上抓包...${NC}"
    echo -e "${YELLOW}💡 按 Ctrl+C 停止抓包${NC}"
    echo ""

    local capture_cmd=""
    if [ "$selected_tool" = "tcpdump" ]; then
        capture_cmd="tcpdump -i $selected_iface -w $save_file"
        [ -n "$filter" ] && capture_cmd="$capture_cmd $filter"
        [ -n "$packet_count" ] && capture_cmd="$capture_cmd -c $packet_count"
    elif [ "$selected_tool" = "tshark" ]; then
        capture_cmd="tshark -i $selected_iface -w $save_file"
        [ -n "$filter" ] && capture_cmd="$capture_cmd -f '$filter'"
        [ -n "$packet_count" ] && capture_cmd="$capture_cmd -c $packet_count"
    fi

    eval "$capture_cmd"

    if [ $? -eq 0 ]; then
        log_success "抓包完成！"
        echo "  包文件已保存为: $save_file"
        echo -e "  ${YELLOW}💡 可使用 '2. 分析已保存的包' 选项查看分析结果${NC}"
    else
        log_error "抓包失败"
    fi
}

# 分析已保存的包
analyze_capture() {
    echo ""
    echo "=========================================="
    echo "  📊 分析已保存的包"
    echo "=========================================="
    echo ""

    # 查找当前目录下的pcap文件
    local pcap_files=($(find . -maxdepth 1 -name "*.pcap" -o -name "*.pcapng" | sort))

    if [ ${#pcap_files[@]} -eq 0 ]; then
        log_warning "当前目录下未找到pcap/pcapng文件"
        echo "  请先使用 '1. 开始抓包' 功能或导入包文件"
        return 1
    fi

    # 选择要分析的文件
    echo "可用的包文件:"
    for i in "${!pcap_files[@]}"; do
        echo -e "  ${GREEN}$((i+1)).${NC} ${pcap_files[$i]}"
    done
    echo ""
    read -ep "请选择文件 [1-${#pcap_files[@]}]: " file_choice

    if ! [[ "$file_choice" =~ ^[0-9]+$ ]] || [ "$file_choice" -lt 1 ] || [ "$file_choice" -gt ${#pcap_files[@]} ]; then
        log_error "无效的文件选择"
        return 1
    fi

    local selected_file=${pcap_files[$((file_choice-1))]}

    # 选择分析工具
    local available_tools=($(check_capture_tools))
    if [ ${#available_tools[@]} -eq 0 ]; then
        log_error "未检测到抓包工具（tcpdump/tshark）"
        return 1
    fi

    echo ""
    echo "可用的分析工具:"
    for i in "${!available_tools[@]}"; do
        echo -e "  ${GREEN}$((i+1)).${NC} ${available_tools[$i]}"
    done
    echo ""
    read -ep "请选择工具 [1-${#available_tools[@]}]: " tool_choice

    if ! [[ "$tool_choice" =~ ^[0-9]+$ ]] || [ "$tool_choice" -lt 1 ] || [ "$tool_choice" -gt ${#available_tools[@]} ]; then
        log_error "无效的工具选择"
        return 1
    fi

    local selected_tool=${available_tools[$((tool_choice-1))]}

    # 选择分析类型
    echo ""
    echo "分析类型:"
    echo "  1. 包统计信息"
    echo "  2. 显示所有包内容"
    echo "  3. 按协议过滤显示"
    echo "  4. 按关键词搜索"
    echo ""
    read -ep "请选择分析类型 [1-4]: " analyze_type

    case $analyze_type in
        1)
            echo ""
            echo "包统计信息:"
            echo "────────────────────────────────────"
            if [ "$selected_tool" = "tcpdump" ]; then
                tcpdump -r "$selected_file" -q | sort | uniq -c | sort -nr
            elif [ "$selected_tool" = "tshark" ]; then
                tshark -r "$selected_file" -z protocols,tree
            fi
            ;;
        2)
            echo ""
            echo "包内容 (显示前50个):"
            echo "────────────────────────────────────"
            if [ "$selected_tool" = "tcpdump" ]; then
                tcpdump -r "$selected_file" -n -v | head -50
            elif [ "$selected_tool" = "tshark" ]; then
                tshark -r "$selected_file" -V | head -100
            fi
            ;;
        3)
            echo ""
            read -ep "输入协议名称 (如 tcp, udp, http): " protocol
            echo ""
            echo "按 ${protocol} 协议过滤的包:"
            echo "────────────────────────────────────"
            if [ "$selected_tool" = "tcpdump" ]; then
                tcpdump -r "$selected_file" -n "$protocol" | head -50
            elif [ "$selected_tool" = "tshark" ]; then
                tshark -r "$selected_file" -Y "$protocol" | head -50
            fi
            ;;
        4)
            echo ""
            read -ep "输入关键词 (如 IP地址、端口号): " keyword
            echo ""
            echo "包含 '${keyword}' 的包:"
            echo "────────────────────────────────────"
            if [ "$selected_tool" = "tcpdump" ]; then
                tcpdump -r "$selected_file" -n | grep -i "$keyword" | head -50
            elif [ "$selected_tool" = "tshark" ]; then
                tshark -r "$selected_file" -Y "frame contains '$keyword'" | head -50
            fi
            ;;
        *)
            log_warning "无效的分析类型选择"
            return 1
            ;;
    esac

    echo ""
    log_success "分析完成！"
}

# 导入包文件
import_capture() {
    echo ""
    echo "=========================================="
    echo "  📥 导入包文件"
    echo "=========================================="
    echo ""

    read -ep "请输入包文件路径 (支持 .pcap 和 .pcapng 格式): " import_path

    if [ ! -f "$import_path" ]; then
        log_error "文件不存在: $import_path"
        return 1
    fi

    # 检查文件格式
    local file_ext=$(echo "$import_path" | awk -F. '{print $NF}')
    if [[ "$file_ext" != "pcap" && "$file_ext" != "pcapng" ]]; then
        log_error "不支持的文件格式: $file_ext (仅支持 .pcap 和 .pcapng)"
        return 1
    fi

    # 复制到当前目录
    local new_name="imported_$(date +%Y%m%d_%H%M%S).$file_ext"
    cp "$import_path" "$new_name"

    if [ $? -eq 0 ]; then
        log_success "包文件导入成功！"
        echo "  导入的文件: $new_name"
        echo -e "  ${YELLOW}💡 可使用 '2. 分析已保存的包' 选项查看分析结果${NC}"
    else
        log_error "包文件导入失败"
    fi
}

# 导出包文件
export_capture() {
    echo ""
    echo "=========================================="
    echo "  📤 导出包文件"
    echo "=========================================="
    echo ""

    # 查找当前目录下的pcap文件
    local pcap_files=($(find . -maxdepth 1 -name "*.pcap" -o -name "*.pcapng" | sort))

    if [ ${#pcap_files[@]} -eq 0 ]; then
        log_warning "当前目录下未找到pcap/pcapng文件"
        return 1
    fi

    # 选择要导出的文件
    echo "可用的包文件:"
    for i in "${!pcap_files[@]}"; do
        echo -e "  ${GREEN}$((i+1)).${NC} ${pcap_files[$i]}"
    done
    echo ""
    read -ep "请选择文件 [1-${#pcap_files[@]}]: " file_choice

    if ! [[ "$file_choice" =~ ^[0-9]+$ ]] || [ "$file_choice" -lt 1 ] || [ "$file_choice" -gt ${#pcap_files[@]} ]; then
        log_error "无效的文件选择"
        return 1
    fi

    local selected_file=${pcap_files[$((file_choice-1))]}

    # 输入导出路径
    echo ""
    read -ep "请输入导出路径 (如 /tmp/exported.pcap): " export_path

    # 复制文件
    cp "$selected_file" "$export_path"

    if [ $? -eq 0 ]; then
        log_success "包文件导出成功！"
        echo "  导出到: $export_path"
    else
        log_error "包文件导出失败"
    fi
}

# 抓包工具设置
capture_settings() {
    echo ""
    echo "=========================================="
    echo "  ⚙️  抓包工具设置"
    echo "=========================================="
    echo ""

    local available_tools=($(check_capture_tools))

    echo "当前已安装的工具:"
    if [ ${#available_tools[@]} -eq 0 ]; then
        echo -e "  ${RED}✗${NC} 无抓包工具安装"
    else
        for tool in "${available_tools[@]}"; do
            echo -e "  ${GREEN}✓${NC} $tool"
        done
    fi

    echo ""
    echo "安装命令参考:"
    echo "  Debian/Ubuntu: sudo apt install tcpdump tshark -y"
    echo "  CentOS/RHEL: sudo yum install tcpdump wireshark-cli -y"
    echo "  Arch Linux: sudo pacman -S tcpdump wireshark-cli -y"
    echo ""

    log_info "抓包工具设置完成！"
}

# ============================================================================
# 交互式主菜单
# ============================================================================

# 权限管理菜单
permission_management() {
    while true; do
        echo ""
        echo "=========================================="
        echo "  🔑 权限管理"
        echo "=========================================="
        echo "  当前权限状态:"
        if [ "$HAS_ROOT" = true ]; then
            echo -e "  ${GREEN}✓ 管理员权限 (root)${NC}"
        else
            echo -e "  ${YELLOW}⚠ 普通用户权限${NC}"
        fi
        echo "  1. 切换到管理员权限 (sudo)"
        echo "  2. 切换回普通用户权限"
        echo "  0. 返回主菜单"
        echo "  输入 b 或 返回 可随时回退主菜单。"
        read -ep "请选择 [0-2]，或输入b/返回: " perm_choice
        case "$perm_choice" in
            1) switch_to_root "$@" ;;
            2) switch_to_user "$@" ;;
            0|b|返回) return 0 ;;
            *) log_warning "无效选择，请输入 0-2 或 b/返回"; sleep 1 ;;
        esac
    done
}

interactive_menu() {
    trap 'echo ""; log_info "返回主菜单..."; echo ""' SIGINT
    while true; do
        echo ""
        echo "=========================================="
        echo "  🚀 通用Linux自动化工具集 (v2.0)"
        echo "=========================================="
        echo "  请选择要执行的功能，输入对应数字，或输入 b/返回 回退退出。"
        echo "  1. 查询系统信息（显示主机、CPU、内存、磁盘、网络等详细信息）"
        echo "  2. SSL证书管理（适配多面板，支持部署、续期、SAN、通配符等）"
        echo "  3. 网络工具（端口占用、进程管理、路由、Ping等，支持交互杀进程）"
        echo "  4. 系统工具（资源监控、进程、磁盘、日志等）"
        echo "  5. 文件管理（文件搜索、内容查找、权限、统计等）"
        echo "  6. 抓包管理（网口选择、关键词过滤、导入导出、分析等）"
        echo "  7. 权限管理（sudo/root切换，安全提示）"
        echo "  0. 退出"
        echo ""
        read -ep "请输入功能编号 [0-7]，或输入 b/返回: " choice
        case "$choice" in
            1) query_system_info; read -ep "按Enter键返回主菜单..." dummy ;;
            2) menu_cert_management; read -ep "按Enter键返回主菜单..." dummy ;;
            3) network_tools; read -ep "按Enter键返回菜单..." dummy ;;
            4) system_tools; read -ep "按Enter键返回菜单..." dummy ;;
            5) file_tools; read -ep "按Enter键返回菜单..." dummy ;;
            6) capture_management; read -ep "按Enter键返回菜单..." dummy ;;
            7) permission_management "$@" ;;
            0|b|返回) echo ""; log_info "感谢使用通用Linux自动化工具集"; echo ""; exit 0 ;;
            *) log_warning "无效选择，请输入 0-7 或 b/返回"; sleep 1 ;;
        esac
    done
}

# ============================================================================
# 主流程
# ============================================================================

main() {
    echo ""
    echo "=========================================="
    echo "  🚀 通用Linux自动化工具集"
    echo "  版本: v2.0 | 适用于各种Linux系统"
    echo "  功能: 系统信息、SSL管理、网络工具、系统工具、文件管理、抓包管理"
    echo "=========================================="
    echo ""
    echo -e "${YELLOW}💡 提示: 使用方向键和回车键进行操作${NC}"
    echo ""

    # 参数处理
    if [ $# -gt 0 ]; then
        case $1 in
            --version|-v)
                echo "通用Linux自动化工具集 v2.0"
                echo "更新日期: 2026-03-20"
                echo ""
                echo "版本历史:"
                echo "  v2.0 (2026-03-20): 增加版本化管理、抓包管理功能"
                echo "  v1.0 (2024-01-01): 初始版本"
                exit 0
                ;;
            --help|-h)
                echo "使用方法: ./linux-tools.sh [选项]"
                echo ""
                echo "选项:"
                echo "  --version, -v    显示版本信息"
                echo "  --help, -h       显示帮助信息"
                echo "  --sudo, -s       使用sudo权限运行"
                echo ""
                echo "主菜单功能:"
                echo "  1. 查询系统信息"
                echo "  2. SSL证书管理"
                echo "  3. 网络工具"
                echo "  4. 系统工具"
                echo "  5. 文件管理"
                echo "  6. 抓包管理"
                echo "  7. 权限管理"
                echo "  0. 退出"
                exit 0
                ;;
            --sudo|-s)
                log_info "正在使用sudo权限运行..."
                exec sudo "$0" "${@:2}"
                ;;
        esac
    fi

    # 检查当前权限
    check_permission
    echo ""

    interactive_menu
}

# 脚本入口
main "$@"
