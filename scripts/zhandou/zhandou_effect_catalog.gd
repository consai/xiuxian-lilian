class_name ZhandouEffectCatalog
extends RefCounted

const PATH := "res://data/exportjson/战斗effects效果介绍.json"


static func load_schema() -> Dictionary:
	return JsonReader.read_object(PATH).duplicate(true)
