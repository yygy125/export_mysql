#!/bin/bash

# ========= 输出目录 =========
OUT_DIR="./output"
mkdir -p "$OUT_DIR"

# ========= 参数检查 =========
if [ $# -eq 0 ]; then
    echo "❌ 请至少传一个表名，格式：table 或 table=文件名"
    exit 1
fi

# ========= ~/.my.cnf 文件检查 =========
CNF_FILE="$HOME/.my.cnf"

if [ ! -f "$CNF_FILE" ]; then
    echo "⚡ ~/.my.cnf 不存在，需要输入数据库信息："

    read -p "MySQL IP (默认127.0.0.1): " MYSQL_HOST
    MYSQL_HOST=${MYSQL_HOST:-127.0.0.1}

    read -p "MySQL 端口 (默认3306): " MYSQL_PORT
    MYSQL_PORT=${MYSQL_PORT:-3306}

    read -p "MySQL 用户名 (默认root): " MYSQL_USER
    MYSQL_USER=${MYSQL_USER:-root}

    read -s -p "MySQL 密码: " MYSQL_PASS
    echo

    read -p "MySQL 数据库名: " MYSQL_DB
    while [ -z "$MYSQL_DB" ]; do
        echo "❌ 数据库名不能为空"
        read -p "MySQL 数据库名: " MYSQL_DB
    done

    # 保存到 ~/.my.cnf
    cat > "$CNF_FILE" <<EOF
[client]
host=${MYSQL_HOST}
user=${MYSQL_USER}
password=${MYSQL_PASS}
database=${MYSQL_DB}
default-character-set=utf8mb4
port=${MYSQL_PORT}
EOF

    chmod 600 "$CNF_FILE"
    echo "✅ 已保存配置到 $CNF_FILE"
else
    # 从已有 ~/.my.cnf 中读取 database
    MYSQL_DB=$(grep -E '^database\s*=' "$CNF_FILE" | head -n1 | cut -d'=' -f2 | tr -d ' ')
    if [ -z "$MYSQL_DB" ]; then
        echo "❌ ~/.my.cnf 中未配置 database，请检查"
        exit 1
    fi
fi

# ========= 使用 mysql 客户端（自动读 ~/.my.cnf） =========
MYSQL_CMD="mysql --defaults-file=$CNF_FILE --batch --raw --silent"

# ========= 遍历表参数 =========
for ARG in "$@"; do
    # 解析表名和文件名
    if [[ "$ARG" == *=* ]]; then
        TABLE="${ARG%%=*}"
        FILE_NAME="${ARG#*=}.csv"
    else
        TABLE="$ARG"
        FILE_NAME="${TABLE}.csv"
    fi

    OUT_FILE="${OUT_DIR}/${FILE_NAME}"

    echo "📤 导出表：$TABLE -> $OUT_FILE"

    # 1️⃣ 表头（字段注释优先）
    HEADER=$($MYSQL_CMD -D information_schema -e "
        SELECT GROUP_CONCAT(
          IF(COLUMN_COMMENT <> '',
             REPLACE(COLUMN_COMMENT, ',', ' '),
             COLUMN_NAME
          )
          ORDER BY ORDINAL_POSITION
          SEPARATOR ','
        )
        FROM COLUMNS
        WHERE TABLE_SCHEMA='${MYSQL_DB}'
          AND TABLE_NAME='${TABLE}';
    ")

    if [ -z "$HEADER" ]; then
        echo "❌ 表不存在或无字段：$TABLE"
        continue
    fi

    echo "$HEADER" > "$OUT_FILE"

    # 2️⃣ 导出数据
    $MYSQL_CMD -D "$MYSQL_DB" -e "SELECT * FROM \`${TABLE}\`;" \
        | sed 's/\t/,/g' >> "$OUT_FILE"

    echo "✅ 完成：$OUT_FILE"
done
