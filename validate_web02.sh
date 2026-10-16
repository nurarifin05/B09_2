#!/usr/bin/env bash
# Jalankan di Ubuntu sesudah hardening
set -Eeuo pipefail
HOST=web02.lab.example.com
IP=192.168.36.232
CA=/etc/ssl/web02/ca.crt
fail=0
pass(){ echo "[LULUS] $*"; }
no(){ echo "[GAGAL] $*"; fail=1; }
if apache2ctl configtest >/dev/null 2>&1; then pass 'Konfigurasi Apache'; else no 'Konfigurasi Apache'; fi
if systemctl is-active --quiet apache2; then pass 'Apache aktif'; else no 'Apache mati'; fi
if openssl verify -CAfile "$CA" -verify_hostname "$HOST" /etc/ssl/web02/server.crt 2>/dev/null | grep -q ': OK'; then pass 'Sertifikat dan hostname valid'; else no 'Sertifikat / hostname'; fi
if [[ $(curl --noproxy '*' --resolve "$HOST:443:$IP" -sS -m 10 -o /dev/null -w '%{http_code}' "https://$HOST/health" 2>/dev/null || :) == 200 ]] && [[ $(curl --noproxy '*' --resolve "$HOST:443:$IP" -fsS -m 10 "https://$HOST/health" 2>/dev/null || :) == WEB02_OK ]]; then pass 'Website HTTPS berfungsi'; else no 'Website HTTPS health check'; fi
probe(){ local version="$1"; local opt="$2"; local out
 out=$(timeout 8 openssl s_client -connect "$IP:443" -servername "$HOST" "$opt" -cipher 'DEFAULT:@SECLEVEL=0' -brief </dev/null 2>&1 || true)
 if grep -Eq '^[[:space:]]*Protocol version:' <<<"$out"; then return 0; else return 1; fi
}
for spec in 'TLS1.0 -tls1' 'TLS1.1 -tls1_1'; do read -r name opt <<<"$spec"; if probe "$name" "$opt"; then no "$name masih diterima"; else pass "$name tidak diterima"; fi; done
for spec in 'TLS1.2 -tls1_2' 'TLS1.3 -tls1_3'; do read -r name opt <<<"$spec"; if probe "$name" "$opt"; then pass "$name berhasil"; else no "$name gagal dinegosiasikan"; fi; done
legacy=$(timeout 8 openssl s_client -connect "$IP:443" -servername "$HOST" -tls1_2 -cipher 'AES128-SHA:@SECLEVEL=0' -brief </dev/null 2>&1 || true)
if grep -Eq '^[[:space:]]*Protocol version:' <<<"$legacy"; then no 'Cipher TLS1.2 AES128-SHA masih diterima'; else pass 'Cipher TLS1.2 AES128-SHA ditolak'; fi
if ((fail == 0)); then echo 'FLAG{WEB02_TLS_HARDENED}'; else echo '[BELUM LULUS] Perbaiki poin di atas, lalu ulangi validator.'; exit 1; fi
