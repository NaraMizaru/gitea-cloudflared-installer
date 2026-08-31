# ============================================================
# Gitea Cloudflare Tunnel - SSH Client Setup (Windows PowerShell)
# ============================================================

[CmdletBinding()]
param (
    [Parameter(Position=0)]
    [string]$Domain,

    [Alias("host-ssh")]
    [switch]$HostSsh,

    [switch]$Uninstall,

    [Alias("h")]
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$ConfigStart = "# >>> Gitea Cloudflare SSH >>>"
$ConfigEnd   = "# <<< Gitea Cloudflare SSH <<<"

$SshDir    = Join-Path $HOME ".ssh"
$SshConfig = Join-Path $SshDir "config"

# ============================================================
# Logging Helpers
# ============================================================

function Write-InfoMessage ($message) {
    Write-Host "INFO  " -ForegroundColor Cyan -NoNewline
    Write-Host $message
}

function Write-SuccessMessage ($message) {
    Write-Host "OK    " -ForegroundColor Green -NoNewline
    Write-Host $message
}

function Write-WarningMessage ($message) {
    Write-Host "WARN  " -ForegroundColor Yellow -NoNewline
    Write-Host $message
}

function Write-ErrorMessage ($message) {
    Write-Host "ERROR " -ForegroundColor Red -NoNewline
    Write-Host $message
}

function Stop-WithDie ($message) {
    Write-ErrorMessage $message
    exit 1
}

# ============================================================
# Help
# ============================================================

if ($Help) {
    Write-Host @"

Gitea Cloudflare Tunnel - SSH Client Setup (PowerShell)

Usage:
    .\setup-ssh.ps1
    .\setup-ssh.ps1 <domain>
    .\setup-ssh.ps1 -HostSsh
    .\setup-ssh.ps1 -HostSsh <domain>
    .\setup-ssh.ps1 -Uninstall
    .\setup-ssh.ps1 -Help

Options:
    -HostSsh
        Enable SSH access to the server host (ssh.<domain>).

    -Uninstall
        Remove the SSH configuration created by this script.

    -Help
        Show this help message.

Examples:
    .\setup-ssh.ps1 example.com
    .\setup-ssh.ps1 -HostSsh example.com

"@
    exit 0
}

# ============================================================
# Uninstall
# ============================================================

function Remove-ConfigBlock {
    if (-not (Test-Path $SshConfig)) { return }

    $lines = Get-Content -Path $SshConfig
    $newLines = @()
    $inside = $false

    foreach ($line in $lines) {
        if ($line.Trim() -eq $ConfigStart) {
            $inside = $true
            continue
        }
        if ($line.Trim() -eq $ConfigEnd) {
            $inside = $false
            continue
        }
        if (-not $inside) {
            $newLines += $line
        }
    }

    Set-Content -Path $SshConfig -Value $newLines -Encoding UTF8
}

if ($Uninstall) {
    Write-Host ""
    Write-Host "Gitea Cloudflare SSH Uninstaller"
    Write-Host "────────────────────────────────"
    Write-Host ""

    if (-not (Test-Path $SshConfig)) {
        Write-InfoMessage "SSH config does not exist."
        exit 0
    }

    $content = Get-Content -Path $SshConfig -Raw -ErrorAction SilentlyContinue
    if (-not $content -or -not $content.Contains($ConfigStart)) {
        Write-InfoMessage "No configuration created by this script was found."
        exit 0
    }

    Remove-ConfigBlock
    Write-SuccessMessage "Cloudflare SSH configuration removed."
    Write-Host ""
    Write-Host "cloudflared was NOT uninstalled."
    Write-Host "To remove cloudflared, use winget, choco, or Windows Settings."
    Write-Host ""
    exit 0
}

# ============================================================
# Main Execution
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " Gitea Cloudflare Tunnel - SSH Client Setup (PowerShell)"
Write-Host "============================================================"
Write-Host ""

Write-InfoMessage "OS           : Windows"
Write-InfoMessage "Architecture : $env:PROCESSOR_ARCHITECTURE"
Write-Host ""

# ------------------------------------------------------------
# 1. Cloudflared Check & Installation
# ------------------------------------------------------------

Write-InfoMessage "Checking cloudflared..."

$cloudflaredCmd = Get-Command cloudflared -ErrorAction SilentlyContinue

if ($cloudflaredCmd) {
    $versionOutput = & cloudflared --version 2>&1 | Select-Object -First 1
    Write-SuccessMessage "cloudflared detected: $versionOutput"
} else {
    Write-WarningMessage "cloudflared is not installed in current PATH."
    Write-Host ""

    # Try common install locations before attempting package manager install
    $candidatePaths = @(
        "$env:ProgramFiles\cloudflared\cloudflared.exe",
        "${env:ProgramFiles(x86)}\cloudflared\cloudflared.exe",
        "$HOME\.local\bin\cloudflared.exe"
    )

    $foundPath = $null
    foreach ($p in $candidatePaths) {
        if (Test-Path $p) {
            $foundPath = $p
            break
        }
    }

    if (-not $foundPath) {
        $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
        $chocoCmd  = Get-Command choco -ErrorAction SilentlyContinue

        $pkgInstalled = $false
        if ($wingetCmd) {
            try {
                Write-InfoMessage "Installing cloudflared using winget..."
                & winget install --id Cloudflare.cloudflared --exact --accept-source-agreements --accept-package-agreements
                $pkgInstalled = $true
            } catch {
                Write-WarningMessage "winget installation failed or returned an error. Falling back to direct download."
            }
        } elseif ($chocoCmd) {
            try {
                Write-InfoMessage "Installing cloudflared using Chocolatey..."
                & choco install cloudflared -y
                $pkgInstalled = $true
            } catch {
                Write-WarningMessage "Chocolatey installation failed. Falling back to direct download."
            }
        }

        # Check candidate paths after package manager install attempt
        foreach ($p in $candidatePaths) {
            if (Test-Path $p) {
                $foundPath = $p
                break
            }
        }

        if (-not $foundPath) {
            Write-InfoMessage "Downloading cloudflared.exe directly from Cloudflare GitHub releases..."
            $binDir = Join-Path $HOME ".local\bin"
            if (-not (Test-Path $binDir)) { New-Item -ItemType Directory -Path $binDir -Force | Out-Null }
            $targetExe = Join-Path $binDir "cloudflared.exe"

            $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") { "amd64" } else { "386" }
            $downloadUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-$arch.exe"

            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri $downloadUrl -OutFile $targetExe -UseBasicParsing
                Write-SuccessMessage "Downloaded cloudflared.exe to $targetExe"
                $foundPath = $targetExe
            } catch {
                Stop-WithDie "Failed to download cloudflared.exe: $_"
            }
        }
    }

    if ($foundPath) {
        $binDir = Split-Path $foundPath -Parent
        Write-InfoMessage "Adding $binDir to User PATH..."
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$binDir*") {
            $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $binDir } else { "$userPath;$binDir" }
            [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
            $env:Path = "$binDir;$env:Path"
            Write-SuccessMessage "User PATH updated."
        }
    }

    $cloudflaredCmd = Get-Command cloudflared -ErrorAction SilentlyContinue
    if ($cloudflaredCmd) {
        $versionOutput = & cloudflared --version 2>&1 | Select-Object -First 1
        Write-SuccessMessage "cloudflared is ready: $versionOutput"
    } else {
        Write-WarningMessage "cloudflared is installed, but you may need to restart your PowerShell session for PATH changes to take effect."
    }
}

