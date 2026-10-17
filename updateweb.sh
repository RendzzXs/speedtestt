#!/bin/bash
# ============================================
#   🚀 RENDZZ TOOLS — UPDATE v2.0
#   Tambah TikTok Downloader + 10 Tools
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🚀 RENDZZ TOOLS v2.0 — UPDATE             ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

read -p "👉 Subdomain (contoh: tools.voltxyz.my.id): " SUBDOMAIN
WEB_ROOT="/var/www/$SUBDOMAIN"

[[ ! -d "$WEB_ROOT" ]] && { echo -e "${RED}❌ Folder tidak ada: $WEB_ROOT${NC}"; exit 1; }

echo -e "${GREEN}📁 Web root: $WEB_ROOT${NC}"

# ============ STEP 1: API TIKTOK ============
echo -e "${CYAN}[1/3] API TikTok Downloader...${NC}"

cat > "$WEB_ROOT/api/tiktok.php" << 'PHPEOF'
<?php
header('Content-Type: application/json');

$url = $_GET['url'] ?? '';
if (!$url || !preg_match('/tiktok\.com/i', $url)) {
    echo json_encode(['ok' => false, 'error' => 'URL TikTok tidak valid']);
    exit;
}

// === COBA YuuLabs API dulu ===
$tryYuuLabs = function($url) {
    $api = "https://api.yuulabs.web.id/api/downloader/tiktok?url=" . urlencode($url);
    $ch = curl_init($api);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 30,
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_HTTPHEADER => [
            'User-Agent: Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 Chrome/130.0.6723.86 Mobile Safari/537.36'
        ]
    ]);
    $res = curl_exec($ch);
    curl_close($ch);
    if (!$res) return null;
    $data = json_decode($res, true);
    if (!($data['status'] ?? false) || empty($data['result'])) return null;

    $r = $data['result'];
    $downloads = [];
    if (!empty($r['videoUrl'])) $downloads[] = ['type'=>'nowatermark','label'=>'Video Tanpa Watermark','url'=>$r['videoUrl']];
    if (!empty($r['hdVideo'])) $downloads[] = ['type'=>'nowatermark_hd','label'=>'Video HD','url'=>$r['hdVideo']];
    if (!empty($r['audioUrl'])) $downloads[] = ['type'=>'mp3','label'=>'Audio MP3','url'=>$r['audioUrl']];
    if (empty($downloads)) return null;

    return [
        'title' => $r['description'] ?? '',
        'author' => $r['author'] ?? '',
        'cover' => $r['cover'] ?? null,
        'downloads' => $downloads
    ];
};

// === FALLBACK: TikTok oEmbed + Direct API (public) ===
$tryPublicApi = function($url) {
    // Ambil ID video dari URL
    if (!preg_match('/(?:video|photo)\/(\d+)/', $url, $m)) return null;
    $videoId = $m[1];

    // API publik (dari tiktok.com sendiri via oembed)
    $ch = curl_init("https://www.tiktok.com/oembed?url=" . urlencode($url));
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 20,
        CURLOPT_SSL_VERIFYPEER => false
    ]);
    $meta = json_decode(curl_exec($ch), true);
    curl_close($ch);

    // Fallback tanpa watermark via tikwm
    $ch = curl_init("https://tikwm.com/api/?url=" . urlencode($url));
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 30,
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_HTTPHEADER => ['User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0']
    ]);
    $res = curl_exec($ch);
    curl_close($ch);

    if ($res) {
        $data = json_decode($res, true);
        if (($data['code'] ?? 0) === 0 && !empty($data['data'])) {
            $d = $data['data'];
            $downloads = [];
            if (!empty($d['play'])) $downloads[] = ['type'=>'nowatermark','label'=>'Video Tanpa Watermark','url'=>$d['play']];
            if (!empty($d['hdplay'])) $downloads[] = ['type'=>'nowatermark_hd','label'=>'Video HD','url'=>$d['hdplay']];
            if (!empty($d['music'])) $downloads[] = ['type'=>'mp3','label'=>'Audio MP3','url'=>$d['music']];

            if (!empty($downloads)) {
                return [
                    'title' => $d['title'] ?? ($meta['title'] ?? ''),
                    'author' => $d['author']['unique_id'] ?? ($meta['author_name'] ?? ''),
                    'cover' => $d['cover'] ?? ($meta['thumbnail_url'] ?? null),
                    'downloads' => $downloads
                ];
            }
        }
    }
    return null;
};

