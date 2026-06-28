class_name LilianDituJiedianView
extends Button

signal node_selected(node_id: String)

const EnumLilianNodeTypeScript := preload("res://scripts/enum/enum_lilian_node_type.gd")

var node_id := ""


func setup(node: Dictionary, state: String) -> void:
	node_id = str(node.get("id", ""))
	text = "%s\n%s" % [
		EnumLilianNodeTypeScript.label(str(node.get("type", ""))),
		str(node.get("risk_text", "")),
	]
	disabled = state != "available" and state != "pending_battle"
	tooltip_text = "%s · 难度 %d" % [str(node.get("label", "")), int(node.get("difficulty", 1))]
	match state:
		"visited":
			modulate = Color(0.72, 0.78, 0.62, 1.0)
		"available":
			modulate = Color(1.0, 0.94, 0.62, 1.0)
		"current":
			modulate = Color(0.98, 0.76, 0.42, 1.0)
		"pending_battle":
			# 战前弹窗关闭后：当前遭遇节点可再次点击打开弹窗
			modulate = Color(0.98, 0.76, 0.42, 1.0)
			tooltip_text = "%s · 点此迎战" % tooltip_text
		_:
			modulate = Color(0.82, 0.78, 0.70, 1.0)


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	node_selected.emit(node_id)
