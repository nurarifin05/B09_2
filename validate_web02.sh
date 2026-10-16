#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Gunakan sudo bash validate_web02.sh'; exit 1; }
IP=192.168.36.232; DOMAIN=web02.lab.example.com; CA=/etc/ssl/web02/ca.crt
pass=0; bad=0
ok(){ echo "[PASS] $*"; pass=$((pass+1)); }
no(){ echo "[FAIL] $*"; bad=$((bad+1)); }
probe(){ timeout 10 openssl s_client -connect "$IP:443" -servername "$DOMAIN" "$1" ${2:-} -brief </dev/null 2>&1 || true; }
nginx -t >/dev/null 2>&1 && ok 'Konfigurasi Nginx valid' || no 'Konfigurasi Nginx invalid'
systemctl is-active --quiet nginx && ok 'Nginx aktif' || no 'Nginx tidak aktif'
[[ $(curl --noproxy '*' --cacert "$CA" -sS -o /dev/null -w '%{http_code}' "https://$DOMAIN/health" 2>/dev/null || true) == 200 ]] && ok 'HTTPS /health 200 + sertifikat dipercaya' || no 'HTTPS health gagal'
openssl verify -CAfile "$CA" -verify_hostname "$DOMAIN" /etc/ssl/web02/server.crt >/dev/null 2>&1 && ok 'Sertifikat dipercaya dan hostname sesuai' || no 'Verifikasi sertifikat gagal'
for spec in '-tls1 TLS1.0' '-tls1_1 TLS1.1'; do set -- $spec; if grep -q 'Protocol version: TLSv' <<< "$(probe "$1" '-cipher DEFAULT:@SECLEVEL=0')"; then no "$2 masih diterima"; else ok "$2 ditolak"; fi; done
for spec in '-tls1_2 TLS1.2' '-tls1_3 TLS1.3'; do set -- $spec; if grep -q "Protocol version: ${2/TLS1/TLSv1}" <<< "$(probe "$1" '-cipher DEFAULT:@SECLEVEL=0')"; then ok "$2 diterima"; else no "$2 ditolak"; fi; done
if grep -q 'Protocol version: TLSv1.2' <<< "$(probe -tls1_2 '-cipher AES128-SHA:@SECLEVEL=0')"; then no 'Cipher AES128-SHA diterima'; else ok 'Cipher AES128-SHA ditolak'; fi
[[ $(cat /opt/web02-ctf/mode 2>/dev/null) == secure ]] && ok 'Mode hardening tercatat' || no 'Mode secure belum diaktifkan'
echo "[WEB02] $pass lulus, $bad gagal"
if [[ $bad -eq 0 ]]; then echo 'FLAG{WEB02_TLS_HARDENED}'; else exit 1; fi
