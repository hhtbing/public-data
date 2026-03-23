#!/bin/bash
# ==========================================
#   通用Linux自动化工具集 (v2.1)
#   更新日期: 2026-03-20
#   适用于各种 Linux 发行版与主流面板
# ==========================================

VERSION="v2.1"
UPDATE_DATE="2026-03-20"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 通用输出函数
print_info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# 分隔线
print_line() {
    echo "=========================================="
}

# 按任意键继续
press_any_key() {
    echo ""
    read -n 1 -s -r -p "按任意键继续..."
    echo ""
}

# 检查是否回退
check_back() {
    local input="$1"
    if [[ "$input" == "b" || "$input" == "B" || "$input" == "返回" ]]; then
        return 0
    fi
    return 1
}

# 检查命令是否存在
cmd_exists() {
    command -v "$1" &>/dev/null
}

# ==========================================
# 1. 查询系统信息
# ==========================================
show_system_info() {
    print_line
    echo "  系统信息查询"
    print_line

    # 主机名
    echo -e "${GREEN}主机名:${NC} $(hostname)"

    # 操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo -e "${GREEN}操作系统:${NC} $PRETTY_NAME"
    elif [ -f /etc/redhat-release ]; then
        echo -e "${GREEN}操作系统:${NC} $(cat /etc/redhat-release)"
    else
        echo -e "${GREEN}操作系统:${NC} $(uname -s) $(uname -r)"
    fi

    # 内核版本
    echo -e "${GREEN}内核版本:${NC} $(uname -r)"

    # 系统架构
    echo -e "${GREEN}系统架构:${NC} $(uname -m)"

    # 运行时间
    echo -e "${GREEN}运行时间:${NC} $(uptime -p 2>/dev/null || uptime)"

    # CPU 信息
    if [ -f /proc/cpuinfo ]; then
        cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | awk -F: '{print $2}' | sed 's/^ //')
        cpu_cores=$(grep -c "^processor" /proc/cpuinfo)
        echo -e "${GREEN}CPU型号:${NC} $cpu_model"
        echo -e "${GREEN}CPU核心数:${NC} $cpu_cores"
    fi

    # 内存信息
    if cmd_exists free; then
        mem_total=$(free -h | awk '/^Mem:/{print $2}')
        mem_used=$(free -h | awk '/^Mem:/{print $3}')
        mem_avail=$(free -h | awk '/^Mem:/{print $7}')
        echo -e "${GREEN}内存总量:${NC} $mem_total"
        echo -e "${GREEN}已用内存:${NC} $mem_used"
        echo -e "${GREEN}可用内存:${NC} $mem_avail"
    fi

    # 磁盘信息
    echo -e "${GREEN}磁盘使用:${NC}"
    df -h --total 2>/dev/null | grep -E "^/|total" | awk '{printf "  %-20s %s/%s (%s)\n", $6, $3, $2, $5}'

    # 网络信息
    echo -e "${GREEN}网络接口:${NC}"
    if cmd_exists ip; then
        ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+.*' | while read line; do
            echo "  $line"
        done
    elif cmd_exists ifconfig; then
        ifconfig | grep "inet " | awk '{print "  " $2}'
    fi

    # 公网IP
    public_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 ipinfo.io/ip 2>/dev/null || echo "无法获取")
    echo -e "${GREEN}公网IP:${NC} $public_ip"

    # 负载
    echo -e "${GREEN}系统负载:${NC} $(cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}')"

    press_any_key
}

# ==========================================
# 2. SSL证书管理
# ==========================================

# 常见面板证书路径
CERT_SEARCH_PATHS=(
    "/etc/letsencrypt/live"
    "/etc/ssl/certs"
    "/etc/ssl/private"
    "/etc/nginx/ssl"
    "/etc/apache2/ssl"
    "/etc/httpd/ssl"
    "/www/server/panel/vhost/cert"
    "/www/server/panel/ssl"
    "/opt/1panel/ssl"
    "/root/.acme.sh"
    "/home/*/.acme.sh"
    "/etc/pki/tls/certs"
    "/etc/pki/tls/private"
    "/usr/local/nginx/conf/ssl"
    "/usr/local/apache/conf/ssl"
)

# 查看证书信息
show_cert_info() {
    local cert_path="$1"
    if [ ! -f "$cert_path" ]; then
        print_error "证书文件不存在: $cert_path"
        return 1
    fi
    echo ""
    print_info "证书文件: $cert_path"
    openssl x509 -in "$cert_path" -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null
    if [ $? -ne 0 ]; then
        print_error "无法解析证书文件"
        return 1
    fi
    # 检查过期
    local end_date
    end_date=$(openssl x509 -in "$cert_path" -noout -enddate 2>/dev/null | cut -d= -f2)
    local end_epoch
    end_epoch=$(date -d "$end_date" +%s 2>/dev/null)
    local now_epoch
    now_epoch=$(date +%s)
    if [ -n "$end_epoch" ]; then
        local days_left=$(( (end_epoch - now_epoch) / 86400 ))
        if [ $days_left -le 0 ]; then
            print_error "证书已过期!"
        elif [ $days_left -le 30 ]; then
            print_warn "证书将在 ${days_left} 天后过期!"
        else
            print_success "证书有效，剩余 ${days_left} 天"
        fi
    fi
}

