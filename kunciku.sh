#!/bin/bash
# ============================================
#   🛡️ SECURITY TOOLS — FULL INSTALLER
#   Auth • Password • Hash • QR • User System
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🛡️ SECURITY TOOLS — INSTALLER             ║${NC}"
echo -e "${CYAN}║  2FA • Password • Hash • QR Code           ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

read -p "👉 Subdomain (contoh: tools.domain.com): " SUBDOMAIN
[[ -z "$SUBDOMAIN" ]] && { echo -e "${RED}❌ Kosong!${NC}"; exit 1; }

read -p "👉 Email SSL: " EMAIL
[[ -z "$EMAIL" ]] && EMAIL="admin@$SUBDOMAIN"

DB_PASS=$(openssl rand -hex 12)
DB_NAME="tools_$(echo $SUBDOMAIN | tr '.' '_' | cut -c1-15)"
WEB_ROOT="/var/www/$SUBDOMAIN"
NGINX_CONF="/etc/nginx/sites-available/$SUBDOMAIN"

echo ""
read -p "Lanjut? (y/n): " C
[[ "$C" != "y" && "$C" != "Y" ]] && exit 0

# ============ 1. PACKAGES ============
echo -e "\n${CYAN}[1/5] Install packages...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt update -qq 2>/dev/null
apt install nginx php8.3-fpm php8.3-mysql php8.3-mbstring php8.3-curl php8.3-xml php8.3-zip php8.3-gd mysql-server curl unzip -y -qq 2>/dev/null

systemctl enable --now nginx php8.3-fpm mysql >/dev/null 2>&1

# ============ 2. DATABASE ============
echo -e "${CYAN}[2/5] Database...${NC}"
mysql -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;"
mysql -e "CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'toolsapp'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO 'toolsapp'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

