class_name SaveApplication
extends RefCounted

const SaveRepositoryScript := preload("res://scripts/core/save_repository.gd")


static func auto_save(snapshot: Dictionary) -> Dictionary:
	return SaveRepositoryScript.save_auto(snapshot)


static func load_auto() -> Dictionary:
	var result: Dictionary = SaveRepositoryScript.load_auto()
	if not bool(result.get("ok", false)):
		return result
	return {"ok": true, "game": result.get("payload", {}).duplicate(true)}


static func restore_backup() -> Dictionary:
	var result: Dictionary = SaveRepositoryScript.restore_auto_backup()
	if not bool(result.get("ok", false)):
		return result
	return {"ok": true, "game": result.get("payload", {}).duplicate(true)}