// === COBA SEMUA CARA ===
$result = $tryYuuLabs($url);
$source = 'YuuLabs';

if (!$result) {
    $result = $tryPublicApi($url);
    $source = 'TikWM';
}

if (!$result) {
    echo json_encode(['ok' => false, 'error' => 'Gagal download. Server API sedang down atau URL tidak valid.']);
    exit;
}

echo json_encode(['ok' => true, 'source' => $source, 'result' => $result]);
PHPEOF

# ============ STEP 2: API TOOLS BARU ============
echo -e "${CYAN}[2/3] API Tools baru...${NC}"

# QR Generator
cat > "$WEB_ROOT/api/qr.php" << 'PHPEOF'
<?php
header('Content-Type: application/json');
$text = $_GET['text'] ?? '';
$size = (int)($_GET['size'] ?? 300);
if (!$text) { echo json_encode(['ok'=>false,'error'=>'Text required']); exit; }
if ($size < 100 || $size > 1000) $size = 300;

// Pakai API gratis qrserver.com
$qrUrl = "https://api.qrserver.com/v1/create-qr-code/?size={$size}x{$size}&data=" . urlencode($text);
echo json_encode(['ok'=>true, 'url'=>$qrUrl]);
PHPEOF

# Base64 / Hash / Text Tools
cat > "$WEB_ROOT/api/texttools.php" << 'PHPEOF'
<?php
header('Content-Type: application/json');
$action = $_GET['action'] ?? '';
$text = $_GET['text'] ?? '';

if (!$text && $action !== 'hash') { echo json_encode(['ok'=>false,'error'=>'Text required']); exit; }

switch ($action) {
    case 'base64_encode':
        echo json_encode(['ok'=>true, 'result'=>base64_encode($text)]);
        break;
    case 'base64_decode':
        $d = base64_decode($text, true);
        if ($d === false) echo json_encode(['ok'=>false,'error'=>'Base64 tidak valid']);
        else echo json_encode(['ok'=>true, 'result'=>$d]);
        break;
    case 'url_encode':
        echo json_encode(['ok'=>true, 'result'=>urlencode($text)]);
        break;
    case 'url_decode':
        echo json_encode(['ok'=>true, 'result'=>urldecode($text)]);
        break;
    case 'uppercase':
        echo json_encode(['ok'=>true, 'result'=>strtoupper($text)]);
        break;
    case 'lowercase':
        echo json_encode(['ok'=>true, 'result'=>strtolower($text)]);
        break;
    case 'title':
        echo json_encode(['ok'=>true, 'result'=>ucwords(strtolower($text))]);
        break;
    case 'reverse':
        echo json_encode(['ok'=>true, 'result'=>strrev($text)]);
        break;
    case 'word_count':
        $words = str_word_count($text);
        $chars = strlen($text);
        $chars_no_space = strlen(preg_replace('/\s+/', '', $text));
        $lines = substr_count($text, "\n") + 1;
        echo json_encode(['ok'=>true, 'result'=>['words'=>$words, 'chars'=>$chars, 'chars_no_space'=>$chars_no_space, 'lines'=>$lines]]);
        break;
    case 'hash':
        $algo = $_GET['algo'] ?? 'sha256';
        $allowed = ['md5','sha1','sha256','sha512'];
        if (!in_array($algo, $allowed)) { echo json_encode(['ok'=>false,'error'=>'Algo tidak support']); exit; }
        echo json_encode(['ok'=>true, 'algo'=>$algo, 'result'=>hash($algo, $text)]);
        break;
    default:
        echo json_encode(['ok'=>false,'error'=>'Action tidak dikenal']);
}
PHPEOF

# Shortlink Unshortener
cat > "$WEB_ROOT/api/unshorten.php" << 'PHPEOF'
<?php
header('Content-Type: application/json');
$url = $_GET['url'] ?? '';
if (!$url) { echo json_encode(['ok'=>false,'error'=>'URL required']); exit; }

