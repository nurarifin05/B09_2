#!/usr/bin/env bash
set -u
HOST='akademik.sibertaruna.my.id'; IP='192.168.36.232'; NUM='02'
E="${SSLCTF_EVIDENCE:-$HOME/sslctf-evidence}"; mkdir -p "$E"
flag() { local n="$1"; shift; if "$@"; then printf '[LULUS] %02d => {FLAG_SSL%s_%02d_%s}\n' "$n" "$NUM" "$n" "$(printf '%s' "${HOST}:$n:CTF-LMS-2026" | sha256sum | cut -c1-12 | tr '[:lower:]' '[:upper:]')"; else printf '[BELUM] %02d\n' "$n"; fi; }
web() { curl --noproxy '*' --resolve "$HOST:443:$IP" -fsS --max-time 6 "https://$HOST/" >/dev/null 2>&1; }
http() { curl --noproxy '*' --resolve "$HOST:80:$IP" -fsS --max-time 6 "http://$HOST/" >/dev/null 2>&1; }
before() { [[ -s "$E/before.pcap" ]] && tshark -r "$E/before.pcap" -Y 'http.request.method=="POST"' -T fields -e http.request.uri 2>/dev/null | grep -q '/login'; }
leaked() { [[ -s "$E/before.pcap" ]] && tshark -r "$E/before.pcap" -V 2>/dev/null | grep -Fq 'taruna_demo_02' && tshark -r "$E/before.pcap" -V 2>/dev/null | grep -Fq 'Latihan-02!'; }
tls() { echo | timeout 6 openssl s_client -connect "$IP:443" -servername "$HOST" -tls1_2 2>&1 | grep -Eq 'New, TLSv1.2|Protocol *: TLSv1.2'; }
tlsoldoff() { ! (echo | timeout 6 openssl s_client -connect "$IP:443" -servername "$HOST" -tls1 2>&1 | grep -Eq 'New, TLSv1($|[^.])|Protocol *: TLSv1($|[^.])'); }
certname() { echo | timeout 6 openssl s_client -connect "$IP:443" -servername "$HOST" 2>/dev/null | openssl x509 -noout -checkhost "$HOST" 2>/dev/null | grep -q 'does match'; }
chain() { local out; out=$(echo | timeout 6 openssl s_client -connect "$IP:443" -servername "$HOST" -showcerts 2>/dev/null); [[ $(grep -c 'BEGIN CERTIFICATE' <<<"$out") -ge 2 ]]; }
redirect() { curl --noproxy '*' -sS -o /dev/null --resolve "$HOST:80:$IP" -w '%{http_code} %{redirect_url}' "http://$HOST/" 2>/dev/null | grep -Fq 'https://akademik.sibertaruna.my.id/'; }
hsts() { curl --noproxy '*' -sSI --resolve "$HOST:443:$IP" "https://$HOST/" 2>/dev/null | grep -Eiq '^Strict-Transport-Security: *max-age=[0-9]+'; }
after() { [[ -s "$E/after.pcap" ]] && tshark -r "$E/after.pcap" -Y tls -T fields -e frame.number 2>/dev/null | grep -q '[0-9]' && ! tshark -r "$E/after.pcap" -V 2>/dev/null | grep -Fq 'Latihan-02!' ; }
# CH01-02 harus dikerjakan SEBELUM memasang TLS; gunakan evidence yang disimpan.
flag 1 before
flag 2 leaked
flag 3 certname
flag 4 web
flag 5 chain
flag 6 redirect
flag 7 tls
flag 8 tlsoldoff
flag 9 after
flag 10 hsts
