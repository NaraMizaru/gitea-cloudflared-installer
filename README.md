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

## 📁 Struktur Repositori
Repositori ini memiliki struktur folder yang rapi dan terorganisir secara modular:
```text
.
├── .env.example            # Template konfigurasi environment
├── README.md               # Panduan penggunaan (dokumentasi)
├── install.sh              # Skrip utama (installer) untuk memulai deployment
├── compose/                # Konfigurasi Docker Compose & template internal
│   ├── cloudflared/
│   ├── gitea/
│   ├── nginx/
│   └── runner/
└── scripts/                # Kumpulan skrip otomasi yang dikelompokkan
    ├── backup/             # Skrip setup & eksekusi backup otomatis
    ├── deploy/             # Skrip untuk mendeploy kontainer masing-masing service
    ├── setup/              # Skrip persiapan system (Docker, folder, network)
    └── utils/              # Skrip utilitas pembantu (validasi konfigurasi)
```

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

### Langkah 2: Inisialisasi Stack Utama
Karena Gitea Runner memerlukan token registrasi dari web UI Gitea, jalankan instalasi untuk seluruh komponen utama terlebih dahulu. Skrip secara otomatis akan melewatkan (skip) instalasi Runner karena `RUNNER_TOKEN` masih kosong.

1. Jalankan instalasi untuk mendeploy seluruh stack utama:
   ```bash
   bash install.sh
   # atau bash install.sh all
   ```
   *Skrip akan memasang Docker, menyiapkan folder data, membuat docker network, lalu mendeploy database PostgreSQL, Gitea, Nginx, Cloudflared Tunnel, dan Backup Cron.*

2. Buka browser Anda dan akses Gitea (misalnya lewat domain `git.<DOMAIN>` yang sudah terhubung Cloudflare Tunnel, atau lokal IP di port `3000`).
3. Selesaikan form instalasi Gitea di browser (buat akun Administrator pertama Anda).

---

### Langkah 3: Mengambil Token Runner & Deploy Runner
1. Masuk ke akun Admin Gitea Anda di web browser.
2. Navigasikan ke **Site Administration (Administrasi Situs)** -> **Actions** -> **Runners**.
3. Klik tombol **Register runner** di pojok kanan atas.
4. Salin token registrasi yang muncul (Registration Token).
5. Buka kembali berkas `.env` di server Anda, lalu isi token tersebut pada variabel:
   ```env
   RUNNER_TOKEN=KODE_TOKEN_YANG_ANDA_SALIN
   ```
6. Jalankan deployment khusus untuk mengaktifkan **Gitea Runner**:
   ```bash
   bash install.sh runner
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

## 🔒 Konfigurasi SSH Client (Akses SSH lewat Cloudflare Tunnel)
Karena traffic SSH dilewatkan melalui Cloudflare Tunnel, komputer client (PC Anda) yang ingin melakukan koneksi SSH ke Host OS maupun melakukan `git clone/push` lewat SSH Gitea harus terintegrasi dengan client-side `cloudflared`.

### 1. Download & Install `cloudflared` di Client:
- **Windows**: Download berkas `.exe` dari [Cloudflare GitHub Releases](https://github.com/cloudflare/cloudflared/releases) atau instal via winget: `winget install cloudflare.cloudflared`. Jika menggunakan installer `.msi`, letak default aplikasinya berada di `C:\Program Files\cloudflared\cloudflared.exe`. Pastikan direktori ini sudah masuk dalam `PATH` environment variable sistem Anda.
- **Linux**: Pasang paket resmi `cloudflared` sesuai distro Anda (misal `apt install cloudflared`).
- **macOS**: Instal melalui Homebrew: `brew install cloudflare/cloudflare/cloudflared`.

### 2. Tambahkan Konfigurasi ke file SSH `config` Client:
Buka berkas konfigurasi SSH di komputer client Anda (terletak di `~/.ssh/config` untuk Linux/macOS, atau `C:\Users\<Username>\.ssh\config` untuk Windows). Tambahkan konfigurasi berikut:

#### Opsi A: Menggunakan Command Global (Direkomendasikan untuk Windows/Linux/macOS jika `cloudflared` ada di PATH)
```ssh
Host ssh.<DOMAIN>
    User %r
    ProxyCommand cloudflared access ssh --hostname %h

Host git-ssh.<DOMAIN>
    ProxyCommand cloudflared access ssh --hostname %h
```

#### Opsi B: Menggunakan Absolute Path (Khusus Windows jika tidak mendaftarkan cloudflared ke PATH)
```ssh
Host ssh.<DOMAIN>
    User %r
    ProxyCommand "C:\Program Files\cloudflared\cloudflared.exe" access ssh --hostname %h

Host git-ssh.<DOMAIN>
    ProxyCommand "C:\Program Files\cloudflared\cloudflared.exe" access ssh --hostname %h
```

> *Ganti `<DOMAIN>` dengan nama domain yang Anda definisikan di berkas `.env` (contoh: `rplcraft.my.id`).*

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
