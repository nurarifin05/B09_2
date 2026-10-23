#!/usr/bin/env bash
set -Eeuo pipefail
((EUID==0)) || { echo 'Gunakan sudo bash setup.sh'; exit 1; }
HERE="$(cd "$(dirname "$0")" && pwd)"
CERT="$HERE/cert-input/fullchain.pem"; KEY="$HERE/cert-input/sibertaruna.my.id.key"
[[ -s "$CERT" && -s "$KEY" ]] || { echo 'Sertifikat/key tidak ada di cert-input'; exit 2; }
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y nginx openssl python3 curl ca-certificates
openssl x509 -in "$CERT" -noout -checkend 0 >/dev/null
openssl pkey -in "$KEY" -noout >/dev/null
A=$(openssl x509 -in "$CERT" -pubkey -noout | openssl pkey -pubin -outform DER | sha256sum | cut -d' ' -f1)
B=$(openssl pkey -in "$KEY" -pubout -outform DER | sha256sum | cut -d' ' -f1)
[[ "$A" == "$B" ]] || { echo 'KEY dan CERT tidak cocok'; exit 3; }
openssl x509 -in "$CERT" -noout -ext subjectAltName | grep -Fq '*.sibertaruna.my.id' || { echo 'SAN wildcard tidak ada'; exit 4; }
install -d -m 700 /etc/ssl/sslctf
install -m 600 "$KEY" /etc/ssl/sslctf/server.key
install -m 644 "$CERT" /etc/ssl/sslctf/fullchain.pem
openssl x509 -in "$CERT" -out /etc/ssl/sslctf/leaf.pem
install -d -m 755 /opt/sslctf
install -m 755 "$HERE/app.py" /opt/sslctf/app.py
cat > /etc/systemd/system/sslctf-app.service <<'EOF'
[Unit]
Description=SSL CTF dummy login application
After=network.target
[Service]
ExecStart=/usr/bin/python3 /opt/sslctf/app.py
User=www-data
Group=www-data
Restart=always
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
[Install]
WantedBy=multi-user.target
EOF
cat > /etc/nginx/sites-available/sslctf.conf <<'EOF'
server {
  listen 80;
  server_name akademik.sibertaruna.my.id;
  location / {
    proxy_pass http://127.0.0.1:8088;
    proxy_set_header Host $host;
  }
}
EOF
rm -f /etc/nginx/sites-enabled/default
ln -sfn /etc/nginx/sites-available/sslctf.conf /etc/nginx/sites-enabled/sslctf.conf
systemctl daemon-reload
systemctl enable --now sslctf-app.service nginx
nginx -t && systemctl restart nginx
sed -i '/[[:space:]]akademik.sibertaruna.my.id$/d' /etc/hosts
printf '%s %s\n' '192.168.36.232' 'akademik.sibertaruna.my.id' >> /etc/hosts
cat > /opt/sslctf/INFO.txt <<'EOF'
Portal Nilai Akademik: KONDISI AWAL HTTP tanpa HTTPS.
Taruna harus memasang TLS sendiri pada /etc/nginx/sites-available/sslctf.conf.
Sertifikat: /etc/ssl/sslctf/fullchain.pem
Private key: /etc/ssl/sslctf/server.key (JANGAN DIBAGIKAN)
Khusus WEB-02: lakukan eksperimen leaf-only menggunakan /etc/ssl/sslctf/leaf.pem kemudian perbaiki ke fullchain.
Uji konfigurasi: sudo nginx -t && sudo systemctl reload nginx
EOF
echo 'SELESAI: HTTP tersedia di http://akademik.sibertaruna.my.id . Simpan snapshot kondisi awal.'
