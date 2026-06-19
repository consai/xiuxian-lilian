extends Control

const STAGE_TEXTS := [
	"第一周天 · 引气入体",
	"第二周天 · 气息渐稳",
	"第三周天 · 周天将成",
]

const MODE_STAGE_TITLES := {
	"cycle": "灵气沿经脉运转",
	"insight": "沉入功法参悟",
	"breathing": "吸纳洞府灵气",
}

const QI_RING_BREATH := [
	{"period": 3.4, "phase": 0.0, "min_scale": 0.94, "max_scale": 1.06, "min_alpha": 0.72},
	{"period": 2.8, "phase": 0.22, "min_scale": 0.95, "max_scale": 1.07, "min_alpha": 0.78},
	{"period": 2.2, "phase": 0.45, "min_scale": 0.96, "max_scale": 1.08, "min_alpha": 0.84},
]

@export var progress_duration := 3.0

@onready var _qi_rings: Array[Panel] = [$OuterQiRing, $MiddleQiRing, $InnerQiRing]
@onready var _method_label: Label = %MethodLabel
@onready var _day_label: Label = %DayLabel
@onready var _stage_title: Label = %StageTitle
@onready var _status_label: Label = %StatusLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _skip_button: Button = %SkipButton
@onready var _result_popup: CultivationResultPopup = %ResultPopup

var _mode_id := "cycle"
var _days := 1
var _start_day := 1
var _method_name := ""
var _mode_name := ""
var _pill_id := ""
var _running := false
var _finishing := false
var _elapsed := 0.0
var _breath_time := 0.0


func _ready() -> void:
	_setup_qi_ring_pivots()
	_skip_button.pressed.connect(_on_skip_pressed)
	_result_popup.confirmed.connect(_on_result_confirmed)
	var payload: Dictionary = SceneManager.take_payload(SceneManager.CULTIVATION_PROGRESS)
	if not _apply_payload(payload):
		var nav: Dictionary = SceneManager.go_cultivation_panel()
		if not bool(nav.get("ok", false)):
			SceneManager.go_hub()
		return
	_bind_header()
	_start_progress()


func _apply_payload(payload: Dictionary) -> bool:
	_mode_id = str(payload.get("mode_id", "")).strip_edges()
	_days = int(payload.get("days", 0))
	if _mode_id == "" or _days <= 0:
		return false
	_start_day = int(payload.get("start_day", GameState.day))
	_method_name = str(payload.get("method_name", "主功法"))
	_mode_name = str(payload.get("mode_name", "运转周天"))
	_pill_id = str(payload.get("pill_id", ""))
	return true


func _bind_header() -> void:
	_method_label.text = "%s\n%s" % [_method_name, _mode_name]
	_stage_title.text = str(MODE_STAGE_TITLES.get(_mode_id, MODE_STAGE_TITLES["cycle"]))


func _setup_qi_ring_pivots() -> void:
	for ring in _qi_rings:
		if ring == null:
			continue
		ring.pivot_offset = ring.size * 0.5


func _update_qi_ring_breath(delta: float) -> void:
	_breath_time += delta
	for index in _qi_rings.size():
		var ring := _qi_rings[index]
		if ring == null or index >= QI_RING_BREATH.size():
			continue
		var cfg: Dictionary = QI_RING_BREATH[index]
		var wave := (sin((_breath_time / float(cfg["period"]) + float(cfg["phase"])) * TAU) + 1.0) * 0.5
		var scale_value := lerpf(float(cfg["min_scale"]), float(cfg["max_scale"]), wave)
		ring.scale = Vector2.ONE * scale_value
		var alpha := lerpf(float(cfg["min_alpha"]), 1.0, wave)
		ring.modulate = Color(ring.modulate.r, ring.modulate.g, ring.modulate.b, alpha)


func _start_progress() -> void:
	_elapsed = 0.0
	_running = true
	_update_visuals(0.0)


func _process(delta: float) -> void:
	_update_qi_ring_breath(delta)
	if not _running or _finishing:
		return
	_elapsed += delta
	if _elapsed >= progress_duration:
		_elapsed = progress_duration
		_running = false
		_update_visuals(1.0)
		_finish_progress()
		return
	_update_visuals(_elapsed / progress_duration)


func _update_visuals(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	var percent := ratio * 100.0
	_progress_bar.value = percent
	_progress_label.text = "%d%%" % int(round(percent))
	if is_equal_approx(ratio, 1.0):
		_day_label.text = "闭关 %s / %s\n%s" % [
			GameState.time_duration_label(_days),
			GameState.time_duration_label(_days),
			GameState.time_date_label(_start_day + _days - 1),
		]
		_status_label.text = "周天圆满 · 功行已成"
		return
	var day_progress := ratio * float(_days)
	var current_day := clampi(int(day_progress) + 1, 1, _days)
	var within_day: float = day_progress - floor(day_progress)
	var cycle_index := clampi(int(within_day * float(STAGE_TEXTS.size())), 0, STAGE_TEXTS.size() - 1)
	_day_label.text = "闭关 %s / %s\n%s" % [
		GameState.time_duration_label(current_day),
		GameState.time_duration_label(_days),
		GameState.time_date_label(_start_day + current_day - 1),
	]
	_status_label.text = STAGE_TEXTS[cycle_index]


func _on_skip_pressed() -> void:
	if _finishing:
		return
	_running = false
	_elapsed = progress_duration
	_update_visuals(1.0)
	_finish_progress()


func _finish_progress() -> void:
	if _finishing:
		return
	_finishing = true
	_skip_button.disabled = true
	var result: Dictionary = GameState.cultivate_session(_mode_id, _days, _pill_id)
	if not bool(result.get("ok", false)):
		push_warning(str(result.get("error", "修炼失败")))
		SceneManager.go_cultivation_panel()
		return
	_result_popup.show_result(result)
	TutorialService.game_event("tutorial.cultivation_result_shown")


func _on_result_confirmed() -> void:
	TutorialService.game_event("tutorial.cultivation_completed")
	var nav: Dictionary = SceneManager.go_hub()
	if not bool(nav.get("ok", false)):
		push_warning(str(nav.get("error", "无法返回洞府")))
