# Gitea + Cloudflared Docker Installer

Installer otomatis untuk mendeploy **Gitea**, **PostgreSQL**, **Gitea Runner (CI/CD Linux & Windows VM)**, **Nginx Reverse Proxy**, dan **Cloudflared Tunnel** secara praktis di server berbasis Linux (Ubuntu/Debian). Dilengkapi dengan antarmuka CLI berbasis `Makefile`, skrip pembaruan otomatis (`update.sh`), dan sistem pencadangan otomatis (*automated backup*) berkala menggunakan Cron.

---

## 🚀 Fitur Utama

1. **Gitea & PostgreSQL**: Layanan git hosting mandiri yang ringan, cepat, dan terintegrasi dengan database PostgreSQL relasional persisten.
2. **Multi-Platform Gitea Runner (CI/CD)**:
   - **Linux Runner**: Menjalankan alur kerja Docker-in-Docker (`ubuntu-latest:docker://gitea/runner-images:ubuntu-latest`).
   - **Headless Windows VM Runner**: Menjalankan VM Windows asli (`dockurr/windows` via akselerasi KVM) yang dilengkapi Git, Visual Studio MSBuild, PowerShell Core, Node.js, dan Python.
   - **Zero-Touch Provisioning**: Provisi Windows 100% otomatis dari terminal tanpa perlu campur tangan VNC manual.
   - **Token Terpisah**: Mendukung token registrasi terpisah per runner (`LINUX_RUNNER_TOKEN` & `WINDOWS_RUNNER_TOKEN`).
   - **Keamanan VNC**: Port VNC (8006) dapat dikunci ke `localhost` (`127.0.0.1`) agar aman dari internet publik.
3. **Nginx Reverse Proxy**: Mengatur lalu lintas HTTP/HTTPS masuk ke container Gitea secara optimal.
4. **Cloudflared Tunnel**: Mengekspos server lokal ke internet secara aman melalui Cloudflare Tunnel tanpa memerlukan IP Publik statis maupun membuka port di router/firewall.
5. **Auto-Backup System**: Pencadangan otomatis harian/mingguan untuk data repositori, database Postgres, dan file konfigurasi Docker Compose dengan manajemen retensi.
6. **One-Command Management**: Seluruh operasi server dapat dikontrol lewat `make` CLI (`make install`, `make update`, `make restart`, `make reset-runner`, dll).

---

## 📁 Struktur Repositori

Repositori ini dirancang dengan arsitektur modular yang rapi:

```text
.
├── .env.example                          # Template konfigurasi environment server
├── .gitignore                            # Berkas pengecualian Git (data, log, secret)
├── Makefile                              # Antarmuka CLI ringkas untuk mengelola seluruh stack
├── README.md                             # Dokumentasi dan panduan penggunaan lengkap
├── install.sh                            # Skrip installer utama dengan UI spinner & auto-elevate
├── update.sh                             # Skrip pembaruan otomatis (git pull, sync .env, re-deploy)
├── setup-ssh.sh                          # Skrip otomatisasi SSH client untuk Linux/macOS/Git Bash
├── setup-ssh.ps1                         # Skrip otomatisasi SSH client untuk Windows PowerShell
│
├── compose/                              # Konfigurasi Docker Compose & template per modul
│   ├── cloudflared/                      # Stack Cloudflare Tunnel
│   │   ├── .env.template
│   │   └── docker-compose.yml
│   ├── gitea/                            # Stack Gitea & PostgreSQL
│   │   ├── .env.template
│   │   └── docker-compose.yml
│   ├── nginx/                            # Stack Nginx Reverse Proxy
│   │   ├── conf.d/
│   │   │   └── gitea.conf
│   │   ├── .env.template
│   │   └── docker-compose.yml
│   └── runner/                           # Stack Gitea Runner (Linux & Windows VM)
│       ├── .env.template
│       ├── config.linux.yaml             # Template konfigurasi act_runner Linux
│       ├── config.windows-vm.yaml         # Template konfigurasi act_runner Windows
│       ├── config.yaml                   # Konfigurasi fallback
│       ├── docker-compose.linux.yml      # Profile Docker Compose: Linux saja
│       ├── docker-compose.windows-vm.yml  # Profile Docker Compose: Windows VM saja
│       ├── docker-compose.yml            # Multi-profile Compose (Linux, Windows, Both)
│       └── oem/                          # Otomasi unattended script untuk Windows VM
│           ├── install.bat               # Bootstrap script Windows OEM
│           └── install.ps1               # Provisi otomatis Gitea Runner & tools Windows
│
└── scripts/                              # Kumpulan modul otomasi bash
    ├── backup/                           # Modul pencadangan otomatis
    │   ├── backup-gitea.sh               # Skrip eksekutor pencadangan database & file
    │   └── install-backup.sh             # Pemasang cron job pencadangan otomatis
    ├── deploy/                           # Modul deployment kontainer idempotent
    │   ├── deploy-cloudflared.sh
    │   ├── deploy-gitea.sh
    │   ├── deploy-nginx.sh
    │   └── deploy-runner.sh
    ├── setup/                            # Modul penyiapan sistem host
    │   ├── install-docker.sh             # Instalasi Docker Engine & Compose
    │   ├── setup-directory.sh            # Pembuatan direktori data persisten
    │   └── setup-network.sh              # Penyiapan Docker network terisolasi
    └── utils/                            # Utilitas pembantu
        ├── check-config.sh               # Validasi kelengkapan berkas .env
        └── ui.sh                         # Helper tampilan CLI, spinner, & format warna
```

