Set-ExecutionPolicy Bypass -Scope Process -Force

$LogFile = "C:\oem\install-runner.log"
try {
    Start-Transcript -Path $LogFile -Append -ErrorAction SilentlyContinue
} catch {}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "       GITEA WINDOWS RUNNER AUTOMATIC PROVISIONING          " -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Waktu: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# ---------------------------------------------------------
# STEP 1: Muat Konfigurasi dan Injeksi Token
# ---------------------------------------------------------
Write-Host "[1/5] Membaca Konfigurasi dan Token Gitea..." -ForegroundColor Cyan

$GiteaUrl = $null
$Token = $null
$RunnerName = $null
$Labels = $null

# Cari file env di berbagai lokasi potensial
$envCandidates = @(
    "$PSScriptRoot\runner-env.ps1",
    "C:\oem\runner-env.ps1",
    "C:\OEM\runner-env.ps1"
)

$foundEnv = $null
foreach ($f in $envCandidates) {
    if (Test-Path $f) {
        $foundEnv = $f
        break
    }
}

if ($foundEnv) {
    Write-Host "  -> Memuat konfigurasi dari: $foundEnv" -ForegroundColor Green
    . $foundEnv
} else {
    Write-Host "  -> runner-env.ps1 tidak ditemukan, mencoba environment variable..." -ForegroundColor Yellow
}

# Fallback ke environment variable container jika belum terisi
if (-not $GiteaUrl) { $GiteaUrl = $env:GITEA_INSTANCE_URL }
if (-not $Token) {
    if ($env:WINDOWS_RUNNER_TOKEN) { $Token = $env:WINDOWS_RUNNER_TOKEN }
    elseif ($env:GITEA_RUNNER_REGISTRATION_TOKEN) { $Token = $env:GITEA_RUNNER_REGISTRATION_TOKEN }
    elseif ($env:RUNNER_TOKEN) { $Token = $env:RUNNER_TOKEN }
}
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
# STEP 2: Siapkan Binary Gitea Runner
# ---------------------------------------------------------
Write-Host "[2/5] Menyiapkan Direktori dan Binary Gitea Runner..." -ForegroundColor Cyan
$RunnerDir = "C:\actions-runner"
if (-not (Test-Path -Path $RunnerDir)) {
    New-Item -ItemType Directory -Force -Path $RunnerDir | Out-Null
}

Set-Location $RunnerDir

# Cek apakah binary sudah ada dari C:\OEM (pre-downloaded dari host)
$oemBinary = @("C:\oem\gitea-runner.exe", "C:\OEM\gitea-runner.exe", "$PSScriptRoot\gitea-runner.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not (Test-Path -Path "$RunnerDir\gitea-runner.exe")) {
    if ($oemBinary) {
        Write-Host "  -> Menyalin gitea-runner.exe dari $oemBinary..." -ForegroundColor Green
        Copy-Item -Path $oemBinary -Destination "$RunnerDir\gitea-runner.exe" -Force
    } else {
        $RunnerVersion = "3.3.2"
        $RunnerUrl = "https://gitea.com/gitea/runner/releases/download/v$RunnerVersion/gitea-runner-$RunnerVersion-windows-amd64.exe"
        Write-Host "  -> Mengunduh gitea-runner v$RunnerVersion dari internet..." -ForegroundColor Gray
        try {
            Invoke-WebRequest -Uri $RunnerUrl -OutFile "$RunnerDir\gitea-runner.exe"
            Write-Host "  [OK] gitea-runner.exe berhasil diunduh ke $RunnerDir" -ForegroundColor Green
        } catch {
            Write-Host "  [FAIL] Gagal mengunduh gitea-runner.exe: $_" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  -> gitea-runner.exe sudah tersedia di $RunnerDir" -ForegroundColor Green
}
Write-Host ""

# ---------------------------------------------------------
# STEP 3: Generate Config dan Register Runner
# ---------------------------------------------------------
Write-Host "[3/5] Konfigurasi dan Registrasi Runner ke Gitea..." -ForegroundColor Cyan

$configTemplate = @("C:\oem\config.windows-vm.yaml", "C:\OEM\config.windows-vm.yaml", "$PSScriptRoot\config.windows-vm.yaml") | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not (Test-Path -Path "$RunnerDir\config.yaml")) {
    if ($configTemplate) {
        Write-Host "  -> Menyalin template konfigurasi dari $configTemplate..." -ForegroundColor Gray
        Copy-Item -Path $configTemplate -Destination "$RunnerDir\config.yaml" -Force
    } else {
        Write-Host "  -> Men-generate konfigurasi default config.yaml..." -ForegroundColor Gray
        .\gitea-runner.exe generate-config > "$RunnerDir\config.yaml"
    }
}

if (-not (Test-Path -Path "$RunnerDir\.runner")) {
    if ($GiteaUrl -and $Token) {
        $maxRetries = 6
        $retryCount = 0
        $registered = $false

        while (-not $registered -and $retryCount -lt $maxRetries) {
            $retryCount++
            Write-Host "  -> Mendaftarkan runner ke instance Gitea (Percobaan $retryCount/$maxRetries)..." -ForegroundColor Yellow
            $regOutput = .\gitea-runner.exe register --no-interactive --instance $GiteaUrl --token $Token --name $RunnerName --labels $Labels 2>&1
            Write-Host "     $regOutput" -ForegroundColor Gray
            
            if (Test-Path -Path "$RunnerDir\.runner") {
                $registered = $true
                Write-Host "  [OK] Registrasi BERHASIL! File .runner berhasil dibuat." -ForegroundColor Green
            } else {
                if ($retryCount -lt $maxRetries) {
                    Write-Host "  [!] Registrasi belum berhasil, menunggu 5 detik sebelum mencoba lagi..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 5
                }
            }
        }

        if (-not $registered) {
            Write-Host "  [FAIL] Registrasi GAGAL setelah $maxRetries percobaan. Periksa token atau koneksi ke $GiteaUrl." -ForegroundColor Red
        }
    } else {
        Write-Host "  [!] Melewati registrasi: URL Gitea atau Token belum diisi." -ForegroundColor Yellow
    }
} else {
    Write-Host "  -> File registrasi (.runner) sudah ada. Melewati pendaftaran ulang." -ForegroundColor Green
}
Write-Host ""

# ---------------------------------------------------------
# STEP 4: Pasang dan Jalankan Service Windows
# ---------------------------------------------------------
Write-Host "[4/5] Memasang Service Background Runner (Windows Startup Task)..." -ForegroundColor Cyan
try {
    $Action = New-ScheduledTaskAction -Execute "$RunnerDir\gitea-runner.exe" -Argument "daemon --config `"$RunnerDir\config.yaml`"" -WorkingDirectory $RunnerDir
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName "GiteaRunner" -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
    Start-ScheduledTask -TaskName "GiteaRunner"
    Write-Host "  [OK] Service Task 'GiteaRunner' berhasil dipasang dan dijalankan!" -ForegroundColor Green
} catch {
    Write-Host "  -> Fallback: Menjalankan daemon secara langsung di background..." -ForegroundColor Yellow
    Start-Process "$RunnerDir\gitea-runner.exe" -ArgumentList "daemon", "--config", "$RunnerDir\config.yaml" -WindowStyle Hidden
}

# Pasang startup shortcut di Common Startup sebagai cadangan
try {
    $startupDir = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
    if (Test-Path $startupDir) {
        $startupBat = "@echo off`r`ntasklist /FI `"IMAGENAME eq gitea-runner.exe`" 2>NUL | find /I /N `"gitea-runner.exe`" >NUL || start `"`" /min `"$RunnerDir\gitea-runner.exe`" daemon --config `"$RunnerDir\config.yaml`""
        Set-Content -Path "$startupDir\run-gitea-runner.bat" -Value $startupBat -Force
    }
} catch {}
Write-Host ""

