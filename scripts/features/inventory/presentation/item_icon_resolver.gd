class_name ItemIconResolver
extends RefCounted


static func resolve(icon_path: String, fallback: Texture2D) -> Texture2D:
	var path := icon_path.strip_edges()
	if path != "" and ResourceLoader.exists(path):
		var resource := load(path)
		if resource is Texture2D:
			return resource as Texture2D
	return fallback
