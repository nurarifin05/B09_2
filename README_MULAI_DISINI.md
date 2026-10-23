# WEB-02 — Paket CTF SSL/TLS mandiri

- Ubuntu 192.168.36.232 — `Ubuntu/setup.sh` (file input cert di `Ubuntu/cert-input/`).
- Kali 192.168.36.250 — `Kali/setup.sh`.
- 10 pertanyaan flag taruna — `Materi-Taruna/10_Soal_Flag_LMS.docx` dan `.md`.
- 15 soal pilihan ganda — `Materi-Taruna/15_Soal_Pilihan_Ganda.txt`.
- Kunci LMS dan panduan lengkap — `Panduan-Dosen-RAHASIA/` (jangan dibagikan kepada taruna).

## Instalasi

1. Pada Ubuntu, masukkan `fullchain.pem` dan `sibertaruna.my.id.key` ke direktori `Ubuntu/cert-input` (JANGAN pada Kali).
2. Pada Ubuntu: `cd Ubuntu && sudo bash setup.sh`.
3. Pada Kali: `cd Kali && sudo bash setup.sh`.
4. Di Kali: `sslctf-info` lalu lakukan capture HTTP terlebih dahulu. Kerjakan flag 01–02, baru pasang HTTPS di Ubuntu; lanjutkan hingga flag 10.
5. Dosen jalankan `bash Panduan-Dosen-RAHASIA/Kunci_Flag_LMS_DOSEN.sh` di lingkungan dosen untuk melihat nilai jawaban 10 soal di LMS.

## Format

Saat ini validator menghasilkan `{FLAG_SSL02_01_XXXXXXXXXXXX}`, bukan `FLAG{...}`. Input ke LMS harus sama persis dengan keluaran validator.

## Prasyarat dan batasan

Butuh akses repositori APT pada saat pemasangan; alamat IP perlu sudah terkonfigurasi. Capture di Kali berasal dari login dummy yang dikirim sendiri oleh Kali, bukan intersepsi trafik mesin lain. Sertifikat dan private key **tidak disertakan**. Uji end-to-end tetap perlu dilakukan pada VM nyata. Data flag deterministik; jangan membagikan kunci LMS atau menempatkannya pada VM taruna.
