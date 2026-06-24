extends Control

## GM 调试面板
##
## 修改角色属性、境界、资源时，必须走与正常玩法相同的 GameState / RewardService 入口，
## 以便触发小境界自动提升、大境界突破结算、根基成长、属性重算、经历记录等副作用。
## 禁止在此直接写入 DataStore.savedata 或跳过 GameState 赋值器篡改 hp / realm_index 等字段。
##
## 正常途径对照：
## - 修为：GameState.grant_cultivation / fill_cultivation_to_breakthrough（含 _auto_advance_layers）
## - 境界：GameState.advance_realm_one_step / advance_realm_to_index（大境界走 breakthrough）
## - 气血法力：GameState.rest（恢复满值并重算衍生属性后写入）
## - 伤势：GameState.rest_until_injury_cleared（每次均走 rest 完整流程）
## - 物品 / 灵石：GameState.grant_rewards → RewardService.apply_rewards
## - 新局：GameState.new_game
## - 日数：无独立「跳日」玩法 API，GM 直接改 day 仅用于测试时间轴

const SIM_PATH := "res://data/simulation.yaml"
const GmBattleBuilderScript := preload("res://scripts/ui/gm_battle_builder.gd")

@onready var _status_label: Label = %StatusLabel
@onready var _message_label: Label = %MessageLabel
@onready var _location_option: OptionButton = %LocationOption
@onready var _monster_option: OptionButton = %MonsterOption
@onready var _enemy_count_input: SpinBox = %EnemyCountInput
@onready var _close_button: TextureButton = %CloseButton


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(_on_close_pressed)
	_connect_buttons()
	_build_location_options()
	_build_monster_options()


func refresh() -> void:
	_bind_status()
	_message_label.text = ""


func _connect_buttons() -> void:
	%Cultivation100Button.pressed.connect(func() -> void: _add_cultivation(100))
	%Cultivation1000Button.pressed.connect(func() -> void: _add_cultivation(1000))
	%CultivationMaxButton.pressed.connect(_fill_cultivation)
	%Stones100Button.pressed.connect(func() -> void: _add_stones(100))
	%Stones1000Button.pressed.connect(func() -> void: _add_stones(1000))
	%Day1Button.pressed.connect(func() -> void: _add_days(1))
	%Day10Button.pressed.connect(func() -> void: _add_days(10))
	%RealmNextButton.pressed.connect(_advance_realm)
	%RealmMaxButton.pressed.connect(_set_max_realm)
	%HealButton.pressed.connect(_full_heal)
	%ClearInjuryButton.pressed.connect(_clear_injury)
	%OpenItemGrantButton.pressed.connect(_open_item_grant_panel)
	%HubButton.pressed.connect(_go_hub)
	%WorldMapButton.pressed.connect(_go_world_map)
	%AttributesButton.pressed.connect(_go_attributes)
	%BackpackButton.pressed.connect(_go_backpack)
	%StartExpeditionButton.pressed.connect(_start_expedition)
	%ForceSettleButton.pressed.connect(_force_settle_expedition)
	%ResetExpeditionButton.pressed.connect(_reset_expedition)
	%StartGmBattleButton.pressed.connect(_start_gm_battle)
	%NewGameButton.pressed.connect(_new_game)
	if has_node("%DaoKnowledgeButton"):
		%DaoKnowledgeButton.pressed.connect(_grant_dao_knowledge)


func _build_location_options() -> void:
	_location_option.clear()
	var ids: Array = ConfigManager.all_location_ids()
	ids.sort()
	for location_id_v in ids:
		var location_id := str(location_id_v)
		var row := ConfigManager.location_by_id(location_id)
		var label := str(row.get("name", location_id))
		_location_option.add_item(label, _location_option.item_count)
		_location_option.set_item_metadata(_location_option.item_count - 1, location_id)
	if _location_option.item_count > 0:
		_location_option.select(0)


