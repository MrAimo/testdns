#!/usr/bin/env bash
#
# DNS 解析测试脚本（准确耗时版 - 已修正）
# 依赖: dig
# 用法: ./dns_test.sh [选项]

set -euo pipefail

# ----------------------------- 默认配置 ---------------------------------
TIMEOUT=2
EXPORT_CSV=""
DNS_SERVERS=()
RECORD_TYPES=("A" "AAAA")
SORT_BY="domain"

DEFAULT_DOMAINS=(
    "www.baidu.com" "www.taobao.com" "www.tmall.com" "www.jd.com"
    "www.pinduoduo.com" "www.qq.com" "weixin.qq.com" "www.sina.com.cn"
    "weibo.com" "www.163.com" "www.sohu.com" "www.bilibili.com"
    "www.douyin.com" "www.kuaishou.com" "www.zhihu.com" "www.douban.com"
    "www.ele.me" "www.meituan.com" "www.ctrip.com" "amap.com"
    "map.baidu.com" "alipay.com" "www.aliyun.com" "cloud.tencent.com"
    "www.xiaohongshu.com" "www.toutiao.com" "www.iqiyi.com"
    "www.youku.com" "www.mgtv.com" "www.dangdang.com"
)

# 颜色 (使用 tput)
if [ -t 1 ] && command -v tput &>/dev/null && [ "$(tput colors)" -ge 8 ]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    CYAN=$(tput setaf 6)
    BOLD=$(tput bold)
    NC=$(tput sgr0)
else
    RED=""; GREEN=""; YELLOW=""; CYAN=""; BOLD=""; NC=""
fi

# ----------------------------- 函数 ------------------------------------
show_help() {
    cat <<EOF
用法: $0 [选项]
选项:
  -d DNS_SERVER      指定DNS（可多次使用）
  -t TIMEOUT         超时秒数，默认2
  -r TYPE            A / AAAA / ALL (默认ALL)
  -f FILE            从文件读取域名列表
  -o FILE.csv        导出CSV
  -s domain|time     排序方式，默认domain
  -h                 帮助
EOF
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d) DNS_SERVERS+=("$2"); shift 2 ;;
            -t) TIMEOUT="$2"; shift 2 ;;
            -r)
                case "$2" in
                    A) RECORD_TYPES=("A") ;;
                    AAAA) RECORD_TYPES=("AAAA") ;;
                    ALL) RECORD_TYPES=("A" "AAAA") ;;
                    *) echo -e "${RED}无效类型${NC}" >&2; exit 1 ;;
                esac
                shift 2 ;;
            -f) DOMAIN_FILE="$2"; shift 2 ;;
            -o) EXPORT_CSV="$2"; shift 2 ;;
            -s) SORT_BY="$2"; shift 2 ;;
            -h) show_help ;;
            *) echo -e "${RED}未知选项: $1${NC}" >&2; exit 1 ;;
        esac
    done
}

