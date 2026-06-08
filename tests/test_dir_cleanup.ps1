function Remove-TestRuntimeDir {
	param([string]$Dir)

	if (-not (Test-Path -LiteralPath $Dir)) {
		return
	}

	# Godot may still hold log handles briefly after exit.
	Start-Sleep -Milliseconds 300

	for ($attempt = 1; $attempt -le 3; $attempt++) {
		cmd /c "rmdir /s /q `"$Dir`" 2>nul" | Out-Null
		if (-not (Test-Path -LiteralPath $Dir)) {
			Write-Host "Removed test directory: $Dir"
			return
		}
		Start-Sleep -Milliseconds (300 * $attempt)
	}

	Write-Warning "Could not fully remove test directory (close open log files and retry): $Dir"
}

function Remove-AllTestRuntimeDirs {
	param([string]$ProjectRoot)

	Get-ChildItem -LiteralPath $ProjectRoot -Directory -Force |
		Where-Object { $_.Name -like ".godot_test_*" } |
		ForEach-Object {
			Remove-TestRuntimeDir -Dir $_.FullName
		}
}
