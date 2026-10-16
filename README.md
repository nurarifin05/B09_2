# WEB-02 — Weak TLS Configuration | Apache2 Ubuntu 24.04

**Catatan adaptasi skenario:** Narasi referensi menyebut Nginx; paket ini **menggunakan Apache2** sesuai permintaan implementasi. Seluruh konfigurasi TLS berada di `/etc/apache2/sites-available/web02.conf`.

## Mesin
- Blue Team: Ubuntu 24.04, IP `192.168.36.232`
- Red Team: Kali Linux, IP `192.168.36.250`
- Domain lab: `web02.lab.example.com`
- Website: `https://web02.lab.example.com`
- Endpoint health: `https://web02.lab.example.com/health`, mengembalikan `WEB02_OK`

## Instal Ubuntu
1. Pastikan VM mempunyai IP `192.168.36.232` secara manual di pengaturan jaringan (script tidak mengubah Netplan).
2. Ekstrak paket pada Ubuntu: `unzip WEB02_Weak_TLS_Apache_Ubuntu24.zip` lalu `cd web02_ctf`.
3. Jalankan `sudo bash setup.sh`.
4. Jalankan `sudo bash setup.sh --status`.
5. Default pertama adalah mode `weak` untuk audit. HTTPS aktif dan HTTP redirect ke HTTPS.

## Instal Kali
1. Kali harus memiliki IP `192.168.36.250`, dapat menjangkau Blue Team melalui SSH port 22.
2. Ekstrak paket; `cd web02_ctf`.
3. Jalankan `sudo bash setup_kali.sh ubuntu` (ubah `ubuntu` sesuai username SSH Ubuntu).
4. Pada prompt SSH, **verifikasi** fingerprint yang ditampilkan dengan `sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` pada Ubuntu, lalu jawab `yes` jika sama.
5. Kali memasang hanya CA publik ke trust store. Tidak boleh mengunduh private key CA/server.
6. Uji `curl --noproxy '*' -Iv https://web02.lab.example.com/`.

## Perintah penting Blue Team
- `sudo bash setup.sh --status` — cek TLS dan status Apache.
- `sudo bash setup.sh --secure` — menerapkan konfigurasi TLS1.2/1.3 + GCM (jalankan setelah audit).
- `sudo bash setup.sh --reset-weak` — kembali ke baseline lemah untuk sesi praktikum baru.
- `sudo bash validate_web02.sh` — evaluasi final dan flag.
- `sudo apache2ctl -S` — daftar virtual host.
- `sudo apache2ctl configtest` — sintaks Apache.

## Perintah penting Kali
```bash
nmap -sT -sV -p 80,443 192.168.36.232
curl --noproxy '*' -Iv https://web02.lab.example.com/
openssl s_client -connect 192.168.36.232:443 -servername web02.lab.example.com -tls1 -cipher 'DEFAULT:@SECLEVEL=0' -brief </dev/null
openssl s_client -connect 192.168.36.232:443 -servername web02.lab.example.com -tls1_1 -cipher 'DEFAULT:@SECLEVEL=0' -brief </dev/null
openssl s_client -connect 192.168.36.232:443 -servername web02.lab.example.com -tls1_2 -cipher 'DEFAULT:@SECLEVEL=0' -brief </dev/null
openssl s_client -connect 192.168.36.232:443 -servername web02.lab.example.com -tls1_3 -brief </dev/null
openssl s_client -connect 192.168.36.232:443 -servername web02.lab.example.com -tls1_2 -cipher 'AES128-SHA:@SECLEVEL=0' -brief </dev/null
```

## Hal-hal penting
- **Ubuntu 24.04 / OpenSSL 3:** penerimaan TLS 1.0/1.1 dapat dibatasi oleh build OpenSSL, library, atau kebijakan sistem. Mode `weak` meminta Apache menerima TLS1.0/1.1 dan `AES128-SHA`, namun penerimaan sebenarnya **harus diukur**. Jika versi legacy ditolak karena keterbatasan lingkungan, catat sebagai keterbatasan lab (jangan beri klaim palsu). Paket tidak mengganti kebijakan kriptografi sistem secara global.
- Untuk pengujian TLS 1.0/1.1, argumen `-cipher 'DEFAULT:@SECLEVEL=0'` hanya melonggarkan **client uji** demi mengidentifikasi dukungan legacy; bukan hardening dan tidak digunakan untuk validasi sertifikat modern.
- IP Blue Team harus benar dan host Kali harus menggunakan resolver lokal `/etc/hosts` dari installer.
- `--secure` disediakan untuk pengajar atau saat peserta telah selesai audit. Penggunaan flag dari skrip lokal bukan anti-cheat untuk ujian resmi.
- Jangan menggunakan `curl -k` saat memeriksa certificate trust. CA publik harus diverifikasi fingerprint-nya melalui kanal tepercaya.
- Script belum diuji pada VM Anda; jalankan snapshot dan cek output `--status` sebelum menyelenggarakan ujian.

Dokumen pendamping: `CTF_SSL_Certificate_Weak_TLS_Configuration_Kedua.docx` dengan 15 soal, langkah pemula, materi pengantar, rubrik dan kunci jawaban.
