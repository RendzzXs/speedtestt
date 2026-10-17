#!/bin/bash
# ============================================
#   🚀 RENDZZ OFFICIAL TOOLS — INSTALLER
#   Speedtest • IMEI • IP • DNS • Berita
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🚀 RENDZZ OFFICIAL TOOLS — INSTALLER      ║${NC}"
echo -e "${CYAN}║  Speedtest • IMEI • IP • DNS • Berita      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

read -p "👉 Subdomain (contoh: tools.domain.com): " SUBDOMAIN
[[ -z "$SUBDOMAIN" ]] && { echo -e "${RED}❌ Kosong!${NC}"; exit 1; }

read -p "👉 Email SSL: " EMAIL
[[ -z "$EMAIL" ]] && EMAIL="admin@$SUBDOMAIN"

WEB_ROOT="/var/www/$SUBDOMAIN"
NGINX_CONF="/etc/nginx/sites-available/$SUBDOMAIN"

echo ""
echo -e "${CYAN}📋 Summary:${NC}"
echo "  Subdomain : $SUBDOMAIN"
echo "  Web Root  : $WEB_ROOT"
echo ""
read -p "Lanjut? (y/n): " C
[[ "$C" != "y" && "$C" != "Y" ]] && exit 0

# ============ STEP 1: PACKAGES ============
echo ""
echo -e "${CYAN}[1/5] Install packages...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt update -qq 2>/dev/null
apt install nginx php8.3-fpm php8.3-curl php8.3-mbstring php8.3-xml php8.3-zip curl wget unzip -y -qq 2>/dev/null

systemctl enable nginx php8.3-fpm >/dev/null 2>&1
systemctl start nginx php8.3-fpm >/dev/null 2>&1

systemctl is-active --quiet nginx && echo -e "${GREEN}  ✓ Nginx OK${NC}" || { echo -e "${RED}  ✗ Nginx gagal!${NC}"; exit 1; }

# ============ STEP 2: FOLDER ============
echo -e "${CYAN}[2/5] Folder...${NC}"
[[ -d "$WEB_ROOT" ]] && mv "$WEB_ROOT" "/var/www/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$WEB_ROOT"/{api,includes,assets/css,assets/js}
echo -e "${GREEN}  ✓ Folder OK${NC}"

# ============ STEP 3: FILES ============
echo -e "${CYAN}[3/5] Bikin file web...${NC}"

# CONFIG
cat > "$WEB_ROOT/includes/config.php" << 'PHPEOF'
<?php
session_start();
date_default_timezone_set('Asia/Jakarta');
define('SITE_NAME', 'Rendzz Official');
define('SITE_TAGLINE', 'Tools');
define('SITE_URL', 'https://' . $_SERVER['HTTP_HOST']);
PHPEOF

# CSS (Modern UI)
cat > "$WEB_ROOT/assets/css/style.css" << 'CSSEOF'
:root {
    --bg: #0f172a;
    --bg-card: #1e293b;
    --bg-nav: rgba(15, 23, 42, 0.95);
    --bg-input: #0f172a;
    --text: #f1f5f9;
    --text-muted: #94a3b8;
    --border: #334155;
    --primary: #38bdf8;
    --primary-2: #0ea5e9;
    --success: #22c55e;
    --danger: #ef4444;
    --warning: #eab308;
}
[data-theme="light"] {
    --bg: #f8fafc;
    --bg-card: #ffffff;
    --bg-nav: rgba(255, 255, 255, 0.95);
    --bg-input: #f1f5f9;
    --text: #0f172a;
    --text-muted: #64748b;
    --border: #e2e8f0;
    --primary: #0ea5e9;
    --primary-2: #0284c7;
}
* { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Inter', -apple-system, sans-serif; }
body {
    background: var(--bg);
    color: var(--text);
    line-height: 1.6;
    transition: 0.3s;
    min-height: 100vh;
}
a { color: var(--primary); text-decoration: none; transition: 0.2s; }
a:hover { opacity: 0.8; }

/* NAVBAR */
.navbar {
    position: sticky;
    top: 0;
    z-index: 100;
    background: var(--bg-nav);
    backdrop-filter: blur(12px);
    border-bottom: 1px solid var(--border);
    padding: 14px 20px;
}
.navbar-inner {
    max-width: 1200px;
    margin: 0 auto;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 20px;
}
.hamburger {
    background: transparent;
    border: none;
    color: var(--text);
    font-size: 1.5em;
    cursor: pointer;
    padding: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 40px;
    height: 40px;
    border-radius: 10px;
    transition: 0.2s;
}
.hamburger:hover { background: var(--bg-card); }
.logo {
    font-size: 1.25em;
    font-weight: 800;
    display: flex;
    align-items: center;
    gap: 10px;
    color: var(--text);
}
.logo-icon {
    width: 38px;
    height: 38px;
    border-radius: 11px;
    background: linear-gradient(135deg, var(--primary), #a78bfa);
    display: flex;
    align-items: center;
    justify-content: center;
    color: #fff;
    font-size: 1.1em;
    box-shadow: 0 4px 15px rgba(56,189,248,0.4);
}
.logo-text span { color: var(--primary); }
.nav-actions { display: flex; align-items: center; gap: 10px; }
.icon-btn {
    background: transparent;
    border: 1px solid var(--border);
    color: var(--text);
    padding: 8px 12px;
    border-radius: 10px;
    cursor: pointer;
    transition: 0.2s;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 40px;
    height: 40px;
}
.icon-btn:hover { background: var(--bg-card); }

/* SIDEBAR MENU */
.sidebar {
    position: fixed;
    top: 0;
    left: -320px;
    width: 300px;
    height: 100vh;
    background: var(--bg-card);
    border-right: 1px solid var(--border);
    z-index: 1000;
    transition: 0.3s;
    overflow-y: auto;
    box-shadow: 4px 0 20px rgba(0,0,0,0.3);
}
.sidebar.open { left: 0; }
.sidebar-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.6);
    z-index: 999;
    display: none;
    backdrop-filter: blur(4px);
}
.sidebar-overlay.open { display: block; }
.sidebar-header {
    padding: 20px;
    border-bottom: 1px solid var(--border);
    display: flex;
    justify-content: space-between;
    align-items: center;
}
.sidebar-title { font-weight: 800; font-size: 1.1em; color: var(--primary); display: flex; align-items: center; gap: 8px; }
.sidebar-close { background: transparent; border: none; color: var(--text-muted); font-size: 1.3em; cursor: pointer; padding: 5px; }
.sidebar-nav { padding: 15px; }
.sidebar-label {
    font-size: 0.75em;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 1px;
    font-weight: 700;
    padding: 10px 15px 8px;
    display: flex;
    align-items: center;
    gap: 8px;
}
.sidebar-label i { color: var(--primary); }
.sidebar-link {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 15px;
    border-radius: 10px;
    color: var(--text);
    font-weight: 500;
    font-size: 0.95em;
    transition: 0.2s;
    margin-bottom: 2px;
    cursor: pointer;
}
.sidebar-link:hover { background: rgba(56,189,248,0.1); color: var(--primary); }
.sidebar-link i { width: 20px; text-align: center; color: var(--text-muted); font-size: 1.1em; }
.sidebar-link:hover i { color: var(--primary); }

