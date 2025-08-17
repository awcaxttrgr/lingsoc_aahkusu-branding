# Path to the CSV file
$csvPath = ".\tools\naming_scheme_pairs.csv"

# Read the CSV into an array of objects
$mapping = Import-Csv -Path $csvPath -Header Old,New

# Get all files recursively
Get-ChildItem -Recurse -File | ForEach-Object {
    $file = $_
    $newName = $file.Name
    foreach ($pair in $mapping) {
        if ($newName -like "*$($pair.Old)*") {
            $newName = $newName -replace [regex]::Escape($pair.Old), $pair.New
        }
    }
    if ($newName -ne $file.Name) {
        $newPath = Join-Path -Path $file.DirectoryName -ChildPath $newName
        Rename-Item -Path $file.FullName -NewName $newPath
        Write-Host "Renamed '$($file.FullName)' to '$newPath'"
    }
}