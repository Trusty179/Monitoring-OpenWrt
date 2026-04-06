#!/bin/sh

# Pastikan output adalah JSON
echo "Content-type: application/json"
echo ""

# ===== 1. PARSE QUERY STRING =====
# Mengubah %3A menjadi : agar MAC Address terbaca normal
QUERY=$(echo "$QUERY_STRING" | sed 's/%3A/:/g')
ACTION=$(echo "$QUERY" | sed -n 's/.*action=\([^&]*\).*/\1/p')
IP_REQ=$(echo "$QUERY" | sed -n 's/.*ip=\([^&]*\).*/\1/p')
MAC_REQ=$(echo "$QUERY" | sed -n 's/.*mac=\([^&]*\).*/\1/p')

# ===== 2. ACTION HANDLER =====
if [ "$ACTION" = "block" ] && [ -n "$IP_REQ" ]; then
    iptables -C FORWARD -s "$IP_REQ" -j DROP 2>/dev/null || iptables -I FORWARD -s "$IP_REQ" -j DROP
    echo "{\"status\":\"blocked\",\"ip\":\"$IP_REQ\"}"
    exit 0
elif [ "$ACTION" = "unblock" ] && [ -n "$IP_REQ" ]; then
    while iptables -C FORWARD -s "$IP_REQ" -j DROP 2>/dev/null; do 
        iptables -D FORWARD -s "$IP_REQ" -j DROP
    done
    echo "{\"status\":\"unblocked\",\"ip\":\"$IP_REQ\"}"
    exit 0
elif [ "$ACTION" = "disconnect" ] && [ -n "$IP_REQ" ]; then
    MAC_KICK=$(grep "$IP_REQ" /tmp/dhcp.leases | awk '{print $2}')
    if [ -n "$MAC_KICK" ]; then
        for iface in $(iw dev | awk '/Interface/ {print $2}'); do
            iw dev "$iface" station del "$MAC_KICK" 2>/dev/null
        done
    fi
    echo "{\"status\":\"disconnected\",\"ip\":\"$IP_REQ\"}"
    exit 0
elif [ "$ACTION" = "static" ] && [ -n "$IP_REQ" ]; then
    [ -z "$MAC_REQ" ] && MAC_REQ=$(grep "$IP_REQ" /tmp/dhcp.leases | awk '{print $2}')
    if [ -n "$MAC_REQ" ]; then
        uci show dhcp | grep "=host" | cut -d. -f2 | while read s; do
            [ "$(uci -q get dhcp.$s.mac)" = "$MAC_REQ" ] && uci delete dhcp.$s
        done
        uci add dhcp host >/dev/null
        uci set dhcp.@host[-1].mac="$MAC_REQ"
        uci set dhcp.@host[-1].ip="$IP_REQ"
        uci commit dhcp
        /etc/init.d/dnsmasq restart >/dev/null 2>&1
    fi
    echo "{\"status\":\"static\",\"ip\":\"$IP_REQ\"}"
    exit 0
fi

# ===== 3. SYSTEM DATA COLLECTION =====
MODEL=$(cat /tmp/sysinfo/model 2>/dev/null || ubus call system board | jsonfilter -e '@.model')
FIRMWARE=$(cat /etc/openwrt_release | grep DISTRIB_DESCRIPTION | cut -d"'" -f2)
KERNEL=$(uname -r)
L_TIME=$(date "+%H:%M:%S")

UP_RAW=$(cat /proc/uptime | awk '{print $1}' | cut -d. -f1)
D=$((UP_RAW/86400)); H=$(((UP_RAW%86400)/3600)); M=$(((UP_RAW%3600)/60))
UP_STR="${D}d ${H}h ${M}m"

CPU=$(top -bn1 | awk '/CPU:/ {print 100-$8}' | head -n1 | cut -d. -f1)
[ -z "$CPU" ] && CPU=0
TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
[ -n "$TEMP" ] && TEMP=$((TEMP/1000)) || TEMP=0

# --- Memory ---
M_TOT=$(grep "^MemTotal:" /proc/meminfo | awk '{print $2}')
M_FRE=$(grep "^MemFree:" /proc/meminfo | awk '{print $2}')
M_BUF=$(grep "^Buffers:" /proc/meminfo | awk '{print $2}')
M_CAC=$(grep "^Cached:" /proc/meminfo | awk '{print $2}')
M_AVA=$(grep "^MemAvailable:" /proc/meminfo | awk '{print $2}')
S_FRE=$(grep "^SwapFree:" /proc/meminfo | awk '{print $2}')
[ -z "$M_AVA" ] && M_AVA=$((M_FRE + M_BUF + M_CAC))
M_USD=$((M_TOT - M_AVA))
M_PER=$((M_USD * 100 / M_TOT))

# --- Storage Detail ---
ROOT_T=$(df / | tail -1 | awk '{print $2}')
ROOT_U=$(df / | tail -1 | awk '{print $3}')
ROOT_P=$((ROOT_U * 100 / ROOT_T))
TEMP_T=$(df /tmp | tail -1 | awk '{print $2}')
TEMP_U=$(df /tmp | tail -1 | awk '{print $3}')
TEMP_P=$((TEMP_U * 100 / TEMP_T))
RUN_T=$(df /run 2>/dev/null | tail -1 | awk '{print $2}')
RUN_U=$(df /run 2>/dev/null | tail -1 | awk '{print $3}')
[ -z "$RUN_T" ] && RUN_T=0 && RUN_U=0
RUN_P=0; [ "$RUN_T" -gt 0 ] && RUN_P=$((RUN_U * 100 / RUN_T))

