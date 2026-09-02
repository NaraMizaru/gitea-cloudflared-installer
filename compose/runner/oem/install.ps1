Set-ExecutionPolicy Bypass -Scope Process -Force

$LogFile = "C:\oem\install-runner.log"
Start-Transcript -Path $LogFile -Append

Write-Host "=================================================="
Write-Host "  Auto-Installing Gitea Windows Runner & BuildTools "
Write-Host "=================================================="

# 1. Install Chocolatey
if (-not (Get-Command "choco" -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Installing Chocolatey package manager..."
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path += ";C:\ProgramData\chocolatey\bin"
}

# 2. Install Packages
Write-Host "[*] Installing Git, PowerShell Core, Node.js, Python..."
choco install -y git powershell-core nodejs python docker-cli

Write-Host "[*] Installing Visual Studio 2022 Build Tools (MSBuild, .NET SDK)..."
choco install -y visualstudio2022buildtools --package-parameters " \
    --quiet --norestart \
    --add Microsoft.VisualStudio.Workload.VisualStudioExtensionBuildTools \
    --add Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools \
    --add Microsoft.NetCore.Component.SDK \
    --add Microsoft.Net.Component.4.8.TargetingPack \
    "

$env:Path += ";C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin;C:\Program Files\Git\usr\bin"
[Environment]::SetEnvironmentVariable("Path", $env:Path, "Machine")

# 3. Setup Gitea act_runner
$RunnerDir = "C:\actions-runner"
if (-not (Test-Path -Path $RunnerDir)) {
    New-Item -ItemType Directory -Force -Path $RunnerDir | Out-Null
}

Set-Location $RunnerDir

if (-not (Test-Path -Path "$RunnerDir\act_runner.exe")) {
    Write-Host "[*] Downloading Gitea act_runner..."
    $RunnerVersion = "3.3.2"
    $RunnerUrl = "https://gitea.com/gitea/act_runner/releases/download/v$RunnerVersion/act_runner-$RunnerVersion-windows-amd64.exe"
    Invoke-WebRequest -Uri $RunnerUrl -OutFile "$RunnerDir\act_runner.exe"
}

# Env variables passed from docker-compose / environment file
$GiteaUrl = $env:GITEA_INSTANCE_URL
$Token = $env:GITEA_RUNNER_REGISTRATION_TOKEN
$RunnerName = if ($env:GITEA_RUNNER_NAME) { $env:GITEA_RUNNER_NAME } else { "gitea-runner-windows-vm" }
$Labels = if ($env:GITEA_RUNNER_LABELS) { $env:GITEA_RUNNER_LABELS } else { "windows:host,windows-msbuild:host,windows-latest:host" }

if (-not (Test-Path -Path "$RunnerDir\.runner")) {
    if ($GiteaUrl -and $Token) {
        Write-Host "[*] Registering Gitea Runner: $RunnerName..."
        .\act_runner.exe register --no-interactive --instance $GiteaUrl --token $Token --name $RunnerName --labels $Labels
    } else {
        Write-Host "[!] Skipping registration: GITEA_INSTANCE_URL or GITEA_RUNNER_REGISTRATION_TOKEN not provided."
    }
}

# 4. Start act_runner daemon
Write-Host "[*] Starting Gitea act_runner daemon..."
Start-Process "$RunnerDir\act_runner.exe" -ArgumentList "daemon" -WindowStyle Hidden

Stop-Transcript