$ch = curl_init($url);
curl_setopt_array($ch, [
    CURLOPT_NOBODY => true,
    CURLOPT_FOLLOWLOCATION => true,
    CURLOPT_TIMEOUT => 15,
    CURLOPT_SSL_VERIFYPEER => false,
    CURLOPT_USERAGENT => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0'
]);
curl_exec($ch);
$final = curl_getinfo($ch, CURLINFO_EFFECTIVE_URL);
$code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo json_encode(['ok'=>true, 'url'=>$final, 'status'=>$code]);
PHPEOF

# Text to Speech (gratis via Google Translate TTS)
cat > "$WEB_ROOT/api/tts.php" << 'PHPEOF'
<?php
header('Content-Type: application/json');
$text = $_GET['text'] ?? '';
$lang = $_GET['lang'] ?? 'id';
if (!$text) { echo json_encode(['ok'=>false,'error'=>'Text required']); exit; }
if (strlen($text) > 200) { echo json_encode(['ok'=>false,'error'=>'Maksimal 200 karakter per request']); exit; }

$url = "https://translate.google.com/translate_tts?ie=UTF-8&q=" . urlencode($text) . "&tl={$lang}&client=tw-ob";
echo json_encode(['ok'=>true, 'url'=>$url]);
PHPEOF

echo -e "${GREEN}  ✓ API OK${NC}"

# ============ STEP 3: UPDATE CSS & UI ============
echo -e "${CYAN}[3/3] Update UI + semua tools...${NC}"

# Update index.php dengan semua tools
cat > "$WEB_ROOT/index.php" << 'PHPEOF'
<?php
require_once __DIR__ . '/includes/config.php';
$pageTitle = 'Tools Lengkap';
include __DIR__ . '/includes/header.php';
include __DIR__ . '/includes/navbar.php';
?>

