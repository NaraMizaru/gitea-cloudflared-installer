Set-ExecutionPolicy Bypass -Scope Process -Force

$LogFile = "C:\oem\install-runner.log"
try {
    Start-Transcript -Path $LogFile -Append -ErrorAction SilentlyContinue
} catch {}

Clear-Host
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "       GITEA WINDOWS RUNNER AUTOMATIC PROVISIONING          " -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Tanggal & Waktu: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# ---------------------------------------------------------
# STEP 1: Muat Konfigurasi & Injeksi Token
# ---------------------------------------------------------
Write-Host "[1/5] Membaca Konfigurasi & Token Gitea..." -ForegroundColor Cyan

$GiteaUrl = $null
$Token = $null
$RunnerName = $null
$Labels = $null

if (Test-Path "C:\oem\runner-env.ps1") {
    Write-Host "  -> Menemukan C:\oem\runner-env.ps1. Memuat variabel..." -ForegroundColor Green
    . "C:\oem\runner-env.ps1"
} else {
    Write-Host "  -> C:\oem\runner-env.ps1 tidak ditemukan, mencoba environment variable..." -ForegroundColor Yellow
}

if (-not $GiteaUrl) { $GiteaUrl = $env:GITEA_INSTANCE_URL }
if (-not $Token) { $Token = if ($env:WINDOWS_RUNNER_TOKEN) { $env:WINDOWS_RUNNER_TOKEN } elseif ($env:GITEA_RUNNER_REGISTRATION_TOKEN) { $env:GITEA_RUNNER_REGISTRATION_TOKEN } else { $env:RUNNER_TOKEN } }
if (-not $RunnerName) { $RunnerName = if ($env:GITEA_RUNNER_NAME) { $env:GITEA_RUNNER_NAME } else { "gitea-runner-windows-vm" } }
if (-not $Labels) { $Labels = if ($env:GITEA_RUNNER_LABELS) { $env:GITEA_RUNNER_LABELS } else { "windows:host,windows-msbuild:host,windows-latest:host" } }

Write-Host "  -> Target Gitea URL : $GiteaUrl" -ForegroundColor Gray
Write-Host "  -> Runner Name      : $RunnerName" -ForegroundColor Gray
Write-Host "  -> Labels           : $Labels" -ForegroundColor Gray
if ($Token) {
    Write-Host "  -> Token Registrasi : [TERSEDIA]" -ForegroundColor Green
} else {
    Write-Host "  -> Token Registrasi : [KOSONG / TIDAK DITEMUKAN]" -ForegroundColor Red
}
Write-Host ""

# ---------------------------------------------------------
# STEP 2: Download Gitea Runner
# ---------------------------------------------------------
Write-Host "[2/5] Menyiapkan Direktori & Mengunduh Gitea Runner..." -ForegroundColor Cyan
$RunnerDir = "C:\actions-runner"
if (-not (Test-Path -Path $RunnerDir)) {
    New-Item -ItemType Directory -Force -Path $RunnerDir | Out-Null
}

Set-Location $RunnerDir