---

## 📁 Struktur Direktori Persisten di Server

Installer akan membuat struktur direktori persisten berikut pada server host Anda:

| Path di Server | Fungsi & Deskripsi |
| :--- | :--- |
| `/opt/stacks/{gitea,runner,nginx,cloudflared}` | Lokasi file `docker-compose.yml` aktif dan konfigurasi stack runtime. |
| `<DATA_DIR>/gitea` *(Default: `/srv/data/gitea`)* | Data repositori, git lfs, sesi, dan konfigurasi `app.ini` Gitea. |
| `<DATA_DIR>/postgres` *(Default: `/srv/data/postgres`)* | Berkas database PostgreSQL persisten. |
| `<DATA_DIR>/runner-linux` *(Default: `/srv/data/runner-linux`)* | Token registrasi `.runner` dan cache alur kerja Linux Runner. |
| `<DATA_DIR>/runner-windows-vm` *(Default: `/srv/data/runner-windows-vm`)* | Virtual hard disk image (`data.img`) Windows VM KVM. |
| `<BACKUP_DIR>` *(Default: `/srv/backups`)* | Arsip pencadangan berkala (`.tar.gz` dan `.sql.gz`). |

---

## 🛠️ Langkah-Langkah Instalasi & Setup

### Langkah 1: Persiapan Berkas Konfigurasi (.env)

1. Salin berkas template `.env.example` menjadi `.env`:
   ```bash
   cp .env.example .env
   ```
2. Sesuaikan konfigurasi utama di dalam `.env`:
   ```env
   # Domain utama Gitea (contoh: linkbee.id)
   DOMAIN=example.com

   # Folder penyimpanan data persisten & backup
   DATA_DIR=/srv/data
   BACKUP_DIR=/srv/backups

   # Token Cloudflare Tunnel dari Zero Trust Dashboard
   CLOUDFLARE_TOKEN=eyJh...
   ```
   *(Biarkan `LINUX_RUNNER_TOKEN` / `WINDOWS_RUNNER_TOKEN` kosong terlebih dahulu).*

---

### Langkah 2: Deploy Stack Utama (Gitea, Nginx, Cloudflared)

Jalankan instalasi stack utama melalui `make` atau skrip:

```bash
make install
# atau: sudo ./install.sh --all
```

Installer akan:
1. Memeriksa & memasang dependensi Docker Engine.
2. Membuat Docker network terisolasi (`git-network`).
3. Menyiapkan seluruh folder data persisten.
4. Mendeploy PostgreSQL, Gitea, Nginx, Cloudflared Tunnel, dan Cron Backup.
5. Melewati (*skip*) instalasi Runner karena token belum diisi.

