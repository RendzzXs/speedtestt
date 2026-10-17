#!/bin/bash
# ============================================
#   💬 RENDZZ NGL — ANONYMOUS MESSAGE
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  💬 RENDZZ NGL — INSTALLER                 ║${NC}"
echo -e "${CYAN}║  Anonymous Message • Admin Panel           ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

read -p "👉 Subdomain (contoh: ngl.domain.com): " SUBDOMAIN
[[ -z "$SUBDOMAIN" ]] && { echo -e "${RED}❌ Kosong!${NC}"; exit 1; }

read -p "👉 Email SSL: " EMAIL
[[ -z "$EMAIL" ]] && EMAIL="admin@$SUBDOMAIN"

read -s -p "👉 Password Admin Panel [admin123]: " ADMIN_PASS
echo ""
ADMIN_PASS=${ADMIN_PASS:-admin123}

DB_PASS=$(openssl rand -hex 12)
DB_NAME="ngl_$(echo $SUBDOMAIN | tr '.' '_' | cut -c1-15)"
WEB_ROOT="/var/www/$SUBDOMAIN"
NGINX_CONF="/etc/nginx/sites-available/$SUBDOMAIN"

echo ""
echo -e "${CYAN}📋 Summary:${NC}"
echo "  Subdomain : $SUBDOMAIN"
echo "  Admin Path: /x-panel-core"
echo "  Admin Pass: $ADMIN_PASS"
echo ""
read -p "Lanjut? (y/n): " C
[[ "$C" != "y" && "$C" != "Y" ]] && exit 0

# ============ STEP 1: PACKAGES ============
echo ""
echo -e "${CYAN}[1/5] Install packages...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt update -qq 2>/dev/null
apt install nginx php8.3-fpm php8.3-mysql php8.3-mbstring php8.3-curl php8.3-xml php8.3-zip mysql-server curl wget unzip -y -qq 2>/dev/null

rm -f /etc/mysql/FROZEN 2>/dev/null
systemctl enable mysql nginx php8.3-fpm >/dev/null 2>&1
systemctl start mysql nginx php8.3-fpm >/dev/null 2>&1

if ! systemctl is-active --quiet mysql; then
    systemctl stop mysql >/dev/null 2>&1
    apt purge mysql-server mysql-server-8.0 mysql-client mysql-common -y >/dev/null 2>&1
    rm -rf /var/lib/mysql /etc/mysql
    apt install mysql-server -y -qq >/dev/null 2>&1
    systemctl start mysql >/dev/null 2>&1
    sleep 5
fi

systemctl is-active --quiet mysql && echo -e "${GREEN}  ✓ MySQL OK${NC}" || { echo -e "${RED}  ✗ MySQL gagal!${NC}"; exit 1; }

# ============ STEP 2: DATABASE ============
echo -e "${CYAN}[2/5] Database...${NC}"
mysql -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null
mysql -e "CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'nglapp'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO 'nglapp'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

mysql "$DB_NAME" << 'SQLEOF'
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('admin','user') DEFAULT 'user',
    status ENUM('active','banned') DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    sender_ip VARCHAR(45),
    is_read BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX(user_id)
);
CREATE TABLE settings (
    k VARCHAR(50) PRIMARY KEY,
    v TEXT
);
SQLEOF

ADMIN_HASH=$(php -r "echo password_hash('$ADMIN_PASS', PASSWORD_BCRYPT);")
mysql "$DB_NAME" << SQLEOF
INSERT INTO users (username, email, password, role) VALUES ('admin', 'admin@$SUBDOMAIN', '$ADMIN_HASH', 'admin');
INSERT INTO settings VALUES ('site_name', 'Rendzz NGL');
SQLEOF

echo -e "${GREEN}  ✓ Database OK${NC}"

# ============ STEP 3: FOLDER ============
echo -e "${CYAN}[3/5] Folder...${NC}"
[[ -d "$WEB_ROOT" ]] && mv "$WEB_ROOT" "/var/www/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$WEB_ROOT"/{includes,assets/css,assets/js,x-panel-core}
echo -e "${GREEN}  ✓ Folder OK${NC}"

