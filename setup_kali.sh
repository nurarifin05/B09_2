#!/usr/bin/env bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
BLUE_IP=192.168.36.232
DOMAIN=web02.lab.example.com
BLUE_USER="${1:-ubuntu}"
LAB=/home/${SUDO_USER:-kali}/web02-lab
log(){ echo "[KALI] $*"; }
[[ $EUID == 0 ]] || { echo 'Jalankan: sudo bash setup_kali.sh ubuntu'; exit 1; }
apt-get -o DPkg::Lock::Timeout=300 update
apt-get -o DPkg::Lock::Timeout=300 install -y openssh-client openssl curl ca-certificates nmap tshark wireshark tcpdump python3 git
sed -i '/[[:space:]]web02\.lab\.example\.com\([[:space:]]\|$\)/d' /etc/hosts
printf '%s\t%s\n' "$BLUE_IP" "$DOMAIN" >> /etc/hosts
mkdir -p "$LAB" /root/.ssh; chmod 700 /root/.ssh
log "Fingerprint SSH Ubuntu WAJIB dibandingkan dengan: sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub pada Blue Team."
log 'Sekarang akan dilakukan autentikasi SSH interaktif sebagai root Kali agar known_hosts sama dengan SCP.'
ssh -tt -o StrictHostKeyChecking=ask -o ConnectTimeout=15 "${BLUE_USER}@${BLUE_IP}" 'printf "[UBUNTU] SSH berhasil; sertifikat CA publik siap ditransfer.\n"'
log 'Mengunduh HANYA sertifikat CA publik dari Ubuntu (bukan private key).'
scp -o StrictHostKeyChecking=yes "${BLUE_USER}@${BLUE_IP}:/usr/local/share/ca-certificates/web02-lab-ca.crt" "$LAB/web02-lab-ca.crt"
install -m 644 "$LAB/web02-lab-ca.crt" /usr/local/share/ca-certificates/web02-lab-ca.crt
update-ca-certificates >/dev/null
chown -R "${SUDO_USER:-root}:${SUDO_USER:-root}" "$LAB" 2>/dev/null || true
log 'Fingerprint sertifikat CA (cocokkan dengan Ubuntu):'
openssl x509 -in "$LAB/web02-lab-ca.crt" -noout -fingerprint -sha256
log "Uji HTTPS: curl --noproxy '*' -Iv https://$DOMAIN/"
curl --noproxy '*' --connect-timeout 8 --max-time 15 -fsS "https://$DOMAIN/health" || true
log "Selesai. Folder kerja: $LAB"