Buka browser dan akses **`https://git.<DOMAIN>`** untuk membuat akun Administrator Gitea pertama Anda.

---

### Langkah 3: Mengambil Token & Deploy Gitea Runner

1. Masuk ke web Gitea dengan akun Administrator Anda.
2. Navigasikan ke **Site Administration (Administrasi Situs)** $\rightarrow$ **Actions** $\rightarrow$ **Runners**.
3. Klik tombol **Register runner** di pojok kanan atas, lalu salin **Registration Token** yang muncul.
4. Buka kembali berkas `.env` di server:
   ```env
   # Tentukan tipe runner yang diinginkan: linux, windows-vm, atau both-vm
   RUNNER_TYPE=both-vm

   # Konfigurasi Linux Runner (Docker-in-Docker)
   LINUX_RUNNER_NAME=gitea-runner-linux
   LINUX_RUNNER_LABELS=ubuntu-latest:docker://gitea/runner-images:ubuntu-latest
   LINUX_RUNNER_TOKEN=TOKEN_DARI_GITEA

   # Konfigurasi Windows Headless VM Runner (KVM)
   WINDOWS_RUNNER_NAME=gitea-runner-windows-vm
   WINDOWS_RUNNER_LABELS=windows:host,windows-msbuild:host,windows-latest:host
   WINDOWS_RUNNER_TOKEN=TOKEN_DARI_GITEA

   # Keamanan Port VNC Windows (127.0.0.1:8006 = aman via SSH Tunnel, 8006 = publik)
   WINDOWS_VM_VNC_PORT=127.0.0.1:8006
   ```
5. Deploy runner secara otomatis:
   ```bash
   make install-runner
   # atau: sudo ./install.sh --runner
   ```

Runner akan **langsung mendaftar dan aktif (Online)** di Web Gitea tanpa perlu membuka VNC manual! 🎉

---

## 🔒 Keamanan Akses VNC Windows (Port 8006)

Secara bawaan, Web VNC Windows VM dikunci ke `127.0.0.1:8006` sehingga **tidak dapat diakses oleh publik/internet**:

### Cara Mengakses Layar Windows dari Laptop/PC Lokal:
1. Buka terminal di laptop Anda dan buat SSH Tunnel ke server:
   ```bash
   ssh -L 8006:localhost:8006 ubuntu@IP_SERVER_ANDA
   ```
2. Buka browser di laptop Anda dan akses:
   **`http://localhost:8006`**
3. Anda dapat melihat layar desktop Windows VM secara aman dan terenkripsi.

*(Jika ingin membuka port secara publik langsung ke IP server, ubah `WINDOWS_VM_VNC_PORT=8006` di `.env` lalu jalankan `make install-runner`).*

---

## 🌐 Konfigurasi Cloudflare Tunnel

Tambahkan **3 Public Hostname** berikut pada Cloudflare Zero Trust Dashboard Anda:

| Public Hostname (Domain) | Service Type | URL Service Internal | Keterangan |
| :--- | :--- | :--- | :--- |
| `git.<DOMAIN>` | `HTTP` | `http://nginx:80` | Akses Web UI & HTTP Git Clone |
| `ssh.<DOMAIN>` | `SSH` | `ssh://host.docker.internal:22` | Akses SSH langsung ke Host OS server |
| `git-ssh.<DOMAIN>` | `SSH` | `ssh://gitea:22` | Akses Git Cloning / Push via SSH |

---

## 🔑 Konfigurasi SSH Client di Laptop / PC Pengembang

Agar laptop Anda dapat melakukan `git clone` / `git push` via SSH melalui Cloudflare Tunnel, jalankan perintah otomatis berikut **langsung di terminal komputer lokal Anda** (tanpa perlu meng-clone repo ini):

### 🪟 Windows (PowerShell)
```powershell
irm https://raw.githubusercontent.com/NaraMizaru/gitea-cloudflared-installer/main/setup-ssh.ps1 | iex
```

### 🐧 Linux & 🍎 macOS (atau Windows Git Bash / WSL)
```bash
curl -fsSL https://raw.githubusercontent.com/NaraMizaru/gitea-cloudflared-installer/main/setup-ssh.sh | bash
```

