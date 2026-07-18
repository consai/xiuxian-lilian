extends Node

const SAVEDATA_SCHEMA_VERSION := 2
const RUNDATA_SCHEMA_VERSION := 1

signal state_replaced

var savedata: Dictionary = {}
var rundata: Dictionary = {}


func _ready() -> void:
	ensure_initialized()


func ensure_initialized() -> void:
	if savedata.is_empty():
		reset_savedata()
	if rundata.is_empty():
		reset_rundata()


func reset_savedata(extra_defaults: Dictionary = {}) -> void:
	savedata = _default_savedata(extra_defaults)


func coalesce_savedata(data: Dictionary, extra_defaults: Dictionary = {}) -> Dictionary:
	var out := _default_savedata(extra_defaults)
	_overlay_snapshot(out, data)
	return out


func reset_rundata() -> void:
	rundata = {
		"game": {
			"last_rewards": [],
			"last_lilian_summary": {},
			"last_settled_lilian_id": "",
			"active_save_slot": 0,
		},
	}

func reset_all(extra_defaults: Dictionary = {}) -> void:
	reset_savedata(extra_defaults)
	reset_rundata()
	state_replaced.emit()


func export_savedata() -> Dictionary:
	ensure_initialized()
	return savedata.duplicate(true)


func import_savedata(data: Dictionary, extra_defaults: Dictionary = {}) -> bool:
	if not validate_savedata(data):
		return false
	savedata = coalesce_savedata(data, extra_defaults)
	reset_rundata()
	state_replaced.emit()
	return true


func validate_savedata(data: Dictionary) -> bool:
	return true


func game_runtime() -> Dictionary:
	ensure_initialized()
	return rundata["game"] as Dictionary


func _default_savedata(extra_defaults: Dictionary = {}) -> Dictionary:
	var out := {
		"player_name": "",
		"player_icon": "",
	}
	_overlay_snapshot(out, extra_defaults)
	return out


func _overlay_snapshot(target: Dictionary, overlay: Dictionary) -> void:
	for key in overlay.keys():
		var value: Variant = overlay[key]
		if value is Dictionary:
			target[key] = (value as Dictionary).duplicate(true)
		elif value is Array:
			target[key] = (value as Array).duplicate(true)
		else:
			target[key] = value
