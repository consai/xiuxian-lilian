extends Node

const SCHEMA_VERSION := 1
const SLOT_COUNT := 3
const AUTO_SAVE_SLOT := 1


func save_slot(slot: int, data: Dictionary) -> Dictionary:
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


func load_slot(slot: int) -> Dictionary:
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


func slot_exists(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT and FileAccess.file_exists(_path(slot))


func slot_info(slot: int) -> Dictionary:
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


func _path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot
