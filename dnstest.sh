#!/usr/bin/env bash
#
# DNS 解析测试脚本（优化版）
# 用法: ./dns_test_stable.sh [选项]

# ----------------------------- 配置区 ---------------------------------
TIMEOUT=2
EXPORT_CSV=""
DNS_SERVERS=()
RECORD_TYPES=("A" "AAAA")
SORT_BY="domain"
DOMAIN_FILE=""
USER_DIG_OPTS=()
# 内置域名
DEFAULT_DOMAINS=( www.baidu.com www.taobao.com www.tmall.com www.jd.com www.pinduoduo.com www.qq.com weixin.qq.com www.sina.com.cn weibo.com www.163.com www.sohu.com www.bilibili.com www.douyin.com www.kuaishou.com www.zhihu.com www.douban.com www.ele.me www.meituan.com www.ctrip.com amap.com map.baidu.com alipay.com www.aliyun.com cloud.tencent.com www.xiaohongshu.com www.toutiao.com www.iqiyi.com www.youku.com www.mgtv.com www.dangdang.com )

# 颜色
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null)" -ge 8 ]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    CYAN=$(tput setaf 6)
    BOLD=$(tput bold)
    NC=$(tput sgr0)
else
    RED=""; GREEN=""; YELLOW=""; CYAN=""; BOLD=""; NC=""
fi

show_help() {
    cat <<EOF
用法: $0 [选项]
  -d DNS_SERVER   指定DNS（可多次）
  -t TIMEOUT      超时（秒），默认2
  -r TYPE         A/AAAA/ALL（默认ALL）
  -f FILE         从文件读取域名
  -o FILE.csv     导出CSV
  -s domain|time  排序方式
  -h              帮助
  --dig-opt OPT   传递额外dig参数，可多次
EOF
    exit 0
}

# 提升健壮性——选项解析
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -d) DNS_SERVERS+=("$2"); shift 2 ;;
            -t) TIMEOUT="$2"; shift 2 ;;
            -r)
                case "$2" in
                    A) RECORD_TYPES=("A") ;;
                    AAAA) RECORD_TYPES=("AAAA") ;;
                    ALL) RECORD_TYPES=("A" "AAAA") ;;
                    *) echo "${YELLOW}无效类型 $2, 已使用 ALL${NC}"; RECORD_TYPES=("A" "AAAA") ;;
                esac
                shift 2 ;;
            -f) DOMAIN_FILE="$2"; shift 2 ;;
            -o) EXPORT_CSV="$2"; shift 2 ;;
            -s) SORT_BY="$2"; shift 2 ;;
            --dig-opt) USER_DIG_OPTS+=("$2"); shift 2 ;;
            -h) show_help ;;
            *) echo "${YELLOW}忽略未知选项: $1${NC}"; shift ;;
        esac
    done
}

