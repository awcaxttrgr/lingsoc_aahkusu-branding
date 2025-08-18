# Script to check for file renaming conflicts based on a CSV mapping.

# Load the renaming rules from the CSV file
$mapping = @{}
Import-Csv -Path "c:\Users\aa981\GitLocal\lingsoc_aahkusu-branding\tools\naming_scheme_pairs.csv" -Header "Old", "New" | ForEach-Object {
    $mapping[$_.Old] = $_.New
}

# Get the list of files
$fileList = Get-Content -Path "c:\Users\aa981\GitLocal\lingsoc_aahkusu-branding\filelist.txt"

# Hashtable to store the new filenames and identify duplicates
$newNames = @{}
# Arrays to store the results
$renamedFiles = @()
$unaffectedFiles = @()
$conflicts = @()

foreach ($line in $fileList) {
    # Extract the filename from the line
    $fileName = $line.Split('|')[-1].Trim()

    if (-not [string]::IsNullOrWhiteSpace($fileName)) {
        $originalFileName = $fileName
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
        $extension = [System.IO.Path]::GetExtension($fileName)
        $foundMatch = $false

        foreach ($key in $mapping.Keys) {
            if ($baseName.Contains($key)) {
                $newBaseName = $baseName.Replace($key, $mapping[$key])
                $newName = $newBaseName + $extension
                
                if ($newNames.ContainsKey($newName)) {
                    $conflicts += "Conflict: '$originalFileName' and '$($newNames[$newName])' would both be renamed to '$newName'"
                } else {
                    $newNames[$newName] = $originalFileName
                }
                
                $renamedFiles += "Original: $originalFileName -> New: $newName"
                $foundMatch = $true
                break # Move to the next file once a match is found
            }
        }

        if (-not $foundMatch) {
            $unaffectedFiles += $originalFileName
        }
    }
}

# Output the results
Write-Output "Renaming Simulation Results:"
Write-Output "============================="

Write-Output "Unaffected Files:"
$unaffectedFiles | ForEach-Object { Write-Output "- $_" }

Write-Output "============================="
Write-Output "Renamed Files:"
$renamedFiles | ForEach-Object { Write-Output "- $_" }

Write-Output "============================="
Write-Output "Conflicts:"
if ($conflicts.Count -eq 0) {
    Write-Output "No conflicts found."
} else {
    $conflicts | ForEach-Object { Write-Output "- $_" }
}
