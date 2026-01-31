#!/bin/bash

# ========= 输出目录 =========
OUT_DIR="./output"
mkdir -p "$OUT_DIR"

# ========= 表名参数 =========
TABLES=("$@")

if [ ${#TABLES[@]} -eq 0 ]; then
  echo "❌ 请至少传一个表名"
  exit 1
fi

# ========= 自动读取 ~/.my.cnf 中的 database =========
CNF_FILE="$HOME/.my.cnf"
if [ ! -f "$CNF_FILE" ]; then
    echo "❌ 未找到 $CNF_FILE"
    exit 1
fi

MYSQL_DB=$(grep -E '^database\s*=' "$CNF_FILE" | head -n1 | cut -d'=' -f2 | tr -d ' ')
if [ -z "$MYSQL_DB" ]; then
    echo "❌ ~/.my.cnf 中未配置 database"
    exit 1
fi

# ========= 使用 mysql 客户端（自动读 ~/.my.cnf） =========
MYSQL_CMD="mysql --defaults-file=$CNF_FILE --batch --raw --silent"

for TABLE in "${TABLES[@]}"; do
  echo "📤 导出表：$TABLE"

  OUT_FILE="${OUT_DIR}/${TABLE}.csv"

  # 1️⃣ 生成表头（字段注释优先）
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
