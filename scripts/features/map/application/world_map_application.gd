class_name WorldMapApplication
extends RefCounted

const WorldMapStateScript := preload(
	"res://scripts/features/map/domain/world_map_state.gd"
)


static func snapshot(savedata: Dictionary) -> Dictionary:
	if not savedata.has("map"):
		push_error("[world_map_application:missing_state_slice] field=map")
		return {}
	return WorldMapStateScript.prepare(savedata.get("map"))


static func commit(savedata: Dictionary, candidate: Variant) -> bool:
	var prepared := WorldMapStateScript.prepare(candidate)
	if prepared.is_empty():
		return false
	savedata["map"] = prepared
	return true


static func initialize_default(savedata: Dictionary) -> bool:
	return commit(savedata, WorldMapStateScript.default_state())
