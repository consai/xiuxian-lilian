extends SceneTree

## ZhandouEffectCodec 最小自测：positional effects 解析。


func _initialize() -> void:
	var failed := 0
	failed += _run("damage_scaled", _test_damage_scaled)
	failed += _run("attrschange_config", _test_attrschange_config)
	failed += _run("buff_runtime", _test_buff_runtime)
	quit(1 if failed > 0 else 0)


func _run(name: String, callable: Callable) -> int:
	callable.call()
	print("PASS %s" % name)
	return 0


func _test_damage_scaled() -> void:
	var runtime: Dictionary = ZhandouEffectCodec.parse_positional_runtime(
		["damage", "10", "physical_atk", "100"]
	)
	if str(runtime.get("type", "")) != EnumCombatEffectType.LABEL_DAMAGE:
		push_error("damage runtime type mismatch")
	var caster: Dictionary = {ZhandouAttr.PHYSICAL_ATK: 50.0}
	var value: float = ZhandouEffectCodec._resolve_scaled_value(
		["damage", "10", "physical_atk", "100"],
		caster,
		{}
	)
	if not is_equal_approx(value, 15.0):
		push_error("damage scaled value expected 15 got %s" % value)


func _test_attrschange_config() -> void:
	var cfg: Dictionary = ZhandouEffectCodec.parse_positional_config(["attrschange", "spd", "20"])
	if str(cfg.get("effectId", "")) != "cast_speed":
		push_error("attrschange should map to cast_speed")
	if float(cfg.get("base", 0.0)) != 20.0:
		push_error("attrschange flat base expected 20")


func _test_buff_runtime() -> void:
	var runtime: Dictionary = ZhandouEffectCodec.parse_positional_runtime(["buff", "buff_0001"])
	if str(runtime.get("type", "")) != EnumCombatEffectType.LABEL_APPLY_BUFF:
		push_error("buff runtime type mismatch")
	if str(runtime.get("id", "")) != "buff_0001":
		push_error("buff id mismatch")
