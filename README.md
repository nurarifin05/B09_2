# WEB-02 — Weak TLS Configuration (Nginx, Ubuntu 24.04)

**Hanya untuk lab terisolasi.** Mode awal sengaja mengizinkan cipher lama dan berupaya mengaktifkan TLS 1.0/1.1. Jangan gunakan konfigurasi weak di sistem produksi atau jaringan terbuka.

## Topologi
- Blue Team Ubuntu 24.04: `192.168.36.232`; Nginx: `https://web02.lab.example.com`
- Red Team Kali: `192.168.36.250`
- Nginx static website dan `/health`
- CA publik `/etc/ssl/web02/ca.crt`, private key CA `/etc/ssl/web02/ca.key` (jangan salin private key)

## Instalasi Blue Team
1. Pastikan NIC Ubuntu sudah menggunakan `192.168.36.232`, bisa mengakses repository Ubuntu, dan tidak berbenturan dengan mesin lain.
2. `sudo bash setup.sh` — instal APT, Nginx, sertifikat CA dan web, VirtualHost weak. Jika Apache lama aktif, installer menghentikan serta menonaktifkannya agar port Nginx tersedia.
3. `sudo bash setup.sh --status` — cek bukti koneksi, termasuk TLS 1.0, 1.1, 1.2, 1.3 dan cipher AES128-SHA.
4. Untuk konfigurasi akhir: `sudo bash setup.sh --secure` (instruktur dapat menyimpan perintah ini sampai ujian selesai). `sudo bash validate_web02.sh` untuk verifikasi dan flag.
5. Untuk ulang praktikum: `sudo bash setup.sh --reset-weak`.
6. Menjalankan `sudo bash setup.sh` ulang mempertahankan mode yang ada, tidak otomatis reset ke weak.

## Instalasi Kali
1. `sudo bash setup_kali.sh ubuntu`.
2. Script akan meminta verifikasi host key SSH untuk `192.168.36.232`. Bandingkan fingerprint dengan yang dihitung **langsung pada konsol Ubuntu** menggunakan `sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`. Jangan menerima fingerprint yang berbeda. Password SSH Ubuntu mungkin diminta.
3. Sertifikat **CA publik** disalin ke trust store Kali. Tidak ada private key yang ditransfer.
4. Tes `curl -Iv https://web02.lab.example.com/health` (tanpa `-k`).

## Audit sebelum perubahan (Kali)
```
getent hosts web02.lab.example.com
nmap -sT -sV -p 80,443 192.168.36.232
nmap --script ssl-enum-ciphers -p 443 web02.lab.example.com
openssl s_client -connect 192.168.36.232:443 -servername web02.lab.example.com -tls1_2 -cipher 'AES128-SHA:@SECLEVEL=0' -brief </dev/null
openssl s_client -connect 192.168.36.232:443 -servername web02.lab.example.com -tls1_3 -brief </dev/null
```

## Kesalahan umum
- `tlsv1 alert protocol version`: server menolak handshake versi TLS yang diuji.
- `no shared cipher`: klien dan server tak menyepakati cipher; periksa `ssl_ciphers`, cipher klien, serta kebijakan OpenSSL.
- `curl: (60)`: CA belum di-trust atau SAN tidak cocok; jangan gunakan `curl -k` sebagai pembuktian validasi.
- `nginx -t` gagal: jalankan `sudo nginx -t` dan periksa log `sudo journalctl -u nginx -n 50 --no-pager`.
- Port 443 konflik: `sudo ss -tlnp | grep -E ':80 |:443 '`.
- SSH host key verification gagal: verifikasi fingerprint di konsol Ubuntu; jangan menggunakan `StrictHostKeyChecking=no`.
- **Keterbatasan penting:** Nginx Ubuntu 24.04 memakai OpenSSL 3. Menuliskan TLSv1 dan TLSv1.1 dalam `ssl_protocols` **tidak menjamin** bahwa handshake legacy dapat diselesaikan pada setiap build/konfigurasi OpenSSL. Installer sengaja *melaporkan kemampuan aktual* tanpa mengklaim TLS legacy aktif. Untuk ujian yang **wajib** menerima TLS1.0/1.1 secara nyata, lakukan validasi pra-ujian; apabila tidak tersedia, gunakan runtime legacy terisolasi yang telah diverifikasi, bukan melemahkan kebijakan kriptografi sistem global.
- Penting: Apache lama dari paket sebelumnya dapat bertabrakan dengan Nginx; installer menghentikan Apache bila berjalan.

## Tujuan dan flag
Kondisi akhir: TLS 1.0/1.1 ditolak, TLS 1.2/1.3 diterima, AES128-SHA (TLS1.2) ditolak, trust CA/hostname valid, dan `/health` HTTP 200. Validator mengeluarkan `FLAG{WEB02_TLS_HARDENED}` ketika semua pemeriksaan lolos. Validator lokal bukan anti-cheat (user dengan root dapat membacanya).