# 自动搜索证书路径
auto_search_certs() {
    print_info "正在搜索系统中的证书文件..."
    local found=0
    for search_path in "${CERT_SEARCH_PATHS[@]}"; do
        # 展开通配符
        for expanded_path in $search_path; do
            if [ -d "$expanded_path" ]; then
                local certs
                certs=$(find "$expanded_path" -maxdepth 3 -name "*.pem" -o -name "*.crt" -o -name "*.cer" 2>/dev/null)
                if [ -n "$certs" ]; then
                    echo ""
                    echo -e "${BLUE}目录: $expanded_path${NC}"
                    echo "$certs" | while read -r f; do
                        echo "  $f"
                        found=1
                    done
                fi
            fi
        done
    done
    if [ $found -eq 0 ]; then
        print_warn "未找到证书文件"
    fi
}

# 查看当前证书状态
ssl_view_status() {
    print_line
    echo "  查看当前证书状态（自动适配多面板路径）"
    print_line
    local found=0
    for search_path in "${CERT_SEARCH_PATHS[@]}"; do
        for expanded_path in $search_path; do
            if [ -d "$expanded_path" ]; then
                local certs
                certs=$(find "$expanded_path" -maxdepth 3 \( -name "fullchain.pem" -o -name "cert.pem" -o -name "*.crt" \) 2>/dev/null)
                if [ -n "$certs" ]; then
                    echo "$certs" | while read -r cert; do
                        show_cert_info "$cert"
                        found=1
                    done
                fi
            fi
        done
    done
    if [ $found -eq 0 ]; then
        print_warn "未在常见路径中找到证书，请使用手动指定路径功能。"
    fi
    press_any_key
}

