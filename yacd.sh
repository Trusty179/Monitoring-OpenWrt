#!/bin/sh

echo "Content-type: application/json"
echo ""

# ===== PARSE QUERY =====
QUERY="$QUERY_STRING"
ACTION=$(echo "$QUERY" | sed -n 's/.*action=\([^&]*\).*/\1/p')
IP_REQ=$(echo "$QUERY" | sed -n 's/.*ip=\([^&]*\).*/\1/p')

# ===== BLOCK (ANTI DOUBLE) =====
if [ "$ACTION" = "block" ] && [ -n "$IP_REQ" ]; then
    iptables -C FORWARD -s "$IP_REQ" -j DROP 2>/dev/null || \
    iptables -I FORWARD -s "$IP_REQ" -j DROP

    echo "{\"status\":\"blocked\",\"ip\":\"$IP_REQ\"}"
    exit 0
fi

# ===== UNBLOCK (HAPUS SEMUA RULE) =====
if [ "$ACTION" = "unblock" ] && [ -n "$IP_REQ" ]; then
    while iptables -C FORWARD -s "$IP_REQ" -j DROP 2>/dev/null; do
        iptables -D FORWARD -s "$IP_REQ" -j DROP
    done

    echo "{\"status\":\"unblocked\",\"ip\":\"$IP_REQ\"}"
    exit 0
fi

# ===== DISCONNECT (KICK WIFI) =====
if [ "$ACTION" = "disconnect" ] && [ -n "$IP_REQ" ]; then

    MAC=$(grep " $IP_REQ " /tmp/dhcp.leases 2>/dev/null | awk '{print $2}')

    if [ -n "$MAC" ]; then
        for iface in $(iw dev 2>/dev/null | awk '/Interface/ {print $2}'); do
            iw dev "$iface" station del "$MAC" 2>/dev/null
        done
        echo "{\"status\":\"kicked\",\"ip\":\"$IP_REQ\"}"
    else
        echo "{\"status\":\"error\",\"msg\":\"MAC not found\"}"
    fi

    exit 0
fi

# ===== INTERFACE =====
IF="wwan0"
[ ! -d /sys/class/net/$IF ] && IF="eth0"

RX=$(cat /sys/class/net/$IF/statistics/rx_bytes 2>/dev/null)
TX=$(cat /sys/class/net/$IF/statistics/tx_bytes 2>/dev/null)

[ -z "$RX" ] && RX=0
[ -z "$TX" ] && TX=0

# ===== CPU =====
CPU=$(top -bn1 | grep "CPU:" | awk '{print 100 - $8}' | cut -d. -f1 | head -n1)
CPU=${CPU%% *}
[ -z "$CPU" ] && CPU=0

# ===== TEMP =====
TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
[ -n "$TEMP" ] && TEMP=$((TEMP/1000))
[ -z "$TEMP" ] && TEMP=0

# ===== CLIENT REALTIME =====
CLIENTS=""
FIRST=1

for mac in $(iw dev 2>/dev/null | awk '/Interface/ {print $2}' | while read iface; do
    iw dev "$iface" station dump 2>/dev/null | awk '/Station/ {print $2}'
done); do

    LINE=$(grep -i "$mac" /tmp/dhcp.leases 2>/dev/null)

    IP=$(echo "$LINE" | awk '{print $3}')
    NAME=$(echo "$LINE" | awk '{print $4}')

    [ -z "$IP" ] && IP="$mac"
    [ -z "$NAME" ] && NAME="Unknown"

    # ===== CEK STATUS BLOCK =====
    if iptables -C FORWARD -s "$IP" -j DROP 2>/dev/null; then
        STATUS="blocked"
    else
        STATUS="active"
    fi

    [ $FIRST -eq 0 ] && CLIENTS="$CLIENTS,"
    FIRST=0

    CLIENTS="$CLIENTS{\"ip\":\"$IP\",\"name\":\"$NAME\",\"status\":\"$STATUS\"}"
done

echo "{\"rx\":$RX,\"tx\":$TX,\"cpu\":$CPU,\"temp\":$TEMP,\"clients\":[${CLIENTS}]}"