# --- Traffic ---
IF="wwan0"; [ ! -d /sys/class/net/$IF ] && IF="eth0"
RX=$(cat /sys/class/net/$IF/statistics/rx_bytes 2>/dev/null || echo 0)
TX=$(cat /sys/class/net/$IF/statistics/tx_bytes 2>/dev/null || echo 0)

# --- IPv4 Upstream (Logic Perbaikan Gateway) ---
WAN_INFO=$(ubus call network.interface.wan status 2>/dev/null || ubus call network.interface.wwan status 2>/dev/null)
WAN_IP=$(echo "$WAN_INFO" | jsonfilter -e "@['ipv4-address'][0].address")
WAN_MSK=$(echo "$WAN_INFO" | jsonfilter -e "@['ipv4-address'][0].mask")

# Pencarian Gateway yang lebih kuat
WAN_GW=$(echo "$WAN_INFO" | jsonfilter -e "@['ipv4-address'][0].gateway")
if [ -z "$WAN_GW" ] || [ "$WAN_GW" = "null" ]; then
    WAN_GW=$(ip route show dev $IF | grep default | awk '{print $3}' | head -n1)
    [ -z "$WAN_GW" ] && WAN_GW="-"
fi

WAN_DNS=$(echo "$WAN_INFO" | jsonfilter -e "@['dns-server'][0]")
WAN_MAC=$(cat /sys/class/net/$IF/address 2>/dev/null)

# --- Active Connections ---
CONN_CUR=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo 0)
CONN_MAX=$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo 0)
CONN_PER=0; [ "$CONN_MAX" -gt 0 ] && CONN_PER=$((CONN_CUR * 100 / CONN_MAX))

# ===== 4. JSON CONSTRUCTORS =====
IFS_JSON=""
for i in eth0 wwan0; do
    if [ -d "/sys/class/net/$i" ]; then
        ST=$(cat /sys/class/net/$i/operstate 2>/dev/null)
        RI=$(cat /sys/class/net/$i/statistics/rx_bytes 2>/dev/null || echo 0)
        TI=$(cat /sys/class/net/$i/statistics/tx_bytes 2>/dev/null || echo 0)
        JI="{\"name\":\"$i\",\"state\":\"$ST\",\"rx\":$RI,\"tx\":$TI}"
        [ -z "$IFS_JSON" ] && IFS_JSON="$JI" || IFS_JSON="$IFS_JSON,$JI"
    fi
done

CLIENTS_JSON=""
grep -v '^#' /tmp/dhcp.leases 2>/dev/null | while read line; do
    MAC=$(echo "$line" | awk '{print $2}')
    IP=$(echo "$line" | awk '{print $3}')
    NAME=$(echo "$line" | awk '{print $4}')
    [ "$NAME" = "*" ] && NAME="Unknown"
    IS_B=0; iptables -C FORWARD -s "$IP" -j DROP 2>/dev/null && IS_B=1
    IS_S=0; uci show dhcp | grep -qi "$MAC" && IS_S=1
    CJ="{\"ip\":\"$IP\",\"name\":\"$NAME\",\"mac\":\"$MAC\",\"is_static\":$IS_S,\"is_blocked\":$IS_B}"
    [ -z "$CLIENTS_JSON" ] && CLIENTS_JSON="$CJ" || CLIENTS_JSON="$CLIENTS_JSON,$CJ"
    echo "$CLIENTS_JSON" > /tmp/cl_yacd.json
done
CLIENTS_OUT=$(cat /tmp/cl_yacd.json 2>/dev/null); rm -f /tmp/cl_yacd.json

# ===== 5. FINAL OUTPUT =====
echo "{"
echo "  \"sys\": {\"model\":\"$MODEL\",\"firmware\":\"$FIRMWARE\",\"kernel\":\"$KERNEL\",\"time\":\"$L_TIME\",\"uptime\":\"$UP_STR\"},"
echo "  \"rx\":$RX,"
echo "  \"tx\":$TX,"
echo "  \"cpu\":$CPU,"
echo "  \"temp\":$TEMP,"
echo "  \"memory\":{\"total\":$M_TOT,\"used\":$M_USD,\"buffers\":${M_BUF:-0},\"cached\":${M_CAC:-0},\"swap_free\":${S_FRE:-0},\"percent\":$M_PER},"
echo "  \"storage\":{"
echo "    \"root_t\":$ROOT_T, \"root_u\":$ROOT_U, \"root_p\":$ROOT_P,"
echo "    \"temp_t\":$TEMP_T, \"temp_u\":$TEMP_U, \"temp_p\":$TEMP_P,"
echo "    \"run_t\":$RUN_T, \"run_u\":$RUN_U, \"run_p\":$RUN_P"
echo "  },"
echo "  \"wan\": {"
echo "    \"ip\":\"$WAN_IP/$WAN_MSK\", \"gw\":\"$WAN_GW\", \"dns\":\"$WAN_DNS\", \"mac\":\"$WAN_MAC\", \"iface\":\"$IF\""
echo "  },"
echo "  \"conn\": {\"cur\":$CONN_CUR, \"max\":$CONN_MAX, \"per\":$CONN_PER},"
echo "  \"interfaces\":[$IFS_JSON],"
echo "  \"clients\":[$CLIENTS_OUT]"
echo "}"
