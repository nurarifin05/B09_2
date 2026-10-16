#!/usr/bin/env bash
# WEB-02 Weak TLS Configuration | Ubuntu 24.04 Apache2
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
IP='192.168.36.232'; DOMAIN='web02.lab.example.com'
BASE='/opt/web02-ctf'; CERT='/etc/ssl/web02'; SITE='/var/www/web02/public'
APACHE='/etc/apache2/sites-available/web02.conf'; MODE_FILE="$BASE/mode"
log(){ printf '[WEB02] %s\n' "$*"; }
die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }
trap 'printf "[ERROR] Gagal pada baris %s (exit %s). Log Apache: sudo journalctl -u apache2 -n 40 --no-pager\n" "$LINENO" "$?" >&2' ERR
[[ $EUID -eq 0 ]] || die 'Harus dijalankan dengan sudo bash setup.sh.'
usage(){ echo 'Penggunaan: sudo bash setup.sh [--status|--secure|--reset-weak]'; }
check_os(){ . /etc/os-release; [[ $ID == ubuntu && $VERSION_ID == 24.04 ]] || log "PERINGATAN: diuji untuk Ubuntu 24.04, terdeteksi $PRETTY_NAME"; ip -4 addr show | grep -q "inet $IP/" || log "PERINGATAN: IP $IP belum terlihat pada antarmuka. Pastikan jaringan VM benar."; }
run_apt(){ apt-get -o DPkg::Lock::Timeout=300 "$@"; }
install_packages(){ log 'Instal dependensi (APT lock ditunggu maksimum 300 detik)'; run_apt update; run_apt install -y apache2 openssl ca-certificates curl wget openssh-server python3 php libapache2-mod-php tcpdump tshark nmap ufw; }
hosts(){ sed -i '/[[:space:]]web02\.lab\.example\.com\([[:space:]]\|$\)/d' /etc/hosts; printf '%s\t%s\n' "$IP" "$DOMAIN" >> /etc/hosts; }
certs(){
 mkdir -p "$CERT" "$BASE"; chmod 700 "$CERT"
 if [[ ! -s $CERT/ca.key || ! -s $CERT/ca.crt ]]; then
   log 'Membuat CA internal lab (private key tetap pada Ubuntu)'
   openssl req -x509 -newkey rsa:3072 -sha256 -nodes -days 1825 -keyout "$CERT/ca.key" -out "$CERT/ca.crt" -subj '/CN=WEB02 Training Root CA/O=WEB02 Lab' -addext 'basicConstraints=critical,CA:TRUE' -addext 'keyUsage=critical,keyCertSign,cRLSign' >/dev/null 2>&1
 fi
 if [[ ! -s $CERT/server.key || ! -s $CERT/server.crt ]]; then
   log 'Membuat sertifikat server SAN web02.lab.example.com'
   openssl req -new -newkey rsa:2048 -nodes -keyout "$CERT/server.key" -out "$CERT/server.csr" -subj "/CN=$DOMAIN/O=WEB02 Lab" -addext "subjectAltName=DNS:$DOMAIN,IP:$IP" >/dev/null 2>&1
   cat > "$CERT/server.ext" <<EOF
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:$DOMAIN,IP:$IP
EOF
   openssl x509 -req -in "$CERT/server.csr" -CA "$CERT/ca.crt" -CAkey "$CERT/ca.key" -CAcreateserial -out "$CERT/server.crt" -days 365 -sha256 -extfile "$CERT/server.ext" >/dev/null 2>&1
 fi
 chmod 600 "$CERT/ca.key" "$CERT/server.key"; chmod 644 "$CERT/ca.crt" "$CERT/server.crt"
 install -m 644 "$CERT/ca.crt" /usr/local/share/ca-certificates/web02-lab-ca.crt
 update-ca-certificates >/dev/null
}
webapp(){
 mkdir -p "$SITE"; cat > "$SITE/index.php" <<'PHP'
<?php
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
$proto = $_SERVER['SERVER_PROTOCOL'] ?? 'HTTP/1.1';
?><!doctype html><html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>WEB-02 | Portal Akademik</title><style>body{font-family:system-ui;background:#eef3f9;color:#173451;margin:0}.wrap{max-width:860px;margin:8vh auto;background:white;border-radius:18px;padding:3rem;box-shadow:0 16px 50px #1d3c551c}h1{color:#123d67}.tag{font-size:.85rem;background:#e6effa;padding:8px 12px;border-radius:20px;display:inline-block}code{background:#edf2f7;padding:4px}footer{margin-top:3rem;color:#688}</style></head><body><main class="wrap"><span class="tag">Laboratorium CTF SSL/TLS • WEB-02</span><h1>Portal Informasi Akademik Taruna</h1><p>Website latihan ini menggunakan HTTPS. Misi Anda adalah mengaudit protokol TLS dan cipher suite kemudian menerapkan hardening sesuai baseline.</p><h2>Health Check</h2><p>Endpoint: <code>/health</code> • Respons: <code>WEB02_OK</code></p><p>Nama host: <strong><?=htmlspecialchars($_SERVER['HTTP_HOST'] ?? 'unknown',ENT_QUOTES)?></strong></p><footer>Gunakan hanya dalam jaringan laboratorium yang diizinkan.</footer></main></body></html>
PHP
 printf 'WEB02_OK\n' > "$SITE/health"; chown -R www-data:www-data /var/www/web02; chmod -R a+rX /var/www/web02
}
write_conf(){
 local mode="$1"; local protocols ciphers
 if [[ $mode == weak ]]; then
  protocols='TLSv1 TLSv1.1 TLSv1.2 TLSv1.3'
  ciphers='AES128-SHA:AES256-SHA:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:@SECLEVEL=0'
 else
  protocols='TLSv1.2 TLSv1.3'
  ciphers='ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:@SECLEVEL=2'
 fi
 cat > "$APACHE" <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    Redirect permanent / https://$DOMAIN/
    ErrorLog \${APACHE_LOG_DIR}/web02-http-error.log
</VirtualHost>
<VirtualHost *:443>
    ServerName $DOMAIN
    DocumentRoot $SITE
    SSLEngine on
    SSLCertificateFile $CERT/server.crt
    SSLCertificateKeyFile $CERT/server.key
    SSLProtocol $protocols
    SSLCipherSuite $ciphers
    SSLHonorCipherOrder on
    Header always set X-Content-Type-Options nosniff
    <Directory "$SITE">
        Require all granted
        AllowOverride None
        Options -Indexes +FollowSymLinks
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/web02-https-error.log
    CustomLog \${APACHE_LOG_DIR}/web02-https-access.log combined
</VirtualHost>
EOF
 a2ensite web02.conf >/dev/null; apache2ctl configtest; systemctl reload apache2
 printf '%s\n' "$mode" > "$MODE_FILE"
}
probe(){
 local version="$1"; shift
 local res
 res=$(timeout 10 openssl s_client -connect "${IP}:443" -servername "$DOMAIN" "$@" -cipher 'DEFAULT:@SECLEVEL=0' -brief </dev/null 2>&1 || true)
 if echo "$res" | grep -Eq '^[[:space:]]*Protocol version:'; then printf '%-8s ACCEPTED (%s)\n' "$version" "$(echo "$res" | sed -n 's/^[[:space:]]*Protocol version: //p' | head -1)"; else printf '%-8s REJECTED / UNAVAILABLE\n' "$version"; fi
}
status(){
 log "Domain: $DOMAIN → $IP"; log "Mode: $(cat "$MODE_FILE" 2>/dev/null || echo not-installed)"; systemctl is-active apache2 || :; apache2ctl -S 2>&1 | grep -E 'web02|VirtualHost' || :
 local code; code=$(curl --noproxy '*' --max-time 10 -s -o /dev/null -w '%{http_code}' "https://$DOMAIN/health" || true); log "HTTPS health HTTP status: ${code:-000}";
 probe TLS1.0 -tls1; probe TLS1.1 -tls1_1; probe TLS1.2 -tls1_2; probe TLS1.3 -tls1_3
 log 'Cek dari Kali juga; server-level TLS lama mungkin tidak tersedia pada build OpenSSL tertentu.'
}
main(){
 case "${1:-install}" in
  --status) status; exit 0;;
  install|--secure|--reset-weak) ;;
  *) usage; exit 2;;
 esac
 check_os
 install_packages
 hosts
 certs
 webapp
 a2enmod ssl headers rewrite >/dev/null
 a2dissite 000-default.conf default-ssl.conf >/dev/null 2>&1 || true
 systemctl enable --now apache2 ssh >/dev/null
 if ufw status | grep -q '^Status: active'; then ufw allow 22/tcp >/dev/null; ufw allow 80/tcp >/dev/null; ufw allow 443/tcp >/dev/null; fi
 if [[ ${1:-install} == --secure ]]; then write_conf secure
 elif [[ ${1:-install} == --reset-weak ]]; then write_conf weak
 elif [[ -s $MODE_FILE ]]; then log 'Mode sebelumnya dipertahankan'; old_mode="$(cat "$MODE_FILE")"; [[ $old_mode == weak || $old_mode == secure ]] || { echo "Mode tersimpan tidak valid" >&2; exit 1; }; write_conf "$old_mode"
 else write_conf weak
 fi
 openssl verify -CAfile "$CERT/ca.crt" -verify_hostname "$DOMAIN" "$CERT/server.crt"
 status
 log 'Selesai. Dari Kali: sudo bash setup_kali.sh ubuntu'
 log 'JANGAN unggah /etc/ssl/web02/*.key (private key).'
}
main "$@"
