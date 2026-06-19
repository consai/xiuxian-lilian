extends Control

signal closed(message: String)
signal loaded(slot: int)

@export var load_only := false


func _ready() -> void:
	%CloseButton.pressed.connect(_on_close_pressed)
	%Slot1SaveButton.disabled = true
	%Slot2SaveButton.pressed.connect(_on_save_pressed.bind(2))
	%Slot3SaveButton.pressed.connect(_on_save_pressed.bind(3))
	%Slot1LoadButton.pressed.connect(_on_load_pressed.bind(1))
	%Slot2LoadButton.pressed.connect(_on_load_pressed.bind(2))
	%Slot3LoadButton.pressed.connect(_on_load_pressed.bind(3))
	_apply_mode()


func _apply_mode() -> void:
	if not load_only:
		return
	%Title.text = "读取存档"
	%Slot1SaveButton.visible = false
	%Slot2SaveButton.visible = false
	%Slot3SaveButton.visible = false


func refresh() -> void:
	var active := GameState.active_save_slot
	%Slot1SaveButton.disabled = true
	_refresh_slot(1, %Slot1Label, %Slot1LoadButton, active, true)
	_refresh_slot(2, %Slot2Label, %Slot2LoadButton, active)
	_refresh_slot(3, %Slot3Label, %Slot3LoadButton, active)


func _refresh_slot(
	slot: int,
	label: Label,
	load_button: Button,
	active_slot: int,
	auto_save: bool = false,
) -> void:
	var prefix := "自动存档" if auto_save else "槽位 %d" % slot
	var info: Dictionary = SaveService.slot_info(slot)
	if bool(info.get("ok", false)):
		label.text = "%s：%s · %s · 修为 %d" % [
			prefix,
			GameState.time_date_label(int(info.get("day", 1))),
			str(info.get("realm_name", "未知")),
			int(info.get("cultivation", 0)),
		]
		load_button.disabled = false
	else:
		label.text = "%s：空" % prefix
		load_button.disabled = true
	if active_slot == slot:
		label.text += "（当前）"


func _on_save_pressed(slot: int) -> void:
	if slot == SaveService.AUTO_SAVE_SLOT:
		closed.emit("槽位 1 为自动存档，历练完成后会自动写入。")
		return
	var result: Dictionary = GameState.save_game(slot)
	if bool(result.get("ok", false)):
		refresh()
		closed.emit("已存入槽位 %d。" % slot)
	else:
		closed.emit(str(result.get("error", "存档失败")))


func _on_load_pressed(slot: int) -> void:
	var result: Dictionary = GameState.load_game(slot)
	if bool(result.get("ok", false)):
		refresh()
		loaded.emit(slot)
		closed.emit("已读档：槽位 %d。" % slot)
		visible = false
	else:
		closed.emit(str(result.get("error", "读档失败")))


func _on_close_pressed() -> void:
	visible = false
	closed.emit("")
