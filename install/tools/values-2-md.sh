#!/bin/bash
if [ $# -ne 1 ]; then
    echo "使用方法: $0 <values.yaml路径>"
    exit 1
fi

VALUES_FILE="$1"

if [ ! -f "$VALUES_FILE" ]; then
    echo "错误: 文件 $VALUES_FILE 不存在!"
    exit 1
fi

if ! command -v yq &> /dev/null; then
    echo "错误: 需要安装 yq (https://github.com/mikefarah/yq) 工具"
    exit 1
fi

TMP_FILE=$(mktemp)
TMP_CLEAN=$(mktemp)

# 移除注释和空行后处理
sed '/^#/d' "$VALUES_FILE" | sed '/^$/d' > "$TMP_CLEAN"

parse_yaml() {
    local prefix="$1"
    local data="$2"
    
    local keys=$(echo "$data" | yq e 'keys | .[]' -)
    
    for key in $keys; do
        local full_key="${prefix}${key}"
        local type=$(echo "$data" | yq e ".$key | type" -)
        local value=$(echo "$data" | yq e ".$key" -)
        value=$(echo "$value" | sed 's/"/\\"/g')
        echo "$full_key|$type|$value" >> "$TMP_FILE"
        
        if [ "$type" = "object" ]; then
            local sub_data=$(echo "$data" | yq e ".$key" -)
            parse_yaml "${full_key}." "$sub_data"
        fi
    done
}

echo "正在解析 $VALUES_FILE ..."
parse_yaml "" "$(cat "$TMP_CLEAN")"

echo "| 参数路径 | 类型 | 默认值 |"
echo "|----------|------|--------|"

sort "$TMP_FILE" | while IFS="|" read -r key type value; do
    if [ "$value" = "null" ]; then
        value="\`null\`"
    elif [ -z "$value" ]; then
        value="\`\`"
    else
        if [ ${#value} -gt 60 ]; then
            value="${value:0:60}..."
        fi
        value="\`$value\`"
    fi
    
    echo "| $key | $type | $value |"
done

rm -f "$TMP_FILE" "$TMP_CLEAN"

echo -e "\n注: 表格中的参数路径可直接用于helm install/upgrade的--set参数"
