extends SceneTree

const WorldMapStateScript := preload(
	"res://scripts/features/map/domain/world_map_state.gd"
)
const WorldMapApplicationScript := preload(
	"res://scripts/features/map/application/world_map_application.gd"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var default_map := WorldMapStateScript.default_state()
	assert(default_map == {
		"current_city_id": "qingshi_market",
		"discovered_cities": ["qingshi_market"],
		"discovered_regions": [],
		"discovered_locations": [],
		"vanished_nodes": [],
		"route_states": {},
		"region_exploration": {},
	})
	assert(WorldMapStateScript.validate(default_map))

	Engine.print_error_messages = false
	assert(not WorldMapStateScript.validate([]))
	for field in WorldMapStateScript.REQUIRED_FIELDS:
		var missing := default_map.duplicate(true)
		missing.erase(field)
		assert(not WorldMapStateScript.validate(missing))
	var invalid_values := {
		"current_city_id": 1,
		"discovered_cities": {},
		"discovered_regions": {},
		"discovered_locations": {},
		"vanished_nodes": {},
		"route_states": [],
		"region_exploration": [],
	}
	for field in invalid_values:
		var invalid := default_map.duplicate(true)
		invalid[field] = invalid_values[field]
		assert(not WorldMapStateScript.validate(invalid))
	var bad_array_entry := default_map.duplicate(true)
	bad_array_entry["discovered_cities"] = [7]
	assert(not WorldMapStateScript.validate(bad_array_entry))
	Engine.print_error_messages = true

	var savedata := {"map": default_map.duplicate(true)}
	var snapshot := WorldMapApplicationScript.snapshot(savedata)
	snapshot["discovered_cities"].append("yunlan_city")
	snapshot["route_states"]["qingshi_market|yunlan_city"] = "discovered"
	assert(savedata["map"] == default_map)

	var candidate := default_map.duplicate(true)
	candidate["current_city_id"] = "yunlan_city"
	candidate["discovered_cities"].append("yunlan_city")
	candidate["region_exploration"]["qinglan_mountain"] = 2
	assert(WorldMapApplicationScript.commit(savedata, candidate))
	assert(savedata["map"] == candidate)
	candidate["discovered_cities"].append("later_mutation")
	candidate["region_exploration"]["qinglan_mountain"] = 9
	assert(not (savedata["map"]["discovered_cities"] as Array).has("later_mutation"))
	assert(int(savedata["map"]["region_exploration"]["qinglan_mountain"]) == 2)

	var before_failed_commit := savedata.duplicate(true)
	var bad_candidate := default_map.duplicate(true)
	bad_candidate["route_states"] = []
	Engine.print_error_messages = false
	assert(not WorldMapApplicationScript.commit(savedata, bad_candidate))
	Engine.print_error_messages = true
	assert(savedata == before_failed_commit)

	var initialized := {}
	assert(WorldMapApplicationScript.initialize_default(initialized))
	assert(initialized["map"] == default_map)
	var initialized_snapshot := WorldMapApplicationScript.snapshot(initialized)
	initialized_snapshot["vanished_nodes"].append("fixture")
	assert((initialized["map"]["vanished_nodes"] as Array).is_empty())

	var store := root.get_node("DataStore")
	var game_state := root.get_node("GameState")
	game_state.new_game({"player_name": "地图状态测试"})
	var new_game_map: Dictionary = game_state.map_data()
	assert(str(new_game_map.get("current_city_id", "")) == "qingshi_market")
	assert((new_game_map.get("discovered_cities", []) as Array).has("qingshi_market"))
	assert(WorldMapStateScript.validate(new_game_map))

	var roundtrip_save: Dictionary = store.export_savedata()
	var roundtrip_map := default_map.duplicate(true)
	roundtrip_map["current_city_id"] = "yunlan_city"
	roundtrip_map["discovered_cities"] = ["yunlan_city", "qingshi_market"]
	roundtrip_map["discovered_regions"] = ["qinglan_mountain"]
	roundtrip_map["discovered_locations"] = ["wild_wolf_valley"]
	roundtrip_map["vanished_nodes"] = ["old_map_node"]
	roundtrip_map["route_states"] = {"yunlan_city|qingshi_market": "discovered"}
	roundtrip_map["region_exploration"] = {"qinglan_mountain": 3}
	roundtrip_save["map"] = roundtrip_map
	assert(game_state.apply_dict(roundtrip_save))
	assert(game_state.map_data() == roundtrip_map)

	print("PASS: world map state and application ownership")
	quit(0)