# 按域名搜索并部署证书
ssl_search_deploy() {
    print_line
    echo "  按域名搜索并部署证书"
    print_line
    read -rp "请输入域名: " domain
    check_back "$domain" && return

    if [ -z "$domain" ]; then
        print_error "域名不能为空"
        press_any_key
        return
    fi

    print_info "正在搜索域名 $domain 的证书..."
    local found_certs=()
    local idx=0

    for search_path in "${CERT_SEARCH_PATHS[@]}"; do
        for expanded_path in $search_path; do
            if [ -d "$expanded_path" ]; then
                while IFS= read -r -d '' cert; do
                    local subject
                    subject=$(openssl x509 -in "$cert" -noout -subject 2>/dev/null)
                    local san
                    san=$(openssl x509 -in "$cert" -noout -ext subjectAltName 2>/dev/null)
                    if echo "$subject $san" | grep -qi "$domain"; then
                        idx=$((idx + 1))
                        found_certs+=("$cert")
                        echo "  [$idx] $cert"
                        openssl x509 -in "$cert" -noout -subject -dates 2>/dev/null | sed 's/^/      /'
                    fi
                done < <(find "$expanded_path" -maxdepth 3 \( -name "*.pem" -o -name "*.crt" -o -name "*.cer" \) -print0 2>/dev/null)
            fi
        done
    done

    if [ ${#found_certs[@]} -eq 0 ]; then
        print_warn "未找到与 $domain 匹配的证书"
        press_any_key
        return
    fi

    echo ""
    read -rp "选择要部署的证书编号 (输入编号): " cert_idx
    check_back "$cert_idx" && return

    if [[ "$cert_idx" =~ ^[0-9]+$ ]] && [ "$cert_idx" -ge 1 ] && [ "$cert_idx" -le ${#found_certs[@]} ]; then
        local selected_cert="${found_certs[$((cert_idx - 1))]}"
        print_info "已选择证书: $selected_cert"
        read -rp "请输入部署目标路径 (如 /etc/nginx/ssl/$domain/): " deploy_path
        check_back "$deploy_path" && return

        if [ -z "$deploy_path" ]; then
            print_error "部署路径不能为空"
        else
            mkdir -p "$deploy_path" 2>/dev/null
            cp "$selected_cert" "$deploy_path/" && print_success "证书已部署到 $deploy_path" || print_error "部署失败"
        fi
    else
        print_error "无效的编号"
    fi
    press_any_key
}

# 全局搜索系统中所有证书
ssl_global_search() {
    print_line
    echo "  全局搜索系统中所有证书"
    print_line
    auto_search_certs
    press_any_key
}

# 手动指定证书路径
ssl_manual_path() {
    print_line
    echo "  手动指定证书路径"
    print_line
    read -rp "请输入证书文件路径 (如 /etc/ssl/cert.pem): " cert_path
    check_back "$cert_path" && return

    read -rp "请输入私钥文件路径 (如 /etc/ssl/private/key.pem): " key_path
    check_back "$key_path" && return

    if [ ! -f "$cert_path" ]; then
        print_error "证书文件不存在: $cert_path"
        press_any_key
        return
    fi
    if [ ! -f "$key_path" ]; then
        print_error "私钥文件不存在: $key_path"
        press_any_key
        return
    fi

    # 校验证书与私钥是否匹配
    cert_md5=$(openssl x509 -noout -modulus -in "$cert_path" 2>/dev/null | openssl md5)
    key_md5=$(openssl rsa -noout -modulus -in "$key_path" 2>/dev/null | openssl md5)

    if [ "$cert_md5" == "$key_md5" ]; then
        print_success "证书与私钥匹配"
        show_cert_info "$cert_path"
        echo ""
        read -rp "是否部署到指定路径? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            read -rp "请输入部署目标路径: " deploy_path
            if [ -n "$deploy_path" ]; then
                mkdir -p "$deploy_path" 2>/dev/null
                cp "$cert_path" "$deploy_path/" && cp "$key_path" "$deploy_path/" && \
                    print_success "证书和私钥已部署到 $deploy_path" || print_error "部署失败"
            fi
        fi
    else
        print_error "证书与私钥不匹配!"
    fi
    press_any_key
}

# 跨域名证书部署
ssl_cross_domain() {
    print_line
    echo "  跨域名证书部署（支持多个域名一键申请和部署）"
    print_line
    read -rp "请输入域名列表 (空格分隔, 如: a.com b.com c.com): " domain_list
    check_back "$domain_list" && return

    if [ -z "$domain_list" ]; then
        print_error "域名列表不能为空"
        press_any_key
        return
    fi

    local domain_args=""
    for d in $domain_list; do
        domain_args="$domain_args -d $d"
    done

    print_info "将为以下域名申请证书: $domain_list"
    echo ""

    if cmd_exists certbot; then
        print_info "使用 certbot 申请证书..."
        read -rp "确认申请? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            certbot certonly --standalone $domain_args
        fi
    elif [ -f "$HOME/.acme.sh/acme.sh" ]; then
        print_info "使用 acme.sh 申请证书..."
        read -rp "确认申请? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            "$HOME/.acme.sh/acme.sh" --issue $domain_args --standalone
        fi
    else
        print_error "未找到 certbot 或 acme.sh，请先安装证书申请工具"
    fi
    press_any_key
}

# 查询证书覆盖情况
ssl_coverage_check() {
    print_line
    echo "  查询证书覆盖情况（批量域名检查）"
    print_line
    read -rp "请输入域名列表 (空格分隔): " domain_list
    check_back "$domain_list" && return

    if [ -z "$domain_list" ]; then
        print_error "域名列表不能为空"
        press_any_key
        return
    fi

    for domain in $domain_list; do
        echo ""
        echo -e "${BLUE}检查域名: $domain${NC}"
        local found=0
        for search_path in "${CERT_SEARCH_PATHS[@]}"; do
            for expanded_path in $search_path; do
                if [ -d "$expanded_path" ]; then
                    while IFS= read -r -d '' cert; do
                        local info
                        info=$(openssl x509 -in "$cert" -noout -subject -ext subjectAltName 2>/dev/null)
                        if echo "$info" | grep -qi "$domain"; then
                            print_success "$domain -> $cert"
                            found=1
                            break 3
                        fi
                    done < <(find "$expanded_path" -maxdepth 3 \( -name "*.pem" -o -name "*.crt" \) -print0 2>/dev/null)
                fi
            done
        done
        if [ $found -eq 0 ]; then
            print_warn "$domain -> 未找到覆盖证书"
        fi
    done
    press_any_key
}

# 交互式申请SAN证书
ssl_san_cert() {
    print_line
    echo "  交互式申请SAN证书（多域名证书）"
    print_line
    local domains=()
    echo "请逐个输入域名 (输入空行结束):"
    while true; do
        read -rp "  域名: " d
        if [ -z "$d" ]; then
            break
        fi
        check_back "$d" && return
        domains+=("$d")
    done

    if [ ${#domains[@]} -eq 0 ]; then
        print_error "至少需要一个域名"
        press_any_key
        return
    fi

    local domain_args=""
    for d in "${domains[@]}"; do
        domain_args="$domain_args -d $d"
    done

    print_info "将为以下域名申请SAN证书: ${domains[*]}"

    if cmd_exists certbot; then
        read -rp "使用 certbot 申请? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            certbot certonly --standalone $domain_args
        fi
    elif [ -f "$HOME/.acme.sh/acme.sh" ]; then
        read -rp "使用 acme.sh 申请? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            "$HOME/.acme.sh/acme.sh" --issue $domain_args --standalone
        fi
    else
        print_error "未找到 certbot 或 acme.sh，请先安装"
    fi
    press_any_key
}

# 交互式申请通配符证书
ssl_wildcard_cert() {
    print_line
    echo "  交互式申请通配符证书（需DNS验证）"
    print_line
    read -rp "请输入根域名 (如 example.com): " root_domain
    check_back "$root_domain" && return

    if [ -z "$root_domain" ]; then
        print_error "域名不能为空"
        press_any_key
        return
    fi

    print_info "将为 *.$root_domain 申请通配符证书"
    print_warn "通配符证书需要 DNS 验证，请确保您有域名的 DNS 管理权限"
    echo ""

    if cmd_exists certbot; then
        read -rp "使用 certbot 申请? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            certbot certonly --manual --preferred-challenges=dns -d "*.$root_domain" -d "$root_domain"
        fi
    elif [ -f "$HOME/.acme.sh/acme.sh" ]; then
        read -rp "使用 acme.sh 申请? 需要配置 DNS API (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            print_info "请确保已配置 DNS API 环境变量"
            read -rp "DNS提供商 (如 dns_ali, dns_cf, dns_dp): " dns_provider
            "$HOME/.acme.sh/acme.sh" --issue --dns "$dns_provider" -d "$root_domain" -d "*.$root_domain"
        fi
    else
        print_error "未找到 certbot 或 acme.sh，请先安装"
    fi
    press_any_key
}

# 域名证书自动延期
ssl_auto_renew() {
    print_line
    echo "  域名证书自动延期"
    print_line

    if cmd_exists certbot; then
        print_info "使用 certbot 自动续期..."
        certbot renew --dry-run
        echo ""
        read -rp "执行实际续期? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            certbot renew
        fi
    elif [ -f "$HOME/.acme.sh/acme.sh" ]; then
        print_info "使用 acme.sh 自动续期..."
        "$HOME/.acme.sh/acme.sh" --renew-all
    else
        print_error "未找到 certbot 或 acme.sh"
    fi
    press_any_key
}

# 域名证书手动延期
ssl_manual_renew() {
    print_line
    echo "  域名证书手动延期"
    print_line
    read -rp "请输入要续期的域名: " domain
    check_back "$domain" && return

    if [ -z "$domain" ]; then
        print_error "域名不能为空"
        press_any_key
        return
    fi

    if cmd_exists certbot; then
        print_info "使用 certbot 续期 $domain ..."
        certbot renew --cert-name "$domain" --force-renewal
    elif [ -f "$HOME/.acme.sh/acme.sh" ]; then
        print_info "使用 acme.sh 续期 $domain ..."
        "$HOME/.acme.sh/acme.sh" --renew -d "$domain" --force
    else
        print_error "未找到 certbot 或 acme.sh"
    fi
    press_any_key
}

# 查询证书延期状态
ssl_renew_status() {
    print_line
    echo "  查询证书延期状态"
    print_line

    if cmd_exists certbot; then
        print_info "certbot 管理的证书:"
        certbot certificates 2>/dev/null
    fi

    if [ -f "$HOME/.acme.sh/acme.sh" ]; then
        echo ""
        print_info "acme.sh 管理的证书:"
        "$HOME/.acme.sh/acme.sh" --list 2>/dev/null
    fi

    if ! cmd_exists certbot && [ ! -f "$HOME/.acme.sh/acme.sh" ]; then
        print_error "未找到 certbot 或 acme.sh"
    fi
    press_any_key
}

# SSL证书管理子菜单
ssl_menu() {
    while true; do
        clear
        print_line
        echo "  SSL证书管理"
        print_line
        echo "  1. 查看当前证书状态（自动适配多面板路径）"
        echo "  2. 按域名搜索并部署证书（输入域名，自动查找并可一键部署）"
        echo "  3. 全局搜索系统中所有证书（自动遍历常见面板和路径）"
        echo "  4. 手动指定证书路径（输入证书和私钥路径，校验并部署）"
        echo "  5. 跨域名证书部署（支持多个域名一键申请和部署）"
        echo "  6. 查询证书覆盖情况（批量输入域名，检查哪些已覆盖）"
        echo "  7. 交互式申请SAN证书（多域名证书，交互输入）"
        echo "  8. 交互式申请通配符证书（如*.example.com，需DNS验证）"
        echo "  9. 域名证书自动延期（自动续期，支持certbot/acme.sh）"
        echo "  10. 域名证书手动延期（手动续期指定域名）"
        echo "  11. 查询证书延期状态（查看所有证书续期状态）"
        echo "  0. 返回主菜单"
        echo ""
        read -rp "  请选择操作 [0-11]: " choice
        check_back "$choice" && return
        case "$choice" in
            1) ssl_view_status ;;
            2) ssl_search_deploy ;;
            3) ssl_global_search ;;
            4) ssl_manual_path ;;
            5) ssl_cross_domain ;;
            6) ssl_coverage_check ;;
            7) ssl_san_cert ;;
            8) ssl_wildcard_cert ;;
            9) ssl_auto_renew ;;
            10) ssl_manual_renew ;;
            11) ssl_renew_status ;;
            0) return ;;
            *) print_error "无效选项"; sleep 1 ;;
        esac
    done
}

