extends HBoxContainer

const TupoServiceScript := preload("res://scripts/sim/tupo_service.gd")
const HoverTipPayloadScript := preload("res://scripts/ui/hover/hover_tip_payload.gd")

@onready var _name_label: Label = %Name
@onready var _value_label: Label = %Value
@onready var _help: BaseButton = %Help
@onready var _hover_tip: HoverTipSource = %HoverTipSource

var _sources: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.mouse_filter = Control.MOUSE_FILTER_STOP
	if _hover_tip == null:
		push_error("TupoValueRow 缺少 Help/HoverTipSource")
		return
	call_deferred("_sync_hover_payload")


func bind(value: int, sources: Array) -> void:
	_sources = sources.duplicate(true)
	_value_label.text = str(value)
	call_deferred("_sync_hover_payload")


func _sync_hover_payload() -> void:
	if _hover_tip == null:
		return
	var payload := _build_tip_payload()
	_hover_tip.set_payload(payload)
	_hover_tip.enabled = not HoverTipPayloadScript.is_empty(payload)


func _build_tip_payload() -> Dictionary:
	return TupoServiceScript.make_component_tip_payload(_name_label.text, _sources)