Write-Host ""

# ------------------------------------------------------------
# 2. SSH Client Check
# ------------------------------------------------------------

$sshCmd = Get-Command ssh -ErrorAction SilentlyContinue
if ($sshCmd) {
    Write-SuccessMessage "SSH client detected."
} else {
    Stop-WithDie "OpenSSH client was not found. Please enable OpenSSH Client in Windows Features or install via settings."
}

Write-Host ""

# ------------------------------------------------------------
# 3. Domain Input & Validation
# ------------------------------------------------------------

function Test-Domain ($domainStr) {
    if ([string]::IsNullOrWhiteSpace($domainStr)) {
        Stop-WithDie "Domain cannot be empty."
    }
    $domainStr = $domainStr.TrimEnd(".")
    if ($domainStr -like "*://*") {
        Stop-WithDie "Enter domain only without scheme (e.g. example.com, not https://example.com)."
    }
    if ($domainStr -like "*/*" -or $domainStr -like "* *") {
        Stop-WithDie "Domain must not contain slashes or spaces."
    }
    return $domainStr
}

if ([string]::IsNullOrWhiteSpace($Domain)) {
    Write-Host "Cloudflare Tunnel Domain"
    Write-Host "─────────────────────────"
    Write-Host "Example: example.com"
    Write-Host ""
    $Domain = Read-Host "Domain"
}

$Domain = Test-Domain $Domain

Write-Host ""

$gitHost  = "git-ssh.$Domain"
$hostSshHost = "ssh.$Domain"

Write-Host "Configuration"
Write-Host "────────────────────────────────────────"
Write-Host "✓ Git SSH  : $gitHost"
if ($HostSsh) {
    Write-Host "✓ Host SSH : $hostSshHost"
}
Write-Host ""

# ------------------------------------------------------------
# 4. Write SSH Config
# ------------------------------------------------------------

Write-InfoMessage "Updating SSH configuration..."

if (-not (Test-Path $SshDir)) {
    New-Item -ItemType Directory -Path $SshDir -Force | Out-Null
}

if (-not (Test-Path $SshConfig)) {
    New-Item -ItemType File -Path $SshConfig -Force | Out-Null
}

Remove-ConfigBlock

$blockLines = @(
    "",
    $ConfigStart,
    "",
    "# Gitea Git SSH via Cloudflare Tunnel",
    "Host $gitHost",
    "    ProxyCommand cloudflared access ssh --hostname %h"
)

if ($HostSsh) {
    $blockLines += @(
        "",
        "# Server Host SSH via Cloudflare Tunnel",
        "Host $hostSshHost",
        "    User %r",
        "    ProxyCommand cloudflared access ssh --hostname %h"
    )
}

$blockLines += @(
    "",
    $ConfigEnd,
    ""
)

Add-Content -Path $SshConfig -Value ($blockLines -join [Environment]::NewLine) -Encoding UTF8
Write-SuccessMessage "SSH configuration updated."

# ------------------------------------------------------------
# 5. Validation
# ------------------------------------------------------------

Write-Host ""
if ($sshCmd) {
    $testResult = & ssh -G $gitHost 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-SuccessMessage "Git SSH configuration is valid."
    } else {
        Write-WarningMessage "Git SSH configuration test failed."
    }
}

# ------------------------------------------------------------
# 6. Completion Summary
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================================"
Write-Host " Setup completed!"
Write-Host "============================================================"
Write-Host ""
Write-Host "Git SSH:"
Write-Host "    git clone git@${gitHost}:USERNAME/REPOSITORY.git"
Write-Host ""
if ($HostSsh) {
    Write-Host "Host SSH:"
    Write-Host "    ssh USERNAME@$hostSshHost"
    Write-Host ""
}
Write-Host "SSH config:"
Write-Host "    $SshConfig"
Write-Host ""
Write-Host "NOTE:"
Write-Host "cloudflared does not run as a client-side background service."
Write-Host "SSH/Git automatically invokes cloudflared through ProxyCommand."
Write-Host ""
