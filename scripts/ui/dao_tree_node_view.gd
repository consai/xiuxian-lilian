class_name DaoTreeNodeView
extends PanelContainer

signal pressed(skill_id: String)
signal double_pressed(skill_id: String)

@onready var _title: Label = $VBox/Title
@onready var _rank: Label = $VBox/Rank

var skill_id: String = ""

var _press_time := 0.0
var _last_click := 0.0


func _ready() -> void:
	gui_input.connect(_on_gui_input)


func bind(skill: Dictionary, state: int, effective_level: float, marked: bool) -> void:
	skill_id = str(skill.get("id", ""))
	_title.text = str(skill.get("name", ""))
	if effective_level >= 1.0:
		_rank.text = _roman_level(maxi(1, int(floor(effective_level))))
	elif state == EnumDaoNodeState.State.LOCKED:
		_rank.text = "未解锁"
	else:
		_rank.text = "—"
	_apply_state(state, marked)


func _apply_state(state: int, marked: bool) -> void:
	match state:
		EnumDaoNodeState.State.LEARNED:
			modulate = Color(0.65, 0.7, 0.53, 0.96)
		EnumDaoNodeState.State.GROWING:
			modulate = Color(0.55, 0.72, 0.68, 0.96)
		EnumDaoNodeState.State.AVAILABLE:
			modulate = Color(0.97, 0.91, 0.78, 0.96)
		_:
			modulate = Color(0.68, 0.64, 0.55, 0.78)
	tooltip_text = "标记目标" if marked else ""


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
			return
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_click < 0.35:
			double_pressed.emit(skill_id)
		else:
			pressed.emit(skill_id)
		_last_click = now


static func _roman_level(level: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(level, 0, 5)]