# ============ STEP 4: CONFIG & ASSETS ============
echo -e "${CYAN}[4/5] Config & Assets...${NC}"

cat > "$WEB_ROOT/includes/config.php" << PHPEOF
<?php
session_start();
date_default_timezone_set('Asia/Jakarta');

define('DB_HOST', 'localhost');
define('DB_NAME', '$DB_NAME');
define('DB_USER', 'nglapp');
define('DB_PASS', '$DB_PASS');
define('SITE_URL', 'https://$SUBDOMAIN');
define('SITE_NAME', 'Rendzz NGL');
define('ADMIN_PATH', 'x-panel-core');

try {
    \$pdo = new PDO("mysql:host=".DB_HOST.";dbname=".DB_NAME.";charset=utf8mb4", DB_USER, DB_PASS, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
} catch (PDOException \$e) { die("DB Error: " . \$e->getMessage()); }

function isLoggedIn() { return isset(\$_SESSION['user_id']); }
function isAdmin() { return isLoggedIn() && \$_SESSION['role'] === 'admin'; }
function requireLogin() { if (!isLoggedIn()) { header('Location: /login.php'); exit; } }
function requireAdmin() { if (!isAdmin()) { header('Location: /'.ADMIN_PATH.'/login.php'); exit; } }
function csrf() { if (empty(\$_SESSION['csrf'])) \$_SESSION['csrf'] = bin2hex(random_bytes(32)); return \$_SESSION['csrf']; }
function checkCsrf(\$t) { return isset(\$_SESSION['csrf']) && hash_equals(\$_SESSION['csrf'], \$t); }
function timeAgo(\$ts) {
    \$diff = time() - strtotime(\$ts);
    if (\$diff < 60) return 'baru saja';
    if (\$diff < 3600) return floor(\$diff/60) . ' menit lalu';
    if (\$diff < 86400) return floor(\$diff/3600) . ' jam lalu';
    return floor(\$diff/86400) . ' hari lalu';
}
PHPEOF

# CSS (Modern Dark NGL Style)
cat > "$WEB_ROOT/assets/css/style.css" << 'CSSEOF'
:root { --bg: #09090b; --bg-card: #18181b; --text: #fafafa; --text-muted: #a1a1aa; --border: #27272a; --primary: #f43f5e; --primary-hover: #e11d48; --success: #10b981; --danger: #ef4444; --warning: #f59e0b; }
* { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Inter', -apple-system, sans-serif; }
body { background: var(--bg); color: var(--text); line-height: 1.6; min-height: 100vh; display: flex; flex-direction: column; }
a { color: var(--primary); text-decoration: none; transition: 0.2s; }
a:hover { opacity: 0.8; }

/* NAVBAR */
.navbar { background: rgba(9,9,11,0.9); backdrop-filter: blur(12px); border-bottom: 1px solid var(--border); padding: 15px 20px; position: sticky; top: 0; z-index: 100; display: flex; justify-content: center; }
.nav-inner { max-width: 600px; width: 100%; display: flex; justify-content: space-between; align-items: center; }
.logo { font-size: 1.2em; font-weight: 800; display: flex; align-items: center; gap: 8px; }
.logo i { color: var(--primary); }
.nav-links a { font-size: 0.9em; font-weight: 600; margin-left: 15px; color: var(--text-muted); }
.nav-links a:hover { color: var(--text); }

/* CONTAINER */
.container { max-width: 600px; margin: 0 auto; padding: 40px 20px; width: 100%; flex: 1; }
.auth-container { max-width: 400px; margin: 60px auto; width: 100%; padding: 0 20px; }

/* CARDS */
.card { background: var(--bg-card); border: 1px solid var(--border); border-radius: 24px; padding: 30px; }
.card-center { text-align: center; }

/* FORMS */
.form-group { margin-bottom: 20px; }
.form-group label { display: block; margin-bottom: 8px; font-weight: 600; font-size: 0.9em; color: var(--text-muted); }
.form-group input, .form-group textarea { width: 100%; padding: 15px 20px; border: 1px solid var(--border); border-radius: 16px; background: var(--bg); color: var(--text); font-family: inherit; font-size: 1em; outline: none; transition: 0.2s; }
.form-group input:focus, .form-group textarea:focus { border-color: var(--primary); box-shadow: 0 0 0 3px rgba(244,63,94,0.15); }
.form-group textarea { resize: vertical; min-height: 120px; }

/* BUTTONS */
.btn { padding: 14px 24px; border-radius: 16px; border: none; font-weight: 700; font-family: inherit; font-size: 1em; cursor: pointer; display: inline-flex; align-items: center; justify-content: center; gap: 8px; transition: 0.2s; text-decoration: none; }
.btn-primary { background: var(--primary); color: #fff; }
.btn-primary:hover { background: var(--primary-hover); transform: translateY(-1px); }
.btn-outline { background: transparent; border: 2px solid var(--border); color: var(--text); }
.btn-outline:hover { border-color: var(--primary); color: var(--primary); }
.btn-block { width: 100%; }
.btn-sm { padding: 8px 16px; font-size: 0.85em; border-radius: 12px; }

/* ALERTS */
.alert { padding: 15px 20px; border-radius: 12px; margin-bottom: 20px; font-size: 0.9em; text-align: center; }
.alert-success { background: rgba(16,185,129,0.1); color: var(--success); border: 1px solid rgba(16,185,129,0.2); }
.alert-error { background: rgba(239,68,68,0.1); color: var(--danger); border: 1px solid rgba(239,68,68,0.2); }

/* INBOX / MESSAGES */
.msg-card { background: var(--bg-card); border: 1px solid var(--border); border-radius: 20px; padding: 25px; margin-bottom: 15px; transition: 0.2s; }
.msg-card:hover { transform: translateY(-2px); border-color: rgba(255,255,255,0.15); }
.msg-content { font-size: 1.1em; line-height: 1.6; margin-bottom: 15px; word-wrap: break-word; }
.msg-time { font-size: 0.8em; color: var(--text-muted); display: flex; align-items: center; gap: 6px; }

/* PROFILE HEADER */
.profile-header { text-align: center; margin-bottom: 30px; }
.profile-avatar { width: 80px; height: 80px; border-radius: 50%; background: linear-gradient(135deg, var(--primary), #f43f5e); display: flex; align-items: center; justify-content: center; font-size: 2em; font-weight: 800; color: #fff; margin: 0 auto 15px; box-shadow: 0 10px 30px rgba(244,63,94,0.3); }
.profile-name { font-size: 1.5em; font-weight: 800; margin-bottom: 5px; }
.profile-link { color: var(--text-muted); font-size: 0.9em; margin-bottom: 20px; }

/* FOOTER */
.footer { text-align: center; padding: 30px 20px; color: var(--text-muted); font-size: 0.85em; border-top: 1px solid var(--border); margin-top: auto; }
CSSEOF

# HEADER & FOOTER
cat > "$WEB_ROOT/includes/header.php" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title><?= $pageTitle ?? 'Home' ?> — <?= SITE_NAME ?></title>
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>💬</text></svg>">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
<link rel="stylesheet" href="/assets/css/style.css">
</head>
<body>
HTMLEOF

cat > "$WEB_ROOT/includes/navbar.php" << 'HTMLEOF'
<nav class="navbar">
    <div class="nav-inner">
        <a href="/" class="logo"><i class="fas fa-comment-dots"></i> RendzzNGL</a>
        <div class="nav-links">
            <?php if (isLoggedIn()): ?>
                <a href="/inbox.php">Inbox</a>
                <?php if (isAdmin()): ?><a href="/<?= ADMIN_PATH ?>/" style="color:var(--warning)">Admin</a><?php endif; ?>
                <a href="/logout.php">Logout</a>
            <?php else: ?>
                <a href="/login.php">Login</a>
                <a href="/register.php" style="color:var(--primary)">Daftar</a>
            <?php endif; ?>
        </div>
    </div>
</nav>
HTMLEOF

cat > "$WEB_ROOT/includes/footer.php" << 'HTMLEOF'
<footer class="footer">
    <p>&copy; <?= date('Y') ?> <?= SITE_NAME ?>. All rights reserved.</p>
</footer>
</body>
</html>
HTMLEOF

# ============ STEP 5: HALAMAN ============
echo -e "${CYAN}[5/5] Halaman...${NC}"

# HOME
cat > "$WEB_ROOT/index.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
$pageTitle = 'Kirim Pesan Anonim';
include __DIR__ . '/includes/header.php';
include __DIR__ . '/includes/navbar.php';
?>
<div class="container" style="text-align:center; padding-top:60px;">
    <h1 style="font-size:2.8em; margin-bottom:15px; font-weight:800;">Kirim Pesan<br>Secara <span style="color:var(--primary)">Anonim</span></h1>
    <p style="color:var(--text-muted); font-size:1.1em; margin-bottom:40px; max-width:400px; margin-left:auto; margin-right:auto;">Buat link unikmu sendiri dan terima pesan dari siapa pun tanpa mereka ketahuan siapa!</p>
    
    <div style="display:flex; gap:10px; justify-content:center; flex-wrap:wrap;">
        <?php if (isLoggedIn()): ?>
            <a href="/profile.php" class="btn btn-primary" style="font-size:1.1em; padding:16px 32px;"><i class="fas fa-link"></i> Link Saya</a>
            <a href="/inbox.php" class="btn btn-outline" style="font-size:1.1em; padding:16px 32px;"><i class="fas fa-envelope"></i> Buka Inbox</a>
        <?php else: ?>
            <a href="/register.php" class="btn btn-primary" style="font-size:1.1em; padding:16px 32px;"><i class="fas fa-rocket"></i> Mulai Sekarang</a>
            <a href="/login.php" class="btn btn-outline" style="font-size:1.1em; padding:16px 32px;">Login</a>
        <?php endif; ?>
    </div>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# LOGIN
cat > "$WEB_ROOT/login.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
if (isLoggedIn()) { header('Location: /inbox.php'); exit; }
$err = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $u = trim($_POST['username']); $p = $_POST['password'];
    $s = $pdo->prepare("SELECT * FROM users WHERE username=?"); $s->execute([$u]);
    $user = $s->fetch();
    if ($user && password_verify($p, $user['password'])) {
        if ($user['status'] === 'banned') { $err = 'Akun kamu dibanned!'; }
        else {
            $_SESSION['user_id'] = $user['id']; $_SESSION['username'] = $user['username']; $_SESSION['role'] = $user['role'];
            header('Location: /inbox.php'); exit;
        }
    } else { $err = 'Username/Password salah!'; }
}
$pageTitle = 'Login';
include __DIR__ . '/includes/header.php'; include __DIR__ . '/includes/navbar.php';
?>
<div class="auth-container">
    <div class="card">
        <h2 class="card-center" style="margin-bottom:25px">Login</h2>
        <?php if ($err): ?><div class="alert alert-error"><?= $err ?></div><?php endif; ?>
        <form method="POST">
            <div class="form-group"><label>Username</label><input type="text" name="username" required autofocus></div>
            <div class="form-group"><label>Password</label><input type="password" name="password" required></div>
            <button class="btn btn-primary btn-block">Masuk</button>
        </form>
        <p style="text-align:center; margin-top:20px; font-size:0.9em; color:var(--text-muted)">Belum punya link? <a href="/register.php">Buat Sekarang</a></p>
    </div>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# REGISTER
cat > "$WEB_ROOT/register.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
if (isLoggedIn()) { header('Location: /inbox.php'); exit; }
$err = ''; $succ = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $u = strtolower(trim($_POST['username'])); $e = trim($_POST['email']);
    $p = $_POST['password'];
    
    if (!preg_match('/^[a-zA-Z0-9._]+$/', $u)) { $err = 'Username hanya boleh huruf, angka, titik, underscore.'; }
    elseif (strlen($u) < 3) { $err = 'Username minimal 3 karakter'; }
    elseif (strlen($p) < 6) { $err = 'Password minimal 6 karakter'; }
    else {
        $s = $pdo->prepare("SELECT id FROM users WHERE username=? OR email=?"); $s->execute([$u, $e]);
        if ($s->fetch()) { $err = 'Username atau Email sudah dipakai!'; }
        else {
            $h = password_hash($p, PASSWORD_BCRYPT);
            $pdo->prepare("INSERT INTO users (username, email, password) VALUES (?,?,?)")->execute([$u, $e, $h]);
            $succ = 'Berhasil! Silakan login.';
        }
    }
}
$pageTitle = 'Daftar Link';
include __DIR__ . '/includes/header.php'; include __DIR__ . '/includes/navbar.php';
?>
<div class="auth-container">
    <div class="card">
        <h2 class="card-center" style="margin-bottom:10px">Buat Link Kamu</h2>
        <p class="card-center" style="font-size:0.9em;color:var(--text-muted);margin-bottom:25px">Orang lain akan mengirim pesan via link ini.</p>
        <?php if ($err): ?><div class="alert alert-error"><?= $err ?></div><?php endif; ?>
        <?php if ($succ): ?><div class="alert alert-success"><?= $succ ?> <a href="/login.php">Login</a></div><?php endif; ?>
        <form method="POST">
            <div class="form-group">
                <label>Username Unik Kamu</label>
                <div style="display:flex;align-items:center;background:var(--bg);border:1px solid var(--border);border-radius:16px;overflow:hidden">
                    <span style="padding:0 0 0 20px;color:var(--text-muted);font-size:0.9em"><?= parse_url(SITE_URL, PHP_URL_HOST) ?>/u/</span>
                    <input type="text" name="username" placeholder="rendzz" required style="border:none;background:transparent;padding-left:5px;">
                </div>
            </div>
            <div class="form-group"><label>Email (untuk recovery)</label><input type="email" name="email" required></div>
            <div class="form-group"><label>Password</label><input type="password" name="password" required></div>
            <button class="btn btn-primary btn-block">Klaim Link</button>
        </form>
    </div>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# INBOX (Dashboard User)
cat > "$WEB_ROOT/inbox.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
requireLogin();
$uid = $_SESSION['user_id'];
$s = $pdo->prepare("SELECT * FROM users WHERE id=?"); $s->execute([$uid]); $me = $s->fetch();

$msgs = $pdo->prepare("SELECT * FROM messages WHERE user_id=? ORDER BY id DESC");
$msgs->execute([$uid]); $msgs = $msgs->fetchAll();

$pageTitle = 'Inbox';
include __DIR__ . '/includes/header.php'; include __DIR__ . '/includes/navbar.php';
?>
<div class="container">
    <div class="profile-header">
        <div class="profile-avatar"><?= strtoupper(substr($me['username'], 0, 1)) ?></div>
        <h1 class="profile-name">@<?= htmlspecialchars($me['username']) ?></h1>
        <p class="profile-link"><?= SITE_URL ?>/u/<?= htmlspecialchars($me['username']) ?></p>
        
        <div style="display:flex; gap:10px; justify-content:center; flex-wrap:wrap">
            <button class="btn btn-primary" onclick="copyLink('<?= SITE_URL ?>/u/<?= htmlspecialchars($me['username']) ?>')">
                <i class="fas fa-copy"></i> Copy Link
            </button>
            <a href="https://wa.me/?text=Kirim%20pesan%20anonim%20ke%20aku%20di%20<?= urlencode(SITE_URL . '/u/' . $me['username']) ?>" target="_blank" class="btn btn-outline" style="color:var(--success);border-color:var(--success)">
                <i class="fab fa-whatsapp"></i> Share WA
            </a>
        </div>
    </div>

    <h3 style="margin-bottom:20px; display:flex; align-items:center; gap:10px">
        <i class="fas fa-envelope-open-text" style="color:var(--primary)"></i> Kotak Masuk
    </h3>

    <?php if (empty($msgs)): ?>
        <div class="card card-center" style="color:var(--text-muted)">
            <i class="fas fa-inbox" style="font-size:3em; margin-bottom:15px; opacity:0.5"></i>
            <p>Belum ada pesan. Share link kamu biar dapet pesan anonim!</p>
        </div>
    <?php else: foreach ($msgs as $m): ?>
        <div class="msg-card">
            <div class="msg-content"><?= nl2br(htmlspecialchars($m['content'])) ?></div>
            <div class="msg-time"><i class="fas fa-clock"></i> <?= timeAgo($m['created_at']) ?></div>
        </div>
    <?php endforeach; endif; ?>
</div>

<script>
function copyLink(text) {
    navigator.clipboard.writeText(text).then(() => alert('Link berhasil dicopy!'));
}
</script>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# VIEW PROFILE /u/username (Tempat Kirim Pesan)
cat > "$WEB_ROOT/u.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';

// Ambil username dari URL (jika pakai .htaccess rewrite)
$username = $_GET['u'] ?? '';
if (!$username) { header('Location: /'); exit; }

$s = $pdo->prepare("SELECT * FROM users WHERE username=? AND status='active'");
$s->execute([$username]);
$target = $s->fetch();

if (!$target) { die("<div style='text-align:center;padding:50px;font-family:sans-serif'><h2>User tidak ditemukan atau dibanned.</h2><a href='/'>Kembali</a></div>"); }

$msg = ''; $err = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $content = trim($_POST['message']);
    if (empty($content)) { $err = 'Pesan tidak boleh kosong!'; }
    elseif (strlen($content) > 1000) { $err = 'Maksimal 1000 karakter!'; }
    else {
        $ip = $_SERVER['REMOTE_ADDR'];
        $pdo->prepare("INSERT INTO messages (user_id, content, sender_ip) VALUES (?,?,?)")->execute([$target['id'], $content, $ip]);
        $msg = 'Pesan berhasil dikirim secara anonim!';
    }
}

$pageTitle = 'Kirim Pesan ke @' . $target['username'];
include __DIR__ . '/includes/header.php'; include __DIR__ . '/includes/navbar.php';
?>
<div class="auth-container">
    <div class="card">
        <div class="profile-header" style="margin-bottom:20px">
            <div class="profile-avatar" style="width:60px;height:60px;font-size:1.5em"><?= strtoupper(substr($target['username'], 0, 1)) ?></div>
            <h1 class="profile-name" style="font-size:1.3em">Kirim pesan ke @<?= htmlspecialchars($target['username']) ?></h1>
            <p style="color:var(--text-muted);font-size:0.9em">100% Anonim. Mereka tidak akan tahu siapa kamu.</p>
        </div>

        <?php if ($msg): ?><div class="alert alert-success"><?= $msg ?></div><?php endif; ?>
        <?php if ($err): ?><div class="alert alert-error"><?= $err ?></div><?php endif; ?>

        <form method="POST">
            <div class="form-group">
                <textarea name="message" placeholder="Tulis pesan rahasia kamu di sini..." maxlength="1000" required></textarea>
            </div>
            <button class="btn btn-primary btn-block"><i class="fas fa-paper-plane"></i> Kirim Anonim</button>
        </form>
    </div>
</div>
<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# LOGOUT
cat > "$WEB_ROOT/logout.php" << 'PHPEOF'
<?php session_start(); session_destroy(); header('Location: /'); exit; ?>
PHPEOF

# ============ ADMIN PANEL ============
echo -e "${CYAN}📝 Admin Panel (x-panel-core)...${NC}"

# LOGIN ADMIN
cat > "$WEB_ROOT/x-panel-core/login.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
if (isAdmin()) { header('Location: /'.ADMIN_PATH.'/'); exit; }
$err = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $u = trim($_POST['username']); $p = $_POST['password'];
    $s = $pdo->prepare("SELECT * FROM users WHERE username=? AND role='admin'"); $s->execute([$u]);
    $user = $s->fetch();
    if ($user && password_verify($p, $user['password'])) {
        $_SESSION['user_id'] = $user['id']; $_SESSION['username'] = $user['username']; $_SESSION['role'] = 'admin';
        header('Location: /'.ADMIN_PATH.'/'); exit;
    } else { $err = 'Akses ditolak!'; }
}
?>
<!DOCTYPE html>
<html lang="id">
<head><meta charset="UTF-8"><title>Admin Access</title><link rel="stylesheet" href="/assets/css/style.css"></head>
<body style="background:#050508">
<div style="min-height:100vh; display:flex; align-items:center; justify-content:center; padding:20px;">
    <div class="card" style="max-width:400px;width:100%;text-align:center;">
        <i class="fas fa-shield-alt" style="font-size:3em;color:var(--primary);margin-bottom:15px"></i>
        <h2>Restricted Area</h2>
        <?php if ($err): ?><div class="alert alert-error"><?= $err ?></div><?php endif; ?>
        <form method="POST" style="text-align:left;margin-top:20px">
            <div class="form-group"><label>Username</label><input type="text" name="username" required></div>
            <div class="form-group"><label>Password</label><input type="password" name="password" required></div>
            <button class="btn btn-primary btn-block">Login Admin</button>
        </form>
    </div>
</div>
</body></html>
PHPEOF

# DASHBOARD ADMIN (Pantau Pesan & Ban User)
cat > "$WEB_ROOT/x-panel-core/index.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/../includes/config.php';
requireAdmin();

$msg = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    $uid = (int)$_POST['uid'];
    if ($_POST['action'] === 'ban') {
        $pdo->prepare("UPDATE users SET status='banned' WHERE id=? AND role='user'")->execute([$uid]);
        $msg = 'User dibanned! Link mereka tidak bisa diakses.';
    } elseif ($_POST['action'] === 'unban') {
        $pdo->prepare("UPDATE users SET status='active' WHERE id=? AND role='user'")->execute([$uid]);
        $msg = 'User diaktifkan kembali.';
    } elseif ($_POST['action'] === 'delete_msg') {
        $mid = (int)$_POST['mid'];
        $pdo->prepare("DELETE FROM messages WHERE id=?")->execute([$mid]);
        $msg = 'Pesan dihapus.';
    }
}

$users = $pdo->query("SELECT u.*, (SELECT COUNT(*) FROM messages WHERE user_id=u.id) as total_msg FROM users u WHERE u.role='user' ORDER BY u.id DESC")->fetchAll();
$recentMsgs = $pdo->query("SELECT m.*, u.username FROM messages m JOIN users u ON m.user_id=u.id ORDER BY m.id DESC LIMIT 50")->fetchAll();
?>
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8"><title>Admin Panel</title>
<link rel="stylesheet" href="/assets/css/style.css">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
</head>
<body>
<nav class="navbar" style="background:#0a0a0f">
    <div class="nav-inner" style="max-width:1000px">
        <a href="/x-panel-core/" class="logo" style="color:var(--warning)"><i class="fas fa-shield-alt"></i> ADMIN NGL</a>
        <div class="nav-links"><a href="/" target="_blank">Lihat Web</a><a href="/logout.php" style="color:var(--danger)">Logout</a></div>
    </div>
</nav>
<div class="container" style="max-width:1000px">
    <?php if ($msg): ?><div class="alert alert-success"><?= $msg ?></div><?php endif; ?>

    <div class="card" style="margin-bottom:30px">
        <h2 style="margin-bottom:20px;color:var(--primary)"><i class="fas fa-users"></i> Manajemen User</h2>
        <div style="overflow-x:auto">
            <table style="width:100%;text-align:left;border-collapse:collapse">
                <tr style="border-bottom:1px solid var(--border);color:var(--text-muted)">
                    <th style="padding:10px">Username</th><th>Link</th><th>Pesan</th><th>Status</th><th>Aksi</th>
                </tr>
                <?php foreach ($users as $u): ?>
                <tr style="border-bottom:1px solid var(--border)">
                    <td style="padding:15px 10px"><b>@<?= htmlspecialchars($u['username']) ?></b></td>
                    <td><a href="/u/<?= htmlspecialchars($u['username']) ?>" target="_blank" style="font-size:0.85em">/u/<?= htmlspecialchars($u['username']) ?></a></td>
                    <td><?= $u['total_msg'] ?></td>
                    <td><span class="badge" style="background:<?= $u['status']=='banned'?'rgba(239,68,68,0.15)':'rgba(16,185,129,0.15)' ?>;color:<?= $u['status']=='banned'?'var(--danger)':'var(--success)' ?>;padding:4px 8px;border-radius:6px;font-weight:bold"><?= strtoupper($u['status']) ?></span></td>
                    <td>
                        <form method="POST" style="display:inline">
                            <input type="hidden" name="uid" value="<?= $u['id'] ?>">
                            <?php if ($u['status'] == 'active'): ?>
                                <button name="action" value="ban" class="btn btn-sm" style="background:var(--danger);color:#fff;border-radius:8px" onclick="return confirm('Ban user ini?')">Ban</button>
                            <?php else: ?>
                                <button name="action" value="unban" class="btn btn-sm" style="background:var(--success);color:#fff;border-radius:8px">Unban</button>
                            <?php endif; ?>
                        </form>
                    </td>
                </tr>
                <?php endforeach; ?>
            </table>
        </div>
    </div>

    <div class="card">
        <h2 style="margin-bottom:20px;color:var(--primary)"><i class="fas fa-envelope"></i> Pantau Pesan (50 Terakhir)</h2>
        <div style="max-height:500px;overflow-y:auto">
            <?php foreach ($recentMsgs as $m): ?>
                <div style="padding:15px;border-bottom:1px solid var(--border)">
                    <div style="font-size:0.85em;color:var(--text-muted);margin-bottom:5px">
                        Ke: <b>@<?= htmlspecialchars($m['username']) ?></b> | IP: <?= htmlspecialchars($m['sender_ip']) ?> | <?= date('d/m H:i', strtotime($m['created_at'])) ?>
                    </div>
                    <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:15px">
                        <p><?= nl2br(htmlspecialchars($m['content'])) ?></p>
                        <form method="POST" style="flex-shrink:0">
                            <input type="hidden" name="mid" value="<?= $m['id'] ?>">
                            <button name="action" value="delete_msg" style="background:transparent;border:none;color:var(--danger);cursor:pointer"><i class="fas fa-trash"></i></button>
                        </form>
                    </div>
                </div>
            <?php endforeach; ?>
        </div>
    </div>
</div>
</body>
</html>
PHPEOF

# ============ NGINX REWRITE (Agar /u/username jalan) ============
cat > "$NGINX_CONF" << NGINXEOF
server {
    listen 80;
    listen [::]:80;
    server_name $SUBDOMAIN;
    root $WEB_ROOT;
    index index.php index.html;

    # Route /u/username ke u.php?u=username
    location ~ ^/u/([a-zA-Z0-9._]+)\$ {
        rewrite ^/u/([a-zA-Z0-9._]+)\$ /u.php?u=\$1 last;
    }

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    }
}
NGINXEOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/ 2>/dev/null
[[ -f /etc/nginx/sites-enabled/default ]] && rm -f /etc/nginx/sites-enabled/default

nginx -t >/dev/null 2>&1 && systemctl reload nginx || { nginx -t; exit 1; }

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

clear
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ RENDZZ NGL BERHASIL DI-INSTALL!        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🔗 URL Publik:${NC}"
echo -e "  Home    : $PROTO://$SUBDOMAIN"
echo -e "  Contoh Link User: $PROTO://$SUBDOMAIN/u/rendzz"
echo ""
echo -e "${MAGENTA}🔒 Admin Panel (Hidden):${NC}"
echo -e "  URL     : $PROTO://$SUBDOMAIN/x-panel-core"
echo -e "  User    : admin"
echo -e "  Pass    : $ADMIN_PASS"
echo ""
echo -e "${GREEN}🎉 Selesai!${NC}"