# ==========================================
# 3. 网络工具
# ==========================================

# 网络连接状态
net_connections() {
    print_line
    echo "  网络连接状态"
    print_line
    if cmd_exists ss; then
        ss -tulnp
    elif cmd_exists netstat; then
        netstat -tulnp
    else
        print_error "未找到 ss 或 netstat 命令"
    fi
    press_any_key
}

# 端口占用情况（支持交互杀进程、二次确认、倒计时）
net_port_check() {
    print_line
    echo "  端口占用情况"
    print_line
    read -rp "请输入要检查的端口号 (留空显示所有): " port
    check_back "$port" && return

    echo ""
    if [ -z "$port" ]; then
        if cmd_exists ss; then
            ss -tulnp
        elif cmd_exists netstat; then
            netstat -tulnp
        fi
    else
        print_info "端口 $port 占用情况:"
        local result=""
        if cmd_exists ss; then
            result=$(ss -tulnp | grep ":$port ")
        elif cmd_exists netstat; then
            result=$(netstat -tulnp | grep ":$port ")
        fi

        if [ -z "$result" ]; then
            print_success "端口 $port 未被占用"
            press_any_key
            return
        fi

        echo "$result"
        echo ""

        # 获取占用进程PID
        local pids
        if cmd_exists ss; then
            pids=$(ss -tulnp | grep ":$port " | grep -oP 'pid=\K[0-9]+' | sort -u)
        elif cmd_exists netstat; then
            pids=$(netstat -tulnp 2>/dev/null | grep ":$port " | awk '{print $NF}' | grep -oP '^\K[0-9]+' | sort -u)
        fi

        if [ -z "$pids" ]; then
            # 尝试用 lsof
            if cmd_exists lsof; then
                pids=$(lsof -i :"$port" -t 2>/dev/null | sort -u)
            fi
        fi

        if [ -n "$pids" ]; then
            echo -e "${YELLOW}占用端口 $port 的进程:${NC}"
            for pid in $pids; do
                local proc_name
                proc_name=$(ps -p "$pid" -o comm= 2>/dev/null)
                local proc_cmd
                proc_cmd=$(ps -p "$pid" -o args= 2>/dev/null)
                echo "  PID: $pid  进程名: $proc_name"
                echo "  命令: $proc_cmd"
                echo ""
            done

            read -rp "是否要杀掉占用该端口的进程? (y/n): " kill_confirm
            if [[ "$kill_confirm" =~ ^[Yy]$ ]]; then
                # 二次确认
                echo ""
                print_warn "即将杀掉以下进程: $pids"
                echo -n "  倒计时确认: "
                for i in 5 4 3 2 1; do
                    echo -n "$i "
                    sleep 1
                done
                echo ""
                read -rp "最终确认: 确定要杀掉这些进程吗? (yes/no): " final_confirm
                if [[ "$final_confirm" == "yes" ]]; then
                    for pid in $pids; do
                        kill -9 "$pid" 2>/dev/null && print_success "已杀掉进程 PID: $pid" || print_error "无法杀掉进程 PID: $pid"
                    done
                else
                    print_info "已取消操作"
                fi
            fi
        fi
    fi
    press_any_key
}