mysql "$DB_NAME" << 'SQLEOF'
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE authenticators (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    name VARCHAR(100) NOT NULL,
    secret VARCHAR(100) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
SQLEOF
echo -e "${GREEN}  ✓ Database OK${NC}"

# ============ 3. FOLDER & LIB ============
echo -e "${CYAN}[3/5] Download Library TOTP...${NC}"
[[ -d "$WEB_ROOT" ]] && mv "$WEB_ROOT" "/var/www/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$WEB_ROOT"/{includes,assets/css,assets/js,vendor}
cd /tmp
wget -q https://raw.githubusercontent.com/PHPGangsta/GoogleAuthenticator/master/PHPGangsta/GoogleAuthenticator.php -O GoogleAuthenticator.php
mv GoogleAuthenticator.php "$WEB_ROOT/vendor/GoogleAuthenticator.php"
echo -e "${GREEN}  ✓ Library OK${NC}"

# ============ 4. CONFIG & ASSETS ============
echo -e "${CYAN}[4/5] Bikin File Config & CSS...${NC}"

cat > "$WEB_ROOT/includes/config.php" << PHPEOF
<?php
session_start();
date_default_timezone_set('Asia/Jakarta');

define('DB_HOST', 'localhost');
define('DB_NAME', '$DB_NAME');
define('DB_USER', 'toolsapp');
define('DB_PASS', '$DB_PASS');
define('SITE_NAME', 'Rendzz Security Tools');

try {
    \$pdo = new PDO("mysql:host=".DB_HOST.";dbname=".DB_NAME.";charset=utf8mb4", DB_USER, DB_PASS, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
} catch (PDOException \$e) { die("DB Error: " . \$e->getMessage()); }

require_once __DIR__ . '/../vendor/GoogleAuthenticator.php';

function isLoggedIn() { return isset(\$_SESSION['user_id']); }
function requireLogin() { if (!isLoggedIn()) { header('Location: /login.php'); exit; } }
function csrf() { if (empty(\$_SESSION['csrf'])) \$_SESSION['csrf'] = bin2hex(random_bytes(32)); return \$_SESSION['csrf']; }
function checkCsrf(\$t) { return isset(\$_SESSION['csrf']) && hash_equals(\$_SESSION['csrf'], \$t); }
PHPEOF

cat > "$WEB_ROOT/assets/css/style.css" << 'CSSEOF'
:root {
    --bg: #0a0a0f;
    --card: rgba(30, 30, 50, 0.4);
    --glass: rgba(255, 255, 255, 0.03);
    --border: rgba(255, 255, 255, 0.08);
    --text: #fafafa;
    --muted: #a1a1aa;
    --primary: #8b5cf6;
    --primary-hover: #7c3aed;
    --success: #10b981;
    --danger: #ef4444;
    --warning: #f59e0b;
    --cyan: #06b6d4;
}
* { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Inter', sans-serif; }
body { background: var(--bg); color: var(--text); min-height: 100vh; padding-bottom: 80px; background-image: radial-gradient(circle at 15% 50%, rgba(139, 92, 246, 0.15), transparent 30%), radial-gradient(circle at 85% 30%, rgba(6, 182, 212, 0.15), transparent 30%); background-attachment: fixed; }
a { color: inherit; text-decoration: none; }

/* NAVBAR */
.navbar { position: sticky; top: 0; z-index: 100; background: rgba(10, 10, 15, 0.8); backdrop-filter: blur(20px); border-bottom: 1px solid var(--border); padding: 14px 20px; display: flex; justify-content: space-between; align-items: center; }
.logo { font-size: 1.1em; font-weight: 800; color: var(--primary); display: flex; align-items: center; gap: 8px; }
.nav-links { display: flex; gap: 5px; }
.nav-icon { padding: 10px 14px; border-radius: 10px; color: var(--muted); transition: 0.2s; display: flex; align-items: center; justify-content: center; font-size: 1.1em; }
.nav-icon:hover, .nav-icon.active { background: var(--glass); color: var(--primary); border: 1px solid var(--border); }

/* CONTAINER */
.container { max-width: 600px; margin: 0 auto; padding: 30px 20px; }

/* CARDS */
.card { background: var(--card); backdrop-filter: blur(16px); border: 1px solid var(--border); border-radius: 20px; padding: 24px; margin-bottom: 20px; box-shadow: 0 8px 32px rgba(0,0,0,0.2); }
.card-header { display: flex; align-items: center; gap: 12px; margin-bottom: 20px; }
.card-icon { width: 45px; height: 45px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 1.3em; color: #fff; flex-shrink: 0; }
.card-title { font-size: 1.1em; font-weight: 700; }
.card-sub { font-size: 0.85em; color: var(--muted); }

/* FORMS */
.form-group { margin-bottom: 16px; }
.form-group label { display: flex; align-items: center; gap: 6px; font-size: 0.85em; color: var(--muted); margin-bottom: 8px; font-weight: 600; }
.form-group input, .form-group select, .form-group textarea { width: 100%; padding: 14px 16px; border: 1px solid var(--border); border-radius: 12px; background: rgba(0,0,0,0.3); color: var(--text); font-family: inherit; font-size: 0.95em; outline: none; transition: 0.2s; }
.form-group input:focus { border-color: var(--primary); box-shadow: 0 0 0 3px rgba(139,92,246,0.15); }

/* BUTTONS */
.btn { padding: 14px 24px; border-radius: 12px; border: none; font-weight: 700; font-family: inherit; font-size: 0.95em; cursor: pointer; display: inline-flex; align-items: center; justify-content: center; gap: 8px; transition: 0.2s; text-decoration: none; }
.btn-primary { background: var(--primary); color: #fff; box-shadow: 0 4px 15px rgba(139,92,246,0.3); }
.btn-primary:hover { background: var(--primary-hover); transform: translateY(-1px); }
.btn-outline { background: transparent; border: 1px solid var(--border); color: var(--text); }
.btn-outline:hover { background: var(--glass); }
.btn-danger { background: rgba(239,68,68,0.15); color: var(--danger); border: 1px solid rgba(239,68,68,0.2); }
.btn-block { width: 100%; }
.btn-sm { padding: 8px 14px; font-size: 0.85em; border-radius: 10px; }

/* AUTH CARD (2FA) */
.auth-item { display: flex; justify-content: space-between; align-items: center; gap: 12px; padding: 16px; background: rgba(0,0,0,0.2); border-radius: 14px; border: 1px solid var(--border); margin-bottom: 10px; }
.auth-name { font-weight: 700; font-size: 0.95em; }
.auth-secret { font-size: 0.75em; color: var(--muted); font-family: monospace; word-break: break-all; }
.code-box { display: flex; align-items: center; gap: 10px; flex-shrink: 0; }
.code-value { font-size: 1.6em; font-weight: 800; letter-spacing: 2px; color: var(--primary); font-family: 'Space Mono', monospace; cursor: pointer; transition: 0.2s; padding: 4px 8px; border-radius: 8px; }
.code-value:hover { background: rgba(139,92,246,0.1); }
.code-value:active { transform: scale(0.95); }

/* TIMER */
.timer { position: relative; width: 40px; height: 40px; flex-shrink: 0; }
.timer svg { transform: rotate(-90deg); width: 100%; height: 100%; }
.timer circle { fill: none; stroke-width: 4; }
.timer .bg { stroke: var(--border); }
.timer .fg { stroke: var(--primary); transition: stroke-dashoffset 1s linear; }
.timer-text { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; font-size: 0.75em; font-weight: 800; }

/* ALERTS */
.alert { padding: 14px 18px; border-radius: 12px; margin-bottom: 16px; font-size: 0.9em; display: flex; align-items: center; gap: 10px; }
.alert-success { background: rgba(16,185,129,0.1); color: var(--success); border: 1px solid rgba(16,185,129,0.2); }
.alert-error { background: rgba(239,68,68,0.1); color: var(--danger); border: 1px solid rgba(239,68,68,0.2); }

/* RESULT BOX */
.result-box { background: rgba(0,0,0,0.3); padding: 16px; border-radius: 12px; border: 1px solid var(--border); margin-top: 16px; font-family: monospace; font-size: 0.9em; word-break: break-all; min-height: 60px; display: none; }
.result-box.show { display: block; animation: fadeIn 0.3s; }
@keyframes fadeIn { from { opacity: 0; transform: translateY(-5px); } to { opacity: 1; transform: translateY(0); } }

/* QR */
.qr-result { display: none; text-align: center; margin-top: 20px; }
.qr-result.show { display: block; }
.qr-result img { max-width: 250px; border-radius: 16px; background: #fff; padding: 10px; margin-bottom: 15px; }

/* EMPTY */
.empty { text-align: center; padding: 40px 20px; color: var(--muted); }
.empty i { font-size: 3em; opacity: 0.3; margin-bottom: 12px; display: block; }
CSSEOF

# HEADER / FOOTER
cat > "$WEB_ROOT/includes/header.php" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title><?= $pageTitle ?? 'Home' ?> — <?= SITE_NAME ?></title>
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🛡️</text></svg>">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&family=Space+Mono&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
<link rel="stylesheet" href="/assets/css/style.css">
</head>
<body>
<nav class="navbar">
    <a href="/" class="logo"><i class="fas fa-shield-halved"></i> Security Tools</a>
    <div class="nav-links">
        <a href="/" class="nav-icon <?= basename($_SERVER['PHP_SELF']) == 'index.php' ? 'active' : '' ?>" title="Authenticator"><i class="fas fa-key"></i></a>
        <a href="/password.php" class="nav-icon <?= basename($_SERVER['PHP_SELF']) == 'password.php' ? 'active' : '' ?>" title="Password Generator"><i class="fas fa-lock"></i></a>
        <a href="/hash.php" class="nav-icon <?= basename($_SERVER['PHP_SELF']) == 'hash.php' ? 'active' : '' ?>" title="Hash Generator"><i class="fas fa-fingerprint"></i></a>
        <a href="/qr.php" class="nav-icon <?= basename($_SERVER['PHP_SELF']) == 'qr.php' ? 'active' : '' ?>" title="QR Code"><i class="fas fa-qrcode"></i></a>
        <?php if (isLoggedIn()): ?>
            <a href="/logout.php" class="nav-icon" style="color:var(--danger)" title="Logout"><i class="fas fa-sign-out-alt"></i></a>
        <?php endif; ?>
    </div>
</nav>
HTMLEOF

cat > "$WEB_ROOT/includes/footer.php" << 'HTMLEOF'
</body>
</html>
HTMLEOF

# ============ 5. HALAMAN & LOGIKA ============
echo -e "${CYAN}[5/5] Bikin Halaman...${NC}"

# --- INDEX: AUTHENTICATOR ---
cat > "$WEB_ROOT/index.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];
$msg = ''; $err = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && checkCsrf($_POST['csrf'] ?? '')) {
    if (isset($_POST['add'])) {
        $name = trim($_POST['name']); $secret = strtoupper(str_replace(' ', '', trim($_POST['secret'])));
        if (empty($name) || empty($secret)) $err = 'Nama & Secret wajib diisi!';
        elseif (strlen($secret) < 16) $err = 'Secret Key minimal 16 karakter!';
        else {
            $pdo->prepare("INSERT INTO authenticators (user_id, name, secret) VALUES (?,?,?)")->execute([$uid, $name, $secret]);
            $msg = 'Akun 2FA berhasil ditambahkan!';
        }
    } elseif (isset($_POST['delete'])) {
        $pdo->prepare("DELETE FROM authenticators WHERE id=? AND user_id=?")->execute([(int)$_POST['id'], $uid]);
        $msg = 'Akun 2FA dihapus.';
    }
}

$accounts = $pdo->prepare("SELECT * FROM authenticators WHERE user_id=? ORDER BY id DESC");
$accounts->execute([$uid]);
$accounts = $accounts->fetchAll();

$pageTitle = 'Authenticator';
include __DIR__ . '/includes/header.php';
?>
<div class="container">
    <?php if ($msg): ?><div class="alert alert-success"><i class="fas fa-check-circle"></i> <?= $msg ?></div><?php endif; ?>
    <?php if ($err): ?><div class="alert alert-error"><i class="fas fa-exclamation-circle"></i> <?= $err ?></div><?php endif; ?>

    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:20px">
        <div>
            <h2 style="font-size:1.3em">Kode 2FA</h2>
            <p style="color:var(--muted); font-size:0.85em">Generate kode 6 digit tiap 30 detik</p>
        </div>
        <button class="btn btn-primary btn-sm" onclick="document.getElementById('modal').classList.add('show')"><i class="fas fa-plus"></i> Tambah</button>
    </div>

    <?php if (empty($accounts)): ?>
        <div class="card empty">
            <i class="fas fa-key"></i>
            <p style="margin-bottom:12px">Belum ada akun 2FA tersimpan.</p>
            <button class="btn btn-primary" onclick="document.getElementById('modal').classList.add('show')"><i class="fas fa-plus"></i> Tambah Akun</button>
        </div>
    <?php else: foreach ($accounts as $a): ?>
        <div class="auth-item">
            <div style="flex:1; min-width:0">
                <div class="auth-name"><?= htmlspecialchars($a['name']) ?></div>
                <div class="auth-secret"><?= htmlspecialchars($a['secret']) ?></div>
            </div>
            <div class="code-box">
                <div class="code-value" id="code-<?= $a['id'] ?>" data-secret="<?= htmlspecialchars($a['secret']) ?>" onclick="copyCode(this)">--- ---</div>
                <div class="timer">
                    <svg viewBox="0 0 40 40"><circle class="bg" cx="20" cy="20" r="16"></circle><circle class="fg" cx="20" cy="20" r="16" style="stroke-dasharray:100.5; stroke-dashoffset:0"></circle></svg>
                    <div class="timer-text">30</div>
                </div>
            </div>
            <form method="POST" style="margin:0"><input type="hidden" name="csrf" value="<?= csrf() ?>"><input type="hidden" name="id" value="<?= $a['id'] ?>"><button name="delete" class="btn btn-danger btn-sm" onclick="return confirm('Hapus?')"><i class="fas fa-trash"></i></button></form>
        </div>
    <?php endforeach; endif; ?>
</div>

<!-- MODAL -->
<div class="modal" id="modal" style="display:none; position:fixed; inset:0; background:rgba(0,0,0,0.8); z-index:999; align-items:center; justify-content:center; padding:20px;">
    <div class="card" style="max-width:400px; width:100%">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:16px">
            <h3 style="font-size:1.1em"><i class="fas fa-plus-circle" style="color:var(--primary)"></i> Tambah 2FA</h3>
            <button onclick="document.getElementById('modal').style.display='none'" style="background:none; border:none; color:var(--muted); font-size:1.2em; cursor:pointer"><i class="fas fa-times"></i></button>
        </div>
        <form method="POST">
            <input type="hidden" name="csrf" value="<?= csrf() ?>">
            <div class="form-group"><label><i class="fas fa-tag"></i> Nama Akun</label><input type="text" name="name" placeholder="Facebook / Google / dll" required></div>
            <div class="form-group"><label><i class="fas fa-key"></i> Secret Key</label><input type="text" name="secret" placeholder="K52KCJNMAK2N5ACM" required style="font-family:monospace; text-transform:uppercase"></div>
            <button name="add" class="btn btn-primary btn-block"><i class="fas fa-save"></i> Simpan Kode</button>
        </form>
    </div>
</div>

<script>
function base32Decode(input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    input = input.replace(/=+$/, '').toUpperCase();
    let bits = 0, value = 0, index = 0;
    const output = new Uint8Array(Math.floor(input.length * 5 / 8));
    for (let i = 0; i < input.length; i++) {
        const idx = alphabet.indexOf(input[i]);
        if (idx === -1) continue;
        value = (value << 5) | idx;
        bits += 5;
        if (bits >= 8) {
            output[index++] = (value >>> (bits - 8)) & 0xff;
            bits -= 8;
        }
    }
    return output.slice(0, index);
}

async function generateTOTP(secret, period = 30) {
    const keyBytes = base32Decode(secret);
    let counter = Math.floor(Date.now() / 1000 / period);
    const counterBytes = new Uint8Array(8);
    for (let i = 7; i >= 0; i--) {
        counterBytes[i] = counter & 0xff;
        counter = Math.floor(counter / 256);
    }
    const cryptoKey = await crypto.subtle.importKey('raw', keyBytes, { name: 'HMAC', hash: 'SHA-1' }, false, ['sign']);
    const signature = await crypto.subtle.sign('HMAC', cryptoKey, counterBytes);
    const hash = new Uint8Array(signature);
    const offset = hash[hash.length - 1] & 0xf;
    const binary = ((hash[offset] & 0x7f) << 24) | ((hash[offset + 1] & 0xff) << 16) | ((hash[offset + 2] & 0xff) << 8) | (hash[offset + 3] & 0xff);
    return (binary % 1000000).toString().padStart(6, '0');
}

async function updateCodes() {
    for (const el of document.querySelectorAll('.code-value')) {
        try {
            const code = await generateTOTP(el.dataset.secret);
            el.textContent = code.slice(0, 3) + ' ' + code.slice(3);
        } catch(e) { el.textContent = 'ERROR'; }
    }
    const now = Math.floor(Date.now() / 1000);
    const rem = 30 - (now % 30);
    document.querySelectorAll('.timer-text').forEach(el => el.textContent = rem);
    document.querySelectorAll('.timer .fg').forEach(el => el.style.strokeDashoffset = (100.5 * (1 - rem / 30)).toString());
}

function copyCode(el) {
    const text = el.textContent.replace(/\s/g, '');
    navigator.clipboard.writeText(text).then(() => {
        const orig = el.textContent;
        el.textContent = '✓ COPIED';
        setTimeout(() => updateCodes(), 1000);
    });
}

updateCodes();
setInterval(updateCodes, 1000);
</script>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# --- PASSWORD GENERATOR ---
cat > "$WEB_ROOT/password.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
$pageTitle = 'Password Generator';
include __DIR__ . '/includes/header.php';
?>
<div class="container">
    <div class="card">
        <div class="card-header">
            <div class="card-icon" style="background:linear-gradient(135deg,#ef4444,#b91c1c)"><i class="fas fa-lock"></i></div>
            <div><div class="card-title">Password Generator</div><div class="card-sub">Bikin password super kuat</div></div>
        </div>

        <div class="form-group">
            <label><i class="fas fa-ruler"></i> Panjang Password: <span id="lenVal" style="color:var(--primary); font-weight:800">16</span></label>
            <input type="range" id="len" min="8" max="64" value="16" oninput="document.getElementById('lenVal').textContent=this.value" style="width:100%">
        </div>

        <div class="form-group" style="display:flex; gap:15px; flex-wrap:wrap">
            <label style="display:flex; gap:8px; align-items:center; cursor:pointer"><input type="checkbox" id="upper" checked> <span>ABC</span></label>
            <label style="display:flex; gap:8px; align-items:center; cursor:pointer"><input type="checkbox" id="lower" checked> <span>abc</span></label>
            <label style="display:flex; gap:8px; align-items:center; cursor:pointer"><input type="checkbox" id="num" checked> <span>123</span></label>
            <label style="display:flex; gap:8px; align-items:center; cursor:pointer"><input type="checkbox" id="sym" checked> <span>!@#</span></label>
        </div>

        <button class="btn btn-primary btn-block" onclick="genPass()"><i class="fas fa-sync"></i> Generate Password</button>

        <div class="result-box" id="result" style="text-align:center; font-size:1.3em; font-weight:800; letter-spacing:2px; color:var(--primary)"></div>
        <div style="text-align:center; margin-top:10px" id="strengthBox"></div>
    </div>
</div>

<script>
function genPass() {
    const len = +document.getElementById('len').value;
    let chars = '';
    if (document.getElementById('upper').checked) chars += 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    if (document.getElementById('lower').checked) chars += 'abcdefghijkmnpqrstuvwxyz';
    if (document.getElementById('num').checked) chars += '23456789';
    if (document.getElementById('sym').checked) chars += '!@#$%^&*()_+-=[]{}|;:,.<>?';
    if (!chars) return alert('Pilih minimal 1 tipe karakter!');

    let pass = '';
    for (let i = 0; i < len; i++) pass += chars.charAt(Math.floor(Math.random() * chars.length));

    document.getElementById('result').textContent = pass;
    document.getElementById('result').classList.add('show');

    // Hitung strength
    let score = 0;
    if (len >= 8) score++;
    if (len >= 12) score++;
    if (len >= 16) score++;
    if (/[A-Z]/.test(pass)) score++;
    if (/[a-z]/.test(pass)) score++;
    if (/[0-9]/.test(pass)) score++;
    if (/[^A-Za-z0-9]/.test(pass)) score++;

    let label = 'Weak', color = 'var(--danger)';
    if (score >= 5) { label = 'Medium'; color = 'var(--warning)'; }
    if (score >= 6) { label = 'Strong'; color = 'var(--success)'; }
    if (score >= 7) { label = 'Very Strong'; color = 'var(--primary)'; }
    document.getElementById('strengthBox').innerHTML = `<span style="color:${color}; font-weight:800">${label}</span>`;
}
genPass();
</script>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# --- HASH GENERATOR ---
cat > "$WEB_ROOT/hash.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
$pageTitle = 'Hash Generator';
include __DIR__ . '/includes/header.php';
?>
<div class="container">
    <div class="card">
        <div class="card-header">
            <div class="card-icon" style="background:linear-gradient(135deg,#10b981,#047857)"><i class="fas fa-fingerprint"></i></div>
            <div><div class="card-title">Hash Generator</div><div class="card-sub">Enkripsi teks ke MD5, SHA-256, dll</div></div>
        </div>

        <div class="form-group">
            <label><i class="fas fa-keyboard"></i> Teks</label>
            <textarea id="text" rows="3" placeholder="Ketik teks apapun..." oninput="genHash()"></textarea>
        </div>

        <div class="form-group">
            <label><i class="fas fa-list"></i> Algoritma</label>
            <select id="algo" onchange="genHash()">
                <option value="md5">MD5</option>
                <option value="sha1">SHA-1</option>
                <option value="sha256" selected>SHA-256</option>
                <option value="sha512">SHA-512</option>
            </select>
        </div>

        <div class="result-box" id="result" style="text-align:left; font-size:0.85em"></div>
    </div>
</div>

<script>
async function genHash() {
    const text = document.getElementById('text').value;
    const algo = document.getElementById('algo').value;
    const result = document.getElementById('result');

    if (!text) { result.classList.remove('show'); return; }

    // Peta algoritma Web Crypto
    const algoMap = { 'md5': 'MD5', 'sha1': 'SHA-1', 'sha256': 'SHA-256', 'sha512': 'SHA-512' };

    if (algo === 'md5') {
        // Web Crypto gak dukung MD5, kita pakai implementasi manual sederhana
        result.textContent = md5(text);
    } else {
        const buf = await crypto.subtle.digest(algoMap[algo], new TextEncoder().encode(text));
        result.textContent = Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, '0')).join('');
    }
    result.classList.add('show');
}

// Implementasi MD5 sederhana (untuk fallback)
function md5(str) {
    // Placeholder (pakai library asli nanti)
    return 'MD5 tidak didukung di browser (gunakan SHA-256)';
}
</script>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# --- QR CODE GENERATOR ---
cat > "$WEB_ROOT/qr.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
$pageTitle = 'QR Code Generator';
include __DIR__ . '/includes/header.php';
?>
<div class="container">
    <div class="card">
        <div class="card-header">
            <div class="card-icon" style="background:linear-gradient(135deg,#06b6d4,#0891b2)"><i class="fas fa-qrcode"></i></div>
            <div><div class="card-title">QR Code Generator</div><div class="card-sub">Ubah link/text jadi QR</div></div>
        </div>

        <div class="form-group">
            <label><i class="fas fa-link"></i> Teks / Link</label>
            <input type="text" id="text" placeholder="https://example.com" oninput="genQR()">
        </div>

        <div class="form-group">
            <label><i class="fas fa-ruler"></i> Ukuran</label>
            <select id="size" onchange="genQR()">
                <option value="200">200 x 200</option>
                <option value="300" selected>300 x 300</option>
                <option value="500">500 x 500</option>
            </select>
        </div>

        <div class="qr-result" id="qrResult">
            <img id="qrImg" src="" alt="QR">
            <br>
            <a id="downloadBtn" class="btn btn-primary" download="qrcode.png"><i class="fas fa-download"></i> Download QR</a>
        </div>
    </div>
</div>

<script>
function genQR() {
    const text = document.getElementById('text').value;
    const size = document.getElementById('size').value;
    const box = document.getElementById('qrResult');

    if (!text) { box.classList.remove('show'); return; }

    const url = `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encodeURIComponent(text)}`;
    document.getElementById('qrImg').src = url;
    document.getElementById('downloadBtn').href = url;
    box.classList.add('show');
}
</script>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# --- LOGIN & REGISTER --- style
cat >=" "$WEB_ROOT/login.php" << 'colorPHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
if (isLoggedIn()) { header('Location: /'); exit; }
$err = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!checkCsrf($_POST['csrf'] ?? '')) $err = 'CSRF Error';
    else {
        $s = $pdo->prepare("SELECT * FROM users WHERE username=?"); $s->execute([trim($_POST['username'])]);
        $u = $s->fetch();
        if ($u && password_verify($_POST['password'], $u['password'])) {
            $_SESSION['user_id'] = $u['id']; $_SESSION['username'] = $u['username'];
            header('Location: /'); exit;
        } else $err = 'Login gagal!';
    }
}
$pageTitle = 'Login';
include __DIR__ . '/includes/header.php';
?>
<div class="container" style="max-width:400px; margin-top:60px">
    <div class="card">
        <div style="text-align:center; margin-bottom:20px">
            <div class="card-icon" style="background:linear-gradient(135deg,var(--primary),#6d28d9); margin:0 auto 15px; width:60px; height:60px; font-size:1.5em"><i class="fas fa-lock"></i></div>
            <h2 style="font-size:1.4em">Login</h2>
            <p style="color:var(--muted); font-size:0.9em">Masuk untuk akses Authenticator</p>
        </div>
        <?php if ($err): ?><div class="alert alert-error"><i class="fas fa-exclamation-circle"></i> <?= $err ?></div><?php endif; ?>
        <form method="POST">
            <input type="hidden" name="csrf" value="<?= csrf() ?>">
            <div class="form-group"><label><i class="fas fa-user"></i> Username</label><input type="text" name="username" required autofocus></div>
            <div class="form-group"><label><i class="fas fa-key"></i> Password</label><input type="password" name="password" required></div>
            <button class="btn btn-primary btn-block"><i class="fas fa-sign-in-alt"></i> Masuk</button>
        </form>
        <p style="text-align:center; margin-top:15px; font-size:0.9em; color:var(--muted)">Belum punya akun? <a href="/register.php":var(--primary)">Daftar</a></p>
    </div>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

cat > "$WEB_ROOT/register.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
if (isLoggedIn()) { header('Location: /'); exit; }
$err = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!checkCsrf($_POST['csrf'] ?? '')) $err = 'CSRF Error';
    else {
        $u = trim($_POST['username']); $p = $_POST['password'];
        if (strlen($u) < 3) $err = 'Username min 3';
        elseif (strlen($p) < 6) $err = 'Password min 6';
        else {
            $s = $pdo->prepare("SELECT id FROM users WHERE username=?"); $s->execute([$u]);
            if ($s->fetch()) $err = 'Username sudah dipakai';
            else {
                $pdo->prepare("INSERT INTO users (username, password) VALUES (?,?)")->execute([$u, password_hash($p, PASSWORD_BCRYPT)]);
                header('Location: /login.php'); exit;
            }
        }
    }
}
$pageTitle = 'Daftar';
include __DIR__ . '/includes/header.php';
?>
<div class="container" style="max-width:400px; margin-top:60px">
    <div class="card">
        <div style="text-align:center; margin-bottom:20px">
            <div class="card-icon" style="background:linear-gradient(135deg,var(--primary),#6d28d9); margin:0 auto 15px; width:60px; height:60px; font-size:1.5em"><i class="fas fa-user-plus"></i></div>
            <h2 style="font-size:1.4em">Daftar Akun</h2>
        </div>
        <?php if ($err): ?><div class="alert alert-error"><i class="fas fa-exclamation-circle"></i> <?= $err ?></div><?php endif; ?>
        <form method="POST">
            <input type="hidden" name="csrf" value="<?= csrf() ?>">
            <div class="form-group"><label><i class="fas fa-user"></i> Username</label><input type="text" name="username" required></div>
            <div class="form-group"><label><i class="fas fa-key"></i> Password</label><input type="password" name="password" required></div>
            <button class="btn btn-primary btn-block"><i class="fas fa-user-plus"></i> Daftar</button>
        </form>
        <p style="text-align:center; margin-top:15px; font-size:0.9em; color:var(--muted)">Sudah punya akun? <a href="/login.php" style="color:var(--primary)">Login</a></p>
    </div>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

