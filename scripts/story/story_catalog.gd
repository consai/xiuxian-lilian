class_name StoryCatalog
extends RefCounted

const EXPORT_DIR := "res://data/exportjson"
const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")


static func load_story(story_id: String) -> Dictionary:
	var name := story_id.replace(".", "_").replace("/", "_").replace("\\", "_")
	var root := ExportTableReaderScript.read_settings("%s/gushi_%s.json" % [EXPORT_DIR, name])
	root["nodes"] = ExportTableReaderScript.read_keyed_rows(
		"%s/gushi_%s_nodes.json" % [EXPORT_DIR, name]
	)
	return root
