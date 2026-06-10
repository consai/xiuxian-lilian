class_name WorldMapDataValidator
extends RefCounted

const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")
const WorldMapServiceScript := preload("res://scripts/map/world_map_service.gd")


static func collect_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	var city_ids := WorldMapServiceScript.all_city_ids()
	var region_ids := WorldMapServiceScript.all_wilderness_region_ids()
	var location_ids := WorldMapServiceScript.all_wilderness_location_ids()
	errors.append_array(_validate_unique_ids(city_ids, "城市"))
	errors.append_array(_validate_unique_ids(region_ids, "野外区域"))
	errors.append_array(_validate_unique_ids(location_ids, "野外地点"))
	var starter := WorldMapServiceScript.starter_city_id()
	if starter != "" and starter not in city_ids:
		errors.append("世界地图 starter_city_id 不存在: %s" % starter)
	for city_id in city_ids:
		var city := WorldMapServiceScript.city_by_id(str(city_id))
		if str(city.get("name", "")).strip_edges() == "":
			errors.append("城市 %s 缺少 name" % city_id)
		var pos_v: Variant = city.get("position", [])
		if not pos_v is Array or (pos_v as Array).size() < 2:
			errors.append("城市 %s 缺少有效 position" % city_id)
	for route_v in WorldMapServiceScript.all_routes():
		if not route_v is Dictionary:
			continue
		var route := route_v as Dictionary
		var from_id := str(route.get("from", ""))
		var to_id := str(route.get("to", ""))
		if from_id == "" or to_id == "":
			errors.append("路线缺少 from/to")
			continue
		if from_id == to_id:
			errors.append("路线起终点相同: %s" % from_id)
		if from_id not in city_ids:
			errors.append("路线 from 引用未知城市: %s" % from_id)
		if to_id not in city_ids:
			errors.append("路线 to 引用未知城市: %s" % to_id)
		if int(route.get("days", 0)) < 1:
			errors.append("路线 %s-%s 的 days 必须大于 0" % [from_id, to_id])
	for region_id in region_ids:
		var region := WorldMapServiceScript.wilderness_region_by_id(str(region_id))
		if str(region.get("name", "")).strip_edges() == "":
			errors.append("野外区域 %s 缺少 name" % region_id)
		var expedition_id := str(region.get("expedition_location_id", "")).strip_edges()
		if expedition_id != "" and not LocationServiceScript.has_location(expedition_id):
			errors.append("野外区域 %s 的 expedition_location_id 不存在: %s" % [region_id, expedition_id])
		for sub_id_v in region.get("sub_locations", []) as Array:
			var sub_id := str(sub_id_v)
			if sub_id not in location_ids:
				errors.append("野外区域 %s 的 sub_locations 引用未知地点: %s" % [region_id, sub_id])
	for location_id in location_ids:
		var row := WorldMapServiceScript.wilderness_location_by_id(str(location_id))
		if str(row.get("name", "")).strip_edges() == "":
			errors.append("野外地点 %s 缺少 name" % location_id)
		var parent := str(row.get("parent_region", ""))
		if parent == "":
			errors.append("野外地点 %s 缺少 parent_region" % location_id)
		elif parent not in region_ids:
			errors.append("野外地点 %s 的 parent_region 不存在: %s" % [location_id, parent])
		var expedition_id := str(row.get("expedition_location_id", "")).strip_edges()
		if expedition_id != "" and not LocationServiceScript.has_location(expedition_id):
			errors.append("野外地点 %s 的 expedition_location_id 不存在: %s" % [location_id, expedition_id])
		var pos_v: Variant = row.get("position", [])
		if not pos_v is Array or (pos_v as Array).size() < 2:
			errors.append("野外地点 %s 缺少有效 position" % location_id)
	for region_id in region_ids:
		var region := WorldMapServiceScript.wilderness_region_by_id(str(region_id))
		for sub_id_v in region.get("sub_locations", []) as Array:
			var sub_id := str(sub_id_v)
			var row := WorldMapServiceScript.wilderness_location_by_id(sub_id)
			if str(row.get("parent_region", "")) != str(region_id):
				errors.append("野外地点 %s 的 parent_region 与区域 %s 不一致" % [sub_id, region_id])
	return errors


static func _validate_unique_ids(ids: Array, label: String) -> PackedStringArray:
	var seen := {}
	var errors: PackedStringArray = []
	for id_v in ids:
		var key := str(id_v)
		if seen.has(key):
			errors.append("%s ID 重复: %s" % [label, key])
		else:
			seen[key] = true
	return errors