<div class="container">
    <!-- HERO -->
    <div class="hero">
        <h1>Speed Test <span>by Rendzz Official</span></h1>
        <p>Speedtest, TikTok Downloader, Cek IMEI, QR Code, dan banyak tools gratis lainnya. Tanpa Iklan!</p>
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
        <h2 class="grid-title"><i class="fas fa-toolbox"></i> Semua Tools</h2>
        <div class="tools-grid">

            <div class="tool-card" onclick="showPanel('panel-tiktok')">
                <div class="tool-icon" style="background:linear-gradient(135deg,#000,#25F4EE)"><i class="fab fa-tiktok"></i></div>
                <h3>TikTok Downloader</h3>
                <p>Download video tanpa watermark + MP3</p>
            </div>

            <div class="tool-card" onclick="showPanel('panel-imei')">
                <div class="tool-icon" style="background:linear-gradient(135deg,#10b981,#059669)"><i class="fas fa-mobile-screen"></i></div>
                <h3>Cek IMEI Kemenperin</h3>
                <p>Cek status legalitas HP dari IMEI</p>
            </div>

            <div class="tool-card" onclick="showPanel('panel-qr')">
                <div class="tool-icon" style="background:linear-gradient(135deg,#f59e0b,#d97706)"><i class="fas fa-qrcode"></i></div>
                <h3>QR Code Generator</h3>
                <p>Generate QR dari teks atau link</p>
            </div>

            <div class="tool-card" onclick="showPanel('panel-ip')">
                <div class="tool-icon" style="background:linear-gradient(135deg,#3b82f6,#2563eb)"><i class="fas fa-location-dot"></i></div>
                <h3>IP Lookup</h3>
                <p>Cek lokasi & ISP dari IP Address</p>
            </div>

            <div class="tool-card" onclick="showPanel('panel-dns')">
                <div class="tool-icon" style="background:linear-gradient(135deg,#8b5cf6,#7c3aed)"><i class="fas fa-server"></i></div>
                <h3>DNS Lookup</h3>
                <p>Lihat record DNS domain</p>
            </div>

            <div class="tool-card" onclick="showPanel('panel-unshorten')">
                <div class="tool-icon" style="background:linear-gradient(135deg,#ec4899,#db2777)"><i class="fas fa-link"></i></div>
                <h3>Unshortlink</h3>
                <p>Bongkar URL asli dari shortlink</p>
            </div>

            <div class="tool-card" onclick="showPanel('panel-hash')">
                <div class="tool-icon" style="background:linear-gradient(135deg,#ef4444,#dc2626)"><i class="fas fa-lock"></i></div>
                <h3>Hash Generator</h3>
                <p>MD5, SHA1, SHA256, SHA512</p>
            </div>

            <div class="tool-card" onclick="showPanel('panel-text')">
                <div class="tool-icon" style="background:linear-gradient(135deg,#06b6d4,#0891b2)"><i class="fas fa-font"></i></div>
                <h3>Text Tools</h3>
                <p>Base64, URL encode, word counter</p>
            </div>

            <div class="tool-card" onclick="showPanel('panel-tts')">
                <div class="tool-icon" style="background:linear-gradient(135deg,#f97316,#ea580c)"><i class="fas fa-volume-high"></i></div>
                <h3>Text to Speech</h3>
                <p>Ubah teks jadi suara (Indonesia)</p>
            </div>
        </div>
    </div>

    <!-- ============ PANEL: TIKTOK ============ -->
    <div id="panel-tiktok" class="panel">
        <h2><i class="fab fa-tiktok"></i> TikTok Downloader</h2>
        <div class="form-group">
            <label>Paste URL TikTok</label>
            <input type="text" id="tiktokUrl" placeholder="https://www.tiktok.com/@user/video/...">
        </div>
        <button class="btn" onclick="downloadTikTok()"><i class="fas fa-download"></i> Download</button>
        <button class="btn btn-outline" onclick="document.getElementById('panel-tiktok').classList.remove('active')">Tutup</button>
        <div id="tiktokResult" style="margin-top:20px;"></div>
    </div>

    <!-- ============ PANEL: IMEI ============ -->
    <div id="panel-imei" class="panel">
        <h2><i class="fas fa-mobile-screen"></i> Cek IMEI Kemenperin</h2>
        <div class="form-group">
            <label>Masukkan IMEI (14-16 digit)</label>
            <input type="text" id="imeiInput" placeholder="Contoh: 356938035643809" maxlength="16" inputmode="numeric">
        </div>
        <button class="btn" onclick="checkIMEI()"><i class="fas fa-search"></i> Cek IMEI</button>
        <button class="btn btn-outline" onclick="document.getElementById('panel-imei').classList.remove('active')">Tutup</button>
        <div id="imeiResult" style="margin-top:20px;"></div>
    </div>

    <!-- ============ PANEL: QR ============ -->
    <div id="panel-qr" class="panel">
        <h2><i class="fas fa-qrcode"></i> QR Code Generator</h2>
        <div class="form-group">
            <label>Teks atau URL</label>
            <input type="text" id="qrText" placeholder="https://example.com atau teks apapun">
        </div>
        <div class="form-group">
            <label>Ukuran (px)</label>
            <select id="qrSize">
                <option value="200">200x200</option>
                <option value="300" selected>300x300</option>
                <option value="500">500x500</option>
            </select>
        </div>
        <button class="btn" onclick="generateQR()"><i class="fas fa-qrcode"></i> Generate</button>
        <button class="btn btn-outline" onclick="document.getElementById('panel-qr').classList.remove('active')">Tutup</button>
        <div id="qrResult" style="text-align:center;margin-top:20px;"></div>
    </div>

    <!-- ============ PANEL: IP ============ -->
    <div id="panel-ip" class="panel">
        <h2><i class="fas fa-location-dot"></i> IP Address Lookup</h2>
        <div class="form-group">
            <label>IP Address</label>
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
            <label>Domain</label>
            <input type="text" id="domainInput" placeholder="google.com">
        </div>
        <button class="btn" onclick="lookupDNS()"><i class="fas fa-search"></i> Cek DNS</button>
        <button class="btn btn-outline" onclick="document.getElementById('panel-dns').classList.remove('active')">Tutup</button>
        <div class="result-box" id="dnsResult">Menunggu input...</div>
    </div>

    <!-- ============ PANEL: UNSHORTEN ============ -->
    <div id="panel-unshorten" class="panel">
        <h2><i class="fas fa-link"></i> Unshortlink</h2>
        <div class="form-group">
            <label>Shortlink URL</label>
            <input type="text" id="shortUrl" placeholder="https://bit.ly/xxx">
        </div>
        <button class="btn" onclick="unshorten()"><i class="fas fa-magnifying-glass"></i> Bongkar</button>
        <button class="btn btn-outline" onclick="document.getElementById('panel-unshorten').classList.remove('active')">Tutup</button>
        <div class="result-box" id="unshortResult">Menunggu input...</div>
    </div>

    <!-- ============ PANEL: HASH ============ -->
    <div id="panel-hash" class="panel">
        <h2><i class="fas fa-lock"></i> Hash Generator</h2>
        <div class="form-group">
            <label>Teks</label>
            <input type="text" id="hashText" placeholder="Masukkan teks">
        </div>
        <div class="form-group">
            <label>Algoritma</label>
            <select id="hashAlgo">
                <option value="md5">MD5</option>
                <option value="sha1">SHA-1</option>
                <option value="sha256" selected>SHA-256</option>
                <option value="sha512">SHA-512</option>
            </select>
        </div>
        <button class="btn" onclick="genHash()"><i class="fas fa-lock"></i> Generate Hash</button>
        <button class="btn btn-outline" onclick="document.getElementById('panel-hash').classList.remove('active')">Tutup</button>
        <div class="result-box" id="hashResult">Menunggu input...</div>
    </div>

    <!-- ============ PANEL: TEXT ============ -->
    <div id="panel-text" class="panel">
        <h2><i class="fas fa-font"></i> Text Tools</h2>
        <div class="form-group">
            <label>Teks</label>
            <textarea id="textInput" rows="4" placeholder="Masukkan teks..." style="width:100%;padding:12px;border:1px solid var(--border);border-radius:10px;background:var(--bg-input);color:var(--text);font-family:inherit;resize:vertical"></textarea>
        </div>
        <div style="display:flex;gap:8px;flex-wrap:wrap;margin-bottom:15px">
            <button class="btn" onclick="textTool('uppercase')">UPPER</button>
            <button class="btn" onclick="textTool('lowercase')">lower</button>
            <button class="btn" onclick="textTool('title')">Title Case</button>
            <button class="btn" onclick="textTool('reverse')">Reverse</button>
            <button class="btn" onclick="textTool('base64_encode')">Base64 Enc</button>
            <button class="btn" onclick="textTool('base64_decode')">Base64 Dec</button>
            <button class="btn" onclick="textTool('url_encode')">URL Enc</button>
            <button class="btn" onclick="textTool('url_decode')">URL Dec</button>
            <button class="btn" onclick="textTool('word_count')">Count</button>
        </div>
        <button class="btn btn-outline" onclick="document.getElementById('panel-text').classList.remove('active')">Tutup</button>
        <div class="result-box" id="textResult">Menunggu input...</div>
    </div>

    <!-- ============ PANEL: TTS ============ -->
    <div id="panel-tts" class="panel">
        <h2><i class="fas fa-volume-high"></i> Text to Speech</h2>
        <div class="form-group">
            <label>Teks (maks 200 karakter)</label>
            <textarea id="ttsText" rows="3" placeholder="Halo, selamat datang di Rendzz Tools!" style="width:100%;padding:12px;border:1px solid var(--border);border-radius:10px;background:var(--bg-input);color:var(--text);font-family:inherit"></textarea>
        </div>
        <div class="form-group">
            <label>Bahasa</label>
            <select id="ttsLang">
                <option value="id">Indonesia</option>
                <option value="en">English</option>
                <option value="ja">Jepang</option>
                <option value="ar">Arab</option>
                <option value="es">Spanyol</option>
            </select>
        </div>
        <button class="btn" onclick="speak()"><i class="fas fa-play"></i> Play</button>
        <button class="btn btn-outline" onclick="document.getElementById('panel-tts').classList.remove('active')">Tutup</button>
        <div id="ttsResult" style="margin-top:15px;"></div>
    </div>

