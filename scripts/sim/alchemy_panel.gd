extends Control

const AlchemyServiceScript := preload("res://scripts/sim/alchemy_service.gd")
const SELECTION_MODES := ["lowest", "highest"]
const TUTORIAL_RECIPE_ID := "recipe.juqi"
const TUTORIAL_STRATEGY_ID := "steady"
const TUTORIAL_SELECTION_MODE := "lowest"
const TUTORIAL_BREW_LOCK_EVENTS := [
	"tutorial.alchemy_recipe_selected",
	"tutorial.alchemy_preview_acknowledged",
]

@onready var _recipe_option: OptionButton = %RecipeOption
@onready var _strategy_option: OptionButton = %StrategyOption
@onready var _selection_option: OptionButton = %SelectionOption
@onready var _status_label: Label = %StatusLabel
@onready var _ingredient_label: Label = %IngredientLabel
@onready var _probability_label: Label = %ProbabilityLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _result_label: Label = %ResultLabel
@onready var _brew_button: Button = %BrewButton
@onready var _player_label: Label = $PlayerChip/Text
@onready var _probability_card: PanelContainer = $StrategyPanel/StrategyContent/ProbabilityCard
@onready var _material_slots: Array[ItemView] = [%MaterialSlot0, %MaterialSlot1, %MaterialSlot2]
@onready var _pill_preview: ItemView = %PillPreviewSlot
@onready var _batch_popup: AlchemyBatchPopup = %BatchPopup

var _recipes: Array = []
var _strategies: Array = []


func _ready() -> void:
	_recipes = GameState.alchemy_recipes()
	_strategies = GameState.alchemy_strategies()
	for recipe_v in _recipes:
		_recipe_option.add_item(str((recipe_v as Dictionary).get("name", "丹方")))
	for strategy_v in _strategies:
		_strategy_option.add_item(str((strategy_v as Dictionary).get("name", "策略")))
	_selection_option.add_item("节省药材")
	_selection_option.add_item("优先品质")
	_bind_option_menus([_recipe_option, _strategy_option, _selection_option])
	if _is_tutorial_alchemy_forced():
		_setup_tutorial_alchemy()
	else:
		_select_saved_defaults()
	_recipe_option.item_selected.connect(_on_recipe_selected)
	_strategy_option.item_selected.connect(func(_index: int) -> void: _refresh())
	_selection_option.item_selected.connect(func(_index: int) -> void: _refresh())
	_probability_card.gui_input.connect(_on_preview_area_gui_input)
	%CloseButton.pressed.connect(_on_close_pressed)
	_brew_button.pressed.connect(_on_brew_pressed)
	_batch_popup.confirmed.connect(_on_batch_confirmed)
	_batch_popup.cancelled.connect(func() -> void: pass)
	_refresh()


func _bind_option_menus(options: Array) -> void:
	var panel_theme := theme
	if panel_theme == null:
		return
	for option_v in options:
		if not option_v is OptionButton:
			continue
		var option := option_v as OptionButton
		var popup := option.get_popup()
		if popup == null:
			continue
		popup.theme = panel_theme


func _select_saved_defaults() -> void:
	var last_recipe := str(GameState.alchemy.get("last_recipe", "recipe.huiqi"))
	var last_strategy := str(GameState.alchemy.get("last_strategy", "standard"))
	_select_option_by_id(_recipes, "id", last_recipe, _recipe_option)
	_select_option_by_id(_strategies, "id", last_strategy, _strategy_option)


func _select_option_by_id(rows: Array, key: String, target_id: String, option: OptionButton) -> void:
	for index in rows.size():
		if str((rows[index] as Dictionary).get(key, "")) == target_id:
			option.select(index)
			return


