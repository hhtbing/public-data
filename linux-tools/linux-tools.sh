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
log_info()     { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success()  { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning()  { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()    { echo -e "${RED}[ERROR]${NC} $1"; }
log_highlight(){ echo -e "${CYAN}$1${NC}"; }

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

    if [ -f "${CERTS_DIR}/fullchain.pem" ] && [ -f "${CERTS_DIR}/privkey.pem" ]; then
        log_success "检测到证书文件"
        echo "  证书路径: ${CERTS_DIR}/fullchain.pem"
        echo "  私钥路径: ${CERTS_DIR}/privkey.pem"
        echo ""

        # 显示证书详情
        local cert_info=$(openssl x509 -in "${CERTS_DIR}/fullchain.pem" -noout -subject -issuer -dates 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "证书详情:"
            echo "  ────────────────────────────────────"
            echo "${cert_info}" | sed 's/^/  /'
            echo ""

            # 检查证书有效期
            local expire_date=$(openssl x509 -in "${CERTS_DIR}/fullchain.pem" -noout -enddate 2>/dev/null | cut -d'=' -f2)
            local expire_seconds=$(date -d "$expire_date" +%s 2>/dev/null)
            local now_seconds=$(date +%s)
            local days_left=$(( (expire_seconds - now_seconds) / 86400 ))

            if [ $days_left -gt 30 ]; then
                echo -e "  ${GREEN}✓${NC} 有效期: $days_left 天"
            elif [ $days_left -gt 7 ]; then
                echo -e "  ${YELLOW}!${NC} 有效期: $days_left 天 (即将过期)"
            else
                echo -e "  ${RED}✗${NC} 有效期: $days_left 天 (紧急过期)"
            fi
        fi
    else
        log_warning "未检测到证书文件"
        echo "  证书目录: ${CERTS_DIR}"
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

# 菜单: SSL证书管理
menu_cert_management() {
    echo ""
    echo "=========================================="
    echo "  🔒 SSL 证书管理"
    echo "=========================================="
    echo ""

    echo "  1. 查看当前证书状态"
    echo "  2. 按域名搜索并部署证书"
    echo "  3. 全局搜索系统中所有证书"
    echo "  4. 手动指定证书路径"
    echo "  5. SSL证书申请指南"
    echo "  0. 返回主菜单"
    echo ""
    read -ep "请选择 [0-5]: " cert_choice

    case $cert_choice in
        1)
            show_deployed_cert_info
            ;;
        2)
            read -ep "请输入域名: " domain
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
                    echo ""
                    read -ep "请选择 [0-${idx}]: " sel

                    if [ "$sel" -ge 1 ] 2>/dev/null && [ "$sel" -le $idx ] 2>/dev/null; then
                        local chosen="${FOUND_CERTS[$((sel-1))]}"
                        local ch_cert=$(echo "$chosen" | cut -d'|' -f2)
                        local ch_key=$(echo "$chosen" | cut -d'|' -f3)

                        # 复制证书到统一目录
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
        3)
            global_search_certs
            ;;
        4)
            manual_deploy_cert
            ;;
        5)
            show_cert_guide
            ;;
        0)
            return 0
            ;;
        *)
            log_warning "无效选择，请输入 0-5"
            sleep 1
            ;;
    esac
}

# ============================================================================
# 网络工具
# ============================================================================

network_tools() {
    echo ""
    echo "=========================================="
    echo "  📡 网络工具"
    echo "=========================================="
    echo ""

    echo "  1. 网络连接状态"
    echo "  2. 端口占用情况"
    echo "  3. Ping 测试"
    echo "  4. 路由表查看"
    echo "  0. 返回主菜单"
    echo ""
    read -ep "请选择 [0-4]: " net_choice

    case $net_choice in
        1)
            echo ""
            echo "网络连接状态:"
            echo "────────────────────────────────────"
            ss -tuln | head -20
            echo ""
            ;;
        2)
            read -ep "请输入端口号 (空查看所有): " port
            echo ""
            echo "端口占用情况:"
            echo "────────────────────────────────────"
            if [ -n "$port" ]; then
                ss -tuln | grep ":$port\b"
            else
                ss -tuln
            fi
            echo ""
            ;;
        3)
            read -ep "请输入目标地址: " target
            if [ -n "$target" ]; then
                echo ""
                echo "Ping 测试结果:"
                echo "────────────────────────────────────"
                ping -c 5 "$target"
                echo ""
            else
                log_warning "未输入目标地址"
            fi
            ;;
        4)
            echo ""
            echo "路由表:"
            echo "────────────────────────────────────"
            ip route
            echo ""
            ;;
        0)
            return 0
            ;;
        *)
            log_warning "无效选择，请输入 0-4"
            sleep 1
            ;;
    esac
}

# ============================================================================
# 系统工具
# ============================================================================

system_tools() {
    echo ""
    echo "=========================================="
    echo "  🛠️  系统工具"
    echo "=========================================="
    echo ""

    echo "  1. 系统资源监控"
    echo "  2. 进程管理"
    echo "  3. 磁盘空间分析"
    echo "  4. 系统日志查看"
    echo "  0. 返回主菜单"
    echo ""
    read -ep "请选择 [0-4]: " sys_choice

    case $sys_choice in
        1)
            echo ""
            echo "系统资源监控 (按 q 退出):"
            echo "────────────────────────────────────"
            top -b -n 1 | head -20
            echo ""
            ;;
        2)
            echo ""
            echo "进程列表 (前20个):"
            echo "────────────────────────────────────"
            ps aux --sort=-%cpu | head -21
            echo ""
            ;;
        3)
            echo ""
            echo "磁盘空间分析:"
            echo "────────────────────────────────────"
            du -h --max-depth=1 / | sort -rh | head -20
            echo ""
            ;;
        4)
            echo ""
            echo "系统日志 (最新50行):"
            echo "────────────────────────────────────"
            journalctl -n 50
            echo ""
            ;;
        0)
            return 0
            ;;
        *)
            log_warning "无效选择，请输入 0-4"
            sleep 1
            ;;
    esac
}