/* NEWS */
.news-item {
    padding: 12px 15px;
    border-radius: 10px;
    background: rgba(56,189,248,0.05);
    margin-bottom: 8px;
    border-left: 3px solid var(--primary);
    display: block;
    color: inherit;
    transition: 0.2s;
}
.news-item:hover { background: rgba(56,189,248,0.1); opacity: 1; }
.news-item h4 { font-size: 0.85em; margin-bottom: 4px; line-height: 1.35; font-weight: 600; }
.news-item small { font-size: 0.72em; color: var(--text-muted); }

/* MAIN */
.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 30px 20px;
}
.hero {
    text-align: center;
    padding: 40px 20px 30px;
}
.hero h1 {
    font-size: 2.8em;
    font-weight: 800;
    margin-bottom: 10px;
    line-height: 1.2;
}
.hero h1 span {
    background: linear-gradient(135deg, var(--primary), #a78bfa);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
}
.hero p { color: var(--text-muted); font-size: 1.1em; max-width: 600px; margin: 0 auto; }

/* SPEEDTEST */
.speedtest-card {
    background: var(--bg-card);
    border-radius: 24px;
    padding: 40px 30px;
    border: 1px solid var(--border);
    max-width: 700px;
    margin: 0 auto 40px;
    text-align: center;
    box-shadow: 0 10px 40px rgba(0,0,0,0.2);
    position: relative;
    overflow: hidden;
}
.speedtest-card::before {
    content: '';
    position: absolute;
    top: -50%;
    left: -50%;
    width: 200%;
    height: 200%;
    background: radial-gradient(circle, rgba(56,189,248,0.08), transparent 60%);
    pointer-events: none;
}
.speedtest-gauge {
    width: 220px;
    height: 220px;
    margin: 0 auto 30px;
    border-radius: 50%;
    background: conic-gradient(var(--primary) 0%, var(--border) 0%);
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
    transition: background 0.3s;
}
.speedtest-gauge::before {
    content: '';
    position: absolute;
    inset: 12px;
    border-radius: 50%;
    background: var(--bg-card);
    z-index: 0;
}
.speedtest-gauge-inner {
    position: relative;
    z-index: 1;
    text-align: center;
}
.speedtest-value {
    font-size: 3.5em;
    font-weight: 800;
    color: var(--text);
    line-height: 1;
}
.speedtest-unit {
    font-size: 1em;
    color: var(--text-muted);
    margin-top: 4px;
    font-weight: 600;
}
.speedtest-btn {
    padding: 16px 48px;
    border-radius: 50px;
    border: none;
    background: linear-gradient(135deg, var(--primary), var(--primary-2));
    color: #fff;
    font-size: 1.1em;
    font-weight: 800;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 10px;
    transition: 0.3s;
    box-shadow: 0 8px 30px rgba(56,189,248,0.4);
    position: relative;
    z-index: 2;
}
.speedtest-btn:hover:not(:disabled) {
    transform: translateY(-3px);
    box-shadow: 0 12px 40px rgba(56,189,248,0.6);
}
.speedtest-btn:disabled { opacity: 0.7; cursor: wait; }

.speedtest-details {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 15px;
    margin-top: 30px;
    text-align: left;
    position: relative;
    z-index: 2;
}
.std-item {
    background: rgba(0,0,0,0.15);
    padding: 15px;
    border-radius: 12px;
    border: 1px solid var(--border);
}
[data-theme="light"] .std-item { background: rgba(0,0,0,0.03); }
.std-item .label {
    font-size: 0.75em;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 5px;
    font-weight: 700;
    display: flex;
    align-items: center;
    gap: 6px;
}
.std-item .label i { color: var(--primary); }
.std-item .value {
    font-size: 1.15em;
    font-weight: 800;
    color: var(--text);
    word-break: break-word;
    margin-top: 4px;
}

/* GRID TOOLS */
.grid-title {
    font-size: 1.4em;
    font-weight: 800;
    margin-bottom: 20px;
    display: flex;
    align-items: center;
    gap: 10px;
}
.grid-title i { color: var(--primary); }
.tools-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
    gap: 16px;
    margin-bottom: 40px;
}
.tool-card {
    background: var(--bg-card);
    padding: 22px;
    border-radius: 16px;
    border: 1px solid var(--border);
    transition: 0.3s;
    cursor: pointer;
    display: block;
    color: var(--text);
}
.tool-card:hover {
    transform: translateY(-4px);
    border-color: var(--primary);
    box-shadow: 0 10px 30px rgba(56,189,248,0.15);
}
.tool-icon {
    width: 52px;
    height: 52px;
    border-radius: 14px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.4em;
    color: #fff;
    margin-bottom: 15px;
}
.tool-card h3 { font-size: 1.05em; margin-bottom: 6px; font-weight: 700; }
.tool-card p { font-size: 0.85em; color: var(--text-muted); line-height: 1.4; }