func _refresh() -> void:
	_player_label.text = "%s\n%s" % [GameState.player_name, GameState.realm_name]
	var preview := _preview()
	var furnace_id := str(GameState.alchemy.get("equipped_furnace", ""))
	var owned := GameState.alchemy.get("owned_furnaces", {}) as Dictionary
	var furnace_state := owned.get(furnace_id, {}) as Dictionary
	_status_label.text = "%s  |  炼丹术 Lv.%d（%d/%d）  |  丹炉耐久 %d" % [
		GameState.time_date_label(GameState.day),
		int(GameState.alchemy.get("level", 1)),
		int(GameState.alchemy.get("xp", 0)),
		int(GameState.alchemy.get("level", 1)) * 100,
		int(furnace_state.get("durability", 0)),
	]
	if not bool(preview.get("ok", false)):
		_ingredient_label.text = str(preview.get("error", "当前无法炼制"))
		_probability_label.text = "备齐药材后可查看成丹概率。"
		_detail_label.text = ""
		_refresh_material_slots(preview.get("ingredients", []) as Array)
		_refresh_pill_preview(_selected_recipe())
		_brew_button.disabled = true
		return
	_ingredient_label.text = _format_ingredients(preview.get("ingredients", []) as Array)
	_probability_label.text = _format_probabilities(preview.get("probabilities", {}) as Dictionary)
	_refresh_material_slots(preview.get("ingredients", []) as Array)
	_refresh_pill_preview(preview.get("recipe", {}) as Dictionary)
	var strategy := preview.get("strategy", {}) as Dictionary
	_detail_label.text = (
		"当前丹方熟练度 %d/1000（品质分 %+.1f）\n成功率 %.1f%% · 上品以上 %.1f%% · 基础成丹分 %.1f\n"
		+ "药材品质 %.2f（%+.1f） · 属性辅助 %+.1f\n"
		+ "基础产量 %d · 多丹概率 %.1f%%（最多 +%d） · 节省药材概率 %.1f%%\n"
		+ "预计耗时 %s\n\n%s"
	) % [
		int(preview.get("recipe_mastery", 0)),
		float(preview.get("mastery_score", 0.0)),
		float(preview.get("success_probability", 0.0)) * 100.0,
		float(preview.get("high_quality_probability", 0.0)) * 100.0,
		float(preview.get("base_score", 0.0)),
		float(preview.get("average_quality", 1.0)),
		float(preview.get("ingredient_score", 0.0)),
		float(preview.get("attribute_score", 0.0)),
		int(preview.get("product_count", 1)),
		float(preview.get("extra_pill_chance", 0.0)) * 100.0,
		int(preview.get("max_extra_pills", 0)),
		float(preview.get("cost_save_chance", 0.0)) * 100.0,
		str(preview.get("duration_label", GameState.time_duration_label(int(preview.get("days", 1))))),
		str(strategy.get("description", "")),
	]
	_brew_button.text = "开炉炼制（%s）" % str(preview.get("duration_label", GameState.time_duration_label(int(preview.get("days", 1)))))
	_brew_button.disabled = _tutorial_brew_locked()


func _preview() -> Dictionary:
	if _recipes.is_empty() or _strategies.is_empty():
		return {"ok": false, "error": "炼丹配置为空"}
	var recipe_id := ""
	var strategy_id := ""
	var selection_mode := ""
	if _is_tutorial_alchemy_forced():
		recipe_id = TUTORIAL_RECIPE_ID
		strategy_id = TUTORIAL_STRATEGY_ID
		selection_mode = TUTORIAL_SELECTION_MODE
	else:
		var recipe := _recipes[clampi(_recipe_option.selected, 0, _recipes.size() - 1)] as Dictionary
		var strategy := _strategies[clampi(_strategy_option.selected, 0, _strategies.size() - 1)] as Dictionary
		recipe_id = str(recipe.get("id", ""))
		strategy_id = str(strategy.get("id", ""))
		selection_mode = str(SELECTION_MODES[clampi(_selection_option.selected, 0, SELECTION_MODES.size() - 1)])
	return GameState.preview_alchemy(recipe_id, strategy_id, selection_mode)


func _selected_recipe() -> Dictionary:
	if _recipes.is_empty():
		return {}
	if _is_tutorial_alchemy_forced():
		for recipe_v in _recipes:
			if str((recipe_v as Dictionary).get("id", "")) == TUTORIAL_RECIPE_ID:
				return recipe_v as Dictionary
	var index := clampi(_recipe_option.selected, 0, _recipes.size() - 1)
	return _recipes[index] as Dictionary


func _format_ingredients(rows: Array) -> String:
	var lines: PackedStringArray = ["本炉药材"]
	for row_v in rows:
		var row := row_v as Dictionary
		lines.append("· %s x%d  品质 %d（持有 %d）" % [
			ConfigManager.get_item_display_name(str(row.get("id", ""))),
			int(row.get("count", 0)),
			int(row.get("quality", 1)),
			int(GameState.inventory.get(str(row.get("id", "")), 0)),
		])
	return "\n".join(lines)


func _refresh_material_slots(ingredients: Array) -> void:
	for index in _material_slots.size():
		var slot := _material_slots[index]
		if index >= ingredients.size():
			slot.visible = false
			continue
		var row := ingredients[index] as Dictionary
		slot.visible = true
		var item_id := str(row.get("id", ""))
		var required := int(row.get("count", 0))
		var sufficient := bool(row.get("sufficient", true))
		ItemView.apply_item_id(slot, item_id, required, {
			"show_name": true,
			"name_override": str(row.get("family", "药材")),
			"always_show_count": true,
			"show_info_on_click": true,
			"click_enabled": true,
			"insufficient": not sufficient,
		})


