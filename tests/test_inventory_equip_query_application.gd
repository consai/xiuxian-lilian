extends SceneTree

const ApplicationScript := preload(
	"res://scripts/features/inventory/application/inventory_equip_query_application.gd"
)

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(ApplicationScript.all_equip_ids() == [5001, 5002, 5003], "IDs retain numeric source order")
	var first := ApplicationScript.equip_by_id(5001)
	_check(not first.is_empty(), "known equip resolves")
	_check((first.get("effects", []) as Array).is_empty(), "JSON string effects retain current empty runtime behavior")
	(first["effects"] as Array).append({"type": "damage"})
	_check((ApplicationScript.equip_by_id(5001).get("effects", []) as Array).is_empty(), "equip query deep clones")
	var cfg := ApplicationScript.build_equip_cfg({
		"5001": {"id": 5001, "name": "override", "effects": []},
		"custom": {"id": "custom", "name": "custom row"},
	})
	_check(cfg.has(5001) and cfg.has("5001"), "numeric equips expose int and string aliases")
	_check(str((cfg[5001] as Dictionary).get("name", "")) == "override", "extra overrides both numeric aliases")
	_check(cfg.has("custom"), "non-numeric extra key remains available")
	(cfg[5002] as Dictionary)["name"] = "mutated"
	_check(str((ApplicationScript.build_equip_cfg()[5002] as Dictionary).get("name", "")) != "mutated", "config result deep clones")
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: inventory equip query application")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