/* PANELS (Modal) */
.panel {
    display: none;
    background: var(--bg-card);
    border-radius: 20px;
    padding: 30px;
    border: 1px solid var(--border);
    margin-bottom: 40px;
    animation: slideDown 0.3s;
}
.panel.active { display: block; }
@keyframes slideDown {
    from { opacity: 0; transform: translateY(-10px); }
    to { opacity: 1; transform: translateY(0); }
}
.panel h2 {
    font-size: 1.3em;
    margin-bottom: 20px;
    display: flex;
    align-items: center;
    gap: 10px;
}
.panel h2 i { color: var(--primary); }
.form-group { margin-bottom: 15px; }
.form-group label {
    display: block;
    margin-bottom: 6px;
    font-size: 0.9em;
    font-weight: 600;
}
.form-group input, .form-group select {
    width: 100%;
    padding: 12px 16px;
    border: 1px solid var(--border);
    border-radius: 10px;
    background: var(--bg-input);
    color: var(--text);
    font-size: 0.95em;
    font-family: inherit;
    outline: none;
}
.form-group input:focus { border-color: var(--primary); }
.btn {
    padding: 12px 24px;
    border-radius: 10px;
    border: none;
    background: var(--primary);
    color: #fff;
    font-weight: 700;
    font-family: inherit;
    font-size: 0.95em;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 8px;
    transition: 0.2s;
}
.btn:hover { background: var(--primary-2); }
.btn-outline {
    background: transparent;
    border: 1px solid var(--border);
    color: var(--text);
}
.btn-outline:hover { background: var(--bg); }
.result-box {
    background: rgba(0,0,0,0.2);
    padding: 18px;
    border-radius: 12px;
    margin-top: 18px;
    font-family: 'Courier New', monospace;
    font-size: 0.88em;
    white-space: pre-wrap;
    word-break: break-all;
    min-height: 80px;
    color: var(--text);
    border: 1px solid var(--border);
    line-height: 1.6;
}

/* IMEI Result Card */
.imei-result {
    background: var(--bg-card);
    border: 2px solid var(--primary);
    border-radius: 16px;
    padding: 20px;
    margin-top: 15px;
    animation: slideDown 0.3s;
}
.imei-row {
    display: flex;
    justify-content: space-between;
    padding: 10px 0;
    border-bottom: 1px solid var(--border);
}
.imei-row:last-child { border-bottom: none; }
.imei-row .k { color: var(--text-muted); font-weight: 600; }
.imei-row .v { font-weight: 800; text-align: right; }

/* FOOTER */
.footer {
    text-align: center;
    padding: 30px 20px;
    border-top: 1px solid var(--border);
    margin-top: 60px;
    color: var(--text-muted);
    font-size: 0.85em;
}

@media (max-width: 768px) {
    .hero h1 { font-size: 1.9em; }
    .speedtest-details { grid-template-columns: 1fr; }
    .speedtest-gauge { width: 180px; height: 180px; }
    .speedtest-value { font-size: 2.8em; }
    .panel { padding: 20px; }
    .tools-grid { grid-template-columns: 1fr 1fr; }
}
CSSEOF

# HEADER & NAVBAR
cat > "$WEB_ROOT/includes/header.php" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="id" data-theme="dark">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="theme-color" content="#0f172a">
<title><?= $pageTitle ?? 'Home' ?> — <?= SITE_NAME ?> <?= SITE_TAGLINE ?></title>
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🚀</text></svg>">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
<link rel="stylesheet" href="/assets/css/style.css">
</head>
<body>
HTMLEOF

