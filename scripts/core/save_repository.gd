class_name SaveRepository
extends RefCounted

const SCHEMA_VERSION := 2
const SLOT_COUNT := 3
const AUTO_SAVE_SLOT := 1


static func save_slot(slot: int, data: Dictionary) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT:
		return {"ok": false, "error": "无效存档槽位"}
	var file := FileAccess.open(_path(slot), FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "无法写入存档"}
	var envelope := {
		"schema_version": SCHEMA_VERSION,
		"saved_unix": int(Time.get_unix_time_from_system()),
		"game": data.duplicate(true),
	}
	file.store_string(JSON.stringify(envelope, "\t"))
	return {"ok": true}


static func load_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT or not FileAccess.file_exists(_path(slot)):
		return {"ok": false, "error": "该槽位为空"}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(_path(slot))) != OK:
		return {"ok": false, "error": "存档损坏"}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return {"ok": false, "error": "存档损坏"}
	var envelope := parsed as Dictionary
	if int(envelope.get("schema_version", -1)) != SCHEMA_VERSION:
		return {"ok": false, "error": "存档版本不兼容"}
	var game_v: Variant = envelope.get("game")
	if not game_v is Dictionary:
		return {"ok": false, "error": "存档缺少游戏状态"}
	return {"ok": true, "game": (game_v as Dictionary).duplicate(true)}


static func slot_exists(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT and FileAccess.file_exists(_path(slot))


static func slot_info(slot: int) -> Dictionary:
	var loaded := load_slot(slot)
	if not bool(loaded.get("ok", false)):
		return loaded
	var game := loaded["game"] as Dictionary
	return {
		"ok": true,
		"day": int(game.get("day", 1)),
		"realm_name": str(game.get("realm_name", "未知")),
		"cultivation": int(game.get("cultivation", 0)),
	}


static func find_latest_slot() -> int:
	var latest_slot := 0
	var latest_time := -1
	for slot in range(1, SLOT_COUNT + 1):
		var saved_unix := _read_saved_unix(slot)
		if saved_unix < 0:
			continue
		if saved_unix >= latest_time:
			latest_time = saved_unix
			latest_slot = slot
	return latest_slot


static func _read_saved_unix(slot: int) -> int:
	if slot < 1 or slot > SLOT_COUNT or not FileAccess.file_exists(_path(slot)):
		return -1
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(_path(slot))) != OK:
		return -1
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return -1
	var envelope := parsed as Dictionary
	if int(envelope.get("schema_version", -1)) != SCHEMA_VERSION:
		return -1
	return int(envelope.get("saved_unix", 0))


static func _path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot
