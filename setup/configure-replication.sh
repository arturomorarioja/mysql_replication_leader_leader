#!/bin/bash
set -euo pipefail

mysql_exec() {
    local host="$1"
    shift
    mysql --protocol=TCP -h "$host" -uroot "$@"
}

echo "1/7 Waiting for both MySQL nodes..."
until mysqladmin ping -h node_a -uroot --silent >/dev/null 2>&1; do sleep 1; done
until mysqladmin ping -h node_b -uroot --silent >/dev/null 2>&1; do sleep 1; done

echo "2/7 Creating local replication accounts without writing them to the binary logs..."
for host in node_a node_b; do
    mysql_exec "$host" <<'SQL'
SET sql_log_bin = 0;
CREATE USER IF NOT EXISTS 'repl_user'@'%' IDENTIFIED BY 'repl_pass';
ALTER USER 'repl_user'@'%' IDENTIFIED BY 'repl_pass';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;
SET sql_log_bin = 1;
SQL
done

echo "3/7 Configuring Node A to replicate from Node B..."
mysql_exec node_a <<'SQL'
STOP REPLICA;
RESET REPLICA ALL;
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = 'node_b',
    SOURCE_PORT = 3306,
    SOURCE_USER = 'repl_user',
    SOURCE_PASSWORD = 'repl_pass',
    SOURCE_AUTO_POSITION = 1,
    GET_SOURCE_PUBLIC_KEY = 1;
START REPLICA;
SQL

echo "4/7 Configuring Node B to replicate from Node A..."
mysql_exec node_b <<'SQL'
STOP REPLICA;
RESET REPLICA ALL;
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = 'node_a',
    SOURCE_PORT = 3306,
    SOURCE_USER = 'repl_user',
    SOURCE_PASSWORD = 'repl_pass',
    SOURCE_AUTO_POSITION = 1,
    GET_SOURCE_PUBLIC_KEY = 1;
START REPLICA;
SQL

check_replication() {
    local host="$1"
    local ok=0
    for attempt in $(seq 1 30); do
        status="$(mysql_exec "$host" -N -B -e "SHOW REPLICA STATUS")"
        io_running="$(printf '%s\n' "$status" | awk -F '\t' '{print $11}')"
        sql_running="$(printf '%s\n' "$status" | awk -F '\t' '{print $12}')"
        if [ "$io_running" = "Yes" ] && [ "$sql_running" = "Yes" ]; then
            ok=1
            break
        fi
        sleep 1
    done
    if [ "$ok" -ne 1 ]; then
        echo "Replication is not healthy on $host."
        mysql_exec "$host" -e "SHOW REPLICA STATUS"
        exit 1
    fi
}

echo "5/7 Verifying replication threads on both nodes..."
check_replication node_a
check_replication node_b

echo "6/7 Creating the schema once on Node A..."
mysql_exec node_a < /setup/01-schema.sql

echo "7/7 Waiting for the schema to replicate to Node B..."
schema_ready=0
for attempt in $(seq 1 30); do
    if mysql_exec node_b -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='multi_leader_messages' AND table_name='messages';" | grep -q '^1$'; then
        schema_ready=1
        break
    fi
    sleep 1
done

if [ "$schema_ready" -ne 1 ]; then
    echo "The schema did not replicate to Node B."
    mysql_exec node_a -e "SHOW REPLICA STATUS"
    mysql_exec node_b -e "SHOW REPLICA STATUS"
    exit 1
fi

echo
echo "Leader-leader replication is ready."
echo "Node A auto_increment: increment=$(mysql_exec node_a -N -B -e "SELECT @@auto_increment_increment"), offset=$(mysql_exec node_a -N -B -e "SELECT @@auto_increment_offset")"
echo "Node B auto_increment: increment=$(mysql_exec node_b -N -B -e "SELECT @@auto_increment_increment"), offset=$(mysql_exec node_b -N -B -e "SELECT @@auto_increment_offset")"