func _refresh_pill_preview(recipe: Dictionary) -> void:
	var product_id := AlchemyServiceScript.recipe_preview_product_id(recipe)
	if product_id == "":
		_pill_preview.visible = false
		_pill_preview.apply_empty(null)
		return
	_pill_preview.visible = true
	ItemView.apply_item_id(_pill_preview, product_id, 0, {
		"show_name": true,
		"name_override": str(recipe.get("pill_name", "丹药")),
		"show_info_on_click": true,
		"click_enabled": true,
	})


func _format_probabilities(probabilities: Dictionary) -> String:
	var failure := (
		float(probabilities.get(EnumAlchemyQuality.LABEL_NONE, 0.0))
		+ float(probabilities.get(EnumAlchemyQuality.LABEL_WASTE, 0.0))
	)
	var lines: PackedStringArray = [
		"炼制成功 %.1f%% · 失败 %.1f%%" % [(1.0 - failure) * 100.0, failure * 100.0],
		"下品及以上视为成功",
	]
	for quality_label in EnumAlchemyQuality.ALL_LABELS:
		lines.append("%s  %5.1f%%" % [
			EnumAlchemyQuality.display_name(quality_label),
			float(probabilities.get(quality_label, 0.0)) * 100.0,
		])
	return "\n".join(lines)


func _on_brew_pressed() -> void:
	var preview := _preview()
	if not bool(preview.get("ok", false)):
		_result_label.text = str(preview.get("error", "炼制失败"))
		return
	if _is_tutorial_alchemy_forced():
		_start_brew(1, preview)
		return
	var max_batch := GameState.max_alchemy_batch_count(preview)
	if max_batch <= 1:
		_start_brew(1, preview)
		return
	_batch_popup.open(preview, max_batch)


func _on_batch_confirmed(batch_count: int) -> void:
	var preview := _preview()
	if not bool(preview.get("ok", false)):
		_result_label.text = str(preview.get("error", "炼制失败"))
		return
	_start_brew(batch_count, preview)


func _start_brew(batch_count: int, preview: Dictionary) -> void:
	var recipe := preview.get("recipe", {}) as Dictionary
	var strategy := preview.get("strategy", {}) as Dictionary
	var days_per_batch := int(preview.get("days", 1))
	var nav: Dictionary = SceneManager.go_alchemy_progress({
		"recipe_id": str(recipe.get("id", "")),
		"strategy_id": str(strategy.get("id", "")),
		"selection_mode": str(preview.get("selection_mode", "lowest")),
		"days": days_per_batch * batch_count,
		"days_per_batch": days_per_batch,
		"batch_count": batch_count,
		"recipe_name": str(recipe.get("name", "丹方")),
		"strategy_name": str(strategy.get("name", "策略")),
		"start_day": GameState.day,
	})
	if not bool(nav.get("ok", false)):
		_result_label.text = str(nav.get("error", "无法开始炼制"))
		return
	TutorialService.game_event("tutorial.alchemy_started")


func _on_close_pressed() -> void:
	SceneManager.go_hub()


func _is_tutorial_alchemy_forced() -> bool:
	if not TutorialService.is_active():
		return false
	var flags := (DataStore.savedata.get("tutorial", {}) as Dictionary).get("flags", {}) as Dictionary
	return bool(flags.get("tutorial.alchemy_notes_used", false)) and not bool(
		flags.get("tutorial.alchemy_completed", false)
	)


func _setup_tutorial_alchemy() -> void:
	_select_option_by_id(_strategies, "id", TUTORIAL_STRATEGY_ID, _strategy_option)
	_selection_option.select(0)
	_recipe_option.select(0)
	_recipe_option.disabled = false
	_strategy_option.disabled = true
	_selection_option.disabled = true


func _on_recipe_selected(index: int) -> void:
	if index < 0 or index >= _recipes.size():
		return
	if str((_recipes[index] as Dictionary).get("id", "")) == TUTORIAL_RECIPE_ID:
		TutorialService.game_event("tutorial.alchemy_recipe_selected")
		call_deferred("_refresh")
		return
	_refresh()


func _tutorial_brew_locked() -> bool:
	if not _is_tutorial_alchemy_forced():
		return false
	var flags := (DataStore.savedata.get("tutorial", {}) as Dictionary).get("flags", {}) as Dictionary
	for event_id in TUTORIAL_BREW_LOCK_EVENTS:
		if not bool(flags.get(event_id, false)):
			return true
	return false


func _on_preview_area_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	TutorialService.game_event("tutorial.alchemy_preview_acknowledged")
	# Story advances synchronously; refresh so brew lock reflects the new step.
	call_deferred("_refresh")