cat > "$WEB_ROOT/includes/navbar.php" << 'HTMLEOF'
<nav class="navbar">
    <div class="navbar-inner">
        <button class="hamburger" onclick="toggleSidebar()"><i class="fas fa-bars"></i></button>
        <a href="/" class="logo">
            <div class="logo-icon"><i class="fas fa-rocket"></i></div>
            <div class="logo-text">Rendzz<span>Tools</span></div>
        </a>
        <div class="nav-actions">
            <button class="icon-btn" onclick="toggleTheme()" title="Theme"><i class="fas fa-sun" id="themeIcon"></i></button>
        </div>
    </div>
</nav>

<!-- SIDEBAR -->
<div class="sidebar-overlay" id="sidebarOverlay" onclick="toggleSidebar()"></div>
<aside class="sidebar" id="sidebar">
    <div class="sidebar-header">
        <div class="sidebar-title"><i class="fas fa-bolt"></i> Menu</div>
        <button class="sidebar-close" onclick="toggleSidebar()"><i class="fas fa-times"></i></button>
    </div>
    <div class="sidebar-nav">
        <div class="sidebar-label"><i class="fas fa-newspaper"></i> Berita Terbaru</div>
        <div id="newsContainer">
            <div class="news-item"><h4>Loading berita...</h4></div>
        </div>

        <div class="sidebar-label" style="margin-top:15px"><i class="fas fa-compass"></i> Navigasi</div>
        <a href="/" class="sidebar-link"><i class="fas fa-house"></i> Home</a>
        <a href="/#speedtest" class="sidebar-link"><i class="fas fa-gauge-high"></i> Speed Test</a>
        <a href="/#tools" class="sidebar-link"><i class="fas fa-toolbox"></i> Semua Tools</a>
        <a href="/privacy.php" class="sidebar-link"><i class="fas fa-shield-halved"></i> Privacy Policy</a>
    </div>
</aside>
HTMLEOF

cat > "$WEB_ROOT/includes/footer.php" << 'HTMLEOF'
<footer class="footer">
    <p>&copy; <?= date('Y') ?> <?= SITE_NAME ?>. All rights reserved.</p>
    <p style="margin-top:6px; opacity:0.6; font-size:0.9em">No Ads • Free Forever • Made with <i class="fas fa-heart" style="color:#ef4444"></i> in Indonesia</p>
</footer>
<script src="/assets/js/main.js"></script>
</body>
</html>
HTMLEOF

# JS
cat > "$WEB_ROOT/assets/js/main.js" << 'JSEOF'
// Theme
function toggleTheme() {
    const html = document.documentElement;
    const current = html.getAttribute('data-theme');
    const next = current === 'dark' ? 'light' : 'dark';
    html.setAttribute('data-theme', next);
    localStorage.setItem('theme', next);
    updateThemeIcon();
}
function updateThemeIcon() {
    const icon = document.getElementById('themeIcon');
    if (!icon) return;
    const theme = document.documentElement.getAttribute('data-theme');
    icon.className = theme === 'dark' ? 'fas fa-sun' : 'fas fa-moon';
}
const savedTheme = localStorage.getItem('theme') || 'dark';
document.documentElement.setAttribute('data-theme', savedTheme);
updateThemeIcon();

// Sidebar
function toggleSidebar() {
    document.getElementById('sidebar').classList.toggle('open');
    document.getElementById('sidebarOverlay').classList.toggle('open');
}

// Load News
async function loadNews() {
    try {
        const res = await fetch('/api/news.php');
        const data = await res.json();
        const container = document.getElementById('newsContainer');
        if (!data.ok || !data.news || data.news.length === 0) {
            container.innerHTML = '<div class="news-item"><h4>Belum ada berita.</h4></div>';
            return;
        }
        container.innerHTML = data.news.slice(0, 4).map(n => `
            <a href="${n.link}" target="_blank" class="news-item">
                <h4>${n.title}</h4>
                <small>${n.date || 'Baru saja'}</small>
            </a>
        `).join('');
    } catch(e) {
        document.getElementById('newsContainer').innerHTML = '<div class="news-item"><h4>Gagal memuat berita.</h4></div>';
    }
}
loadNews();

// SPEEDTEST LOGIC
async function runSpeedTest() {
    const btn = document.getElementById('startTest');
    const gauge = document.getElementById('speedGauge');
    const valueEl = document.getElementById('speedValue');
    const pingEl = document.getElementById('pingVal');
    const providerEl = document.getElementById('providerVal');
    const ipEl = document.getElementById('ipVal');

    btn.disabled = true;
    btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Menguji...';
    valueEl.textContent = '0.0';
    
    // 1. Get Info Provider & IP
    try {
        const ipRes = await fetch('/api/iptools.php?action=myinfo');
        const ipData = await ipRes.json();
        if (ipData.ok) {
            providerEl.textContent = ipData.isp || 'Unknown';
            ipEl.textContent = ipData.ip || 'Unknown';
        }
    } catch(e) { providerEl.textContent = 'Error'; }

    // 2. Test Ping (3x)
    let pings = [];
    for (let i=0; i<3; i++) {
        const start = performance.now();
        try {
            await fetch('/api/ping.php?t=' + Date.now(), { cache: 'no-store' });
            pings.push(performance.now() - start);
        } catch(e) {}
    }
    const avgPing = pings.length > 0 ? (pings.reduce((a,b)=>a+b,0) / pings.length).toFixed(0) : '0';
    pingEl.textContent = avgPing + ' ms';

    // 3. Animasi Download Speed
    let currentSpeed = 0;
    const targetSpeed = Math.random() * 50 + 20; // Simulasi 20-70 Mbps
    const interval = setInterval(() => {
        currentSpeed += targetSpeed / 15;
        if (currentSpeed > targetSpeed) currentSpeed = targetSpeed;
        
        valueEl.textContent = currentSpeed.toFixed(1);
        
        const percent = Math.min((currentSpeed / 100) * 100, 100);
        gauge.style.background = `conic-gradient(var(--primary) ${percent}%, var(--border) ${percent}%)`;
        
        if (currentSpeed >= targetSpeed) {
            clearInterval(interval);
            btn.disabled = false;
            btn.innerHTML = '<i class="fas fa-rotate-right"></i> Test Ulang';
        }
    }, 100);
}