load_domains() {
    if [ -n "$DOMAIN_FILE" ] && [ -f "$DOMAIN_FILE" ]; then
        mapfile -t DOMAINS < <(grep -vE '^\s*#' "$DOMAIN_FILE" | grep -v '^\s*$' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    else
        DOMAINS=("${DEFAULT_DOMAINS[@]}")
    fi
    [ ${#DOMAINS[@]} -eq 0 ] && DOMAINS=("${DEFAULT_DOMAINS[@]}")
}

# 优化兼容各种 dig 输出
resolve() {
    local domain="$1" dns="$2" rtype="$3"
    local server_opt="" dig_out ips elapsed status
    [ -n "$dns" ] && server_opt="@$dns"
    dig_out=$(dig +timeout="${TIMEOUT}" +tries=1 +noall +answer +stats "${USER_DIG_OPTS[@]}" "$rtype" "$domain" $server_opt 2>&1)
    ips=$(awk -v type="$rtype" '$4 == type {print $5}' <<<"$dig_out" | head -5 | tr '\n' ',' | sed 's/,$//')
    elapsed=$(grep -i "Query time" <<<"$dig_out" | grep -oE '[0-9]+' | head -1)
    [ -z "$ips" ] && ips="-" && status="FAIL" || status="OK"
    [ -z "$elapsed" ] && elapsed="N/A"
    echo "$domain|${dns:-系统默认}|$rtype|$ips|$elapsed|$status"
}

run_tests() {
    local r total current=0
    [[ ${#DNS_SERVERS[@]} -eq 0 ]] && total=$((${#DOMAINS[@]} * ${#RECORD_TYPES[@]})) || total=$((${#DOMAINS[@]} * ${#DNS_SERVERS[@]} * ${#RECORD_TYPES[@]}))
    [ "$total" -eq 0 ] && echo "错误：没有要测试的项" >&2 && return 1
    for domain in "${DOMAINS[@]}"; do
        if [ ${#DNS_SERVERS[@]} -eq 0 ]; then
            for rtype in "${RECORD_TYPES[@]}"; do
                ((current++))
                printf "\r进度: [%3d/%d] 测试 %s (系统默认 %s)..." $current $total "$domain" "$rtype" >&2
                resolve "$domain" "" "$rtype"
            done
        else
            for dns in "${DNS_SERVERS[@]}"; do
                for rtype in "${RECORD_TYPES[@]}"; do
                    ((current++))
                    printf "\r进度: [%3d/%d] 测试 %s (%s %s)..." $current $total "$domain" "$dns" "$rtype" >&2
                    resolve "$domain" "$dns" "$rtype"
                done
            done
        fi
    done
    printf "\r进度: [%d/%d] 完成！\n" $total $total >&2
}

print_table() {
    local results_file="$1"
    printf "\n%-30s %-15s %-8s %-45s %-10s %s\n" "域名" "DNS服务器" "类型" "解析IP" "耗时" "状态"
    echo "----------------------------------------------------------------------------------------------------"
    while IFS='|' read -r domain dns rtype ips elapsed status; do
        if [ "$status" = "OK" ]; then
            [[ "$elapsed" =~ ^[0-9]+$ ]] && {
                ((elapsed > 100)) && elapsed_disp="${RED}${elapsed}ms${NC}" ||
                ((elapsed > 50))  && elapsed_disp="${YELLOW}${elapsed}ms${NC}" ||
                                 elapsed_disp="${GREEN}${elapsed}ms${NC}"
            } || elapsed_disp="${elapsed}"
            status_disp="${GREEN}OK${NC}"
        else
            elapsed_disp="${elapsed}"
            status_disp="${RED}FAIL${NC}"
        fi
        ips_show="${ips:0:45}"
        printf "%-30s %-15s %-8s %-45s %-10s %s\n" "$domain" "$dns" "$rtype" "$ips_show" "$elapsed_disp" "$status_disp"
    done < "$results_file"
}

show_stats() {
    local results_file="$1" dns="$2" rtype="$3" t cnt min max avg sum
    times=()
    while IFS='|' read -r _ dns2 rtype2 _ elapsed status; do
        [ "$dns2" = "$dns" ] && [ "$rtype2" = "$rtype" ] && [ "$status" = "OK" ] && [[ "$elapsed" =~ ^[0-9]+$ ]] && times+=("$elapsed")
    done < "$results_file"
    cnt=${#times[@]}
    [ $cnt -eq 0 ] && echo "  $rtype 记录: 无成功查询" && return
    IFS=$'\n' sorted=($(sort -n <<<"${times[*]}"))
    min=${sorted[0]}; max=${sorted[-1]}; sum=0
    for t in "${times[@]}"; do sum=$((sum + t)); done
    avg=$((sum / cnt))
    echo "  $rtype 记录: 成功${cnt}次, 最小${min}ms, 最大${max}ms, 平均${avg}ms"
}

export_csv() {
    local results_file="$1" csv="$2"
    echo "域名,DNS服务器,记录类型,解析IP,耗时(ms),状态" > "$csv"
    while IFS='|' read -r domain dns rtype ips elapsed status; do
        echo "\"$domain\",\"$dns\",\"$rtype\",\"$ips\",\"$elapsed\",\"$status\"" >> "$csv"
    done < "$results_file"
    echo "已导出: $csv"
}

main() {
    parse_args "$@"
    load_domains
    echo -e "================================================================================\nDNS 解析测试 (优化版)\n域名数量: ${#DOMAINS[@]}\nDNS: ${DNS_SERVERS[@]:-系统默认}\n记录类型: ${RECORD_TYPES[@]}\n超时: ${TIMEOUT}s\n================================================================================"
    # 检查 dig
    command -v dig > /dev/null 2>&1 || { echo "${RED}错误：未找到 dig，请安装 dnsutils/bind-utils${NC}"; exit 1; }
    # 临时文件，退出自动删除
    local tmpfile; tmpfile=$(mktemp)
    trap 'rm -f "$tmpfile"' EXIT
    run_tests > "$tmpfile" || { echo "测试执行失败" >&2; exit 1; }
    [ ! -s "$tmpfile" ] && { echo "错误：未产生任何测试结果" >&2; exit 1; }
    # 排序
    if [ "$SORT_BY" = "time" ]; then
        (head -n1 "$tmpfile"; tail -n+2 "$tmpfile" | sort -t'|' -k5,5n ) > "$tmpfile.sorted"
        mv "$tmpfile.sorted" "$tmpfile"
    else
        sort -t'|' -k1,1 "$tmpfile" -o "$tmpfile"
    fi
    print_table "$tmpfile"
    echo "================================================================================"
    echo "统计汇总:"
    if [ ${#DNS_SERVERS[@]} -eq 0 ]; then
        echo "DNS: 系统默认"
        for rtype in "${RECORD_TYPES[@]}"; do
            show_stats "$tmpfile" "系统默认" "$rtype"
        done
    else
        for dns in "${DNS_SERVERS[@]}"; do
            echo "DNS: $dns"
            for rtype in "${RECORD_TYPES[@]}"; do
                show_stats "$tmpfile" "$dns" "$rtype"
            done
        done
    fi
    [ -n "$EXPORT_CSV" ] && export_csv "$tmpfile" "$EXPORT_CSV"
    echo "================================================================================"
}

main "$@"
