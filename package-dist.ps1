param (
    [switch]$publishLocal
)


function Find-Section() {
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string[]]$content,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$section
    )

    process {
        [int]$idx = 0
        for ($idx = 0; $idx -lt $content.Count; $idx++) {

            $line = $content[$idx].Trim()
            
            if ($line.Contains("[$section]")) {
                Write-Host "Found section $section at $idx"
                return $idx
            }
        }
        return -1
    }
}


function Find-Key {
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string[]]$content,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$section,
        [Parameter(Mandatory = $true, Position = 2)]
        [string]$key
    )
    process {
        [int]$idx = Find-Section $content $section
        if ($idx -gt -1) {
            for ($idx; $idx -lt $content.Count; $idx++) {
                $line = $content[$idx].Trim()
                if ($line.Trim().StartsWith($key) -and $line.Contains("=")) {
                    Write-Host("Find-Key Found $key at $idx")
                    return $idx
                }
            }
        }
        return -1
    }
}

function Find-KeyValue {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string[]]$content,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$section,
        [Parameter(Mandatory = $true, Position = 2)]
        [string]$key,
        [Parameter(Mandatory = $false, Position = 3)]
        [int]$keyIndex = -1
    )
    process {
        [int]$idx = ($keyIndex -gt -1) ? $keyIndex : (Find-Key $content $section $key)
        $line = $content[$idx].Trim()
        if ($line.StartsWith($key) -and $line.Contains("=")) {
            $parts = $line.Split([char[]]"=", [System.StringSplitOptions]::RemoveEmptyEntries)
            Write-Host "Found key value $line"
            if ($parts.Count -ge 2) {
                return $parts[1].Trim()                    
            }
        }
        return ""
    }
}

$tomlFilePath = "./pyproject.toml"
$section = "project"
$key = "version"

Write-Host "Updating version in $tomlFilePath"

[string[]]$data = Get-Content -Path $tomlFilePath

$versionIndex = Find-Key -content $data -section $section -key $key

$currentVersionString = Find-KeyValue $data $section $key $versionIndex

Write-Host "Current Version: $currentVersionString"

$currentVersion = [version]$currentVersionString.Trim("'`"")

$newBuild = $currentVersion.Build + 1

$newVersion = [version]::new($currentVersion.Major, $currentVersion.Minor, $newBuild)

Write-Host "Writing new version $newVersion"

$newContent = [System.Collections.Generic.List[string]]$data

$newContent[$versionIndex] = "$key=`"$newVersion`""

Set-Content -Path $tomlFilePath -Value $newContent

Write-Host "Updating stubgen files"
poetry run stubgen ./russell/ -o .

# Write-Host "Copying stub files to source directories"
# robocopy ./out/russell/ ./russell/ /E /MOVE

Write-Host "Removing existing package files in ./dist"
Remove-Item -Path "./dist" -Recurse -Force

Write-Host "Building package..."
python -m build
Write-Host "Package built"

if ($publishLocal) {
    Write-Host "Publishing package to local pypiserver"
    twine upload --repository-url http://192.168.50.11:8297/ ./dist/* --verbose
    Write-Host "Package publish complete."
}

