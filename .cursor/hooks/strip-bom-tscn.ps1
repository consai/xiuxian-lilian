$ErrorActionPreference = "Stop"

$raw = [Console]::In.ReadToEnd()
$payload = $null
if (-not [string]::IsNullOrWhiteSpace($raw)) {
    try {
        $payload = $raw | ConvertFrom-Json
    } catch {
        # Invalid JSON should not block editing; fallback scan still runs.
        $payload = $null
    }
}

$paths = New-Object System.Collections.Generic.List[string]
$protectedExtensions = @(".tscn", ".tres", ".gd", ".godot", ".cfg", ".json")

function Add-PathIfAny($value) {
    if ($null -eq $value) { return }
    if ($value -is [string]) {
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $paths.Add($value)
        }
        return
    }
    if ($value -is [System.Collections.IEnumerable]) {
        foreach ($item in $value) {
            Add-PathIfAny $item
        }
    }
}

# Try common fields used by afterFileEdit payloads.
if ($null -ne $payload) {
    Add-PathIfAny $payload.path
    Add-PathIfAny $payload.file_path
    Add-PathIfAny $payload.filePath
    Add-PathIfAny $payload.paths
    if ($payload.files) {
        foreach ($f in $payload.files) {
            Add-PathIfAny $f.path
            Add-PathIfAny $f.file_path
            Add-PathIfAny $f.filePath
        }
    }
    if ($payload.updated_input) {
        Add-PathIfAny $payload.updated_input.path
        Add-PathIfAny $payload.updated_input.file_path
        Add-PathIfAny $payload.updated_input.filePath
        Add-PathIfAny $payload.updated_input.paths
    }
}

if ($paths.Count -eq 0) {
    # Last-resort regex extraction for common editable text resource paths when payload exists.
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        $matches = [regex]::Matches($raw, '(?:[A-Za-z]:)?[^"''\s]+\.(?:tscn|tres|gd|godot|cfg|json)')
        foreach ($m in $matches) {
            $paths.Add($m.Value)
        }
    }
}

if ($paths.Count -eq 0) {
    # Fallback for environments where hook stdin payload is unavailable.
    $fallbackRoots = @("scenes", "scripts", "data", ".cursor")
    foreach ($root in $fallbackRoots) {
        $rootPath = Join-Path (Get-Location).Path $root
        if (-not (Test-Path -LiteralPath $rootPath)) { continue }
        foreach ($ext in $protectedExtensions) {
            $pattern = "*$ext"
            Get-ChildItem -Path $rootPath -File -Recurse -Filter $pattern -ErrorAction SilentlyContinue | ForEach-Object {
                $paths.Add($_.FullName)
            }
        }
    }
}

$normalized = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
foreach ($p in $paths) {
    $candidate = $p.Trim()
    if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
    $ext = [System.IO.Path]::GetExtension($candidate)
    if (-not ($protectedExtensions -contains $ext.ToLowerInvariant())) { continue }

    # Support absolute or project-relative paths.
    $full = $candidate
    if (-not [System.IO.Path]::IsPathRooted($candidate)) {
        $full = Join-Path (Get-Location).Path $candidate
    }
    try {
        $full = [System.IO.Path]::GetFullPath($full)
    } catch {
        continue
    }
    [void]$normalized.Add($full)
}

foreach ($file in $normalized) {
    if (-not (Test-Path -LiteralPath $file)) { continue }
    $bytes = [System.IO.File]::ReadAllBytes($file)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) {
        $newBytes = New-Object byte[] ($bytes.Length - 3)
        [Array]::Copy($bytes, 3, $newBytes, 0, $bytes.Length - 3)
        [System.IO.File]::WriteAllBytes($file, $newBytes)
    }
}

Write-Output "{}"
exit 0
