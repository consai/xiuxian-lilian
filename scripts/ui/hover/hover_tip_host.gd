extends CanvasLayer

## 全局 Hover Tip 宿主：管理单例浮层，供任意 [HoverTipSource] 调用。

const HoverTipPanelScene := preload("res://scenes/ui/hover_tip_panel.tscn")

var _panel: HoverTipPanel
var _active_source: Control
var _pending_payload: Dictionary = {}
var _show_token: int = 0
var _show_delay_timer: Timer
var _hide_delay_timer: Timer


func _ready() -> void:
	layer = 1001
	follow_viewport_enabled = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = HoverTipPanelScene.instantiate() as HoverTipPanel
	add_child(_panel)
	_show_delay_timer = _make_delay_timer()
	_hide_delay_timer = _make_delay_timer()
	add_child(_show_delay_timer)
	add_child(_hide_delay_timer)


func _make_delay_timer() -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	return timer


func _clear_delay_timers() -> void:
	_show_delay_timer.stop()
	_hide_delay_timer.stop()


func show_for(source: Control, payload: Dictionary, delay_ms: int = 280) -> void:
	if source == null or not is_instance_valid(source):
		return
	if HoverTipPayload.is_empty(payload):
		hide_for(source)
		return
	_show_token += 1
	var token := _show_token
	_active_source = source
	_pending_payload = payload
	_clear_delay_timers()
	if delay_ms <= 0:
		_present_now(token)
		return
	_show_delay_timer.wait_time = float(delay_ms) / 1000.0
	_show_delay_timer.start()
	await _show_delay_timer.timeout
	if token != _show_token or _active_source != source:
		return
	if not is_instance_valid(source):
		return
	_present_now(token)


func hide_for(source: Control, delay_ms: int = 80) -> void:
	if source == null:
		return
	if _active_source != source:
		return
	_show_token += 1
	var token := _show_token
	_clear_delay_timers()
	if delay_ms <= 0:
		_hide_now(token)
		return
	_hide_delay_timer.wait_time = float(delay_ms) / 1000.0
	_hide_delay_timer.start()
	await _hide_delay_timer.timeout
	if token != _show_token:
		return
	if _active_source != source:
		return
	if not is_instance_valid(source):
		return
	if _source_still_hovered(source):
		return
	_hide_now(token)


func hide_immediate() -> void:
	_show_token += 1
	_active_source = null
	_pending_payload = {}
	_clear_delay_timers()
	if _panel != null:
		_panel.hide_immediate()


func _present_now(token: int) -> void:
	if token != _show_token or _panel == null or _active_source == null:
		return
	if not is_instance_valid(_active_source):
		return
	_panel.apply_payload(_pending_payload)
	await _panel.show_at_anchor(_active_source, token, Callable(self, "_is_show_token_active"))
	# 内容已展示，清空悬停延迟计时，避免过期回调干扰
	if token == _show_token:
		_clear_delay_timers()


func _is_show_token_active(token: int) -> bool:
	return token == _show_token and _active_source != null and is_instance_valid(_active_source)


func _hide_now(token: int) -> void:
	if token != _show_token:
		return
	_active_source = null
	_pending_payload = {}
	if _panel != null:
		_panel.hide_immediate()


func _source_still_hovered(source: Control) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	var vp := source.get_viewport()
	if vp == null:
		return false
	var hovered: Control = vp.gui_get_hovered_control()
	if hovered == null:
		return source.get_global_rect().has_point(source.get_global_mouse_position())
	return hovered == source or source.is_ancestor_of(hovered)
