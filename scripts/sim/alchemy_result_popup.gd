extends Control

const AlchemyServiceScript := preload("res://scripts/sim/alchemy_service.gd")

@onready var _quality_label: Label = $Dialog/Content/RewardRow/RewardInfo/Quality/Text
@onready var _name_label: Label = $Dialog/Content/RewardRow/RewardInfo/Name
@onready var _description_label: Label = $Dialog/Content/RewardRow/RewardInfo/Description
@onready var _quality_panel: PanelContainer = $Dialog/Content/RewardRow/RewardInfo/Quality
@onready var _score_label: Label = $Dialog/Content/Stats/Score/Text
@onready var _experience_label: Label = $Dialog/Content/Stats/Experience/Text
@onready var _durability_label: Label = $Dialog/Content/Stats/Durability/Text
@onready var _days_label: Label = $Dialog/Content/Stats/Days/Text
@onready var _mastery_label: Label = %MasteryLabel
@onready var _materials_row: HBoxContainer = $Dialog/Content/Materials
@onready var _reward_item: ItemView = %RewardItem
@onready var _material_template: ItemView = %MaterialTemplate


func _ready() -> void:
	_material_template.visible = false
	_material_template.set_click_enabled(false)
	%ContinueButton.pressed.connect(_on_continue_pressed)
	%ReturnButton.pressed.connect(_on_return_pressed)
	var payload: Dictionary = SceneManager.take_payload(SceneManager.ALCHEMY_RESULT)
	if payload.is_empty() or not bool(payload.get("ok", false)):
		var nav: Dictionary = SceneManager.go_alchemy_panel()
		if not bool(nav.get("ok", false)):
			SceneManager.go_hub()
		return
	_apply_result(payload)


func _apply_result(result: Dictionary) -> void:
	var quality := str(result.get("quality", EnumAlchemyQuality.LABEL_NONE))
	var quality_name := str(result.get("quality_name", "无产物"))
	var pill_name := str(result.get("pill_name", "丹药"))
	var added := int(result.get("added", 0))
	var product_id := str(result.get("product_id", ""))

	var batch_count := int(result.get("batch_count", 1))
	var succeeded := bool(result.get("succeeded", false))
	if batch_count > 1:
		var success_count := int(result.get("success_count", 0))
		_quality_label.text = "连炼 %d 炉 · 成功 %d 炉" % [batch_count, success_count]
	else:
		_quality_label.text = "%s · %s" % [
			"炼制成功" if succeeded else "炼制失败",
			quality_name if quality_name != "" else "无产物",
		]
	_apply_quality_style(quality)
	if batch_count > 1:
		var product_line := _format_batch_products(
			result.get("product_totals", {}) as Dictionary,
			str(result.get("recipe_id", ""))
		)
		var quality_summary := str(result.get("quality_summary", "")).strip_edges()
		if product_line != "":
			_name_label.text = product_line
			_description_label.text = (
				"炉次：%s" % quality_summary if quality_summary != "" else ""
			)
		elif quality_summary != "":
			_name_label.text = quality_summary
			_description_label.text = ""
		else:
			_name_label.text = pill_name
			_description_label.text = ""
	elif added > 0 and product_id != "":
		_name_label.text = "%s%s ×%d" % [
			quality_name,
			ConfigManager.get_item_display_name(product_id),
			added,
		]
		_description_label.text = _product_description(result)
	else:
		_name_label.text = "%s · %s" % [pill_name, quality_name]
		_description_label.text = _product_description(result)

	var product_count := added if added > 0 else int(result.get("count", 0))
	if product_id != "":
		ItemView.apply_item_id(_reward_item, product_id, product_count, {
			"show_name": false,
			"always_show_count": product_count > 0,
			"show_info_on_click": true,
			"click_enabled": true,
		})
	else:
		_reward_item.apply_empty(null)

	_score_label.text = "成丹分\n%d" % int(round(float(result.get("score", 0.0))))
	_experience_label.text = "炼丹经验\n+%d" % int(result.get("xp", 0))
	var furnace_id := str(GameState.alchemy.get("equipped_furnace", ""))
	var furnace := AlchemyServiceScript.furnace_by_id(furnace_id)
	var max_durability := int(furnace.get("max_durability", 30))
	_durability_label.text = "丹炉耐久\n%d/%d" % [
		int(result.get("furnace_durability", 0)),
		max_durability,
	]
	_days_label.text = "耗时\n%s" % str(result.get("duration_label", GameState.time_duration_label(int(result.get("days", 1)))))
	_mastery_label.text = "%s熟练度 +%d  ·  当前 %d/1000%s" % [
		pill_name,
		int(result.get("mastery_gain", 0)),
		int(result.get("recipe_mastery", 0)),
		"（失败研习加成）" if not succeeded else "",
	]
	if int(result.get("extra_pills", 0)) > 0:
		_mastery_label.text += "  ·  熟练多丹 +%d" % int(result.get("extra_pills", 0))
	if int(result.get("saved_material_count", 0)) > 0:
		_mastery_label.text += "  ·  节省药材 %d" % int(result.get("saved_material_count", 0))
	_mastery_label.text += "\n%s" % _breakthrough_feedback(result)
	_render_materials(result.get("ingredients", []) as Array)


