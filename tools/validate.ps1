# Runs Node config validators (dao tree, xiulian methods, abilities).
param()

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $ProjectRoot
try {
	node tools/validate-all.mjs
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}
	Write-Host "PASS: config validators"
	exit 0
} finally {
	Pop-Location
}