load_domains() {
    if [ -n "${DOMAIN_FILE:-}" ]; then
        if [ ! -f "$DOMAIN_FILE" ]; then
            echo -e "${RED}文件不存在: $DOMAIN_FILE${NC}" >&2
            exit 1
        fi
        mapfile -t DOMAINS < <(grep -vE '^\s*#' "$DOMAIN_FILE" | grep -v '^\s*$' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    else
        DOMAINS=("${DEFAULT_DOMAINS[@]}")
    fi
}

# 修正后的解析函数：使用 +noall +answer +stats 同时获取 IP 和 Query time
resolve() {
    local domain="$1"
    local dns="$2"
    local rtype="$3"
    local server_opt=""
    [ -n "$dns" ] && server_opt="@$dns"
    
    # 执行 dig，获取 ANSWER SECTION 和统计信息
    local dig_out
    dig_out=$(dig +timeout=$TIMEOUT +tries=1 +noall +answer +stats "$rtype" "$domain" $server_opt 2>/dev/null)
    
    # 提取 IP 地址（仅匹配指定记录类型，避免 CNAME 干扰）
    local ips=$(echo "$dig_out" | awk -v type="$rtype" '$4 == type {print $5}' | tr '\n' ',' | sed 's/,$//')
    # 提取 Query time（毫秒）
    local elapsed=$(echo "$dig_out" | awk -F': ' '/Query time:/ {print $2}' | awk '{print $1}')
    
    if [ -z "$ips" ]; then
        ips="-"
        status="FAIL"
        [ -z "$elapsed" ] && elapsed="N/A"
    else
        status="OK"
        [ -z "$elapsed" ] && elapsed="N/A"
    fi
    
    echo "$domain|${dns:-系统默认}|$rtype|$ips|$elapsed|$status"
}

run_tests() {
    local results=()
    local total=0
    local current=0
    
    # 计算总数
    if [ ${#DNS_SERVERS[@]} -eq 0 ]; then
        total=$(( ${#DOMAINS[@]} * ${#RECORD_TYPES[@]} ))
    else
        total=$(( ${#DOMAINS[@]} * ${#DNS_SERVERS[@]} * ${#RECORD_TYPES[@]} ))
    fi
    
    for domain in "${DOMAINS[@]}"; do
        if [ ${#DNS_SERVERS[@]} -eq 0 ]; then
            for rtype in "${RECORD_TYPES[@]}"; do
                current=$((current+1))
                printf "\r进度: [%3d/%d] 测试 %s (系统默认 %s)..." $current $total "$domain" "$rtype" >&2
                results+=("$(resolve "$domain" "" "$rtype")")
            done
        else
            for dns in "${DNS_SERVERS[@]}"; do
                for rtype in "${RECORD_TYPES[@]}"; do
                    current=$((current+1))
                    printf "\r进度: [%3d/%d] 测试 %s (%s %s)..." $current $total "$domain" "$dns" "$rtype" >&2
                    results+=("$(resolve "$domain" "$dns" "$rtype")")
                done
            done
        fi
    done
    printf "\r进度: [%d/%d] 完成！\n" $total $total >&2
    printf "%s\n" "${results[@]}"
}

print_table() {
    local results_file="$1"
    printf "\n%-30s %-15s %-8s %-45s %-10s %s\n" "域名" "DNS服务器" "类型" "解析IP" "耗时" "状态"
    echo "----------------------------------------------------------------------------------------------------"
    while IFS='|' read -r domain dns rtype ips elapsed status; do
        # 耗时着色
        if [ "$status" = "OK" ]; then
            if [[ "$elapsed" =~ ^[0-9]+$ ]]; then
                if [ "$elapsed" -gt 100 ]; then
                    elapsed_disp="${RED}${elapsed}ms${NC}"
                elif [ "$elapsed" -gt 50 ]; then
                    elapsed_disp="${YELLOW}${elapsed}ms${NC}"
                else
                    elapsed_disp="${GREEN}${elapsed}ms${NC}"
                fi
            else
                elapsed_disp="${elapsed}"
            fi
            status_disp="${GREEN}OK${NC}"
        else
            elapsed_disp="${elapsed}"
            status_disp="${RED}FAIL${NC}"
        fi
        # IP 截断
        ips_show="${ips:0:45}"
        printf "%-30s %-15s %-8s %-45s %-10s %s\n" \
            "$domain" "$dns" "$rtype" "$ips_show" "$elapsed_disp" "$status_disp"
    done < "$results_file"
}

show_stats() {
    local results_file="$1"
    local dns="$2"
    local rtype="$3"
    local times=()
    while IFS='|' read -r _ dns2 rtype2 _ elapsed status; do
        if [ "$dns2" = "$dns" ] && [ "$rtype2" = "$rtype" ] && [ "$status" = "OK" ] && [[ "$elapsed" =~ ^[0-9]+$ ]]; then
            times+=("$elapsed")
        fi
    done < "$results_file"
    local cnt=${#times[@]}
    if [ $cnt -eq 0 ]; then
        echo -e "  ${rtype}记录: ${RED}无成功查询${NC}"
        return
    fi
    local sorted=($(printf '%s\n' "${times[@]}" | sort -n))
    local min=${sorted[0]}
    local max=${sorted[-1]}
    local sum=0
    for t in "${times[@]}"; do sum=$((sum + t)); done
    local avg=$((sum / cnt))
    echo -e "  ${rtype}记录: ${GREEN}成功${cnt}次${NC}, 最小${min}ms, 最大${max}ms, 平均${avg}ms"
}

export_csv() {
    local results_file="$1"
    local csv="$2"
    echo "域名,DNS服务器,记录类型,解析IP,耗时(ms),状态" > "$csv"
    while IFS='|' read -r domain dns rtype ips elapsed status; do
        echo "\"$domain\",\"$dns\",\"$rtype\",\"$ips\",\"$elapsed\",\"$status\"" >> "$csv"
    done < "$results_file"
    echo -e "${GREEN}已导出: $csv${NC}"
}

main() {
    parse_args "$@"
    load_domains
    if [ ${#DOMAINS[@]} -eq 0 ]; then
        echo -e "${RED}没有要测试的域名${NC}" >&2
        exit 1
    fi

    echo -e "${BOLD}================================================================================${NC}"
    echo -e "${BOLD}DNS 解析测试 (准确耗时版)${NC}"
    echo -e "域名数量: ${#DOMAINS[@]}"
    if [ ${#DNS_SERVERS[@]} -eq 0 ]; then
        echo -e "DNS: 系统默认"
    else
        echo -e "DNS: ${DNS_SERVERS[*]}"
    fi
    echo -e "记录类型: ${RECORD_TYPES[*]}"
    echo -e "超时: ${TIMEOUT}s"
    echo -e "${BOLD}================================================================================${NC}"

    local tmpfile=$(mktemp)
    run_tests > "$tmpfile"

    # 排序
    if [ "$SORT_BY" = "time" ]; then
        # 按耗时数值排序，将 N/A 放到最后
        (head -n1 "$tmpfile"; tail -n+2 "$tmpfile" | sort -t'|' -k5,5n) > "$tmpfile.sorted"
        mv "$tmpfile.sorted" "$tmpfile"
    else
        sort -t'|' -k1,1 "$tmpfile" -o "$tmpfile"
    fi

    print_table "$tmpfile"

    echo -e "${BOLD}================================================================================${NC}"
    echo -e "${BOLD}统计汇总:${NC}"
    if [ ${#DNS_SERVERS[@]} -eq 0 ]; then
        local dns_show="系统默认"
        echo -e "${CYAN}DNS: $dns_show${NC}"
        for rtype in "${RECORD_TYPES[@]}"; do
            show_stats "$tmpfile" "$dns_show" "$rtype"
        done
    else
        for dns in "${DNS_SERVERS[@]}"; do
            echo -e "${CYAN}DNS: $dns${NC}"
            for rtype in "${RECORD_TYPES[@]}"; do
                show_stats "$tmpfile" "$dns" "$rtype"
            done
        done
    fi

    if [ -n "$EXPORT_CSV" ]; then
        export_csv "$tmpfile" "$EXPORT_CSV"
    fi

    rm -f "$tmpfile"
    echo -e "${BOLD}================================================================================${NC}"
}

# 依赖检查
if ! command -v dig &>/dev/null; then
    echo -e "${RED}错误: 需要安装 dig (dnsutils 或 bind-utils)${NC}" >&2
    exit 1
fi

main "$@"