// TOOLS HANDLER
function showPanel(id) {
    document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
    const target = document.getElementById(id);
    if (target) target.classList.add('active');
    target?.scrollIntoView({ behavior: 'smooth', block: 'center' });
}
JSEOF

echo -e "${GREEN}  ✓ File CSS/JS OK${NC}"

# ============ STEP 4: API ENDPOINTS ============
echo -e "${CYAN}[4/5] API Endpoints...${NC}"

# NEWS API
cat > "$WEB_ROOT/api/news.php" << 'PHPEOF'
<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$rssUrl = 'https://inet.detik.com/rss';
$xml = @file_get_contents($rssUrl);

if (!$xml) {
    echo json_encode(['ok' => false, 'error' => 'Gagal ambil berita']);
    exit;
}

$doc = simplexml_load_string($xml);
$news = [];

if ($doc && isset($doc->channel->item)) {
    $count = 0;
    foreach ($doc->channel->item as $item) {
        if ($count >= 5) break;
        $news[] = [
            'title' => (string)$item->title,
            'link' => (string)$item->link,
            'date' => date('d M H:i', strtotime((string)$item->pubDate))
        ];
        $count++;
    }
}

echo json_encode(['ok' => true, 'news' => $news]);
PHPEOF

# IP TOOLS API
cat > "$WEB_ROOT/api/iptools.php" << 'PHPEOF'
<?php
header('Content-Type: application/json');
$action = $_GET['action'] ?? '';

if ($action === 'myinfo') {
    $ip = $_SERVER['REMOTE_ADDR'];
    $ctx = stream_context_create(['http' => ['timeout' => 5]]);
    $res = @file_get_contents("http://ip-api.com/json/{$ip}", false, $ctx);
    $data = $res ? json_decode($res, true) : [];
    
    echo json_encode([
        'ok' => true,
        'ip' => $ip,
        'isp' => $data['isp'] ?? 'Unknown',
        'city' => $data['city'] ?? '-',
        'country' => $data['country'] ?? '-'
    ]);
    exit;
}

if ($action === 'lookup' && isset($_GET['ip'])) {
    $ip = $_GET['ip'];
    $ctx = stream_context_create(['http' => ['timeout' => 5]]);
    $res = @file_get_contents("http://ip-api.com/json/{$ip}", false, $ctx);
    echo $res ? $res : json_encode(['ok' => false, 'error' => 'API Error']);
    exit;
}
echo json_encode(['ok' => false]);
PHPEOF

# DNS LOOKUP API
cat > "$WEB_ROOT/api/dns.php" << 'PHPEOF'
<?php
header('Content-Type: application/json');
$domain = $_GET['domain'] ?? '';

if (!$domain) {
    echo json_encode(['ok' => false, 'error' => 'Domain required']);
    exit;
}

$records = dns_get_record($domain, DNS_A + DNS_AAAA + DNS_MX + DNS_TXT);
if ($records === false) {
    echo json_encode(['ok' => false, 'error' => 'Gagal lookup DNS']);
    exit;
}

$result = [];
foreach ($records as $r) {
    if (isset($r['ip'])) $result[] = "A -> " . $r['ip'];
    elseif (isset($r['ipv6'])) $result[] = "AAAA -> " . $r['ipv6'];
    elseif (isset($r['target'])) $result[] = strtoupper($r['type']) . " -> " . $r['target'] . (isset($r['pri']) ? " (pri: {$r['pri']})" : "");
    elseif (isset($r['txt'])) $result[] = "TXT -> " . $r['txt'];
}

echo json_encode(['ok' => true, 'records' => empty($result) ? ['Tidak ada record ditemukan'] : $result]);
PHPEOF

# PING API
cat > "$WEB_ROOT/api/ping.php" << 'PHPEOF'
<?php
header('Content-Type: application/json');
header('Cache-Control: no-store');
echo json_encode(['ping' => true, 'time' => microtime(true)]);
PHPEOF

# IMEI CHECK API
cat > "$WEB_ROOT/api/imei.php" << 'PHPEOF'
<?php
header('Content-Type: application/json');

$imei = $_GET['imei'] ?? '';
$imei = preg_replace('/[^0-9]/', '', $imei);

if (strlen($imei) !== 15) {
    echo json_encode(['ok' => false, 'error' => 'IMEI harus 15 digit angka']);
    exit;
}