# Ping 测试
net_ping() {
    print_line
    echo "  Ping 测试"
    print_line
    read -rp "请输入目标IP或域名: " target
    check_back "$target" && return

    if [ -z "$target" ]; then
        print_error "目标不能为空"
        press_any_key
        return
    fi

    print_info "正在 Ping $target ..."
    ping -c 10 "$target"
    press_any_key
}

# 路由表查看
net_route() {
    print_line
    echo "  路由表查看"
    print_line
    if cmd_exists ip; then
        ip route show
    elif cmd_exists route; then
        route -n
    else
        print_error "未找到 ip 或 route 命令"
    fi
    press_any_key
}

# 网络工具子菜单
network_menu() {
    while true; do
        clear
        print_line
        echo "  网络工具"
        print_line
        echo "  1. 网络连接状态（显示当前主机所有监听端口和连接）"
        echo "  2. 端口占用情况（可查进程并交互杀进程，支持倒计时和二次确认）"
        echo "  3. Ping 测试（输入目标IP或域名，测试连通性）"
        echo "  4. 路由表查看（显示主机路由表）"
        echo "  0. 返回主菜单"
        echo ""
        read -rp "  请选择操作 [0-4]: " choice
        check_back "$choice" && return
        case "$choice" in
            1) net_connections ;;
            2) net_port_check ;;
            3) net_ping ;;
            4) net_route ;;
            0) return ;;
            *) print_error "无效选项"; sleep 1 ;;
        esac
    done
}

# ==========================================
# 4. 系统工具
# ==========================================

# 系统资源监控
sys_monitor() {
    print_line
    echo "  系统资源监控"
    print_line
    print_info "按 q 退出 top 监控"
    sleep 1
    top -bn1 | head -30
    press_any_key
}

# 进程管理
sys_process() {
    print_line
    echo "  进程管理（按CPU排序，前20个进程）"
    print_line
    ps aux --sort=-%cpu | head -21
    press_any_key
}