---

## ⚙️ Penyesuaian `app.ini` Gitea (Tautan Clone)

Setelah Cloudflare Tunnel aktif, sesuaikan konfigurasi internal Gitea agar tautan clone yang tampil di web menggunakan domain Anda:

1. Buka berkas `app.ini` di server:
   ```bash
   nano /srv/data/gitea/gitea/conf/app.ini
   ```
2. Sesuaikan bagian `[server]`:
   ```ini
   [server]
   PROTOCOL         = http
   DOMAIN           = git.<DOMAIN>
   SSH_DOMAIN       = git-ssh.<DOMAIN>
   HTTP_PORT        = 3000
   ROOT_URL         = https://git.<DOMAIN>
   DISABLE_SSH      = false
   SSH_PORT         = 2222
   SSH_LISTEN_PORT  = 22
   LFS_START_SERVER = true
   ```
3. Restart Gitea:
   ```bash
   docker restart gitea
   ```

---

## 💾 Sistem Pencadangan (Backup)

Installer secara otomatis memasang skrip cron di `/usr/local/bin/backup-gitea.sh`.
- **Manajemen Retensi**: File cadangan lama yang melebihi batas `BACKUP_RETENTION_DAYS` (default: 30 hari) akan dibersihkan otomatis.
- **Picu Pencadangan Manual**:
  ```bash
  make backup
  # atau: sudo /usr/local/bin/backup-gitea.sh
  ```
- File arsip disimpan di: `<BACKUP_DIR>/{gitea,postgres,compose}`.

---

## 🔄 Pembaruan Stack (Update Workflow)

Kapan pun ada fitur atau pembaruan konfigurasi baru di repositori GitHub, perbarui server Anda dengan aman tanpa downtime data:

```bash
# Mengambil update Git & me-redeploy konfigurasi
make update

# Mengambil update Git + menarik Docker Image terbaru
make update-pull-images
```

*(Skrip `update.sh` bersifat idempotent dan otomatis mengecek jika ada variabel baru di `.env.example` yang belum Anda pasang di `.env`).*

---

## 🎛️ Antarmuka Manajemen CLI (`Makefile`)

Tersedia perintah CLI lengkap untuk operasional server sehari-hari:

```text
Penggunaan: make <perintah>
```

| Perintah | Deskripsi |
| :--- | :--- |
| `make help` | Menampilkan panduan seluruh perintah yang tersedia |
| `make install` | Deploy seluruh stack (melewati modul yang sudah terpasang & up-to-date) |
| `make force-install` | Paksa deploy ulang seluruh stack tanpa pengecekan status |
| `make install-gitea` | Deploy layanan Gitea & database PostgreSQL saja |
| `make install-runner` | Deploy layanan Gitea Runner (Linux & Windows VM) saja |
| `make reset-runner` | **Hentikan & bersihkan total data runner (disk VM & cache OEM) untuk deploy bersih** |
| `make install-proxy` | Deploy Nginx Reverse Proxy saja |
| `make install-tunnel` | Deploy Cloudflared Tunnel saja |
| `make install-backup` | Pasang cron job pencadangan otomatis saja |
| `make update` | Ambil update Git (`git pull`) dan terapkan perubahan konfigurasi |
| `make update-pull-images` | Ambil update Git + unduh Docker image terbaru |
| `make up` | Jalankan seluruh container stack di background |
| `make down` | Hentikan seluruh container stack |
| `make restart` | Restart seluruh container stack secara berurutan |
| `make ps` / `make status` | Tampilkan status running container, ports, & kesehatan service |
| `make logs` | Pantau live log seluruh container (`make logs-gitea`, `make logs-runner`, dll) |
| `make backup` | Jalankan pencadangan manual sekarang |
| `make check-env` | Periksa kelengkapan variabel `.env` terhadap `.env.example` |
| `make setup-ssh` | Jalankan wizard otomatisasi konfigurasi SSH client |

---

## 📄 Lisensi
Didistribusikan di bawah lisensi MIT. Silakan gunakan dan kembangkan sesuai kebutuhan deployment Anda.