func _build_monster_options() -> void:
	_monster_option.clear()
	var rows: Array = []
	for monster_id_v in ConfigManager.all_monster_ids():
		var monster_id := str(monster_id_v)
		var monster := ConfigManager.monster_by_id(monster_id)
		if monster.is_empty():
			continue
		rows.append({
			"id": monster_id,
			"name": str(monster.get("name", monster_id)),
			"species": str(monster.get("species", "")),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	for row_v in rows:
		var row := row_v as Dictionary
		var monster_id := str(row.get("id", ""))
		var species := str(row.get("species", ""))
		var label := "%s · %s" % [str(row.get("name", monster_id)), monster_id]
		if species != "":
			label += " · " + species
		_monster_option.add_item(label, _monster_option.item_count)
		_monster_option.set_item_metadata(_monster_option.item_count - 1, monster_id)
	if _monster_option.item_count > 0:
		_monster_option.select(0)
	_enemy_count_input.min_value = 1
	_enemy_count_input.max_value = 8
	_enemy_count_input.value = 1


func _bind_status() -> void:
	var scene_id := str(DataStore.scene_runtime().get("current_id", "unknown"))
	var expedition_text := "无"
	if ExpeditionState.active:
		expedition_text = "%s · %s · 第 %d 步" % [
			ExpeditionState.location_id,
			ExpeditionState.phase,
			ExpeditionState.steps,
		]
	_status_label.text = "场景 %s | %s %s | 修为 %d/%d | 灵石 %d | 历练 %s" % [
		scene_id,
		GameState.time_date_label(GameState.day),
		GameState.realm_name,
		GameState.cultivation,
		GameState.breakthrough_at,
		GameState.ling_stones,
		expedition_text,
	]


func _flash(message: String) -> void:
	_message_label.text = message
	_bind_status()


func _on_close_pressed() -> void:
	visible = false


## 正常途径：grant_cultivation → _auto_advance_layers → refresh_derived_attrs
func _add_cultivation(amount: int) -> void:
	var result: Dictionary = GameState.grant_cultivation(amount)
	if not bool(result.get("ok", false)):
		_flash(str(result.get("error", "修为增加失败")))
		return
	var layer_advances := int(result.get("layer_advances", 0))
	var extra := "，小境界提升 %d 层" % layer_advances if layer_advances > 0 else ""
	_flash("修为 +%d%s，当前 %d/%d" % [
		int(result.get("added", amount)), extra, GameState.cultivation, GameState.breakthrough_at,
	])


## 正常途径：fill_cultivation_to_breakthrough → _auto_advance_layers
func _fill_cultivation() -> void:
	var result: Dictionary = GameState.fill_cultivation_to_breakthrough()
	var layer_advances := int(result.get("layer_advances", 0))
	var extra := "，已提升至 %s" % GameState.realm_name if layer_advances > 0 else ""
	_flash("修为已补满至突破门槛 %d%s" % [GameState.breakthrough_at, extra])


## 正常途径：grant_rewards（currency / ling_stones）
func _add_stones(amount: int) -> void:
	var applied: Array = GameState.grant_rewards([
		{"kind": "currency", "id": "ling_stones", "count": maxi(0, amount)},
	])
	if applied.is_empty():
		_flash("灵石发放失败")
		return
	var row := applied[0] as Dictionary
	_flash("灵石 +%d，当前 %d" % [int(row.get("count", 0)), GameState.ling_stones])


## 无对应玩法 API：仅推进日数，不附带修炼 / 休息副作用
func _add_days(amount: int) -> void:
	GameState.day += maxi(0, amount)
	_flash("日数 +%d，当前 %s" % [amount, GameState.time_date_label(GameState.day)])


## 正常途径：advance_realm_one_step（大境界 → breakthrough，小层 → _auto_advance_layers）
func _advance_realm() -> void:
	var result: Dictionary = GameState.advance_realm_one_step()
	if not bool(result.get("ok", false)):
		_flash(str(result.get("error", "无法继续提升境界")))
		return
	if str(result.get("mode", "")) == "layer":
		_flash("境界提升至 %s（小层）" % GameState.realm_name)
	else:
		_flash("大境界突破成功：%s → %s" % [
			str(result.get("old_realm", "")),
			str(result.get("new_realm", GameState.realm_name)),
		])


## 正常途径：逐步 advance_realm_one_step 直至最高境界
func _set_max_realm() -> void:
	var realms := _realms()
	if realms.is_empty():
		_flash("境界表为空")
		return
	var result: Dictionary = GameState.advance_realm_to_index(realms.size() - 1)
	if not bool(result.get("ok", false)):
		_flash(str(result.get("error", "无法提升至最高境界")))
		return
	_flash("境界设为 %s（共 %d 步）" % [GameState.realm_name, int(result.get("steps", 0))])


## 正常途径：rest（恢复满气血法力、减轻伤势、推进 1 日、写入经历）
func _full_heal() -> void:
	GameState.rest()
	_flash("已休息：气血与法力恢复满值，伤势减轻")


## 正常途径：重复 rest 直至伤势清零（每次均推进 1 日）
func _clear_injury() -> void:
	var rests: int = GameState.rest_until_injury_cleared()
	if rests <= 0:
		_flash("当前无伤势")
		return
	_flash("已通过休息 %d 次清除伤势（每次走 rest 流程）" % rests)


func _open_item_grant_panel() -> void:
	if GmPanelHost != null and GmPanelHost.has_method("open_item_grant_panel"):
		GmPanelHost.open_item_grant_panel()
	else:
		_flash("无法打开添加道具面板")


func _navigate(nav: Dictionary, fallback_error: String) -> bool:
	if bool(nav.get("ok", false)):
		return true
	visible = true
	_flash(str(nav.get("error", fallback_error)))
	return false


func _go_hub() -> void:
	visible = false
	_navigate(SceneManager.go_hub({"allow_active_expedition": true}), "无法返回观中")


func _go_world_map() -> void:
	visible = false
	_navigate(SceneManager.go_world_map(), "无法打开世界地图")


func _go_attributes() -> void:
	visible = false
	_navigate(SceneManager.go_character_attributes_panel(), "无法打开人物属性")


func _go_backpack() -> void:
	visible = false
	_navigate(SceneManager.go_backpack_panel(), "无法打开背包")


func _start_expedition() -> void:
	if _location_option.item_count <= 0:
		_flash("没有可用历练地点")
		return
	var location_id := str(_location_option.get_item_metadata(_location_option.selected))
	visible = false
	_navigate(SceneManager.start_expedition(location_id), "无法开始历练")


func _force_settle_expedition() -> void:
	if not ExpeditionState.active:
		_flash("当前没有进行中的历练")
		return
	visible = false
	_navigate(SceneManager.go_expedition_result("manual"), "无法进入历练结算")


func _reset_expedition() -> void:
	if not ExpeditionState.active:
		_flash("当前没有进行中的历练")
		return
	ExpeditionState.reset()
	_flash("历练状态已重置")


func _start_gm_battle() -> void:
	if ExpeditionState.active:
		_flash("历练中不能创建 GM 战斗，请先结算或重置历练")
		return
	if _monster_option.item_count <= 0:
		_flash("没有可用敌人配置")
		return
	var monster_id := str(_monster_option.get_item_metadata(_monster_option.selected))
	var count := int(_enemy_count_input.value)
	var battle_data := _build_gm_battle_init(monster_id, count)
	if battle_data.is_empty():
		_flash("创建战斗失败：敌人配置无效")
		return
	var errors := BattleInitData.collect_errors(battle_data)
	if not errors.is_empty():
		_flash("创建战斗失败：%s" % errors[0])
		return
	visible = false
	_navigate(SceneManager.go_fight(battle_data, "gm_panel"), "无法进入 GM 战斗")


func _build_gm_battle_init(monster_id: String, count: int) -> Dictionary:
	return GmBattleBuilderScript.build(monster_id, count, GameState, ConfigManager)


func _new_game() -> void:
	GameState.new_game()
	visible = false
	_navigate(SceneManager.go_hub(), "无法返回观中")


func _grant_dao_knowledge() -> void:
	GameState.grant_knowledge("foundation.breathing", 3)
	GameState.grant_knowledge("cultivation.cycle", 2)
	GameState.learn_ability("ability.combat.qi_bolt")
	_flash("已授予入门知识与御气弹")


func _realms() -> Array:
	return JsonLoader._read_json_root_object(SIM_PATH).get("realms", []) as Array
