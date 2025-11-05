<#
This script renames files based on a CSV of rename pairs.

Behavior updates:
- Only processes the following directories (recursively):
  2021 Logos\, 2024 Logos\, 2024 Logos (AA)\,
  Legacy\logotype-emf\, Legacy\logotype-eps\, Legacy\logotype-jpg\,
  Legacy\logotype-pdf\, Legacy\logotype-png\, Legacy\logotype-svg\
- Prefers exact base-name matches (full file name without extension) using the CSV
  Old column as the full base name, and renames to New (base name) while preserving
  the original extension.
- If no exact match is found, falls back to the previous behavior of fragment
  replacement within the base name (not the path or extension), using CSV pairs
  as fragment -> replacement.
- Logs errors to rename_errors.log
#>

# Path to the CSV file
$csvPath = ".\tools\naming_scheme_pairs.csv"

# Error log file path
$errorLogPath = "rename_errors.log"
if (Test-Path $errorLogPath) { Remove-Item $errorLogPath }

if (-not (Test-Path $csvPath)) {
    Write-Host "CSV file not found at $csvPath" -ForegroundColor Red
    exit 1
}

# Read the CSV: two columns (no header row in file): Old,New
$mapping = Import-Csv -Path $csvPath -Header Old,New

# Build a hashtable for fast exact base-name lookups
$exactMap = @{}
foreach ($pair in $mapping) {
    # Trim to avoid whitespace surprises in CSV
    $old = ($pair.Old | ForEach-Object { $_.Trim() })
    $new = ($pair.New | ForEach-Object { $_.Trim() })
    if ([string]::IsNullOrWhiteSpace($old)) { continue }
    $exactMap[$old] = $new
}

# Prompt for dry-run
$dryRun = $false
$resp = Read-Host "Dry-run mode (no files will be renamed)? (Y/N)"
switch (($resp | ForEach-Object { $_.ToString().Trim().ToLower() })) {
    'y' { $dryRun = $true }
    'yes' { $dryRun = $true }
    default { $dryRun = $false }
}
if ($dryRun) {
    Write-Host "Running in DRY-RUN mode. No changes will be made." -ForegroundColor Yellow
}

# Target directories (relative to repo root / script working dir)
$targetDirs = @(
    "2021 Logos",
    "2024 Logos",
    "2024 Logos (AA)",
    "Legacy\logotype-emf",
    "Legacy\logotype-eps",
    "Legacy\logotype-jpg",
    "Legacy\logotype-pdf",
    "Legacy\logotype-png",
    "Legacy\logotype-svg"
)

# Collect all files within target directories
$allFiles = @()
foreach ($relDir in $targetDirs) {
    $dirPath = Join-Path -Path (Get-Location) -ChildPath $relDir
    if (Test-Path $dirPath) {
        $allFiles += Get-ChildItem -Path $dirPath -Recurse -File -ErrorAction SilentlyContinue
    } else {
        Write-Host "Skip missing directory: $relDir" -ForegroundColor Yellow
    }
}

foreach ($file in $allFiles) {
    $originalName = $file.Name
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($originalName)
    $extension = [System.IO.Path]::GetExtension($originalName)

    $newBaseName = $null

    # 1) Try exact base-name mapping
    if ($exactMap.ContainsKey($baseName)) {
        $newBaseName = $exactMap[$baseName]
    } else {
        # 2) Fallback: fragment replacement within base name only
        $temp = $baseName
        foreach ($pair in $mapping) {
            $oldFrag = ($pair.Old | ForEach-Object { $_.Trim() })
            $newFrag = ($pair.New | ForEach-Object { $_.Trim() })
            if ([string]::IsNullOrWhiteSpace($oldFrag)) { continue }
            if ($temp.Contains($oldFrag)) { $temp = $temp.Replace($oldFrag, $newFrag) }
        }
        if ($temp -ne $baseName) { $newBaseName = $temp }
    }

    if ($null -ne $newBaseName -and $newBaseName -ne $baseName) {
        $newName = "$newBaseName$extension"
        $newPath = Join-Path -Path $file.DirectoryName -ChildPath $newName
        if (Test-Path $newPath) {
            $errMsg = "Conflict: '$($newPath)' already exists. Skipping rename for '$($file.FullName)'."
            Write-Host $errMsg -ForegroundColor Red
            Add-Content -Path $errorLogPath -Value $errMsg
            continue
        }
        if ($dryRun) {
            Write-Host "[DRY-RUN] Would rename '$($file.FullName)' -> '$newPath'" -ForegroundColor Cyan
        } else {
            try {
                Rename-Item -Path $file.FullName -NewName $newName -ErrorAction Stop
                Write-Host "Renamed '$($file.FullName)' to '$newPath'"
            } catch {
                $errMsg = "Failed to rename '$($file.FullName)' to '$newPath': $($_.Exception.Message)"
                Write-Host $errMsg -ForegroundColor Red
                Add-Content -Path $errorLogPath -Value $errMsg
            }
        }
    }
}
if ($dryRun) { Write-Host "Dry-run complete." -ForegroundColor Green } else { Write-Host "Rename process complete." -ForegroundColor Green }