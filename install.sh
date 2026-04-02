#!/bin/sh

echo "🔥 INSTALL MONITORING OPENWRT"

# ===== BACKUP LUCI (AMAN) =====
if [ -f /www/luci-static/resources/view/status/index.js ]; then
    cp /www/luci-static/resources/view/status/index.js /www/luci-static/resources/view/status/index.js.bak
    echo "✔ Backup index.js"
fi

# ===== DOWNLOAD BACKEND =====
wget -O /www/cgi-bin/yacd.sh https://raw.githubusercontent.com/Trusty179/Monitoring-OpenWrt/main/yacd.sh
chmod +x /www/cgi-bin/yacd.sh
echo "✔ yacd.sh installed"

# ===== DOWNLOAD FRONTEND =====
mkdir -p /www/luci-static/custom
wget -O /www/luci-static/custom/monitor.html https://raw.githubusercontent.com/Trusty179/Monitoring-OpenWrt/main/monitor.html
echo "✔ monitor.html installed"

# ===== DOWNLOAD LUCI JS =====
wget -O /www/luci-static/resources/view/status/index.js https://raw.githubusercontent.com/Trusty179/Monitoring-OpenWrt/main/index.js
echo "✔ index.js installed (overwrite)"

# ===== CLEAR CACHE =====
rm -rf /tmp/luci-*

# ===== RESTART WEB =====
/etc/init.d/uhttpd restart

echo ""
echo "✅ INSTALL SELESAI"
echo "🌐 http://192.168.1.1/luci-static/custom/monitor.html"
echo ""

# ===== COUNTDOWN REBOOT =====
echo "⚠️ Reboot dalam 5 detik..."
for i in 5 4 3 2 1
do
    echo "Reboot dalam $i..."
    sleep 1
done

echo "🔄 Reboot sekarang..."
reboot