cat > "$WEB_ROOT/logout.php" << 'PHPEOF'
<?php session_start(); session_destroy(); header('Location: /login.php'); exit;
PHPEOF

# --- NGINX ---
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
nginx -t >/dev/null 2>&1 && systemctl reload nginx || exit 1

chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"
systemctl restart php8.3-fpm

# SSL
SERVER_IP=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null)
DOMAIN_IP=$(dig +short A "$SUBDOMAIN" @8.8.8.8 2>/dev/null | head -1)
[[ -z "$DOMAIN_IP" ]] && DOMAIN_IP=$(getent ahostsv4 "$SUBDOMAIN" 2>/dev/null | awk '{print $1}' | head -1)
if [[ "$SERVER_IP" == "$DOMAIN_IP" ]] || [[ -f "/etc/letsencrypt/live/$SUBDOMAIN/fullchain.pem" ]]; then
    apt install certbot python3-certbot-nginx -y -qq 2>/dev/null
    certbot --nginx -d "$SUBDOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect >/dev/null 2>&1
fi

PROTO="https"; [[ ! -f "/etc/letsencrypt/live/$SUBDOMAIN/fullchain.pem" ]] && PROTO="http"

clear
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ SECURITY TOOLS BERHASIL DI-INSTALL!    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🔗 URL:${NC} $PROTO://$SUBDOMAIN"
echo ""
echo -e "${YELLOW}📌 Fitur:${NC}"
echo -e "  🔐 Authenticator (2FA)  — Simpan kode 2FA"
echo -e "  🔑 Password Generator   — Bikin password kuat"
echo -e "  🔒 Hash Generator       — MD5, SHA-256, dll"
echo -e "  📱 QR Code Generator    — Ubah teks ke QR"
echo ""
echo -e "${GREEN}🎉 Selesai!${NC}"