# ============================================================================
# 文件管理
# ============================================================================

file_tools() {
    echo ""
    echo "=========================================="
    echo "  📁 文件管理"
    echo "=========================================="
    echo ""

    echo "  1. 文件搜索"
    echo "  2. 文本内容搜索"
    echo "  3. 文件权限管理"
    echo "  4. 文件大小统计"
    echo "  0. 返回主菜单"
    echo ""
    read -ep "请选择 [0-4]: " file_choice

    case $file_choice in
        1)
            read -ep "请输入文件名搜索模式: " pattern
            read -ep "请输入搜索目录 (默认当前目录): " dir
            [ -z "$dir" ] && dir="."
            echo ""
            echo "搜索结果:"
            echo "────────────────────────────────────"
            find "$dir" -name "$pattern" 2>/dev/null | head -20
            echo ""
            ;;
        2)
            read -ep "请输入要搜索的文本: " text
            read -ep "请输入搜索目录 (默认当前目录): " dir
            [ -z "$dir" ] && dir="."
            echo ""
            echo "搜索结果:"
            echo "────────────────────────────────────"
            grep -r "$text" "$dir" 2>/dev/null | head -20
            echo ""
            ;;
        3)
            read -ep "请输入文件路径: " file
            if [ -f "$file" ]; then
                echo ""
                echo "当前权限: $(stat -c "%a %A" "$file")"
                read -ep "请输入新权限 (如 644): " perm
                chmod "$perm" "$file"
                log_success "权限已修改为 $perm"
                echo ""
            else
                log_error "文件不存在: $file"
            fi
            ;;
        4)
            read -ep "请输入目录路径 (默认当前目录): " dir
            [ -z "$dir" ] && dir="."
            echo ""
            echo "文件大小统计:"
            echo "────────────────────────────────────"
            du -ah "$dir" | sort -rh | head -20
            echo ""
            ;;
        0)
            return 0
            ;;
        *)
            log_warning "无效选择，请输入 0-4"
            sleep 1
            ;;
    esac
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
    echo ""
    echo "=========================================="
    echo "  🕵️  抓包管理"
    echo "=========================================="
    echo ""

    echo "  1. 开始抓包"
    echo "  2. 分析已保存的包"
    echo "  3. 导入包文件"
    echo "  4. 导出包文件"
    echo "  5. 抓包工具设置"
    echo "  0. 返回主菜单"
    echo ""
    read -ep "请选择 [0-5]: " capture_choice

    case $capture_choice in
        1)
            start_capture
            ;;
        2)
            analyze_capture
            ;;
        3)
            import_capture
            ;;
        4)
            export_capture
            ;;
        5)
            capture_settings
            ;;
        0)
            return 0
            ;;
        *)
            log_warning "无效选择，请输入 0-5"
            sleep 1
            ;;
    esac
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

interactive_menu() {
    trap 'echo ""; log_info "返回主菜单..."; echo ""' SIGINT

    while true; do
        echo ""
        echo "=========================================="
        echo "  🚀 通用Linux自动化工具集 (v2.0)"
        echo "=========================================="
        echo ""
        echo -e "  ${GREEN}1.${NC}  🖥️  查询系统信息"
        echo -e "  ${GREEN}2.${NC}  🔒 SSL证书管理"
        echo -e "  ${GREEN}3.${NC}  📡 网络工具"
        echo -e "  ${GREEN}4.${NC}  🛠️  系统工具"
        echo -e "  ${GREEN}5.${NC}  📁 文件管理"
        echo -e "  ${GREEN}6.${NC}  🕵️  抓包管理"
        echo "  0. 🚪 退出"
        echo ""
        read -ep "请选择操作 [0-6]: " choice

        case $choice in
            1)
                query_system_info
                read -ep "按Enter键返回菜单..." dummy
                ;;
            2)
                menu_cert_management
                read -ep "按Enter键返回菜单..." dummy
                ;;
            3)
                network_tools
                read -ep "按Enter键返回菜单..." dummy
                ;;
            4)
                system_tools
                read -ep "按Enter键返回菜单..." dummy
                ;;
            5)
                file_tools
                read -ep "按Enter键返回菜单..." dummy
                ;;
            6)
                capture_management
                read -ep "按Enter键返回菜单..." dummy
                ;;
            0)
                echo ""
                log_info "感谢使用通用Linux自动化工具集"
                echo ""
                exit 0
                ;;
            *)
                log_warning "无效选择，请输入 0-5"
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
                echo "使用方法: sudo ./linux-tools.sh [选项]"
                echo ""
                echo "选项:"
                echo "  --version, -v    显示版本信息"
                echo "  --help, -h       显示帮助信息"
                echo ""
                echo "主菜单功能:"
                echo "  1. 查询系统信息"
                echo "  2. SSL证书管理"
                echo "  3. 网络工具"
                echo "  4. 系统工具"
                echo "  5. 文件管理"
                echo "  6. 抓包管理"
                echo "  0. 退出"
                exit 0
                ;;
        esac
    fi

    # 检查root权限
    if [ "$(id -u)" -ne 0 ]; then
        log_warning "部分功能需要root权限，建议使用sudo运行"
        echo ""
    fi

    interactive_menu
}

# 脚本入口
main "$@"
