🚀 Monitoring OpenWrt

Monitoring realtime untuk OpenWrt dengan tampilan modern + kontrol client WiFi.

---

📸 Preview

"Monitoring UI" (https://raw.githubusercontent.com/Trusty179/Monitoring-OpenWrt/main/Screenshot_2026-04-02-15-26-35-584_com.android.chrome.png)

---

✨ Fitur

- 📊 Speed Internet realtime (Download & Upload)
- 🖥 Monitoring CPU & Suhu
- 📶 Daftar client WiFi realtime
- 🚫 Block / Unblock client
- ❌ Kick / putus koneksi WiFi client
- 🎨 Tampilan modern (grafik + glow effect)
- ⚡ Ringan & realtime

---

🚀 Install (1 Command)

Copy & jalankan di terminal OpenWrt:

wget -O install.sh https://raw.githubusercontent.com/Trusty179/Monitoring-OpenWrt/main/install.sh && sh install.sh

---

🌐 Akses

Setelah install & reboot:

http://192.168.1.1/luci-static/custom/monitor.html

---

📁 Struktur File

Monitoring-OpenWrt/
├── yacd.sh        # Backend (API monitoring + control client)
├── monitor.html   # Tampilan UI
├── index.js       # Integrasi LuCI
└── install.sh     # Auto installer

---

⚠️ Catatan

- Installer akan:
  
  - Backup file LuCI lama
  - Overwrite "index.js"
  - Restart web server
  - Reboot otomatis setelah 5 detik

- Jika terjadi error, restore:

mv /www/luci-static/resources/view/status/index.js.bak /www/luci-static/resources/view/status/index.js
/etc/init.d/uhttpd restart

---

🔥 Kelebihan

- Tanpa install package tambahan
- Full local (tanpa internet setelah install)
- Mudah deploy ulang (cukup 1 command)
- Cocok untuk semua OpenWrt (terutama REYRE-WRT)

---

😎 Author

Made by Trusty179

---
