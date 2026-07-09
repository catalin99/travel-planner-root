#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstraps the TravelPlanner workspace by cloning the two product repos into place.

.DESCRIPTION
    The travel-planner-root repo tracks only the shared/meta files (the .github AI
    tooling, .vscode tasks, PROJECT_OVERVIEW.md, IATA data). The two product repos live
    in their own GitHub repositories and are gitignored here. Run this script after
    cloning travel-planner-root to reconstruct the exact working folder structure:

        Projects/
          .github/                    (from travel-planner-root)
          .vscode/                    (from travel-planner-root)
          PROJECT_OVERVIEW.md         (from travel-planner-root)
          iata_airports_all.csv/.xlsx (from travel-planner-root)
          TravelPlanner/              -> cloned from travel-planner-BE
          travel-planner-frontend/    -> cloned from travel-planner-FE

    Idempotent: skips any target that is already a git repo.

.EXAMPLE
    ./init.ps1

.EXAMPLE
    ./init.ps1 -Branch master
#>
[CmdletBinding()]
param(
    [string]$Root        = $PSScriptRoot,
    [string]$BackendUrl  = 'https://github.com/catalin99/travel-planner-BE.git',
    [string]$FrontendUrl = 'https://github.com/catalin99/travel-planner-FE.git',
    [string]$Branch      = 'master'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git is not installed or not on PATH. Install Git for Windows first.'
}

function Initialize-Repo {
    param([string]$Url, [string]$RelPath)

    $full = Join-Path $Root $RelPath

    if (Test-Path (Join-Path $full '.git')) {
        Write-Host "[skip]  $RelPath is already a git repo." -ForegroundColor Yellow
        return
    }
    if ((Test-Path $full) -and (Get-ChildItem -LiteralPath $full -Force -ErrorAction SilentlyContinue | Select-Object -First 1)) {
        Write-Warning "[warn]  $RelPath exists and is not empty — skipping clone (move it aside to re-clone)."
        return
    }

    Write-Host "[clone] $Url -> $RelPath ($Branch)" -ForegroundColor Cyan
    git clone --branch $Branch $Url $full
    if ($LASTEXITCODE -ne 0) { throw "git clone failed for $Url" }
}

Write-Host "Initializing TravelPlanner workspace under: $Root`n" -ForegroundColor Green

Initialize-Repo -Url $BackendUrl  -RelPath 'TravelPlanner'
Initialize-Repo -Url $FrontendUrl -RelPath 'travel-planner-frontend'

Write-Host "`nDone. Folder structure ready." -ForegroundColor Green
Write-Host "Next: open the workspace, then 'start' the stack (see .github app-lifecycle skill)." -ForegroundColor Green
