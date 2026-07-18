extends SceneTree

const GameTimeServiceScript := preload("res://scripts/sim/game_time_service.gd")
const DataStoreScript := preload("res://scripts/core/data_store.gd")
const LiandanServiceScript := preload("res://scripts/sim/liandan_service.gd")
const LiandanStateScript := preload("res://scripts/features/alchemy/domain/liandan_state.gd")
const RealmServiceScript := preload("res://scripts/sim/realm_service.gd")
const RealmBalanceServiceScript := preload("res://scripts/sim/realm_balance_service.gd")
const TupoServiceScript := preload("res://scripts/sim/tupo_service.gd")
const BreakthroughApplicationScript := preload(
	"res://scripts/features/cultivation/application/breakthrough_application.gd"
)
const XiulianMethodServiceScript := preload("res://scripts/sim/xiulian_method_service.gd")
const MoniCatalogScript := preload("res://scripts/sim/moni_catalog.gd")
const CultivationMethodSavedataApplicationScript := preload(
	"res://scripts/features/cultivation/application/cultivation_method_savedata_application.gd"
)
const CharacterProgressionApplicationScript := preload(
	"res://scripts/features/character/application/character_progression_application.gd"
)

var _errors: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_character_and_cultivation()
	_liandan()
	_breakthrough()
	if not _errors.is_empty():
		for message in _errors:
			push_error(message)
		quit(1)
		return
	print("PASS: long-term gameplay characterization")
	quit(0)


func _character_and_cultivation() -> void:
	var store := DataStoreScript.new()
	store.reset_all()
	var state := store.export_savedata()
	_check(
		bool(CharacterProgressionApplicationScript.initialize_default(state).get("ok", false)),
		"character progression slice initializes through feature application"
	)
	_check(int(state.get("day", 0)) == 1 and int(state.get("realm_index", -1)) == 0 \
		and int(state.get("cultivation", -1)) == 0,
		"new game must reset day, realm and cultivation")
	_check(str(state.get("player_name", "")) == "", "new game name must start empty before profile input")
	_check((state.get("inventory", {}) as Dictionary).is_empty(), "new game inventory must start empty")
	_check(not state.has("equip_slots") and not state.has("item_slots"),
		"raw DataStore defaults must not own inventory slot state")
	var initial := MoniCatalogScript.initial_player()
	var initial_methods := initial.get("gongfa", initial.get("methods", [])) as Array
	var initial_method_id := str(initial_methods[0]) if not initial_methods.is_empty() else ""
	_check(initial_method_id != "", "MoniCatalog must explicitly provide a starter method")
	var initial_slots := {
		"main": initial_method_id, "support_1": "", "support_2": "", "support_3": "",
	}
	var method_commit := CultivationMethodSavedataApplicationScript.commit(state, {
		"method_mastery": {}, "unlocked_methods": initial_methods,
		"current_cultivation_method_id": initial_method_id,
		"cultivation_method_slots": initial_slots,
	})
	_check(bool(method_commit.get("ok", false)), "starter method slice commits through feature application")
	var named := store.coalesce_savedata({"player_name": "测试修士"})
	_check(str(named.get("player_name", "")) == "测试修士", "saved profile name must survive coalescing")

	_check(GameTimeServiceScript.days_per_month() == 30, "calendar month must remain 30 days")
	_check(GameTimeServiceScript.days_per_year() == 360, "calendar year must remain 360 days")
	_check(GameTimeServiceScript.date_label(31) == "第1年2月1日", "day 31 date mapping changed")
	_check(GameTimeServiceScript.duration_label(390) == "1年1月", "390 day duration mapping changed")

	var method_id := str(state.get("current_cultivation_method_id", ""))
	var speed := XiulianMethodServiceScript.cultivation_session_speed(method_id, state)
	var method_gain := XiulianMethodServiceScript.base_cultivation_gain(method_id)
	var player_gain := RealmBalanceServiceScript.base_daily_cultivation_gain({"major_realm": "lianqi"})
	_check(speed > 0.0 and method_gain > 0 and player_gain > 0,
		"cultivation preview components must remain positive")
	var mastery_before := XiulianMethodServiceScript.method_mastery(state, method_id)
	var resolved := XiulianMethodServiceScript.apply_cultivation_cycle(state, float(player_gain) * speed, 1.0)
	_check(str(resolved.get("method_id", "")) == method_id, "cultivation resolve must target active method")
	_check(float(resolved.get("mastery_applied", 0.0)) == 0.02,
		"one cultivation cycle must apply 0.02 mastery")
	_check(XiulianMethodServiceScript.method_mastery(state, method_id) > mastery_before,
		"cultivation resolve must increase method mastery")
	store.free()


