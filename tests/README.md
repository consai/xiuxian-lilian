# Headless Tests

Use the PowerShell wrappers so isolated runtime directories are removed automatically after a successful run.

## Single test

```powershell
.\tests\run_tests.ps1 -Script res://tests/run_zhandou_domain_tests.gd
```

Each run uses a unique `.godot_test_appdata_<id>` / `.godot_test_local_<id>` pair by default, so parallel runs do not fight over the same `godot.log`. Both directories are deleted when the script exits `0`. Failed runs keep them for inspection.

Optional stable suffix (for debugging a specific run):

```powershell
.\tests\run_tests.ps1 -Script res://tests/run_scene_manager_tests.gd -AppDataSuffix "_scene"
```

## Config validators

```powershell
.\tools\validate.ps1
# 或 npm run validate
```

校验大道树、功法、技能 YAML（Node，无需 Godot）。

## Full suite

```powershell
.\tests\run_all_tests.ps1
```

先跑 `tools/validate.ps1`，再按序跑全部 headless 测试；全部通过后会删除项目根下每个 `.godot_test_*` 目录。

## Godot executable

Set `GODOT_BIN` to override the default lookup (`C:\Godot_v4.6.2-stable_win64_console.exe`, then `godot` on `PATH`).

## Manual run (not recommended)

```powershell
$env:APPDATA="$PWD\.godot_test_appdata"
$env:LOCALAPPDATA="$PWD\.godot_test_local"
C:\Godot_v4.6.2-stable_win64_console.exe --headless --path $PWD --script res://tests/run_zhandou_domain_tests.gd
```

Manual runs do not auto-clean. Prefer `run_tests.ps1` or `run_all_tests.ps1`.

## Cleanup only

```powershell
.\tests\cleanup_test_dirs.ps1
```

Removes all `.godot_test_*` directories. If a `godot.log` file is open in the editor, close it first.

Test runners exit with code `0` when all assertions pass and `1` when any assertion fails.
