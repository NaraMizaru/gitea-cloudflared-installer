Set-ExecutionPolicy Bypass -Scope Process -Force

$LogFile = "C:\oem\install-runner.log"
Start-Transcript -Path $LogFile -Append

Write-Host "=================================================="
Write-Host "  Auto-Installing Gitea Windows Runner (Priority 1) "
Write-Host "=================================================="

# ---------------------------------------------------------
# STEP 1: Gitea Runner Setup & Registration (Instant Active)
# ---------------------------------------------------------
$RunnerDir = "C:\actions-runner"
if (-not (Test-Path -Path $RunnerDir)) {
    New-Item -ItemType Directory -Force -Path $RunnerDir | Out-Null
}

Set-Location $RunnerDir

if (-not (Test-Path -Path "$RunnerDir\gitea-runner.exe")) {
    Write-Host "[*] Downloading Gitea Runner v3.3.2..."
    $RunnerVersion = "3.3.2"
    $RunnerUrl = "https://gitea.com/gitea/runner/releases/download/v$RunnerVersion/gitea-runner-$RunnerVersion-windows-amd64.exe"
    Invoke-WebRequest -Uri $RunnerUrl -OutFile "$RunnerDir\gitea-runner.exe"
}

# Load configuration from C:\oem\runner-env.ps1 if present
if (Test-Path "C:\oem\runner-env.ps1") {
    Write-Host "[*] Loading configuration from C:\oem\runner-env.ps1..."
    . "C:\oem\runner-env.ps1"
}

if (-not $GiteaUrl) { $GiteaUrl = $env:GITEA_INSTANCE_URL }
if (-not $Token) { $Token = if ($env:WINDOWS_RUNNER_TOKEN) { $env:WINDOWS_RUNNER_TOKEN } elseif ($env:GITEA_RUNNER_REGISTRATION_TOKEN) { $env:GITEA_RUNNER_REGISTRATION_TOKEN } else { $env:RUNNER_TOKEN } }
if (-not $RunnerName) { $RunnerName = if ($env:GITEA_RUNNER_NAME) { $env:GITEA_RUNNER_NAME } else { "gitea-runner-windows-vm" } }
if (-not $Labels) { $Labels = if ($env:GITEA_RUNNER_LABELS) { $env:GITEA_RUNNER_LABELS } else { "windows:host,windows-msbuild:host,windows-latest:host" } }

if (-not (Test-Path -Path "$RunnerDir\config.yaml")) {
    if (Test-Path -Path "C:\oem\config.windows-vm.yaml") {
        Write-Host "[*] Copying template config.windows-vm.yaml..."
        Copy-Item -Path "C:\oem\config.windows-vm.yaml" -Destination "$RunnerDir\config.yaml" -Force
    } else {
        Write-Host "[*] Generating default config.yaml..."
        .\gitea-runner.exe generate-config > "$RunnerDir\config.yaml"
    }
}

if (-not (Test-Path -Path "$RunnerDir\.runner")) {
    if ($GiteaUrl -and $Token) {
        Write-Host "[*] Registering Gitea Runner: $RunnerName to $GiteaUrl..."
        .\gitea-runner.exe register --no-interactive --instance $GiteaUrl --token $Token --name $RunnerName --labels $Labels
    } else {
        Write-Host "[!] Skipping registration: GiteaUrl or Token not provided."
    }
}

# Register Gitea runner as Scheduled Task and start immediately
Write-Host "[*] Registering Gitea runner daemon as Windows Startup Task..."
try {
    $Action = New-ScheduledTaskAction -Execute "$RunnerDir\gitea-runner.exe" -Argument "daemon --config `"$RunnerDir\config.yaml`"" -WorkingDirectory $RunnerDir
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName "GiteaRunner" -Action $Action -Trigger $Trigger -Principal $Principal -Force
    Start-ScheduledTask -TaskName "GiteaRunner"
    Write-Host "[*] Gitea runner task registered and started successfully!"
} catch {
    Write-Host "[!] Fallback: Starting process directly..."
    Start-Process "$RunnerDir\gitea-runner.exe" -ArgumentList "daemon", "--config", "$RunnerDir\config.yaml" -WindowStyle Hidden
}

# ---------------------------------------------------------
# STEP 2: Install Supporting Tools (Git, PowerShell, Node, Python)
# ---------------------------------------------------------
Write-Host "=================================================="
Write-Host "  Installing Development Tools in Background      "
Write-Host "=================================================="

# Install Chocolatey
if (-not (Get-Command "choco" -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Installing Chocolatey package manager..."
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    try {
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:Path += ";C:\ProgramData\chocolatey\bin"
    } catch {
        Write-Host "[!] Warning: Chocolatey install failed: $_"
    }
}

# Install Git, PowerShell Core, Node.js, Python
if (Get-Command "choco" -ErrorAction SilentlyContinue) {
    Write-Host "[*] Installing Git, PowerShell Core, Node.js, Python..."
    choco install -y git powershell-core nodejs-lts python3
    
    $env:Path += ";C:\Program Files\Git\bin;C:\Program Files\Git\usr\bin;C:\Program Files\nodejs;C:\Python312"
    [Environment]::SetEnvironmentVariable("Path", $env:Path, "Machine")
}

Stop-Transcript
