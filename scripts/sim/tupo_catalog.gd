class_name TupoCatalog
extends RefCounted

const YUNXING_PARAMS_DIR := "res://data/exportjson/yunxing_params"
const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")


static func load_rules() -> Dictionary:
	var root := ExportTableReaderScript.read_settings("%s/tupo_rules.json" % YUNXING_PARAMS_DIR)
	root["component_caps"] = ExportTableReaderScript.read_settings(
		"%s/tupo_rules_component_caps.json" % YUNXING_PARAMS_DIR
	)
	root["major_breakthroughs"] = ExportTableReaderScript.read_keyed_rows(
		"%s/tupo_rules_major_breakthrough.json" % YUNXING_PARAMS_DIR
	)
	return root
