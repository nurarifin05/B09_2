#!/usr/bin/env bash
set -Eeuo pipefail
((EUID==0)) || { echo 'Gunakan sudo bash setup.sh'; exit 1; }
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y curl openssl nmap tcpdump tshark wireshark-common ca-certificates python3
HERE="$(cd "$(dirname "$0")" && pwd)"
sed -i '/[[:space:]]akademik.sibertaruna.my.id$/d' /etc/hosts
printf '%s %s\n' '192.168.36.232' 'akademik.sibertaruna.my.id' >> /etc/hosts
install -m 755 "$HERE/validate.sh" /usr/local/bin/sslctf-validate
cat > /usr/local/bin/sslctf-info <<'EOF'
#!/usr/bin/env bash
cat <<'HELP'
Lab 2 | Target: akademik.sibertaruna.my.id (192.168.36.232)
Username DUMMY: taruna_demo_02
Password DUMMY: Latihan-02!
1) Dari Kali, jalankan tcpdump sebelum lalu lintas: sudo tcpdump -i any -s 0 -w ~/sslctf-evidence/before.pcap 'host 192.168.36.232 and port 80'
2) Terminal kedua, kirim login HTTP:
   curl --noproxy '*' --resolve 'akademik.sibertaruna.my.id:80:192.168.36.232' -d 'username=taruna_demo_02&password=Latihan-02!' 'http://akademik.sibertaruna.my.id/login'
3) Ctrl+C tcpdump; jalankan sslctf-validate; SUBMIT flag 01-02 ke LMS sekarang.
4) Taruna memperbaiki Nginx di Ubuntu lalu merekam HTTPS ke after.pcap (port 443).
5) Lihat dokumen praktikum untuk semua langkah dan validator.
HELP
EOF
chmod 755 /usr/local/bin/sslctf-info
mkdir -p /home/kali/sslctf-evidence
chown -R kali:kali /home/kali/sslctf-evidence 2>/dev/null || true
echo 'KALI-2 selesai. Jalankan sslctf-info (user kali)'