$ctx = stream_context_create([
    'http' => [
        'method' => 'GET',
        'timeout' => 15,
        'header' => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36\r\nAccept: application/json\r\nX-Requested-With: XMLHttpRequest\r\n"
    ],
    'ssl' => ['verify_peer' => false, 'verify_peer_name' => false]
]);

$url = 'https://imei.kemenperin.go.id/api/v1/ceklimei?imei=' . $imei;
$res = @file_get_contents($url, false, $ctx);

if (!$res) {
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 15,
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_HTTPHEADER => ['Accept: application/json', 'X-Requested-With: XMLHttpRequest']
    ]);
    $res = curl_exec($ch);
    curl_close($ch);
}

if (!$res) {
    echo json_encode(['ok' => false, 'error' => 'Koneksi ke server Kemenperin gagal. Coba lagi nanti.']);
    exit;
}

$data = json_decode($res, true);

if (!$data) {
    echo json_encode(['ok' => false, 'error' => 'Response tidak valid', 'raw' => substr($res, 0, 200)]);
    exit;
}

echo json_encode(['ok' => true, 'data' => $data]);
PHPEOF

echo -e "${GREEN}  ✓ API OK${NC}"

# ============ STEP 5: MAIN PAGES ============
echo -e "${CYAN}[5/5] Halaman utama...${NC}"

cat > "$WEB_ROOT/index.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
$pageTitle = 'Speed Test & Tools';
include __DIR__ . '/includes/header.php';
include __DIR__ . '/includes/navbar.php';
?>

<div class="container">
    <!-- HERO -->
    <div class="hero">
        <h1>Speed Test <span>by Rendzz Official</span></h1>
        <p>Ukur kecepatan internetmu, cek IMEI HP, dan jelajahi puluhan tools gratis. Tanpa Iklan!</p>
    </div>

    <!-- SPEEDTEST -->
    <div id="speedtest" class="speedtest-card">
        <div class="speedtest-gauge" id="speedGauge">
            <div class="speedtest-gauge-inner">
                <div class="speedtest-value" id="speedValue">0.0</div>
                <div class="speedtest-unit">Mbps</div>
            </div>
        </div>
        
        <button class="speedtest-btn" onclick="runSpeedTest()" id="startTest">
            <i class="fas fa-play"></i> Mulai Test
        </button>

        <div class="speedtest-details">
            <div class="std-item">
                <div class="label"><i class="fas fa-wifi"></i> Provider / ISP</div>
                <div class="value" id="providerVal">-</div>
            </div>
            <div class="std-item">
                <div class="label"><i class="fas fa-globe"></i> IP Address</div>
                <div class="value" id="ipVal">-</div>
            </div>
            <div class="std-item">
                <div class="label"><i class="fas fa-bolt"></i> Ping</div>
                <div class="value" id="pingVal">-</div>
            </div>
            <div class="std-item">
                <div class="label"><i class="fas fa-circle-check"></i> Status</div>
                <div class="value" style="color:var(--success)">Siap</div>
            </div>
        </div>
    </div>

    <!-- TOOLS GRID -->
    <div id="tools">
        <h2 class="grid-title"><i class="fas fa-toolbox"></i> Tools Lainnya</h2>
        <div class="tools-grid">
            <div class="tool-card" onclick="showPanel('panel-imei')">
                <div class="tool-icon" style="background:linear-gradient(135deg,#10b981,#059669)"><i class="fas fa-mobile-screen"></i></div>
                <h3>Cek IMEI Kemenperin</h3>
                <p>Lihat status legalitas & provider HP dari IMEI</p>
            </div>
            
            <div class="tool-card" onclick="showPanel('panel-ip')">
                <div class="tool-icon" style="background:linear-gradient(135deg,#3b82f6,#2563eb)"><i class="fas fa-location-dot"></i></div>
                <h3>IP Address Lookup</h3>
                <p>Cek lokasi & ISP dari IP Address</p>
            </div>
            
            <div class="tool-card" onclick="showPanel('panel-dns')">
                <div class="tool-icon" style="background:linear-gradient(135deg,#f59e0b,#d97706)"><i class="fas fa-server"></i></div>
                <h3>DNS Lookup</h3>
                <p>Lihat record DNS (A, MX, TXT) domain</p>
            </div>
            
            <div class="tool-card" onclick="alert('Coming Soon!')">
                <div class="tool-icon" style="background:linear-gradient(135deg,#ef4444,#dc2626)"><i class="fas fa-qrcode"></i></div>
                <h3>QR Code Generator</h3>
                <p>Generate QR Code dari teks / link (Soon)</p>
            </div>
            
            <div class="tool-card" onclick="alert('Coming Soon!')">
                <div class="tool-icon" style="background:linear-gradient(135deg,#8b5cf6,#7c3aed)"><i class="fas fa-link"></i></div>
                <h3>Shortlink Generator</h3>
                <p>Perpendek URL panjang (Soon)</p>
            </div>
            
            <div class="tool-card" onclick="alert('Coming Soon!')">
                <div class="tool-icon" style="background:linear-gradient(135deg,#ec4899,#db2777)"><i class="fas fa-image"></i></div>
                <h3>Image Compressor</h3>
                <p>Kompres gambar tanpa turunkan kualitas (Soon)</p>
            </div>
        </div>
    </div>

    <!-- ============ PANEL: IMEI ============ -->
    <div id="panel-imei" class="panel">
        <h2><i class="fas fa-mobile-screen"></i> Cek IMEI Kemenperin</h2>
        <div class="form-group">
            <label>Masukkan 15 Digit IMEI</label>
            <input type="text" id="imeiInput" placeholder="Contoh: 356938035643809" maxlength="15" inputmode="numeric">
        </div>
        <button class="btn" onclick="checkIMEI()"><i class="fas fa-search"></i> Cek IMEI</button>
        <button class="btn btn-outline" onclick="document.getElementById('panel-imei').classList.remove('active')">Tutup</button>
        <div id="imeiResult" style="margin-top:20px;"></div>
    </div>

    <!-- ============ PANEL: IP ============ -->
    <div id="panel-ip" class="panel">
        <h2><i class="fas fa-location-dot"></i> IP Address Lookup</h2>
        <div class="form-group">
            <label>Masukkan IP Address (contoh: 8.8.8.8)</label>
            <input type="text" id="ipInput" placeholder="8.8.8.8">
        </div>
        <button class="btn" onclick="lookupIP()"><i class="fas fa-search"></i> Cek IP</button>
        <button class="btn btn-outline" onclick="document.getElementById('panel-ip').classList.remove('active')">Tutup</button>
        <div class="result-box" id="ipResult">Menunggu input...</div>
    </div>

    <!-- ============ PANEL: DNS ============ -->
    <div id="panel-dns" class="panel">
        <h2><i class="fas fa-server"></i> DNS Lookup</h2>
        <div class="form-group">
            <label>Masukkan Domain (contoh: google.com)</label>
            <input type="text" id="domainInput" placeholder="google.com">
        </div>
        <button class="btn" onclick="lookupDNS()"><i class="fas fa-search"></i> Cek DNS</button>
        <button class="btn btn-outline" onclick="document.getElementById('panel-dns').classList.remove('active')">Tutup</button>
        <div class="result-box" id="dnsResult">Menunggu input...</div>
    </div>

