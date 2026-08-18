<#
    Publishes the Obsidian notes to https://alelom.github.io/holydays-pyrenees/

    Usage:
        .\publish.ps1
        .\publish.ps1 -Message "Add Graus workshop details"

    Copies the vault folder into content/, commits, and pushes to the v5 branch.
    Pushing is what triggers the GitHub Actions build, so git is the only
    requirement here - Node is not needed unless you want a local preview.
#>

param(
    [string]$Message = "Update Pyrenees notes from Obsidian vault"
)

$ErrorActionPreference = "Stop"

$VaultFolder = "P:\Documents\personal-development\Holidays brainstorming\Pyrenees"
$ContentDir = Join-Path $PSScriptRoot "content"

# Pages written directly in this repo rather than synced from the vault.
$RepoAuthored = @("index.md")

if (-not (Test-Path $VaultFolder)) {
    throw "Vault folder not found: $VaultFolder"
}

Write-Host "Syncing from: $VaultFolder" -ForegroundColor Cyan

$vaultItems = Get-ChildItem $VaultFolder -Recurse -File
if ($vaultItems.Count -eq 0) {
    throw "No files found in the vault folder - refusing to publish an empty site."
}

foreach ($item in $vaultItems) {
    $relative = $item.FullName.Substring($VaultFolder.Length).TrimStart('\')
    $target = Join-Path $ContentDir $relative
    $targetParent = Split-Path $target -Parent
    if (-not (Test-Path $targetParent)) {
        New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
    }
    Copy-Item $item.FullName $target -Force
    Write-Host "  + $relative"
}

# Drop pages whose source note no longer exists, so the site matches the vault.
$vaultRelatives = $vaultItems | ForEach-Object { $_.FullName.Substring($VaultFolder.Length).TrimStart('\') }
Get-ChildItem $ContentDir -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($ContentDir.Length).TrimStart('\')
    if ($RepoAuthored -notcontains $relative -and $vaultRelatives -notcontains $relative) {
        Remove-Item $_.FullName -Force
        Write-Host "  - $relative (no longer in vault)" -ForegroundColor Yellow
    }
}

Push-Location $PSScriptRoot
try {
    git add content
    if ([string]::IsNullOrWhiteSpace((git status --porcelain content))) {
        Write-Host "No content changes - nothing to publish." -ForegroundColor Yellow
        return
    }

    git commit -m $Message
    git push origin v5

    Write-Host ""
    Write-Host "Pushed. GitHub Actions is now rebuilding the site." -ForegroundColor Green
    Write-Host "  Progress: https://github.com/alelom/holydays-pyrenees/actions"
    Write-Host "  Site:     https://alelom.github.io/holydays-pyrenees/"
}
finally {
    Pop-Location
}
