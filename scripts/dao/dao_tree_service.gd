class_name DaoTreeService
extends RefCounted

const CharacterStatsScript := preload("res://scripts/sim/character_stats.gd")

const PATH := "res://data/dao_tree.yaml"

static var _config: Dictionary = {}
static var _skills_by_id: Dictionary = {}
static var _skills_by_domain: Dictionary = {}
static var _skills_by_realm: Dictionary = {}
static var _domains_by_id: Dictionary = {}
static var _realm_order: Dictionary = {}


static func reload() -> void:
	_config = JsonLoader.load_dao_tree()
	_skills_by_id.clear()
	_skills_by_domain.clear()
	_skills_by_realm.clear()
	_domains_by_id.clear()
	_realm_order.clear()
	for domain_v in _config.get("domains", []) as Array:
		if domain_v is Dictionary:
			var domain := domain_v as Dictionary
			_domains_by_id[str(domain.get("id", ""))] = domain
	for realm_v in _config.get("realms", []) as Array:
		if realm_v is Dictionary:
			var realm := realm_v as Dictionary
			_realm_order[str(realm.get("id", ""))] = int(realm.get("order", 0))
	for skill_v in _config.get("skills", []) as Array:
		if not skill_v is Dictionary:
			continue
		var skill := skill_v as Dictionary
		var sid := str(skill.get("id", ""))
		if sid == "":
			continue
		_skills_by_id[sid] = skill
		var domain_id := str(skill.get("domain", ""))
		if not _skills_by_domain.has(domain_id):
			_skills_by_domain[domain_id] = []
		(_skills_by_domain[domain_id] as Array).append(skill)
		var realm_id := str(skill.get("realm", ""))
		if not _skills_by_realm.has(realm_id):
			_skills_by_realm[realm_id] = []
		(_skills_by_realm[realm_id] as Array).append(skill)


static func config() -> Dictionary:
	if _config.is_empty():
		reload()
	return _config


static func domains() -> Array:
	config()
	return (_config.get("domains", []) as Array).duplicate(true)


static func domain_groups() -> Array:
	config()
	var groups_v: Variant = _config.get("domainGroups", [])
	if groups_v is Array and not (groups_v as Array).is_empty():
		return (groups_v as Array).duplicate(true)
	var fallback: Array = []
	for domain_v in _config.get("domains", []) as Array:
		if not domain_v is Dictionary:
			continue
		var domain := domain_v as Dictionary
		var domain_id := str(domain.get("id", ""))
		if domain_id == "":
			continue
		fallback.append({
			"id": domain_id,
			"name": str(domain.get("name", "")),
			"domains": [domain_id],
		})
	return fallback


static func realms() -> Array:
	config()
	return (_config.get("realms", []) as Array).duplicate(true)


static func realm_display_name(realm_id: String) -> String:
	var rid := realm_id.strip_edges()
	if rid == "":
		return ""
	for realm_v in realms():
		if not realm_v is Dictionary:
			continue
		var realm := realm_v as Dictionary
		if str(realm.get("id", "")) == rid:
			return str(realm.get("name", rid))
	return rid


static func skill_by_id(skill_id: String) -> Dictionary:
	config()
	var sid := skill_id.strip_edges()
	var row: Variant = _skills_by_id.get(sid)
	if row is Dictionary:
		return (row as Dictionary).duplicate(true)
	return {}


static func skills_in_domain(domain_id: String) -> Array:
	config()
	var rows: Variant = _skills_by_domain.get(domain_id.strip_edges(), [])
	return (rows as Array).duplicate(true) if rows is Array else []


static func skills_in_realm(realm_id: String) -> Array:
	config()
	var rows: Variant = _skills_by_realm.get(realm_id.strip_edges(), [])
	return (rows as Array).duplicate(true) if rows is Array else []


static func domain_by_id(domain_id: String) -> Dictionary:
	config()
	var row: Variant = _domains_by_id.get(domain_id.strip_edges())
	if row is Dictionary:
		return (row as Dictionary).duplicate(true)
	return {}


static func realm_order(realm_id: String) -> int:
	config()
	return int(_realm_order.get(realm_id.strip_edges(), 0))


static func meets_realm_gate(skill_realm: String, player_major_realm: String) -> bool:
	return realm_order(player_major_realm) >= realm_order(skill_realm.strip_edges())


static func required_xp_for_level(skill_id: String, target_level: int) -> float:
	var skill := skill_by_id(skill_id)
	if skill.is_empty():
		return 1.0
	var training: Dictionary = config().get("training", {}) as Dictionary
	var multipliers: Array = training.get("levelMultipliers", [1, 2, 4, 8, 16]) as Array
	var level_index := clampi(target_level - 1, 0, multipliers.size() - 1)
	var rank := maxf(1.0, float(skill.get("rank", 1)))
	var base_points := maxf(1.0, float(training.get("basePoints", 250)))
	return base_points * rank * float(multipliers[level_index])


static func training_speed(skill_id: String, foundations: Dictionary, aptitudes: Dictionary) -> float:
	var skill := skill_by_id(skill_id)
	if skill.is_empty():
		return 1.0
	var domain := domain_by_id(str(skill.get("domain", "")))
	if domain.is_empty():
		return 1.0
	var primary := _attr_value(str(domain.get("primary", "")), foundations, aptitudes)
	var secondary := _attr_value(str(domain.get("secondary", "")), foundations, aptitudes)
	return maxf(0.0, primary + secondary * 0.5)


static func prereqs_met(skill_id: String, knowledge_levels: Dictionary) -> bool:
	var skill := skill_by_id(skill_id)
	for req_v in skill.get("prereqs", []) as Array:
		if not req_v is Dictionary:
			continue
		var req := req_v as Dictionary
		var parent_id := str(req.get("id", ""))
		var need_level := int(req.get("level", 1))
		var have := float(knowledge_levels.get(parent_id, 0.0))
		if have < float(need_level):
			return false
	return true


static func node_display_state(
		skill_id: String,
		effective_level: float,
		growth_source: String,
		player_major_realm: String,
		knowledge_levels: Dictionary
) -> int:
	if effective_level >= 1.0:
		if growth_source != "" and effective_level < float(skill_by_id(skill_id).get("maxLevel", 5)):
			return EnumDaoNodeState.State.GROWING
		return EnumDaoNodeState.State.LEARNED
	var skill := skill_by_id(skill_id)
	if skill.is_empty():
		return EnumDaoNodeState.State.LOCKED
	if not meets_realm_gate(str(skill.get("realm", "")), player_major_realm):
		return EnumDaoNodeState.State.LOCKED
	if prereqs_met(skill_id, knowledge_levels):
		return EnumDaoNodeState.State.AVAILABLE
	return EnumDaoNodeState.State.LOCKED


static func _attr_value(attr_id: String, foundations: Dictionary, aptitudes: Dictionary) -> float:
	match attr_id:
		CharacterStatsScript.BODY, CharacterStatsScript.SENSE, CharacterStatsScript.SPIRIT, CharacterStatsScript.AGILITY:
			return float(foundations.get(attr_id, 0.0))
		CharacterStatsScript.COMPREHENSION, CharacterStatsScript.WILL, CharacterStatsScript.FORTUNE:
			return float(aptitudes.get(attr_id, 0.0))
		_:
			return 0.0
