配置 ~/.my.cnf
[client]
host=127.0.0.1
port=3306
user=root
password=123456
database=test

chmod +x export_mysql_csv.sh
./export_mysql_csv.sh table1 table2 table3
