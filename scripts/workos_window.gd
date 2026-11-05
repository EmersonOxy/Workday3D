extends PanelContainer

signal closed
signal minimized
signal activated

var dragging := false
var maximized := false
var drag_offset := Vector2.ZERO
var restore_rect := Rect2()
var content: VBoxContainer
var title_label: Label
var title_bar: Panel

func configure(title: String) -> void:
	content = $Column/Paper/Content
	title_bar = $Column/TitleBar
	title_label = $Column/TitleBar/Title
	title_label.text = title
	for action in {"Minimize": "min", "Maximize": "max", "Close": "close"}:
		$Column/TitleBar/Controls.get_node(action).pressed.connect(_action.bind({"Minimize": "min", "Maximize": "max", "Close": "close"}[action]))
	title_bar.gui_input.connect(_title_input)
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed: activated.emit())

func _title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		activated.emit()
		if event.double_click and event.pressed:
			_action("max")
			return
		dragging = event.pressed and not maximized
		drag_offset = get_global_mouse_position() - global_position
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		var next := get_global_mouse_position() - drag_offset
		position = Vector2(clampf(next.x, 0, maxf(0, get_parent_control().size.x - size.x)), clampf(next.y, 0, maxf(0, get_parent_control().size.y - size.y)))
		accept_event()

func _action(action: String) -> void:
	match action:
		"close":
			closed.emit()
			queue_free()
		"min":
			hide()
			minimized.emit()
		"max":
			if maximized:
				position = restore_rect.position
				size = restore_rect.size
			else:
				restore_rect = Rect2(position, size)
				position = Vector2.ZERO
				size = get_parent_control().size
			maximized = not maximized
			activated.emit()
