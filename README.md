# Gitea + Cloudflared Docker Installer

Installer otomatis untuk mendeploy Gitea, PostgreSQL, Gitea Runner (CI/CD), Nginx Reverse Proxy, dan Cloudflared Tunnel secara praktis di server berbasis Linux (Ubuntu/Debian). Dilengkapi dengan skrip pencadangan otomatis (automated backup) harian menggunakan Cron.

---

## 🚀 Fitur Utama
1. **Gitea & Postgres**: Layanan git server mandiri yang ringan dan database relasional.
2. **Gitea Runner**: Menjalankan alur kerja CI/CD terintegrasi secara otomatis.
3. **Nginx Reverse Proxy**: Mengatur traffic HTTP masuk ke container Gitea.
4. **Cloudflared Tunnel**: Mengekspos server lokal ke internet secara aman melalui Cloudflare Tunnel tanpa memerlukan IP Publik statis maupun port-forwarding pada router.
5. **Auto-Backup System**: Pencadangan data Gitea, database Postgres, dan file Docker Compose secara berkala yang dikonfigurasi melalui cron job.

---

## 📁 Struktur Direktori Stack
Secara default, installer akan membuat struktur folder persisten berikut di server Anda:
- **Konfigurasi Stack**: `/opt/stacks/{gitea, runner, nginx, cloudflared}`
- **Penyimpanan Data**: `<DATA_DIR>/{gitea, postgres, runner}` (Default: `/srv/data/...`)
- **Pencadangan**: `<BACKUP_DIR>` (Default: `/srv/backups/...`)

---

## 🛠️ Langkah-Langkah Instalasi & Setup

### Langkah 1: Persiapan Environment
1. Salin berkas `.env.example` menjadi `.env` di direktori utama repositori ini:
   ```bash
   cp .env.example .env
   ```
2. Buka berkas `.env` dan sesuaikan nilai variabel konfigurasi berikut:
   - `DOMAIN`: Domain utama Gitea (contoh: `example.com`).
   - `DATA_DIR`: Path folder data persisten (contoh: `/srv/data`).
   - `CLOUDFLARE_TOKEN`: Masukkan Token Tunnel Cloudflare Anda.
   - *Catatan: Biarkan variabel `RUNNER_TOKEN` kosong terlebih dahulu.*

---

### Langkah 2: Deploy Gitea (Inisialisasi)
Karena Gitea Runner memerlukan token registrasi yang hanya bisa didapatkan setelah Gitea terpasang dan dikonfigurasi, jalankan installer secara bertahap.

1. Jalankan instalasi untuk komponen **gitea** saja:
   ```bash
   bash install.sh gitea
   ```
   *Skrip akan memasang Docker (jika belum terpasang), menyiapkan folder data, membuat docker network, lalu mendeploy database PostgreSQL & Gitea.*

2. Buka browser Anda dan akses Gitea secara lokal melalui alamat IP server di port HTTP yang dikonfigurasi (default: `http://<IP_SERVER_ANDA>:3000`).
3. Selesaikan form instalasi Gitea di browser (buat akun Administrator pertama Anda).

---

### Langkah 3: Mengambil Token Runner & Deploy Ulang
1. Masuk ke akun Admin Gitea Anda di web browser.
2. Navigasikan ke **Site Administration (Administrasi Situs)** -> **Actions** -> **Runners**.
3. Klik tombol **Register runner** di pojok kanan atas.
4. Salin token registrasi yang muncul (Registration Token).
5. Buka kembali berkas `.env` di server Anda, lalu paste token tersebut pada variabel:
   ```env
   RUNNER_TOKEN=KODE_TOKEN_YANG_ANDA_SALIN
   ```
6. Deploy sisa stack secara keseluruhan untuk mengaktifkan Runner, Nginx, Cloudflared Tunnel, dan Backup Scheduler:
   ```bash
   bash install.sh all
   ```

---

## 🌐 Konfigurasi Cloudflare Tunnel
Agar Gitea dan SSH host/container dapat diakses secara publik melalui Cloudflare Tunnel, tambahkan **3 Public Hostname** berikut di panel dashboard Cloudflare Zero Trust Anda:

| Public Hostname (Domain) | Service Type | URL Service Internal | Deskripsi |
| :--- | :--- | :--- | :--- |
| `git.<DOMAIN>` | `HTTP` | `http://nginx:80` | Akses Web UI & HTTP Git clone |
| `ssh.<DOMAIN>` | `SSH` | `ssh://host.docker.internal:22` | Akses SSH langsung ke sistem Host OS server |
| `git-ssh.<DOMAIN>` | `SSH` | `ssh://gitea:22` | Akses SSH Gitea untuk Git cloning / push |

> *Sesuaikan `<DOMAIN>` dengan nama domain yang Anda definisikan di berkas `.env` Anda.*

---

## ⚙️ Konfigurasi Gitea (`app.ini`)
Setelah mendeploy Cloudflared Tunnel, Anda perlu menyesuaikan konfigurasi URL dan SSH internal Gitea agar tautan clone yang tampil di web menggunakan domain kustom Anda.

1. Buka berkas konfigurasi Gitea di host OS:
   ```bash
   nano <DATA_DIR>/gitea/gitea/conf/app.ini
   # default path: /srv/data/gitea/gitea/conf/app.ini
   ```
2. Cari bagian `[server]` dan sesuaikan nilainya seperti contoh berikut:
   ```ini
   [server]
   PROTOCOL         = http
   APP_DATA_PATH    = /data/gitea
   DOMAIN           = git.<DOMAIN>
   SSH_DOMAIN       = git-ssh.<DOMAIN>
   HTTP_PORT        = 3000
   ROOT_URL         = https://git.<DOMAIN>
   DISABLE_SSH      = false
   SSH_PORT         = <GITEA_SSH_PORT>   ; Default: 2222 (Port eksternal host SSH Gitea)
   SSH_LISTEN_PORT  = 22                 ; Port internal container
   LFS_START_SERVER = true
   LFS_JWT_SECRET   = <LFS_JWT_SECRET_BAWAAN>
   ```
   > *Ubah `<DOMAIN>` menjadi nama domain Anda (misal `example.com`), dan sesuaikan `<GITEA_SSH_PORT>` dengan port SSH eksternal di `.env` (default: `2222`).*
3. Restart container Gitea untuk menerapkan perubahan:
   ```bash
   docker restart gitea
   ```

---

## 💾 Sistem Pencadangan (Backup)
Installer akan memasang skrip backup otomatis di `/usr/local/bin/backup-gitea.sh` yang terhubung ke Cron.
* **Manajemen Retensi**: Backup lama yang melebihi jumlah hari di variabel `BACKUP_RETENTION_DAYS` (default: 30 hari) akan dihapus secara otomatis.
* **Picu Backup Manual**:
  ```bash
  sudo /usr/local/bin/backup-gitea.sh
  ```
* **Hasil Backup**: File cadangan (.tar.gz dan .sql) disimpan teratur di folder `<BACKUP_DIR>/{gitea, postgres, compose}`.
