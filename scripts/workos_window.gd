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
	custom_minimum_size = Vector2(360, 240)
	size = Vector2(580, 450)
	var frame := StyleBoxTexture.new()
	frame.texture = load("res://assets/ui/workos/window-chrome-frame.png")
	frame.texture_margin_left = 10
	frame.texture_margin_right = 10
	frame.texture_margin_top = 9
	frame.texture_margin_bottom = 14
	add_theme_stylebox_override("panel", frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	title_bar = Panel.new()
	title_bar.custom_minimum_size.y = 40
	var title_style := StyleBoxTexture.new()
	title_style.texture = load("res://assets/ui/workos/window-chrome-title.png")
	title_bar.add_theme_stylebox_override("panel", title_style)
	column.add_child(title_bar)
	title_label = Label.new()
	title_label.text = title
	title_label.position = Vector2(12, 3)
	title_label.add_theme_color_override("font_color", Color("fff8ec"))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bar.add_child(title_label)
	var controls := HBoxContainer.new()
	title_bar.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	controls.offset_left = -108
	controls.offset_right = -4
	controls.offset_top = 4
	controls.offset_bottom = 35
	controls.add_theme_constant_override("separation", 4)
	for action in ["min", "max", "close"]:
		var button := TextureButton.new()
		button.texture_normal = load("res://assets/ui/workos/window-chrome-%s.png" % action)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.custom_minimum_size = Vector2(31, 31)
		button.tooltip_text = {"min": "Minimizar", "max": "Maximizar / restaurar", "close": "Fechar"}[action]
		controls.add_child(button)
		button.pressed.connect(_action.bind(action))
	var paper := PanelContainer.new()
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var paper_style := StyleBoxTexture.new()
	paper_style.texture = load("res://assets/ui/workos/window-paper.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		paper_style.set_content_margin(side, 16)
	paper.add_theme_stylebox_override("panel", paper_style)
	column.add_child(paper)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	paper.add_child(content)
	title_bar.gui_input.connect(_title_input)
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			activated.emit())

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