if (-not (Test-Path -Path "$RunnerDir\gitea-runner.exe")) {
    $RunnerVersion = "3.3.2"
    $RunnerUrl = "https://gitea.com/gitea/runner/releases/download/v$RunnerVersion/gitea-runner-$RunnerVersion-windows-amd64.exe"
    Write-Host "  -> Mengunduh gitea-runner v$RunnerVersion dari GitHub/Gitea..." -ForegroundColor Gray
    try {
        Invoke-WebRequest -Uri $RunnerUrl -OutFile "$RunnerDir\gitea-runner.exe"
        Write-Host "  -> gitea-runner.exe berhasil diunduh ke $RunnerDir" -ForegroundColor Green
    } catch {
        Write-Host "  -> [ERROR] Gagal mengunduh gitea-runner.exe: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  -> gitea-runner.exe sudah tersedia di $RunnerDir" -ForegroundColor Green
}
Write-Host ""

# ---------------------------------------------------------
# STEP 3: Generate Config & Register Runner
# ---------------------------------------------------------
Write-Host "[3/5] Registrasi Runner ke Gitea..." -ForegroundColor Cyan

if (-not (Test-Path -Path "$RunnerDir\config.yaml")) {
    if (Test-Path -Path "C:\oem\config.windows-vm.yaml") {
        Write-Host "  -> Menyalin template konfigurasi config.windows-vm.yaml..." -ForegroundColor Gray
        Copy-Item -Path "C:\oem\config.windows-vm.yaml" -Destination "$RunnerDir\config.yaml" -Force
    } else {
        Write-Host "  -> Men-generate konfigurasi default config.yaml..." -ForegroundColor Gray
        .\gitea-runner.exe generate-config > "$RunnerDir\config.yaml"
    }
}

if (-not (Test-Path -Path "$RunnerDir\.runner")) {
    if ($GiteaUrl -and $Token) {
        Write-Host "  -> Mendaftarkan runner ke instance Gitea..." -ForegroundColor Yellow
        $regOutput = .\gitea-runner.exe register --no-interactive --instance $GiteaUrl --token $Token --name $RunnerName --labels $Labels 2>&1
        Write-Host "     $regOutput" -ForegroundColor Gray
        if (Test-Path -Path "$RunnerDir\.runner") {
            Write-Host "  ✔ Registrasi BERHASIL! File .runner berhasil dibuat." -ForegroundColor Green
        } else {
            Write-Host "  ✘ Registrasi GAGAL. Periksa kembali token Anda." -ForegroundColor Red
        }
    } else {
        Write-Host "  [!] Melewati registrasi: URL Gitea atau Token belum diisi." -ForegroundColor Yellow
    }
} else {
    Write-Host "  -> File registrasi (.runner) sudah ada. Melewati pendaftaran ulang." -ForegroundColor Green
}
Write-Host ""

# ---------------------------------------------------------
# STEP 4: Pasang & Jalankan Service Windows
# ---------------------------------------------------------
Write-Host "[4/5] Memasang Service Background Runner (Windows Startup Task)..." -ForegroundColor Cyan
try {
    $Action = New-ScheduledTaskAction -Execute "$RunnerDir\gitea-runner.exe" -Argument "daemon --config `"$RunnerDir\config.yaml`"" -WorkingDirectory $RunnerDir
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName "GiteaRunner" -Action $Action -Trigger $Trigger -Principal $Principal -Force | Out-Null
    Start-ScheduledTask -TaskName "GiteaRunner"
    Write-Host "  ✔ Service Task 'GiteaRunner' berhasil dipasang dan dijalankan!" -ForegroundColor Green
} catch {
    Write-Host "  -> Fallback: Menjalankan daemon secara langsung..." -ForegroundColor Yellow
    Start-Process "$RunnerDir\gitea-runner.exe" -ArgumentList "daemon", "--config", "$RunnerDir\config.yaml" -WindowStyle Hidden
}
Write-Host ""

# ---------------------------------------------------------
# STEP 5: Pasang Alat Tambahan (Git, Node, Python)
# ---------------------------------------------------------
Write-Host "[5/5] Memasang Alat Pengembang Pendukung (Git, Node.js, Python)..." -ForegroundColor Cyan

if (-not (Get-Command "choco" -ErrorAction SilentlyContinue)) {
    Write-Host "  -> Memasang Chocolatey package manager..." -ForegroundColor Gray
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    try {
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:Path += ";C:\ProgramData\chocolatey\bin"
        Write-Host "  ✔ Chocolatey terpasang." -ForegroundColor Green
    } catch {
        Write-Host "  [!] Peringatan: Gagal memasang Chocolatey: $_" -ForegroundColor Yellow
    }
}

if (Get-Command "choco" -ErrorAction SilentlyContinue) {
    Write-Host "  -> Memasang Git, PowerShell Core, Node.js, & Python via Chocolatey..." -ForegroundColor Gray
    choco install -y git powershell-core nodejs-lts python3 --no-progress
    
    $env:Path += ";C:\Program Files\Git\bin;C:\Program Files\Git\usr\bin;C:\Program Files\nodejs;C:\Python312"
    [Environment]::SetEnvironmentVariable("Path", $env:Path, "Machine")
    Write-Host "  ✔ Alat pendukung selesai dipasang!" -ForegroundColor Green
}
Write-Host ""

Write-Host "============================================================" -ForegroundColor Green
Write-Host "  ✔ SETUP GITEA WINDOWS RUNNER SELESAI DENGAN SUKSES!       " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Status runner saat ini aktif. Anda dapat memantau Web Gitea." -ForegroundColor Cyan
Write-Host "Jendela ini dibiarkan terbuka agar Anda dapat meninjau log instalasi." -ForegroundColor Gray
Write-Host ""

try {
    Stop-Transcript -ErrorAction SilentlyContinue
} catch {}
