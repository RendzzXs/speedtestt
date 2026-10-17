#!/bin/bash
# ============================================
#   🧹 AUTO CLEAN VPS — HAPUS SEMUA WEB LAMA
#   Bebaskan storage & bersihkan konfigurasi
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root! Jalankan pakai sudo.${NC}"; exit 1; }

clear
echo -e "${RED}╔════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  ⚠️  WARNING: AUTO CLEAN VPS               ║${NC}"
echo -e "${RED}║  Ini akan MENGHAPUS SEMUA WEB & DATABASE!  ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Yang akan dihapus:${NC}"
echo "  • Semua folder web di /var/www/ (termasuk backup)"
echo "  • Semua database MySQL (kecuali sistem)"
echo "  • Konfigurasi Nginx (sites-enabled & sites-available)"
echo "  • SSL Certbot (Let's Encrypt)"
echo "  • Log Nginx & Log PHP (bebaskan space)"
echo "  • Cache APT & Cache npm (kalau ada)"
echo "  • File installer /root/*.sh"
echo ""
echo -e "${RED}TINDAKAN INI TIDAK BISA DIBATALKAN!${NC}"
echo ""
read -p "Ketik 'HAPUS' untuk melanjutkan: " CONFIRM

if [[ "$CONFIRM" != "HAPUS" ]]; then
    echo -e "${YELLOW}Dibatalkan.${NC}"
    exit 0
fi

echo ""
echo -e "${CYAN}[1/6] Menghapus folder web di /var/www/...${NC}"
# Hapus semua isi /var/www kecuali html default (kalau ada)
if [ -d "/var/www" ]; then
    find /var/www -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} + 2>/dev/null
    # Hapus juga file installer di /var/www kalau ada
    find /var/www -mindepth 1 -maxdepth 1 -type f -exec rm -f {} + 2>/dev/null
    echo -e "${GREEN}  ✓ /var/www dibersihkan${NC}"
fi

echo -e "${CYAN}[2/6] Menghapus semua database MySQL...${NC}"
if systemctl is-active --quiet mysql; then
    # Dapatkan daftar database, buang yang sistem (information_schema, mysql, performance_schema, sys)
    DBS=$(mysql -u root -N -e "SHOW DATABASES;" 2>/dev/null | grep -Ev "^(information_schema|mysql|performance_schema|sys)$")
    
    if [ -n "$DBS" ]; then
        for DB in $DBS; do
            mysql -u root -e "DROP DATABASE \`$DB\`;" 2>/dev/null
            echo -e "   Drop DB: $DB"
        done
        echo -e "${GREEN}  ✓ Database dihapus${NC}"
    else
        echo -e "   (Tidak ada database user)"
    fi

    # Hapus user MySQL custom (kecuali root)
    USERS=$(mysql -u root -N -e "SELECT user FROM mysql.user WHERE user NOT IN ('root','mysql.sys','mysql.session','mysql.infoschema','debian-sys-maint');" 2>/dev/null)
    if [ -n "$USERS" ]; then
        for USR in $USERS; do
            mysql -u root -e "DROP USER '$USR'@'localhost';" 2>/dev/null
            mysql -u root -e "DROP USER '$USR'@'127.0.0.1';" 2>/dev/null
            mysql -u root -e "DROP USER '$USR'@'%';" 2>/dev/null
            echo -e "   Drop User MySQL: $USR"
        done
        mysql -u root -e "FLUSH PRIVILEGES;" 2>/dev/null
        echo -e "${GREEN}  ✓ User MySQL custom dihapus${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠️ MySQL tidak aktif, skip${NC}"
fi

echo -e "${CYAN}[3/6] Membersihkan konfigurasi Nginx...${NC}"
# Hapus semua sites-enabled
if [ -d "/etc/nginx/sites-enabled" ]; then
    rm -f /etc/nginx/sites-enabled/* 2>/dev/null
fi
# Hapus semua sites-available
if [ -d "/etc/nginx/sites-available" ]; then
    rm -f /etc/nginx/sites-available/* 2>/dev/null
fi
# Hapus conf.d (hati-hati, biasanya default nginx ada di sini, tapi kita hapus yang custom)
rm -f /etc/nginx/conf.d/*.conf 2>/dev/null
echo -e "${GREEN}  ✓ Konfigurasi Nginx dibersihkan${NC}"

echo -e "${CYAN}[4/6] Menghapus sertifikat SSL Certbot...${NC}"
if [ -d "/etc/letsencrypt" ]; then
    apt purge certbot python3-certbot-nginx -y -qq 2>/dev/null
    rm -rf /etc/letsencrypt /var/lib/letsencrypt 2>/dev/null
    echo -e "${GREEN}  ✓ SSL Certbot dihapus${NC}"
else
    echo -e "   (SSL Certbot tidak terinstall)"
fi

echo -e "${CYAN}[5/6] Membersihkan log & cache...${NC}"
# Log Nginx
rm -f /var/log/nginx/*.log 2>/dev/null
rm -f /var/log/nginx/*.log.* 2>/dev/null
# Log PHP
rm -f /var/log/php*.log 2>/dev/null
rm -f /var/log/php*-fpm.log 2>/dev/null
# Log general
rm -f /var/log/*.gz 2>/dev/null

# Cache APT
apt clean -y 2>/dev/null
apt autoclean -y 2>/dev/null
apt autoremove -y 2>/dev/null

# Cache npm (kalau ada)
if command -v npm >/dev/null 2>&1; then
    npm cache clean --force 2>/dev/null
fi

echo -e "${GREEN}  ✓ Log & cache dibersihkan${NC}"

echo -e "${CYAN}[6/6] Menghapus file installer di /root/...${NC}"
# Hapus semua file .sh di /root dan /home (kecuali script ini sendiri)
find /root -maxdepth 1 -name "*.sh" -exec rm -f {} + 2>/dev/null
if [ -d "/home" ]; then
    find /home -maxdepth 2 -name "*.sh" -exec rm -f {} + 2>/dev/null
fi
echo -e "${GREEN}  ✓ File installer dibersihkan${NC}"

# ============ RESTART SERVICES ============
echo -e "\n${CYAN}🔄 Restart services...${NC}"
if systemctl is-active --quiet nginx; then
    nginx -t >/dev/null 2>&1 && systemctl reload nginx 2>/dev/null
    echo -e "  ✓ Nginx reloaded"
fi
if systemctl is-active --quiet php8.3-fpm; then
    systemctl restart php8.3-fpm 2>/dev/null
    echo -e "  ✓ PHP-FPM restarted"
fi

# ============ CEK SISA SPACE ============
clear
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ PEMBERSIHAN SELESAI!                   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}💾 Storage VPS Saat Ini:${NC}"
df -h / | tail -n 1 | awk '{print "  Total: " $2 "  |  Used: " $3 "  |  Free: " $4 "  |  Use%: " $5}'
echo ""
echo -e "${YELLOW}💡 Sisa folder di /var/www:${NC}"
ls -la /var/www/ 2>/dev/null || echo "  (Kosong)"
echo ""
echo -e "${YELLOW}💡 Database yang tersisa:${NC}"
mysql -u root -N -e "SHOW DATABASES;" 2>/dev/null | awk '{print "  - " $1}'
echo ""
echo -e "${GREEN}✅ VPS kamu sekarang lebih lega!${NC}"