# 磁盘空间分析
sys_disk() {
    print_line
    echo "  磁盘空间分析（根目录各子目录空间占用）"
    print_line
    print_info "正在分析磁盘空间，请稍候..."
    du -sh /* 2>/dev/null | sort -rh | head -20
    echo ""
    print_info "磁盘分区使用情况:"
    df -h
    press_any_key
}

# 系统日志查看
sys_log() {
    print_line
    echo "  系统日志查看（最新50行）"
    print_line
    if [ -f /var/log/syslog ]; then
        tail -n 50 /var/log/syslog
    elif [ -f /var/log/messages ]; then
        tail -n 50 /var/log/messages
    elif cmd_exists journalctl; then
        journalctl -n 50 --no-pager
    else
        print_error "未找到系统日志文件"
    fi
    press_any_key
}

# 系统工具子菜单
system_menu() {
    while true; do
        clear
        print_line
        echo "  系统工具"
        print_line
        echo "  1. 系统资源监控（显示CPU/内存/负载等）"
        echo "  2. 进程管理（按CPU排序，显示前20个进程）"
        echo "  3. 磁盘空间分析（根目录各子目录空间占用）"
        echo "  4. 系统日志查看（最新50行日志）"
        echo "  0. 返回主菜单"
        echo ""
        read -rp "  请选择操作 [0-4]: " choice
        check_back "$choice" && return
        case "$choice" in
            1) sys_monitor ;;
            2) sys_process ;;
            3) sys_disk ;;
            4) sys_log ;;
            0) return ;;
            *) print_error "无效选项"; sleep 1 ;;
        esac
    done
}

# ==========================================
# 5. 文件管理
# ==========================================

# 文件搜索
file_search() {
    print_line
    echo "  文件搜索（支持通配符，指定目录）"
    print_line
    read -rp "请输入搜索目录 (默认 /): " search_dir
    check_back "$search_dir" && return
    search_dir="${search_dir:-/}"

    read -rp "请输入文件名或通配符 (如 *.log): " pattern
    check_back "$pattern" && return

    if [ -z "$pattern" ]; then
        print_error "搜索模式不能为空"
        press_any_key
        return
    fi

    print_info "正在搜索 $search_dir 下的 $pattern ..."
    find "$search_dir" -name "$pattern" -type f 2>/dev/null | head -50
    echo ""
    print_info "最多显示50条结果"
    press_any_key
}

# 文本内容搜索
file_content_search() {
    print_line
    echo "  文本内容搜索（递归查找目录下所有文件内容）"
    print_line
    read -rp "请输入搜索目录 (默认 /etc): " search_dir
    check_back "$search_dir" && return
    search_dir="${search_dir:-/etc}"

    read -rp "请输入要搜索的文本内容: " keyword
    check_back "$keyword" && return

    if [ -z "$keyword" ]; then
        print_error "搜索内容不能为空"
        press_any_key
        return
    fi

    print_info "正在搜索 $search_dir 中包含 '$keyword' 的文件..."
    grep -rl "$keyword" "$search_dir" 2>/dev/null | head -30
    echo ""
    print_info "最多显示30条结果"
    press_any_key
}

# 文件权限管理
file_permissions() {
    print_line
    echo "  文件权限管理"
    print_line
    read -rp "请输入文件或目录路径: " filepath
    check_back "$filepath" && return

    if [ ! -e "$filepath" ]; then
        print_error "路径不存在: $filepath"
        press_any_key
        return
    fi

    echo ""
    print_info "当前权限信息:"
    ls -la "$filepath"
    echo ""
    stat "$filepath" 2>/dev/null
    echo ""

    read -rp "是否修改权限? (y/n): " modify
    if [[ "$modify" =~ ^[Yy]$ ]]; then
        read -rp "请输入新权限 (如 755, 644): " new_perm
        if [[ "$new_perm" =~ ^[0-7]{3,4}$ ]]; then
            chmod "$new_perm" "$filepath" && print_success "权限已修改为 $new_perm" || print_error "权限修改失败"
        else
            print_error "无效的权限格式"
        fi
    fi
    press_any_key
}

# 文件大小统计
file_size_stat() {
    print_line
    echo "  文件大小统计（目录下文件/子目录大小排序）"
    print_line
    read -rp "请输入目录路径 (默认当前目录): " dir_path
    check_back "$dir_path" && return
    dir_path="${dir_path:-.}"

    if [ ! -d "$dir_path" ]; then
        print_error "目录不存在: $dir_path"
        press_any_key
        return
    fi

    print_info "目录 $dir_path 下文件大小统计:"
    du -sh "$dir_path"/* 2>/dev/null | sort -rh | head -30
    echo ""
    print_info "最多显示30条结果"
    press_any_key
}

# 文件管理子菜单
file_menu() {
    while true; do
        clear
        print_line
        echo "  文件管理"
        print_line
        echo "  1. 文件搜索（支持通配符，指定目录）"
        echo "  2. 文本内容搜索（递归查找目录下所有文件内容）"
        echo "  3. 文件权限管理（显示并修改文件权限）"
        echo "  4. 文件大小统计（目录下文件/子目录大小排序）"
        echo "  0. 返回主菜单"
        echo ""
        read -rp "  请选择操作 [0-4]: " choice
        check_back "$choice" && return
        case "$choice" in
            1) file_search ;;
            2) file_content_search ;;
            3) file_permissions ;;
            4) file_size_stat ;;
            0) return ;;
            *) print_error "无效选项"; sleep 1 ;;
        esac
    done
}

# ==========================================
# 6. 抓包管理
# ==========================================

CAPTURE_DIR="/tmp/captures"

# 确保抓包目录存在
ensure_capture_dir() {
    mkdir -p "$CAPTURE_DIR" 2>/dev/null
}

# 开始抓包
capture_start() {
    print_line
    echo "  开始抓包"
    print_line

    # 选择网口
    print_info "可用网络接口:"
    if cmd_exists ip; then
        ip link show | grep -E "^[0-9]+:" | awk -F': ' '{print "  " $2}'
    elif cmd_exists ifconfig; then
        ifconfig -a | grep -E "^[a-zA-Z]" | awk -F: '{print "  " $1}'
    fi
    echo ""
    read -rp "请输入网络接口名 (如 eth0, 留空默认 any): " iface
    check_back "$iface" && return
    iface="${iface:-any}"

    # 选择抓包工具
    local tool=""
    if cmd_exists tcpdump; then
        tool="tcpdump"
    elif cmd_exists tshark; then
        tool="tshark"
    else
        print_error "未找到 tcpdump 或 tshark，请先安装"
        press_any_key
        return
    fi
    print_info "使用工具: $tool"

    # 过滤条件
    read -rp "请输入过滤条件 (如 port 80, host 1.1.1.1, 留空抓全部): " filter_expr
    check_back "$filter_expr" && return

    # 保存文件名
    local default_name="capture_$(date +%Y%m%d_%H%M%S).pcap"
    read -rp "保存文件名 (默认 $default_name): " save_name
    check_back "$save_name" && return
    save_name="${save_name:-$default_name}"

    ensure_capture_dir
    local save_path="$CAPTURE_DIR/$save_name"

    print_info "开始抓包..."
    print_info "接口: $iface | 过滤: ${filter_expr:-无} | 保存: $save_path"
    print_warn "按 Ctrl+C 停止抓包"
    echo ""

    if [ "$tool" == "tcpdump" ]; then
        if [ -n "$filter_expr" ]; then
            tcpdump -i "$iface" $filter_expr -w "$save_path" -c 1000
        else
            tcpdump -i "$iface" -w "$save_path" -c 1000
        fi
    elif [ "$tool" == "tshark" ]; then
        if [ -n "$filter_expr" ]; then
            tshark -i "$iface" -f "$filter_expr" -w "$save_path" -c 1000
        else
            tshark -i "$iface" -w "$save_path" -c 1000
        fi
    fi

    print_success "抓包已保存到: $save_path"
    press_any_key
}

# 分析已保存的包
capture_analyze() {
    print_line
    echo "  分析已保存的包"
    print_line

    ensure_capture_dir
    local files
    files=$(find "$CAPTURE_DIR" -name "*.pcap" -o -name "*.pcapng" 2>/dev/null)

    if [ -z "$files" ]; then
        print_warn "未找到保存的抓包文件 ($CAPTURE_DIR)"
        press_any_key
        return
    fi

    echo "已保存的抓包文件:"
    local idx=0
    local file_arr=()
    while IFS= read -r f; do
        idx=$((idx + 1))
        file_arr+=("$f")
        local fsize
        fsize=$(du -h "$f" 2>/dev/null | awk '{print $1}')
        echo "  [$idx] $f ($fsize)"
    done <<< "$files"

    echo ""
    read -rp "选择文件编号: " file_idx
    check_back "$file_idx" && return

    if ! [[ "$file_idx" =~ ^[0-9]+$ ]] || [ "$file_idx" -lt 1 ] || [ "$file_idx" -gt ${#file_arr[@]} ]; then
        print_error "无效编号"
        press_any_key
        return
    fi

    local selected_file="${file_arr[$((file_idx - 1))]}"
    print_info "分析文件: $selected_file"
    echo ""

    echo "分析选项:"
    echo "  1. 统计摘要"
    echo "  2. 前50个包内容"
    echo "  3. 协议过滤"
    echo "  4. 关键词搜索"
    read -rp "选择分析方式 [1-4]: " analyze_type

    case "$analyze_type" in
        1)
            if cmd_exists tcpdump; then
                tcpdump -r "$selected_file" -q 2>/dev/null | tail -5
                tcpdump -r "$selected_file" 2>/dev/null | wc -l | xargs -I{} echo "总包数: {}"
            elif cmd_exists tshark; then
                tshark -r "$selected_file" -q -z io,stat,0 2>/dev/null
            fi
            ;;
        2)
            if cmd_exists tcpdump; then
                tcpdump -r "$selected_file" -c 50 2>/dev/null
            elif cmd_exists tshark; then
                tshark -r "$selected_file" -c 50 2>/dev/null
            fi
            ;;
        3)
            read -rp "请输入协议过滤 (如 tcp, udp, icmp, http): " proto
            if cmd_exists tcpdump; then
                tcpdump -r "$selected_file" "$proto" -c 50 2>/dev/null
            elif cmd_exists tshark; then
                tshark -r "$selected_file" -Y "$proto" -c 50 2>/dev/null
            fi
            ;;
        4)
            read -rp "请输入关键词: " keyword
            if cmd_exists tcpdump; then
                tcpdump -r "$selected_file" -A 2>/dev/null | grep -i "$keyword" | head -30
            elif cmd_exists tshark; then
                tshark -r "$selected_file" -V 2>/dev/null | grep -i "$keyword" | head -30
            fi
            ;;
        *)
            print_error "无效选项"
            ;;
    esac
    press_any_key
}

# 导入包文件
capture_import() {
    print_line
    echo "  导入包文件"
    print_line
    read -rp "请输入要导入的包文件路径: " import_path
    check_back "$import_path" && return

    if [ ! -f "$import_path" ]; then
        print_error "文件不存在: $import_path"
        press_any_key
        return
    fi

    local ext="${import_path##*.}"
    if [[ "$ext" != "pcap" && "$ext" != "pcapng" ]]; then
        print_warn "文件格式可能不支持 (建议 pcap/pcapng)"
        read -rp "继续导入? (y/n): " confirm
        [[ ! "$confirm" =~ ^[Yy]$ ]] && { press_any_key; return; }
    fi

    ensure_capture_dir
    cp "$import_path" "$CAPTURE_DIR/" && print_success "已导入到 $CAPTURE_DIR/" || print_error "导入失败"
    press_any_key
}

# 导出包文件
capture_export() {
    print_line
    echo "  导出包文件"
    print_line

    ensure_capture_dir
    local files
    files=$(find "$CAPTURE_DIR" -name "*.pcap" -o -name "*.pcapng" 2>/dev/null)

    if [ -z "$files" ]; then
        print_warn "没有可导出的文件"
        press_any_key
        return
    fi

    echo "可导出的文件:"
    local idx=0
    local file_arr=()
    while IFS= read -r f; do
        idx=$((idx + 1))
        file_arr+=("$f")
        echo "  [$idx] $f"
    done <<< "$files"

    echo ""
    read -rp "选择文件编号: " file_idx
    check_back "$file_idx" && return

    if ! [[ "$file_idx" =~ ^[0-9]+$ ]] || [ "$file_idx" -lt 1 ] || [ "$file_idx" -gt ${#file_arr[@]} ]; then
        print_error "无效编号"
        press_any_key
        return
    fi

    local selected_file="${file_arr[$((file_idx - 1))]}"
    read -rp "请输入导出目标路径: " export_path
    check_back "$export_path" && return

    if [ -z "$export_path" ]; then
        print_error "路径不能为空"
        press_any_key
        return
    fi

    mkdir -p "$(dirname "$export_path")" 2>/dev/null
    cp "$selected_file" "$export_path" && print_success "已导出到 $export_path" || print_error "导出失败"
    press_any_key
}

# 抓包工具设置
capture_tool_setup() {
    print_line
    echo "  抓包工具设置"
    print_line

    echo "抓包工具检测:"
    if cmd_exists tcpdump; then
        print_success "tcpdump 已安装: $(tcpdump --version 2>&1 | head -1)"
    else
        print_warn "tcpdump 未安装"
    fi

    if cmd_exists tshark; then
        print_success "tshark 已安装: $(tshark --version 2>&1 | head -1)"
    else
        print_warn "tshark 未安装"
    fi

    echo ""
    read -rp "是否安装/更新抓包工具? (y/n): " install_confirm
    if [[ "$install_confirm" =~ ^[Yy]$ ]]; then
        echo "  1. 安装 tcpdump"
        echo "  2. 安装 tshark (wireshark-cli)"
        echo "  3. 全部安装"
        read -rp "选择 [1-3]: " install_choice

        # 检测包管理器
        if cmd_exists apt-get; then
            PKG_MGR="apt-get install -y"
        elif cmd_exists yum; then
            PKG_MGR="yum install -y"
        elif cmd_exists dnf; then
            PKG_MGR="dnf install -y"
        elif cmd_exists pacman; then
            PKG_MGR="pacman -S --noconfirm"
        else
            print_error "未识别的包管理器"
            press_any_key
            return
        fi

        case "$install_choice" in
            1) $PKG_MGR tcpdump ;;
            2) $PKG_MGR wireshark-cli 2>/dev/null || $PKG_MGR wireshark 2>/dev/null || $PKG_MGR tshark ;;
            3) $PKG_MGR tcpdump; $PKG_MGR wireshark-cli 2>/dev/null || $PKG_MGR wireshark ;;
            *) print_error "无效选项" ;;
        esac
    fi
    press_any_key
}

# 抓包管理子菜单
capture_menu() {
    while true; do
        clear
        print_line
        echo "  抓包管理"
        print_line
        echo "  1. 开始抓包（选择网口、工具、过滤条件、保存文件名）"
        echo "  2. 分析已保存的包（统计、内容、协议过滤、关键词搜索）"
        echo "  3. 导入包文件（支持pcap/pcapng）"
        echo "  4. 导出包文件（导出到指定路径）"
        echo "  5. 抓包工具设置（检测/安装tcpdump、tshark等）"
        echo "  0. 返回主菜单"
        echo ""
        read -rp "  请选择操作 [0-5]: " choice
        check_back "$choice" && return
        case "$choice" in
            1) capture_start ;;
            2) capture_analyze ;;
            3) capture_import ;;
            4) capture_export ;;
            5) capture_tool_setup ;;
            0) return ;;
            *) print_error "无效选项"; sleep 1 ;;
        esac
    done
}

# ==========================================
# 7. 权限管理
# ==========================================

# 切换到管理员权限
perm_sudo() {
    print_line
    echo "  切换到管理员权限 (sudo)"
    print_line

    if [ "$(id -u)" -eq 0 ]; then
        print_success "当前已是 root 用户"
        press_any_key
        return
    fi

    print_info "当前用户: $(whoami)"
    print_warn "将以 root 权限重新运行本脚本"
    read -rp "确认切换? (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        exec sudo "$0"
    fi
    press_any_key
}

# 切换回普通用户
perm_user() {
    print_line
    echo "  切换回普通用户权限"
    print_line

    if [ "$(id -u)" -ne 0 ]; then
        print_success "当前已是普通用户: $(whoami)"
        press_any_key
        return
    fi

    print_info "当前用户: root"
    if [ -n "$SUDO_USER" ]; then
        print_info "原始用户: $SUDO_USER"
        print_warn "将以 $SUDO_USER 身份重新运行本脚本"
        read -rp "确认切换? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            exec su - "$SUDO_USER" -c "$0"
        fi
    else
        print_warn "无法检测原始用户，请手动退出后以普通用户身份运行"
    fi
    press_any_key
}

# 权限管理子菜单
permission_menu() {
    while true; do
        clear
        print_line
        echo "  权限管理"
        print_line
        echo "  1. 切换到管理员权限 (sudo)"
        echo "  2. 切换回普通用户权限"
        echo "  0. 返回主菜单"
        echo ""
        read -rp "  请选择操作 [0-2]: " choice
        check_back "$choice" && return
        case "$choice" in
            1) perm_sudo ;;
            2) perm_user ;;
            0) return ;;
            *) print_error "无效选项"; sleep 1 ;;
        esac
    done
}

# ==========================================
# 主菜单
# ==========================================
main_menu() {
    while true; do
        clear
        print_line
        echo "  通用Linux自动化工具集 ($VERSION)"
        print_line
        echo "  1. 查询系统信息（显示主机、CPU、内存、磁盘、网络等详细信息）"
        echo "  2. SSL证书管理（适配多面板，支持部署、续期、SAN、通配符等）"
        echo "  3. 网络工具（端口占用、进程管理、路由、Ping等，支持交互杀进程）"
        echo "  4. 系统工具（资源监控、进程、磁盘、日志等）"
        echo "  5. 文件管理（文件搜索、内容查找、权限、统计等）"
        echo "  6. 抓包管理（网口选择、关键词过滤、导入导出、分析等）"
        echo "  7. 权限管理（sudo/root切换，安全提示）"
        echo "  0. 退出"
        echo "  输入 b 或 返回 可随时回退主菜单。"
        echo ""
        read -rp "  请选择操作 [0-7]: " choice
        case "$choice" in
            1) show_system_info ;;
            2) ssl_menu ;;
            3) network_menu ;;
            4) system_menu ;;
            5) file_menu ;;
            6) capture_menu ;;
            7) permission_menu ;;
            0)
                echo ""
                print_info "感谢使用通用Linux自动化工具集，再见！"
                exit 0
                ;;
            *)
                print_error "无效选项"
                sleep 1
                ;;
        esac
    done
}

# ==========================================
# 入口
# ==========================================
main_menu