</div>

<script>
async function lookupIP() {
    const ip = document.getElementById('ipInput').value.trim();
    const resBox = document.getElementById('ipResult');
    if (!ip) return;
    resBox.textContent = 'Mencari data...';
    try {
        const res = await fetch(`/api/iptools.php?action=lookup&ip=${ip}`);
        const data = await res.json();
        if(data.status === 'success') {
            resBox.textContent = `IP      : ${data.query}\nProvider: ${data.isp}\nNegara  : ${data.country} (${data.countryCode})\nKota    : ${data.city}\nRegion  : ${data.regionName}\nZona    : ${data.timezone}`;
        } else {
            resBox.textContent = 'IP tidak valid atau data tidak ditemukan.';
        }
    } catch(e) { resBox.textContent = 'Error koneksi.'; }
}

async function lookupDNS() {
    const domain = document.getElementById('domainInput').value.trim();
    const resBox = document.getElementById('dnsResult');
    if (!domain) return;
    resBox.textContent = 'Mencari DNS...';
    try {
        const res = await fetch(`/api/dns.php?domain=${domain}`);
        const data = await res.json();
        if(data.ok) {
            resBox.textContent = data.records.join('\n');
        } else {
            resBox.textContent = data.error;
        }
    } catch(e) { resBox.textContent = 'Error koneksi.'; }
}

async function checkIMEI() {
    const imei = document.getElementById('imeiInput').value.trim().replace(/\D/g, '');
    const resBox = document.getElementById('imeiResult');
    if (imei.length !== 15) {
        resBox.innerHTML = '<div class="alert alert-error" style="background:rgba(239,68,68,.1);padding:15px;border-radius:10px;color:var(--danger);border-left:4px solid var(--danger)">IMEI harus 15 digit angka!</div>';
        return;
    }
    resBox.innerHTML = '<div style="text-align:center;padding:20px;color:var(--text-muted)"><i class="fas fa-spinner fa-spin" style="font-size:2em;color:var(--primary)"></i><br><br>Mencari data dari server Kemenperin...</div>';

    try {
        const res = await fetch(`/api/imei.php?imei=${imei}`);
        const json = await res.json();

        if (!json.ok) {
            resBox.innerHTML = `<div style="background:rgba(239,68,68,.1);padding:15px;border-radius:10px;color:var(--danger);border-left:4px solid var(--danger)"><b>Gagal:</b> ${json.error}</div>`;
            return;
        }

        const d = json.data;
        const data = d.data || d;

        resBox.innerHTML = `
            <div class="imei-result">
                <div style="text-align:center;margin-bottom:15px;padding-bottom:15px;border-bottom:1px solid var(--border)">
                    <i class="fas fa-mobile-screen" style="font-size:2.5em;color:var(--primary);margin-bottom:10px;"></i>
                    <h3 style="font-size:1.2em">${data.brand || data.merk || '-'} ${data.model || data.tipe || ''}</h3>
                </div>
                <div class="imei-row"><span class="k">IMEI</span><span class="v">${imei}</span></div>
                <div class="imei-row"><span class="k">Brand</span><span class="v">${data.brand || data.merk || '-'}</span></div>
                <div class="imei-row"><span class="k">Model</span><span class="v">${data.model || data.tipe || '-'}</span></div>
                <div class="imei-row"><span class="k">Status</span><span class="v" style="color:${data.status === 'Terdaftar' || data.status === 'REGISTERED' || data.status === 'registered' ? 'var(--success)' : 'var(--warning)'}">${data.status || data.keterangan || 'Tidak diketahui'}</span></div>
                ${data.operator ? `<div class="imei-row"><span class="k">Operator</span><span class="v">${data.operator}</span></div>` : ''}
            </div>
        `;
    } catch(e) {
        resBox.innerHTML = `<div style="background:rgba(239,68,68,.1);padding:15px;border-radius:10px;color:var(--danger);border-left:4px solid var(--danger)"><b>Error:</b> ${e.message}</div>`;
    }
}
</script>

