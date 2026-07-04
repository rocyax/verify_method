param(
    [string]$Manifest = "sha256sum.txt",
    [string]$Root = ".",
    [switch]$ExcludeSelf,
    [string[]]$ExtraExemptFiles = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-RelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $p = $Path -replace '\\', '/'
    $p = $p -replace '^[.][\\/]', ''
    return $p
}
$RootPath = Resolve-Path -LiteralPath $Root
Push-Location $RootPath

try {
    $ManifestPath = Join-Path (Get-Location) $Manifest

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        Write-Host "Manifest not found: $Manifest" -ForegroundColor Red
        exit 1
    }

    if (-not (Get-Command sha256sum -ErrorAction SilentlyContinue)) {
        Write-Host "sha256sum not found in PATH." -ForegroundColor Red
        Write-Host "Please install GNU coreutils or make sure sha256sum.exe is available."
        exit 1
    }
    $DefaultExemptFiles = @(
        "$Manifest.asc",
        "$Manifest.asc.ots",
        "$Manifest.asc.ots.bak",
        "$Manifest.sigstore.json"
    )

    $ExemptFiles = @($DefaultExemptFiles + $ExtraExemptFiles) |
        ForEach-Object { Normalize-RelativePath $_ } |
        Sort-Object -Unique

    Write-Host "[1/3] Checking SHA256 hashes..."

    sha256sum -c ".\$Manifest" --strict

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Hash check FAILED." -ForegroundColor Red
        exit 1
    }

    Write-Host "[2/3] Comparing file set..."
    $allowed = Get-Content -LiteralPath $ManifestPath |
        Where-Object {
            $_ -match '^[0-9a-fA-F]{64}\s+\*?.+$'
        } |
        ForEach-Object {
            $path = $_ -replace '^[0-9a-fA-F]{64}\s+\*?', ''
            Normalize-RelativePath $path
        } |
        Sort-Object -Unique
    $actual = Get-ChildItem -File -Recurse -Force|
        Where-Object {
            $rel = Resolve-Path -LiteralPath $_.FullName -Relative
            $rel = Normalize-RelativePath $rel
            if ($rel -eq (Normalize-RelativePath $Manifest)) {
                return $false
            }
            if ($ExemptFiles -contains $rel) {
                return $false
            }
            if ($ExcludeSelf) {
                $self = $PSCommandPath
                if ($self) {
                    $selfRel = Resolve-Path -LiteralPath $self -Relative -ErrorAction SilentlyContinue
                    if ($selfRel) {
                        $selfRel = Normalize-RelativePath $selfRel
                        if ($rel -eq $selfRel) {
                            return $false
                        }
                    }
                }
            }

            return $true
        } |
        ForEach-Object {
            $rel = Resolve-Path -LiteralPath $_.FullName -Relative
            Normalize-RelativePath $rel
        } |
        Sort-Object -Unique

    $diff = Compare-Object -ReferenceObject $allowed -DifferenceObject $actual

    $missing = $diff |
        Where-Object { $_.SideIndicator -eq '<=' } |
        ForEach-Object { $_.InputObject }

    $extra = $diff |
        Where-Object { $_.SideIndicator -eq '=>' } |
        ForEach-Object { $_.InputObject }

    if ($missing) {
        Write-Host ""
        Write-Host "Missing files:" -ForegroundColor Red
        $missing | ForEach-Object {
            Write-Host "  $_"
        }
    }

    if ($extra) {
        Write-Host ""
        Write-Host "Extra files:" -ForegroundColor Red
        $extra | ForEach-Object {
            Write-Host "  $_"
        }
    }

    if ($missing -or $extra) {
        Write-Host ""
        Write-Host "File set check FAILED." -ForegroundColor Red
        exit 1
    }

    Write-Host "[3/3] File set is exact."
    Write-Host "All files OK." -ForegroundColor Green
    exit 0
}
finally {
    Pop-Location
}
