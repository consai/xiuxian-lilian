extends Control

var _lilian_session_host: Node
var _game_session_host: Node


func bind_lilian_session_host(host: Node) -> void:
	_lilian_session_host = host


func bind_game_session_host(host: Node) -> void:
	_game_session_host = host


func _game_session() -> Node:
	if _game_session_host == null:
		push_error("TupoZongjie: GameSessionHost 未注入")
		return null
	return _game_session_host.session()


func _lilian_session() -> Node:
	if _lilian_session_host == null:
		push_error("TupoZongjie: LilianSessionHost 未注入")
		return null
	return _lilian_session_host.session()

const TupoServiceScript := preload("res://scripts/sim/tupo_service.gd")

const COMPONENT_ROWS := {
	"cultivation": "LeftPanel/LeftMargin/LeftVBox/Cultivation",
	"pills": "LeftPanel/LeftMargin/LeftVBox/Pills",
	"mind": "LeftPanel/LeftMargin/LeftVBox/Mind",
	"aptitude": "LeftPanel/LeftMargin/LeftVBox/RootBone",
	"fortune": "LeftPanel/LeftMargin/LeftVBox/Luck",
	"special_method": "LeftPanel/LeftMargin/LeftVBox/Method",
	"other": "LeftPanel/LeftMargin/LeftVBox/Other",
}

const PERK_LABELS := {
	"all_stats_percent_2": "全属性 +2%",
	"next_breakthrough_discount_3": "下次大境界突破门槛 -3%",
	"hp_mp_cap_percent_3": "气血与法力上限 +3%",
	"unlock_premium_foundation_passive": "解锁上品筑基被动",
	"cultivation_speed_penalty_5": "修炼速度 -5%",
	"core_passive_tier_1": "一品金丹被动",
	"core_passive_tier_2": "极品金丹被动",
	"core_passive_tier_3": "上品金丹被动",
	"nascent_avatar_tier_1": "一品元婴法相",
	"nascent_avatar_tier_2": "极品元婴法相",
	"nascent_avatar_tier_3": "上品元婴法相",
}

@onready var _player_info: Label = %PlayerInfoLabel
@onready var _ling_stones: Label = %LingStonesLabel
@onready var _total_label: Label = %TotalLabel
@onready var _realm_label: Label = %RealmLabel
@onready var _value_label: Label = %ValueLabel
@onready var _progress: ProgressBar = %ValueProgress
@onready var _warning: Label = %WarningLabel
@onready var _tier_result: Label = %TierResultLabel
@onready var _tier_effect: Label = %TierEffectLabel
@onready var _explain: Label = %ExplainLabel
@onready var _start_button: TextureButton = %StartButton
@onready var _start_label: Label = %StartLabel
@onready var _paths_panel: PanelContainer = %PathsPanel
@onready var _left_panel: PanelContainer = %LeftPanel

var _finished := false