func _format_batch_products(product_totals: Dictionary, recipe_id: String) -> String:
	var rows: Array = []
	for product_id_v in product_totals.keys():
		var batch_product_id := str(product_id_v)
		var amount := int(product_totals.get(product_id_v, 0))
		if amount <= 0:
			continue
		rows.append({
			"product_id": batch_product_id,
			"amount": amount,
			"rank": _product_quality_rank(batch_product_id, recipe_id),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("rank", 0)) != int(b.get("rank", 0)):
			return int(a.get("rank", 0)) > int(b.get("rank", 0))
		return str(a.get("product_id", "")) < str(b.get("product_id", ""))
	)
	var parts: PackedStringArray = []
	for row_v in rows:
		var row := row_v as Dictionary
		parts.append("%s ×%d" % [
			ConfigManager.get_item_display_name(str(row.get("product_id", ""))),
			int(row.get("amount", 0)),
		])
	return " · ".join(parts)


func _product_quality_rank(product_id: String, recipe_id: String) -> int:
	if product_id == "items_WasteDan":
		return EnumAlchemyQuality.rank(EnumAlchemyQuality.LABEL_WASTE)
	var recipe := AlchemyServiceScript.recipe_by_id(recipe_id)
	for quality_key_v in (recipe.get("products", {}) as Dictionary).keys():
		var quality_key := str(quality_key_v)
		if str((recipe.get("products", {}) as Dictionary).get(quality_key_v, "")) == product_id:
			return EnumAlchemyQuality.rank(quality_key)
	return 0


func _apply_quality_style(quality: String) -> void:
	var color := EnumAlchemyQuality.result_color(quality)
	var style := _quality_panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var flat := (style as StyleBoxFlat).duplicate() as StyleBoxFlat
		flat.bg_color = color
		_quality_panel.add_theme_stylebox_override("panel", flat)


func _product_description(result: Dictionary) -> String:
	var product_id := str(result.get("product_id", ""))
	if product_id == "":
		return EnumAlchemyQuality.failure_flavor(str(result.get("quality", EnumAlchemyQuality.LABEL_NONE)))
	var def := ConfigManager.item_def_by_id(product_id)
	if def != null:
		var text := ItemInfoPayloadBuilder.describe_item(def).strip_edges()
		if text != "":
			return text
	return EnumAlchemyQuality.failure_flavor(str(result.get("quality", EnumAlchemyQuality.LABEL_NONE)))


func _breakthrough_feedback(result: Dictionary) -> String:
	var product_id := str(result.get("product_id", ""))
	var pill_name := str(result.get("pill_name", ""))
	if product_id.contains("JuQiDan") or pill_name.contains("聚气"):
		return "突破准备：聚气丹可在修炼界面炼化，快速补修为项。"
	return "突破准备：想冲筑基时，优先炼聚气丹补修为项。"


func _render_materials(ingredients: Array) -> void:
	for child in _materials_row.get_children():
		if child == _material_template:
			continue
		child.queue_free()
	for row_v in ingredients:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		var item_id := str(row.get("id", ""))
		if item_id == "":
			continue
		var view_v := _material_template.duplicate()
		if not view_v is ItemView:
			view_v.queue_free()
			continue
		var view := view_v as ItemView
		view.visible = true
		_materials_row.add_child(view)
		ItemView.apply_item_id(view, item_id, int(row.get("count", 0)), {
			"show_name": false,
			"always_show_count": true,
			"show_info_on_click": true,
			"click_enabled": true,
		})


func _on_continue_pressed() -> void:
	var nav: Dictionary = SceneManager.go_alchemy_panel()
	if not bool(nav.get("ok", false)):
		push_warning(str(nav.get("error", "无法返回炼丹界面")))


func _on_return_pressed() -> void:
	TutorialService.game_event("tutorial.alchemy_completed")
	var nav: Dictionary = SceneManager.go_hub()
	if not bool(nav.get("ok", false)):
		push_warning(str(nav.get("error", "无法返回观中")))