</div>

<script>
// ============ TikTok Downloader ============
async function downloadTikTok() {
    const url = document.getElementById('tiktokUrl').value.trim();
    const box = document.getElementById('tiktokResult');
    if (!url) return;
    if (!url.includes('tiktok.com')) {
        box.innerHTML = '<div style="color:var(--danger);padding:10px">URL tidak valid. Pastikan link TikTok.</div>';
        return;
    }
    box.innerHTML = '<div style="text-align:center;padding:20px"><i class="fas fa-spinner fa-spin" style="font-size:2em;color:var(--primary)"></i><br><br>Downloading...</div>';

    try {
        const res = await fetch(`/api/tiktok.php?url=${encodeURIComponent(url)}`);
        const json = await res.json();

        if (!json.ok) {
            box.innerHTML = `<div style="background:rgba(239,68,68,.1);padding:15px;border-radius:10px;color:var(--danger);border-left:4px solid var(--danger)">${json.error}</div>`;
            return;
        }

        const r = json.result;
        box.innerHTML = `
            <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:16px;padding:20px">
                ${r.cover ? `<img src="${r.cover}" style="width:100%;max-width:300px;border-radius:12px;margin:0 auto 15px;display:block">` : ''}
                <h3 style="font-size:1em;margin-bottom:8px">${r.title || 'TikTok Video'}</h3>
                <p style="color:var(--text-muted);font-size:0.85em;margin-bottom:15px">@${r.author || 'unknown'} • Source: ${json.source}</p>
                <div style="display:flex;flex-direction:column;gap:8px">
                    ${r.downloads.map(d => `
                        <a href="${d.url}" target="_blank" class="btn" style="justify-content:flex-start;text-decoration:none">
                            <i class="fas fa-download"></i> ${d.label}
                        </a>
                    `).join('')}
                </div>
            </div>
        `;
    } catch(e) {
        box.innerHTML = `<div style="color:var(--danger);padding:10px">Error: ${e.message}</div>`;
    }
}