# ---------------------------------------------------------
# STEP 5: Pasang Paket dan Toolchain (GitHub Actions Suite)
# ---------------------------------------------------------
Write-Host "[5/5] Memasang Toolchain Pengembang Lengkap (GitHub Actions Suite)..." -ForegroundColor Cyan

if (-not (Get-Command "choco" -ErrorAction SilentlyContinue)) {
    Write-Host "  -> Memasang Chocolatey package manager..." -ForegroundColor Gray
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    try {
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:Path += ";C:\ProgramData\chocolatey\bin"
        Write-Host "  [OK] Chocolatey terpasang." -ForegroundColor Green
    } catch {
        Write-Host "  [!] Gagal memasang Chocolatey: $_" -ForegroundColor Yellow
    }
}

if (Get-Command "choco" -ErrorAction SilentlyContinue) {
    # 1. Core CLI dan Utilities (Git, 7-Zip, PowerShell Core)
    Write-Host "  -> [1/5] Memasang Git, 7-Zip, PowerShell Core..." -ForegroundColor Yellow
    choco install -y git 7zip.install powershell-core --no-progress

    # 2. Web Runtimes dan Package Managers (Node.js, npm, yarn, pnpm, Python)
    Write-Host "  -> [2/5] Memasang Node.js LTS, Yarn, Pnpm, Python 3..." -ForegroundColor Yellow
    choco install -y nodejs-lts yarn pnpm python3 --no-progress

    # 3. Compilers dan SDKs (.NET SDK, Go, Java 17 Temurin)
    Write-Host "  -> [3/5] Memasang .NET SDK, Golang, Java 17 Temurin..." -ForegroundColor Yellow
    choco install -y dotnet-sdk golang temurin17 --no-progress

    # 4. Build Tools (CMake, Ninja)
    Write-Host "  -> [4/5] Memasang CMake, Ninja..." -ForegroundColor Yellow
    choco install -y cmake ninja --no-progress

    # 5. Visual Studio 2022 MSBuild Tools
    Write-Host "  -> [5/5] Memasang Visual Studio 2022 MSBuild Tools..." -ForegroundColor Yellow
    choco install -y visualstudio2022buildtools --package-parameters "--add Microsoft.VisualStudio.Workload.MSBuildTools --quiet" --no-progress

    # Refresh Environment PATH
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    Write-Host "  [OK] Seluruh paket toolchain berhasil dipasang!" -ForegroundColor Green
}
Write-Host ""

Write-Host "============================================================" -ForegroundColor Green
Write-Host "  [OK] SETUP GITEA WINDOWS RUNNER SELESAI DENGAN SUKSES!    " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Runner sekarang aktif dan siap menerima job dari Gitea." -ForegroundColor Cyan
Write-Host ""

try {
    Stop-Transcript -ErrorAction SilentlyContinue
} catch {}
