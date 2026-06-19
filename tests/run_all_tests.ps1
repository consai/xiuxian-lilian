# Runs the full headless test suite and removes all .godot_test_* dirs when every test passes.
param(
	[string]$Godot = $env:GODOT_BIN
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$runner = Join-Path $PSScriptRoot "run_tests.ps1"
. (Join-Path $PSScriptRoot "test_dir_cleanup.ps1")

$scripts = @(
	"res://tests/run_battle_domain_tests.gd",
	"res://tests/run_game_time_tests.gd",
	"res://tests/run_simulation_tests.gd",
	"res://tests/run_expedition_tests.gd",
	"res://tests/run_expedition_smoke.gd",
	"res://tests/run_scene_manager_tests.gd",
	"res://tests/run_contract_tests.gd",
	"res://tests/run_config_validation_tests.gd",
	"res://tests/run_dao_knowledge_tests.gd",
	"res://tests/run_balance_v1_tests.gd",
	"res://tests/run_world_map_tests.gd",
	"res://tests/run_story_tests.gd"
)

foreach ($script in $scripts) {
	& $runner -Script $script -Godot $Godot
	if ($LASTEXITCODE -ne 0) {
		Write-Host "Suite stopped at $script (exit $LASTEXITCODE)."
		exit $LASTEXITCODE
	}
}

# Sweep any leftover isolated dirs from parallel/manual runs (e.g. _arch, _scene).
Remove-AllTestRuntimeDirs -ProjectRoot $ProjectRoot
Write-Host "PASS: all $($scripts.Count) test scripts"
exit 0
