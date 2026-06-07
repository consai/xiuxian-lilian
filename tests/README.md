# Headless Tests

Run the battle-domain rules tests from the project root:

```powershell
$env:APPDATA="$PWD\.godot_test_appdata"
$env:LOCALAPPDATA="$PWD\.godot_test_local"
C:\Godot_v4.6.2-stable_win64_console.exe --headless --path $PWD --script res://tests/run_battle_domain_tests.gd
```

The temporary application-data directories keep Godot's `user://` writes inside the workspace. They are ignored by Git through the existing `.godot*` rule.

The test runner exits with code `0` when all tests pass and `1` when any assertion fails.