// ============ IMEI ============
async function checkIMEI() {
    const imei = document.getElementById('imeiInput').value.trim().replace(/\D/g, '');
    const resBox = document.getElementById('imeiResult');
    if (imei.length < 14 || imei.length > 16) {
        resBox.innerHTML = '<div style="background:rgba(239,68,68,.1);padding:15px;border-radius:10px;color:var(--danger);border-left:4px solid var(--danger)">IMEI harus 14-16 digit!</div>';
        return;
    }
    resBox.innerHTML = '<div style="text-align:center;padding:20px;color:var(--text-muted)"><i class="fas fa-spinner fa-spin" style="font-size:2em;color:var(--primary)"></i><br><br>Mencari data...</div>';
    try {
        const res = await fetch(`/api/imei.php?imei=${imei}`);
        const json = await res.json();
        if (!json.ok) {
            resBox.innerHTML = `<div style="background:rgba(239,68,68,.1);padding:15px;border-radius:10px;color:var(--danger)">${json.error}</div>`;
            return;
        }
        const data = json.data.data || json.data;
        resBox.innerHTML = `
            <div style="background:var(--bg-card);border:2px solid var(--primary);border-radius:16px;padding:20px">
                <div class="imei-row"><span class="k">IMEI</span><span class="v">${imei}</span></div>
                <div class="imei-row"><span class="k">Brand</span><span class="v">${data.brand || data.merk || '-'}</span></div>
                <div class="imei-row"><span class="k">Model</span><span class="v">${data.model || data.tipe || '-'}</span></div>
                <div class="imei-row"><span class="k">Status</span><span class="v" style="color:${(data.status||'').toLowerCase().includes('terdaftar')||(data.status||'').toLowerCase().includes('registered')?'var(--success)':'var(--warning)'}">${data.status || data.keterangan || 'Tidak diketahui'}</span></div>
            </div>
        `;
    } catch(e) {
        resBox.innerHTML = `<div style="background:rgba(239,68,68,.1);padding:15px;border-radius:10px;color:var(--danger)">Error: ${e.message}</div>`;
    }
}

// ============ QR Code ============
async function generateQR() {
    const text = document.getElementById('qrText').value.trim();
    const size = document.getElementById('qrSize').value;
    if (!text) return;
    const res = await fetch(`/api/qr.php?text=${encodeURIComponent(text)}&size=${size}`);
    const data = await res.json();
    if (data.ok) {
        document.getElementById('qrResult').innerHTML = `
            <img src="${data.url}" style="border-radius:12px;background:#fff;padding:10px">
            <p style="margin-top:10px"><a href="${data.url}" download="qrcode.png" class="btn">Download QR</a></p>
        `;
    }
}

