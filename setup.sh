#!/usr/bin/env bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
IP=192.168.36.232; DOMAIN=web02.lab.example.com; BASE=/opt/web02-ctf; SSLDIR=/etc/ssl/web02; SITE=/etc/nginx/sites-available/web02.conf; STATE=$BASE/mode
log(){ printf '\n[WEB02] %s\n' "$*"; }
fail(){ echo "[ERROR] $*" >&2; exit 1; }
trap 'echo "[ERROR] Baris $LINENO gagal. Periksa: sudo nginx -t; sudo journalctl -u nginx -n 50 --no-pager" >&2' ERR
[[ $EUID == 0 ]] || fail 'Jalankan sudo bash setup.sh [--status|--secure|--reset-weak]'
[[ -r /etc/os-release ]] && . /etc/os-release
[[ ${ID:-} == ubuntu && ${VERSION_ID:-} == 24.04 ]] || log 'PERINGATAN: script ditargetkan Ubuntu 24.04'
mode="${1:-install}"
[[ $mode =~ ^(install|--status|--secure|--reset-weak)$ ]] || fail "Argumen tidak dikenal: $mode"
apt_safe(){ apt-get -o DPkg::Lock::Timeout=300 "$@"; }
install_deps(){ log 'Memasang paket lewat APT (menunggu lock hingga 300 detik)'; apt_safe update; apt_safe install -y nginx openssl ca-certificates curl wget jq openssh-server tcpdump tshark nmap python3 iproute2 ufw; }
set_host(){ sed -i -E "/(^|[[:space:]])${DOMAIN//./\.}([[:space:]]|$)/d" /etc/hosts; echo "$IP $DOMAIN" >> /etc/hosts; }
make_certs(){
 mkdir -p "$SSLDIR" "$BASE" /var/www/web02
 chmod 755 "$SSLDIR"
 if [[ ! -s $SSLDIR/ca.crt || ! -s $SSLDIR/ca.key ]]; then
  log 'Membuat CA lab (private key hanya di Blue Team)'
  openssl req -x509 -newkey rsa:3072 -sha256 -nodes -days 3650 -subj '/CN=WEB02 Lab Root CA' -keyout "$SSLDIR/ca.key" -out "$SSLDIR/ca.crt" >/dev/null 2>&1
 fi
 if [[ ! -s $SSLDIR/server.crt || ! -s $SSLDIR/server.key ]]; then
  log 'Membuat sertifikat web dengan Subject Alternative Name'
  openssl req -new -newkey rsa:2048 -nodes -subj "/CN=$DOMAIN" -keyout "$SSLDIR/server.key" -out "$SSLDIR/server.csr" >/dev/null 2>&1
  printf 'subjectAltName=DNS:%s,IP:%s\nextendedKeyUsage=serverAuth\n' "$DOMAIN" "$IP" > "$SSLDIR/ext.cnf"
  openssl x509 -req -in "$SSLDIR/server.csr" -CA "$SSLDIR/ca.crt" -CAkey "$SSLDIR/ca.key" -CAcreateserial -out "$SSLDIR/server.crt" -days 825 -sha256 -extfile "$SSLDIR/ext.cnf" >/dev/null 2>&1
 fi
 chmod 600 "$SSLDIR"/*.key
 cp "$SSLDIR/ca.crt" /usr/local/share/ca-certificates/web02-lab-ca.crt
 update-ca-certificates >/dev/null
 openssl verify -CAfile "$SSLDIR/ca.crt" -verify_hostname "$DOMAIN" "$SSLDIR/server.crt"
}
create_site(){
 cat >/var/www/web02/index.html <<'HTML'
<!doctype html><html lang="id"><head><meta charset="utf-8"><title>WEB02 - Sistem Informasi Akademik</title><style>body{font:17px system-ui;max-width:780px;margin:65px auto;padding:0 20px;background:#f5f7fb;color:#182b43}.card{background:white;padding:30px;border-radius:14px;box-shadow:0 3px 24px #ccd5e6}code{background:#edf0f4;padding:4px;border-radius:5px}</style></head><body><div class="card"><h1>WEB-02 | TLS Security Laboratory</h1><p>Website akademik latihan. HTTPS aktif, namun keamanan protokol dan cipher perlu diaudit.</p><p>Endpoint kesehatan: <code>/health</code></p><p>Audit dengan Kali Linux, kemudian lakukan TLS hardening di Nginx.</p></div></body></html>
HTML
 echo 'WEB02 HEALTH OK' >/var/www/web02/health
}
write_config(){
 local profile=$1 protos ciphers
 if [[ $profile == weak ]]; then
  protos='TLSv1 TLSv1.1 TLSv1.2 TLSv1.3'
  ciphers='AES128-SHA:AES256-SHA:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:@SECLEVEL=0'
 else
  protos='TLSv1.2 TLSv1.3'
  ciphers='ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:!aNULL:!eNULL:!MD5:!3DES'
 fi
 cat > "$SITE" <<NGINX
# WEB02 CTF - profile: $profile
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl;
    server_name $DOMAIN;
    root /var/www/web02;
    index index.html;
    ssl_certificate $SSLDIR/server.crt;
    ssl_certificate_key $SSLDIR/server.key;
    ssl_protocols $protos;
    ssl_ciphers '$ciphers';
    ssl_session_cache shared:WEB02SSL:10m;
    ssl_session_timeout 10m;
    location / { try_files \$uri \$uri/ =404; }
}
NGINX
 ln -sfn "$SITE" /etc/nginx/sites-enabled/web02.conf
 rm -f /etc/nginx/sites-enabled/default
 nginx -t
 if systemctl is-active --quiet apache2 2>/dev/null; then log "Menghentikan Apache lama agar port 80/443 digunakan Nginx"; systemctl stop apache2; systemctl disable apache2; fi
 systemctl enable --now nginx
 systemctl restart nginx
 echo "$profile" > "$STATE"
}
test_tls(){
 local ver=$1 label=$2 extra=${3:-}
 local out
 # Ignore output and status mismatch by checking negotiated Protocol line.
 out=$(timeout 8 openssl s_client -connect "$IP:443" -servername "$DOMAIN" "$ver" $extra -brief </dev/null 2>&1 || true)
 if grep -qE '^Protocol version: TLSv1' <<< "$out"; then echo "$label ACCEPTED ($(grep -m1 'Protocol version:' <<< "$out" | xargs))"; else echo "$label REJECTED / UNAVAILABLE"; fi
}
status(){
 log "Domain: $DOMAIN -> $IP"
 log "Mode: $(cat "$STATE" 2>/dev/null || echo unknown)"
 systemctl is-active nginx || true
 nginx -t 2>&1 || true
 echo "HTTPS health HTTP status: $(curl --noproxy '*' --cacert "$SSLDIR/ca.crt" -sS -o /dev/null -w '%{http_code}' "https://$DOMAIN/health" 2>/dev/null || true)"
 test_tls -tls1 TLS1.0 '-cipher DEFAULT:@SECLEVEL=0'
 test_tls -tls1_1 TLS1.1 '-cipher DEFAULT:@SECLEVEL=0'
 test_tls -tls1_2 TLS1.2 '-cipher DEFAULT:@SECLEVEL=0'
 test_tls -tls1_3 TLS1.3
 echo 'Legacy cipher TLS1.2:'
 test_tls -tls1_2 AES128-SHA '-cipher AES128-SHA:@SECLEVEL=0'
 log 'Catatan: OPENSSL 3 / kebijakan distribusi dapat menolak TLS1.0/1.1 meskipun tercantum di konfigurasi Nginx.'
}
if [[ $mode == --status ]]; then status; exit 0; fi
if [[ $mode == install ]]; then
 install_deps
 set_host; make_certs; create_site
 if [[ -s $STATE && -f $SITE ]]; then
  log "Konfigurasi sudah ada: $(cat "$STATE"). Tidak mereset mode."; nginx -t; systemctl enable --now nginx
 else
  write_config weak
 fi
elif [[ $mode == --secure ]]; then
 [[ -s $SSLDIR/server.crt ]] || fail 'Jalankan setup.sh dahulu'
 cp -a "$SITE" "${SITE}.backup-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
 write_config secure
elif [[ $mode == --reset-weak ]]; then
 [[ -s $SSLDIR/server.crt ]] || fail 'Jalankan setup.sh dahulu'
 cp -a "$SITE" "${SITE}.backup-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
 write_config weak
fi
status
log 'File publik CA untuk Kali: /etc/ssl/web02/ca.crt (JANGAN bagikan *.key)'
