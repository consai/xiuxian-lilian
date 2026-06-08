# Runs a Godot headless test script with isolated APPDATA and cleans up on success.
param(
	[Parameter(Mandatory = $true)]
	[string]$Script,

	# Optional stable suffix (e.g. "_scene"). Leave empty to use a unique per-run suffix.
	[string]$AppDataSuffix = "",

	[string]$Godot = $env:GODOT_BIN
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot "test_dir_cleanup.ps1")

function Resolve-GodotExe {
	param([string]$Preferred)
	if ($Preferred -and (Test-Path -LiteralPath $Preferred)) {
		return (Resolve-Path -LiteralPath $Preferred).Path
	}
	$default = "C:\Godot_v4.6.2-stable_win64_console.exe"
	if (Test-Path -LiteralPath $default) {
		return $default
	}
	$fromPath = Get-Command godot -ErrorAction SilentlyContinue
	if ($fromPath) {
		return $fromPath.Source
	}
	throw "Godot console executable not found. Set GODOT_BIN or install to $default"
}

function New-TestRuntimeDirs {
	param([string]$Suffix)
	@{
		"appdata" = Join-Path $ProjectRoot ".godot_test_appdata$Suffix"
		"local" = Join-Path $ProjectRoot ".godot_test_local$Suffix"
	}
}

$effectiveSuffix = $AppDataSuffix
if ([string]::IsNullOrWhiteSpace($effectiveSuffix)) {
	$effectiveSuffix = "_" + [guid]::NewGuid().ToString("N").Substring(0, 8)
}

$runtimeDirs = New-TestRuntimeDirs -Suffix $effectiveSuffix
$runtimeDirList = @($runtimeDirs.appdata, $runtimeDirs.local)

foreach ($dir in $runtimeDirList) {
	New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$env:APPDATA = $runtimeDirs.appdata
$env:LOCALAPPDATA = $runtimeDirs.local

$godotExe = Resolve-GodotExe -Preferred $Godot
$logFile = Join-Path $env:TEMP ("xiuxian_godot_test_{0}.log" -f [guid]::NewGuid().ToString("N"))

Write-Host "Running $Script"
Write-Host "  APPDATA=$($env:APPDATA)"
Write-Host "  LOCALAPPDATA=$($env:LOCALAPPDATA)"

& $godotExe --headless --path $ProjectRoot --script $Script --log-file $logFile
$exitCode = $LASTEXITCODE
Remove-Item -LiteralPath $logFile -Force -ErrorAction SilentlyContinue

if ($exitCode -eq 0) {
	foreach ($dir in $runtimeDirList) {
		Remove-TestRuntimeDir -Dir $dir
	}
}
else {
	Write-Host "Tests failed (exit $exitCode); keeping test directories for inspection."
}

exit $exitCode
