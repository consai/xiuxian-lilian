# Removes every .godot_test_* directory under the project root.
$ProjectRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot "test_dir_cleanup.ps1")
Remove-AllTestRuntimeDirs -ProjectRoot $ProjectRoot
