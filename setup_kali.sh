#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Gunakan sudo bash setup_kali.sh ubuntu'; exit 1; }
BLUE_USER="${1:-ubuntu}"; IP=192.168.36.232; DOMAIN=web02.lab.example.com
log(){ echo "[KALI] $*"; }
export DEBIAN_FRONTEND=noninteractive
log 'Memasang tools audit dan SSH'; apt-get -o DPkg::Lock::Timeout=300 update
apt-get -o DPkg::Lock::Timeout=300 install -y openssl ca-certificates curl nmap tshark wireshark tcpdump openssh-client git python3
sed -i -E "/(^|[[:space:]])${DOMAIN//./\.}([[:space:]]|$)/d" /etc/hosts
echo "$IP $DOMAIN" >> /etc/hosts
log 'Verifikasi identitas server Blue Team melalui SSH (bukan mematikan host key checking).'
log "Bandingkan fingerprint dengan perintah di Ubuntu: sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub"
ssh -o StrictHostKeyChecking=ask -o ConnectTimeout=12 "$BLUE_USER@$IP" 'echo "[SSH] Koneksi berhasil"'
log 'Menyalin sertifikat CA PUBLIK saja'
scp -o StrictHostKeyChecking=yes "$BLUE_USER@$IP:/etc/ssl/web02/ca.crt" /usr/local/share/ca-certificates/web02-lab-ca.crt
chmod 644 /usr/local/share/ca-certificates/web02-lab-ca.crt
update-ca-certificates
log 'Menguji URL HTTPS dengan certificate verification aktif'
curl --noproxy '*' -Iv "https://$DOMAIN/health" || { log 'HTTPS gagal, lihat konfigurasi jaringan/server'; exit 1; }
log 'Siap! Contoh audit: nmap --script ssl-enum-ciphers -p 443 web02.lab.example.com'
