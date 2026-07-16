extends RefCounted

const SCHEMA := 2
const REQUIRED_FIELDS := ["schema", "battle_session_id", "source", "created_unix", "payload"]

static func create(
		p_battle_session_id: String,
		p_source: String,
		p_created_unix: int,
		p_payload: Dictionary
) -> Dictionary:
	var candidate := {
		"schema": SCHEMA,
		"battle_session_id": p_battle_session_id,
		"source": p_source,
		"created_unix": p_created_unix,
		"payload": p_payload.duplicate(true),
	}
	if not collect_errors(candidate).is_empty():
		return {}
	return _from_validated(candidate)


static func from_dict(data: Dictionary) -> Dictionary:
	if not collect_errors(data).is_empty():
		return {}
	return _from_validated(data)


static func to_dict(data: Dictionary) -> Dictionary:
	if not collect_errors(data).is_empty():
		return {}
	return _from_validated(data)


static func payload_snapshot(data: Dictionary) -> Dictionary:
	if not collect_errors(data).is_empty():
		return {}
	return (data["payload"] as Dictionary).duplicate(true)


static func collect_errors(candidate: Variant) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not candidate is Dictionary:
		errors.append("battle pending envelope 必须是 Dictionary")
		return errors
	var data := candidate as Dictionary
	for field in REQUIRED_FIELDS:
		if not data.has(field):
			errors.append("battle pending envelope 缺少字段 '%s'" % field)
	var unknown_fields: Array[String] = []
	for key_v in data.keys():
		var key := str(key_v)
		if key not in REQUIRED_FIELDS:
			unknown_fields.append(key)
	unknown_fields.sort()
	for field in unknown_fields:
		errors.append("battle pending envelope 含未知字段 '%s'" % field)
	if data.has("schema"):
		if typeof(data["schema"]) != TYPE_INT:
			errors.append("battle pending envelope.schema 必须是 int")
		elif int(data["schema"]) != SCHEMA:
			errors.append("battle pending envelope.schema 必须为 %d" % SCHEMA)
	var session_id := ""
	if data.has("battle_session_id"):
		if typeof(data["battle_session_id"]) != TYPE_STRING:
			errors.append("battle pending envelope.battle_session_id 必须是 String")
		else:
			session_id = str(data["battle_session_id"]).strip_edges()
			if session_id == "":
				errors.append("battle pending envelope.battle_session_id 不能为空")
	if data.has("source"):
		if typeof(data["source"]) != TYPE_STRING:
			errors.append("battle pending envelope.source 必须是 String")
		elif str(data["source"]).strip_edges() == "":
			errors.append("battle pending envelope.source 不能为空")
	if data.has("created_unix"):
		if typeof(data["created_unix"]) != TYPE_INT:
			errors.append("battle pending envelope.created_unix 必须是 int")
		elif int(data["created_unix"]) <= 0:
			errors.append("battle pending envelope.created_unix 必须 > 0")
	if data.has("payload"):
		var payload_v: Variant = data["payload"]
		if not payload_v is Dictionary:
			errors.append("battle pending envelope.payload 必须是 Dictionary")
		else:
			var payload := payload_v as Dictionary
			if payload.is_empty():
				errors.append("battle pending envelope.payload 不能为空")
			elif not payload.has("battle_session_id"):
				errors.append("battle pending envelope.payload 缺少 battle_session_id")
			elif typeof(payload["battle_session_id"]) != TYPE_STRING:
				errors.append("battle pending envelope.payload.battle_session_id 必须是 String")
			elif str(payload["battle_session_id"]).strip_edges() != session_id:
				errors.append("battle pending envelope.payload.battle_session_id 与 envelope 不一致")
			_collect_scene_value_errors(payload, "payload", errors)
	return errors


static func _from_validated(data: Dictionary) -> Dictionary:
	return {
		"schema": int(data["schema"]),
		"battle_session_id": str(data["battle_session_id"]).strip_edges(),
		"source": str(data["source"]).strip_edges(),
		"created_unix": int(data["created_unix"]),
		"payload": (data["payload"] as Dictionary).duplicate(true),
	}


static func _collect_scene_value_errors(
		value: Variant,
		path: String,
		errors: PackedStringArray
) -> void:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME:
			return
		TYPE_FLOAT:
			var number := float(value)
			if is_nan(number) or is_inf(number):
				errors.append("%s 含非有限 float" % path)
		TYPE_ARRAY:
			var rows := value as Array
			for i in rows.size():
				_collect_scene_value_errors(rows[i], "%s[%d]" % [path, i], errors)
		TYPE_DICTIONARY:
			var data := value as Dictionary
			var keys: Array = data.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			for key_v in keys:
				var key_type := typeof(key_v)
				if key_type not in [TYPE_INT, TYPE_STRING, TYPE_STRING_NAME]:
					errors.append("%s 含不允许的 Dictionary key 类型 %s" % [path, type_string(key_type)])
					continue
				_collect_scene_value_errors(data[key_v], "%s.%s" % [path, str(key_v)], errors)
		TYPE_OBJECT:
			errors.append("%s 含不允许的 Object" % path)
		TYPE_CALLABLE:
			errors.append("%s 含不允许的 Callable" % path)
		TYPE_SIGNAL:
			errors.append("%s 含不允许的 Signal" % path)
		TYPE_RID:
			errors.append("%s 含不允许的 RID" % path)
		_:
			errors.append("%s 含不允许的类型 %s" % [path, type_string(typeof(value))])