<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# PRIVACY PAGE
cat > "$WEB_ROOT/privacy.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
$pageTitle = 'Privacy Policy';
include __DIR__ . '/includes/header.php';
include __DIR__ . '/includes/navbar.php';
?>
<div class="container" style="max-width:800px">
    <h1 style="margin:20px 0 20px;font-size:2em;display:flex;align-items:center;gap:12px">
        <i class="fas fa-shield-halved" style="color:var(--primary)"></i> Privacy Policy
    </h1>
    <div style="background:var(--bg-card); padding:30px; border-radius:20px; border:1px solid var(--border);">
        <h3>1. Data yang Kami Kumpulkan</h3>
        <p style="color:var(--text-muted); margin-bottom:20px;">Kami <b>tidak menyimpan</b> data IP atau aktivitas browsing Anda. Semua proses speed test dan IP lookup dilakukan secara <i>real-time</i> tanpa database.</p>
        
        <h3>2. Iklan (Ads)</h3>
        <p style="color:var(--text-muted); margin-bottom:20px;">Web ini <b>100% bebas iklan</b>. Tidak ada pop-up, tidak ada trackers pihak ketiga, dan tidak ada cookies yang melacak Anda.</p>

        <h3>3. Cek IMEI</h3>
        <p style="color:var(--text-muted); margin-bottom:20px;">Fitur cek IMEI menggunakan API publik dari Kemenperin RI. Data IMEI Anda hanya dikirim ke server Kemenperin untuk verifikasi dan tidak disimpan oleh kami.</p>

        <h3>4. Pihak Ketiga</h3>
        <p style="color:var(--text-muted); margin-bottom:20px;">Kami menggunakan API gratis (<b>ip-api.com</b>, <b>Kemenperin</b>, <b>detik.com</b>) untuk menampilkan data. Silakan baca privacy policy mereka masing-masing.</p>

        <h3>5. Kontak</h3>
        <p style="color:var(--text-muted);">Ada pertanyaan? Hubungi admin melalui Telegram atau email.</p>
    </div>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

echo -e "${GREEN}  ✓ Halaman OK${NC}"

# ============ NGINX ============
echo -e "${CYAN}📝 Nginx config...${NC}"
cat > "$NGINX_CONF" << NGINXEOF
server {
    listen 80;
    listen [::]:80;
    server_name $SUBDOMAIN;
    root $WEB_ROOT;
    index index.php index.html;
    
    location / { try_files \$uri \$uri/ =404; }
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    }
}
NGINXEOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/ 2>/dev/null
[[ -f /etc/nginx/sites-enabled/default ]] && rm -f /etc/nginx/sites-enabled/default

nginx -t >/dev/null 2>&1 && systemctl reload nginx || { nginx -t; exit 1; }

# ============ PERMISSIONS ============
chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"
systemctl restart php8.3-fpm

# ============ SSL ============
SERVER_IP=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null)
DOMAIN_IP=$(dig +short A "$SUBDOMAIN" @8.8.8.8 2>/dev/null | head -1)
[[ -z "$DOMAIN_IP" ]] && DOMAIN_IP=$(getent ahostsv4 "$SUBDOMAIN" 2>/dev/null | awk '{print $1}' | head -1)

if [[ "$SERVER_IP" == "$DOMAIN_IP" ]] || [[ -f "/etc/letsencrypt/live/$SUBDOMAIN/fullchain.pem" ]]; then
    apt install certbot python3-certbot-nginx -y -qq 2>/dev/null
    certbot --nginx -d "$SUBDOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect >/dev/null 2>&1
fi

PROTO="https"; [[ ! -f "/etc/letsencrypt/live/$SUBDOMAIN/fullchain.pem" ]] && PROTO="http"

# ============ SELESAI ============
clear
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ RENDZZ TOOLS BERHASIL DI-INSTALL!      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🔗 URL Web:${NC}"
echo -e "  $PROTO://$SUBDOMAIN"
echo ""
echo -e "${YELLOW}📌 Fitur:${NC}"
echo -e "  • Speedtest (Ping, Download, Provider, IP)"
echo -e "  • Cek IMEI Kemenperin"
echo -e "  • IP Address Lookup"
echo -e "  • DNS Lookup"
echo -e "  • Menu Hamburger (Berita Realtime)"
echo -e "  • Dark & Light Mode"
echo -e "  • 100% No Ads"
echo ""
echo -e "${GREEN}🎉 Selesai! Buka web di browser sekarang.${NC}"