func _liandan() -> void:
	var state := LiandanStateScript.default_state()
	var inventory := {"items_LingCao": 4}
	var preview := LiandanServiceScript.preview(
		"recipe.huiqi", "steady", "lowest", state, inventory,
		{}, {}, "lianqi"
	)
	_check(bool(preview.get("ok", false)), "liandan preview must succeed with four basic herbs")
	_check(int((preview.get("ingredients", [])[0] as Dictionary).get("count", 0)) == 2,
		"huiqi recipe must require two herbs")
	_check(int(preview.get("product_count", 0)) == 3, "huiqi base product count changed")

	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 4242
	rng_b.seed = 4242
	var rolled_a := LiandanServiceScript.roll(preview, rng_a)
	var rolled_b := LiandanServiceScript.roll(preview, rng_b)
	_check(rolled_a == rolled_b, "liandan roll must be deterministic for a fixed seed")
	_check(bool(rolled_a.get("ok", false)) and str(rolled_a.get("product_id", "")) != "",
		"liandan roll must produce a configured pill")
	_check(int(rolled_a.get("count", 0)) >= int(preview.get("product_count", 0)),
		"liandan result count must not fall below preview base yield")
	_check(int(rolled_a.get("xp", 0)) > 0 and int(rolled_a.get("mastery_gain", 0)) > 0,
		"liandan result must award xp and recipe mastery")
	var progressed := LiandanServiceScript.apply_xp(state, int(rolled_a.get("xp", 0)))
	progressed = LiandanServiceScript.apply_recipe_mastery(
		progressed, "recipe.huiqi", int(rolled_a.get("mastery_gain", 0))
	)
	_check(LiandanServiceScript.mastery_for(progressed, "recipe.huiqi") > 0,
		"liandan mastery application must increase mastery")


func _breakthrough() -> void:
	var realms := RealmServiceScript.realms()
	var store := DataStoreScript.new()
	store.reset_all()
	var base := store.export_savedata()
	base["realm_index"] = 8
	base["realm_name"] = str((realms[8] as Dictionary).get("name", ""))
	base["breakthrough_at"] = int((realms[8] as Dictionary).get("breakthrough_at", 0))
	base["cultivation"] = base["breakthrough_at"]
	base["foundations"] = {"roushen": 100, "lingli": 100, "shenshi": 100, "shenfa": 100}
	base["aptitudes"] = {"roots": {"fire": 100}, "fortune": 100, "comprehension": 100}
	var breakthrough_commit := BreakthroughApplicationScript.commit(base, {
		"breakthrough_bonuses": {"pills": 300, "mind": 200, "other": 100},
		"realm_quality": {"zhuji": 0, "jindan": 0, "yuanying": 0},
		"breakthrough_attempt_cooldown_days": 0,
	})
	_check(bool(breakthrough_commit.get("ok", false)), "breakthrough slice commits through feature application")
	base["cultivation_method_slots"] = {"main": "", "support_1": "", "support_2": "", "support_3": ""}

	var preview := TupoServiceScript.compute_breakdown(base.duplicate(true), realms, 8)
	_check(bool(preview.get("ok", false)) and bool(preview.get("can_attempt", false)),
		"major breakthrough preview must allow a sufficiently prepared character")
	var success_state := base.duplicate(true)
	var success_rng := RandomNumberGenerator.new()
	success_rng.seed = 1
	var success := TupoServiceScript.resolve(success_state, realms, 8, success_rng)
	_check(bool(success.get("ok", false)) and bool(success.get("success", false)),
		"breakthrough seed 1 must remain successful")
	_check(int(success_state.get("realm_index", -1)) == 9,
		"successful breakthrough must advance exactly one realm")

	var fail_state := base.duplicate(true)
	var fail_rng := RandomNumberGenerator.new()
	fail_rng.seed = 2
	var failed := TupoServiceScript.resolve(fail_state, realms, 8, fail_rng)
	_check(bool(failed.get("ok", false)) and not bool(failed.get("success", true)),
		"breakthrough seed 2 must remain a failure")
	_check(int(fail_state.get("realm_index", -1)) == 8,
		"failed breakthrough must not advance realm")
	_check(int(fail_state.get("breakthrough_attempt_cooldown_days", 0)) == 3,
		"failed breakthrough must apply three unstable days")
	_check(int((fail_state.get("breakthrough_bonuses", {}) as Dictionary).get("pills", -1)) == 0,
		"failed breakthrough must consume pill bonus")
	store.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