// ============ IP Lookup ============
async function lookupIP() {
    const ip = document.getElementById('ipInput').value.trim();
    if (!ip) return;
    const box = document.getElementById('ipResult');
    box.textContent = 'Mencari...';
    const res = await fetch(`/api/iptools.php?action=lookup&ip=${ip}`);
    const d = await res.json();
    if (d.status === 'success') {
        box.textContent = `IP: ${d.query}\nProvider: ${d.isp}\nNegara: ${d.country} (${d.countryCode})\nKota: ${d.city}\nRegion: ${d.regionName}\nZona: ${d.timezone}`;
    } else box.textContent = 'IP tidak valid.';
}

// ============ DNS ============
async function lookupDNS() {
    const domain = document.getElementById('domainInput').value.trim();
    if (!domain) return;
    const box = document.getElementById('dnsResult');
    box.textContent = 'Mencari...';
    const res = await fetch(`/api/dns.php?domain=${domain}`);
    const d = await res.json();
    box.textContent = d.ok ? d.records.join('\n') : d.error;
}

// ============ Unshorten ============
async function unshorten() {
    const url = document.getElementById('shortUrl').value.trim();
    if (!url) return;
    const box = document.getElementById('unshortResult');
    box.textContent = 'Membongkar...';
    const res = await fetch(`/api/unshorten.php?url=${encodeURIComponent(url)}`);
    const d = await res.json();
    box.textContent = d.ok ? `URL Asli: ${d.url}\nHTTP Status: ${d.status}` : d.error;
}

// ============ Hash ============
async function genHash() {
    const text = document.getElementById('hashText').value.trim();
    const algo = document.getElementById('hashAlgo').value;
    if (!text) return;
    const box = document.getElementById('hashResult');
    box.textContent = 'Generating...';
    const res = await fetch(`/api/texttools.php?action=hash&algo=${algo}&text=${encodeURIComponent(text)}`);
    const d = await res.json();
    box.textContent = d.ok ? d.result : d.error;
}

// ============ Text Tools ============
async function textTool(action) {
    const text = document.getElementById('textInput').value;
    if (!text && action !== 'word_count') return;
    const box = document.getElementById('textResult');
    box.textContent = 'Processing...';
    const res = await fetch(`/api/texttools.php?action=${action}&text=${encodeURIComponent(text)}`);
    const d = await res.json();
    if (!d.ok) { box.textContent = d.error; return; }
    if (action === 'word_count') {
        box.textContent = `Kata: ${d.result.words}\nKarakter: ${d.result.chars}\nTanpa spasi: ${d.result.chars_no_space}\nBaris: ${d.result.lines}`;
    } else {
        box.textContent = d.result;
    }
}

// ============ TTS ============
async function speak() {
    const text = document.getElementById('ttsText').value.trim();
    const lang = document.getElementById('ttsLang').value;
    const box = document.getElementById('ttsResult');
    if (!text) return;
    box.innerHTML = 'Memuat audio...';
    const res = await fetch(`/api/tts.php?text=${encodeURIComponent(text)}&lang=${lang}`);
    const d = await res.json();
    if (d.ok) {
        box.innerHTML = `<audio controls autoplay src="${d.url}" style="width:100%"></audio>`;
    } else {
        box.innerHTML = `<div style="color:var(--danger)">${d.error}</div>`;
    }
}
</script>

<?php include __DIR__ . '/includes/footer.php'; ?>
PHPEOF

# ============ RESTART ============
chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"
systemctl restart php8.3-fpm

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ RENDZZ TOOLS v2.0 — UPDATE SELESAI!    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🎉 Tools yang baru ditambah:${NC}"
echo "  ✅ TikTok Downloader (YuuLabs + TikWM fallback)"
echo "  ✅ QR Code Generator"
echo "  ✅ Unshortlink Checker"
echo "  ✅ Hash Generator (MD5, SHA1, SHA256, SHA512)"
echo "  ✅ Text Tools (Base64, URL encode, count, dll)"
echo "  ✅ Text to Speech (Indonesia + 4 bahasa)"
echo ""
echo "🌐 Buka: https://$SUBDOMAIN"
echo "💡 Refresh dengan Ctrl+Shift+R"
echo ""
