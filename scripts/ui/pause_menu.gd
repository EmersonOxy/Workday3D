extends CanvasLayer
## Menu de pausa do mundo 3D (Esc fora do PC): continuar, configurações e sair.
## As preferências ficam no mesmo user://workos.cfg do WorkOS, então mudar aqui ou nas Configurações do PC dá no mesmo.

signal closed

const WORLD_EFFECTS := ["off", "psx", "vhs", "psx_vhs"]
const WORLD_EFFECT_NAMES := ["Desligado", "PSX", "VHS", "PSX + VHS"]

var host: Node3D
var desktop: Control
var panel: PanelContainer
var body: VBoxContainer

func setup(main_scene: Node3D) -> void:
	host = main_scene
	desktop = host.desktop
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.07, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.theme = preload("res://scripts/workos/os_style.gd").theme()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1d2433")
	style.border_color = Color("#f1d9b5")
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_theme_color_override("font_color", Color("#f1d9b5"))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)
	_apply_saved()
	hide()

func open() -> void:
	_render_main()
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()

func _clear() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()

func _title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color("#f1d9b5"))
	body.add_child(label)

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 42)
	button.pressed.connect(callback)
	body.add_child(button)
	return button

func _row(text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color("#f1d9b5"))
	row.add_child(label)
	control.custom_minimum_size.x = 200
	row.add_child(control)
	body.add_child(row)

func _render_main() -> void:
	_clear()
	_title("PAUSA")
	_button("Continuar", close).grab_focus()
	_button("Configurações", _render_settings)
	_button("Sair do jogo", func() -> void: get_tree().quit())

func _render_settings() -> void:
	_clear()
	_title("CONFIGURAÇÕES")
	var effects := OptionButton.new()
	for effect_name in WORLD_EFFECT_NAMES: effects.add_item(effect_name)
	effects.selected = maxi(0, WORLD_EFFECTS.find(desktop.video_world()))
	_row("Efeito de vídeo", effects)
	var crt := CheckBox.new()
	crt.button_pressed = desktop.video_crt()
	_row("Tela CRT no monitor", crt)
	effects.item_selected.connect(func(index: int) -> void: desktop._set_video(WORLD_EFFECTS[index], crt.button_pressed))
	crt.toggled.connect(func(on: bool) -> void: desktop._set_video(WORLD_EFFECTS[effects.selected], on))
	var fullscreen := CheckBox.new()
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(on: bool) -> void: _set_pref("video", "fullscreen", on); _apply_fullscreen(on))
	_row("Tela cheia", fullscreen)
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = float(desktop.settings.get_value("audio", "master", 1.0))
	volume.value_changed.connect(func(value: float) -> void: _set_pref("audio", "master", value); _apply_volume(value))
	_row("Volume geral", volume)
	var music := HSlider.new()
	music.min_value = 0.0
	music.max_value = 1.0
	music.step = 0.05
	music.value = desktop.music.volume
	music.value_changed.connect(func(value: float) -> void: desktop.music.set_volume(value); desktop.music._save())
	_row("Música", music)
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.0005
	sensitivity.max_value = 0.006
	sensitivity.step = 0.0001
	sensitivity.value = host.mouse_sensitivity
	sensitivity.value_changed.connect(func(value: float) -> void: _set_pref("input", "mouse_sensitivity", value); host.mouse_sensitivity = value)
	_row("Sensibilidade do mouse", sensitivity)
	_button("Voltar", _render_main)

func _set_pref(section: String, key: String, value: Variant) -> void:
	desktop.settings.set_value(section, key, value)
	desktop.settings.save(desktop.SAVE_PATH)

func _apply_saved() -> void:
	_apply_volume(float(desktop.settings.get_value("audio", "master", 1.0)))
	host.mouse_sensitivity = float(desktop.settings.get_value("input", "mouse_sensitivity", host.mouse_sensitivity))
	if bool(desktop.settings.get_value("video", "fullscreen", false)): _apply_fullscreen(true)

func _apply_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.0001)))

func _apply_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
