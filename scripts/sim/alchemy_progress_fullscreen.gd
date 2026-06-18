extends Control

const ItemDefScript := preload("res://scripts/core/item_def.gd")

const MILESTONE_LABELS := ["投药", "控火", "凝丹", "开炉"]
const STATUS_TEXTS := [
	"药材入炉，药香初起",
	"文火慢炼，炉火渐稳",
	"丹液凝形，药力汇聚",
	"丹成出炉，余温未散",
]

@export var progress_duration := 3.0

@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _day_label: Label = %DayLabel
@onready var _status_label: Label = %StatusLabel
@onready var _cancel_button: TextureButton = %CancelButton
@onready var _speed_button: TextureButton = %SpeedButton
@onready var _milestone_labels: Array[Label] = [
	$Milestones/AddHerb/Text,
	$Milestones/ControlFire/Text,
	$Milestones/FormPill/Text,
	$Milestones/OpenFurnace/Text,
]

var _recipe_id := ""
var _strategy_id := ""
var _selection_mode := "lowest"
var _batch_count := 1
var _days := 1
var _days_per_batch := 1
var _start_day := 1
var _recipe_name := ""
var _running := false
var _finishing := false
var _elapsed := 0.0
var _speed_multiplier := 1.0


func _ready() -> void:
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_speed_button.pressed.connect(_on_speed_pressed)
	var payload: Dictionary = SceneManager.take_payload(SceneManager.ALCHEMY_PROGRESS)
	if not _apply_payload(payload):
		var nav: Dictionary = SceneManager.go_alchemy_panel()
		if not bool(nav.get("ok", false)):
			SceneManager.go_hub()
		return
	_start_progress()


func _apply_payload(payload: Dictionary) -> bool:
	_recipe_id = str(payload.get("recipe_id", "")).strip_edges()
	_strategy_id = str(payload.get("strategy_id", "")).strip_edges()
	_selection_mode = str(payload.get("selection_mode", "lowest"))
	_batch_count = maxi(1, int(payload.get("batch_count", 1)))
	_days = int(payload.get("days", 0))
	_days_per_batch = maxi(1, int(payload.get("days_per_batch", _days)))
	if _recipe_id == "" or _strategy_id == "" or _days <= 0:
		return false
	_start_day = int(payload.get("start_day", GameState.day))
	_recipe_name = str(payload.get("recipe_name", "丹方"))
	return true


func _start_progress() -> void:
	_elapsed = 0.0
	_running = true
	_speed_multiplier = 1.0
	_update_visuals(0.0)


func _process(delta: float) -> void:
	if not _running or _finishing:
		return
	_elapsed += delta * _speed_multiplier
	if _elapsed >= progress_duration:
		_elapsed = progress_duration
		_running = false
		_update_visuals(1.0)
		_finish_progress()
		return
	_update_visuals(_elapsed / progress_duration)


func _update_visuals(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	_progress_bar.value = ratio * 100.0
	var day_progress := ratio * float(_days)
	var current_day := clampi(int(day_progress) + 1, 1, _days)
	_day_label.text = "第 %d 日 / 共 %d 日" % [current_day, _days]
	var status_index := clampi(int(ratio * float(STATUS_TEXTS.size())), 0, STATUS_TEXTS.size() - 1)
	_status_label.text = STATUS_TEXTS[status_index]
	for index in _milestone_labels.size():
		var done := ratio >= float(index + 1) / float(_milestone_labels.size())
		_milestone_labels[index].text = "%s%s" % [MILESTONE_LABELS[index], " ✓" if done else ""]


func _on_cancel_pressed() -> void:
	if _finishing:
		return
	_running = false
	var nav: Dictionary = SceneManager.go_alchemy_panel()
	if not bool(nav.get("ok", false)):
		push_warning(str(nav.get("error", "无法返回炼丹界面")))


func _on_speed_pressed() -> void:
	if _finishing:
		return
	_speed_multiplier = 3.0


func _finish_progress() -> void:
	if _finishing:
		return
	_finishing = true
	_cancel_button.disabled = true
	_speed_button.disabled = true
	var result: Dictionary = GameState.brew_alchemy_batches(
		_recipe_id,
		_strategy_id,
		_selection_mode,
		_batch_count
	)
	if not bool(result.get("ok", false)):
		push_warning(str(result.get("error", "炼制失败")))
		var back_nav: Dictionary = SceneManager.go_alchemy_panel()
		if not bool(back_nav.get("ok", false)):
			SceneManager.go_hub()
		return
	result["recipe_name"] = _recipe_name
	result["start_day"] = _start_day
	var result_nav: Dictionary = SceneManager.go_alchemy_result(result)
	if not bool(result_nav.get("ok", false)):
		push_warning(str(result.get("error", "无法展示炼丹结果")))
		SceneManager.go_alchemy_panel()
		return
	TutorialService.game_event("tutorial.alchemy_result_shown")