func _ready() -> void:
	%CloseButton.pressed.connect(_on_close_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	call_deferred("_initialize_after_session")


func _initialize_after_session() -> void:
	if _game_session() == null:
		return
	var payload: Dictionary = SceneManager.take_payload(SceneManager.TUPO_ZONGJIE)
	if str(payload.get("mode", "")) == "result" and bool(payload.get("success", false)):
		_show_success(payload)
		return
	if not _game_session().can_breakthrough():
		_on_close_pressed()
		return
	_refresh_panel()


func _refresh_panel() -> void:
	_finished = false
	var game_session := _game_session()
	_player_info.text = "%s\n%s" % [game_session.player_name, game_session.realm_name]
	_ling_stones.text = "灵石  %d" % game_session.ling_stones
	_paths_panel.visible = true
	_left_panel.visible = true
	_start_label.text = "开始突破"
	var preview: Dictionary = game_session.preview_breakthrough()
	if not bool(preview.get("ok", false)):
		_apply_preview_error(str(preview.get("error", "当前无法突破")))
		return
	_apply_breakdown(preview)


func _apply_preview_error(error: String) -> void:
	for key in COMPONENT_ROWS.keys():
		_bind_row(str(COMPONENT_ROWS[key]), 0, [])
	_total_label.text = "突破值总计       —"
	_realm_label.text = "%s   →   %s" % [_game_session().realm_name, _game_session().next_realm_name()]
	_value_label.text = "突破值     —"
	_progress.max_value = 1.0
	_progress.value = 0.0
	_tier_result.text = "不可突破"
	_tier_effect.text = "当前条件不足，无法预览突破效果"
	_explain.text = ""
	_warning.text = error
	_warning.add_theme_color_override("font_color", Color(0.64, 0.14, 0.08, 1))
	_start_button.disabled = true
	_start_button.modulate = Color(0.65, 0.65, 0.65, 0.85)


func _apply_breakdown(preview: Dictionary) -> void:
	var components: Dictionary = preview.get("components", {}) as Dictionary
	var component_sources: Dictionary = preview.get("component_sources", {}) as Dictionary
	for key in COMPONENT_ROWS.keys():
		_bind_row(str(COMPONENT_ROWS[key]), int(components.get(key, 0)), component_sources.get(key, []) as Array)
	var total := int(preview.get("total", 0))
	var min_total := maxi(1, int(preview.get("min_total", 1)))
	_total_label.text = "突破值总计       %d" % total
	_realm_label.text = "%s   →   %s" % [
		str(preview.get("current_realm_name", _game_session().realm_name)),
		str(preview.get("target_realm_name", "")),
	]
	_value_label.text = "突破值     %d / %d" % [total, min_total]
	_progress.max_value = float(min_total)
	_progress.value = float(mini(total, min_total))
	var tier: Dictionary = preview.get("tier", {}) as Dictionary
	var can_attempt := bool(preview.get("can_attempt", false))
	_tier_result.text = str(tier.get("label", "不可突破"))
	_tier_effect.text = _format_tier_effect(tier)
	var gap_hint := TupoServiceScript.major_gap_hint(preview)
	_explain.text = (
		"突破值达到 %d 可尝试突破\n\n"
		+ "%s\n\n"
		+ "失败可能境界不稳；品质越高，成功率与根基成长越好"
	) % [min_total, gap_hint]
	if can_attempt:
		_warning.text = str(preview.get("hint", tier.get("hint", "可以尝试突破")))
		_warning.add_theme_color_override("font_color", Color(0.22, 0.42, 0.12, 1))
	else:
		_warning.text = gap_hint
		_warning.add_theme_color_override("font_color", Color(0.64, 0.14, 0.08, 1))
	_start_button.disabled = not can_attempt
	_start_button.modulate = Color.WHITE if can_attempt else Color(0.65, 0.65, 0.65, 0.85)


func _show_success(result: Dictionary) -> void:
	_finished = true
	var game_session := _game_session()
	_player_info.text = "%s\n%s" % [game_session.player_name, game_session.realm_name]
	_ling_stones.text = "灵石  %d" % game_session.ling_stones
	_paths_panel.visible = false
	_left_panel.visible = false
	_realm_label.text = "%s   →   %s" % [
		str(result.get("old_realm", "")),
		str(result.get("new_realm", game_session.realm_name)),
	]
	var tier_label := str(result.get("tier_label", ""))
	_value_label.text = "突破成功"
	_progress.value = _progress.max_value
	_warning.text = "历时%s" % game_session.time_date_label(int(result.get("day", game_session.day)))
	_warning.add_theme_color_override("font_color", Color(0.22, 0.42, 0.12, 1))
	_tier_result.text = "突破成功" if tier_label == "" else tier_label
	_tier_effect.text = _format_success_effect(result, tier_label)
	_explain.text = _format_success_stats(result)
	_start_label.text = "继续修行"
	_start_button.disabled = false
	_start_button.modulate = Color.WHITE


func _format_tier_effect(tier: Dictionary) -> String:
	var lines: PackedStringArray = []
	var label := str(tier.get("label", ""))
	if label != "" and label != "不可突破":
		lines.append("预期品质：%s" % label)
	var success_rate := float(tier.get("success_rate", 0.0))
	if success_rate > 0.0:
		lines.append("成功率：%d%%" % int(round(success_rate * 100.0)))
	var perks := tier.get("perks", []) as Array
	for perk in perks:
		lines.append(_perk_label(str(perk)))
	return "\n".join(lines) if not lines.is_empty() else "继续积累突破值可提升品质"


func _format_success_effect(result: Dictionary, tier_label: String) -> String:
	var lines: PackedStringArray = []
	if tier_label != "":
		lines.append("达成品质：%s" % tier_label)
	var perks := result.get("perks", []) as Array
	for perk in perks:
		lines.append(_perk_label(str(perk)))
	return "\n".join(lines) if not lines.is_empty() else "境界提升，根基更为扎实"


func _format_success_stats(result: Dictionary) -> String:
	var totals := result.get("totals", {}) as Dictionary
	return (
		"历练 %d 次，胜 %d 次，负 %d 次\n"
		+ "累计获得物品 %d 件"
	) % [
		int(totals.get("battles", 0)),
		int(totals.get("wins", 0)),
		int(totals.get("losses", 0)),
		int(totals.get("items_gained", 0)),
	]


func _perk_label(perk_id: String) -> String:
	return str(PERK_LABELS.get(perk_id, perk_id))


func _bind_row(row_path: String, value: int, sources: Array) -> void:
	var row := get_node_or_null(row_path)
	if row == null:
		return
	if row.has_method("bind"):
		row.bind(value, sources)
		return
	var value_label := row.get_node_or_null("Value") as Label
	if value_label != null:
		value_label.text = str(value)


func _on_start_pressed() -> void:
	if _finished:
		_on_close_pressed()
		return
	var result: Dictionary = _game_session().attempt_breakthrough()
	if not bool(result.get("ok", false)):
		_warning.text = str(result.get("error", "无法突破"))
		_warning.add_theme_color_override("font_color", Color(0.64, 0.14, 0.08, 1))
		return
	if bool(result.get("success", true)):
		_show_success(result)
		return
	_warning.text = str(result.get("error", "突破失败，境界不稳"))
	_warning.add_theme_color_override("font_color", Color(0.64, 0.14, 0.08, 1))
	_refresh_panel()


func _on_close_pressed() -> void:
	var lilian := _lilian_session()
	if lilian == null: return
	var nav: Dictionary = LilianFlowService.open_hub(lilian, SceneManager)
	if not bool(nav.get("ok", false)):
		push_warning(str(nav.get("error", "无法返回观中")))
