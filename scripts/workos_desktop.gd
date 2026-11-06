extends Control

signal exit_requested

const MUSIC_SCRIPT := preload("res://scripts/workos_music.gd")
const GAME_SCRIPT := preload("res://scripts/workos/game_state.gd")
const SOCIAL_SCRIPT := preload("res://scripts/workos/social_state.gd")
const APPS := preload("res://scripts/workos/apps.gd")
const SAVE_PATH := "user://workos.cfg"
const WALLPAPERS := ["cerejeira-luar", "deserto-por-do-sol", "espaco-terra", "farol-por-do-sol", "lago-primavera", "outono-dourado", "planeta-aneis", "praia-tropical"]
const TITLES := {"workday": "PORTAL_RH.EXE", "calendar": "CALENDÁRIO", "archive": "ARQUIVO", "messenger": "MSWORKN.EXE", "profile": "PERFIL", "backup": "BACKUP", "notes": "NOTAS.TXT", "calc": "CALCULADORA", "settings": "CONFIGURAÇÕES", "about": "WORKOS", "music": "MÚSICA"}
var music: Node
var game: Node
var social: Node
var notification: Label
var windows: Dictionary = {}
var tasks: Dictionary = {}
var settings := ConfigFile.new()
var save_timer: Timer
var clock_timer: Timer
var notes_editor: TextEdit
var current_app := ""

func _ready() -> void:
	settings.load(SAVE_PATH)
	game = GAME_SCRIPT.new()
	add_child(game)
	social = SOCIAL_SCRIPT.new()
	add_child(social)
	social.setup(game)
	notification = Label.new()
	notification.position = Vector2(350, 5)
	notification.size = Vector2(900, 42)
	notification.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification.add_theme_color_override("font_color", Color.WHITE)
	notification.add_theme_color_override("font_shadow_color", Color.BLACK)
	add_child(notification)
	game.notice.connect(func(message: String) -> void: notification.text = message)
	social.incoming.connect(func(npc: String, message: String) -> void: notification.text = str(game.data.cast[npc].name) + ": " + message)
	music = MUSIC_SCRIPT.new()
	add_child(music)
	music.configure(settings, SAVE_PATH)
	_set_wallpaper(str(settings.get_value("desktop", "wallpaper", "lago-primavera")), false)
	for icon in $Icons.get_children():
		icon.pressed.connect(open_app.bind(str(icon.get_meta("app"))))
	for button in $StartMenu/Items.get_children():
		if button is Button:
			button.pressed.connect(open_app.bind(str(button.get_meta("app"))))
	$Taskbar/Start.pressed.connect(func() -> void: $StartMenu.visible = not $StartMenu.visible)
	$Taskbar/Exit.pressed.connect(func() -> void: exit_requested.emit())
	$Wallpaper.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			$StartMenu.hide())
	save_timer = Timer.new()
	save_timer.wait_time = 0.4
	save_timer.one_shot = true
	save_timer.timeout.connect(_save_notes)
	add_child(save_timer)
	clock_timer = Timer.new()
	clock_timer.wait_time = 0.25
	clock_timer.timeout.connect(_update_clock)
	add_child(clock_timer)
	clock_timer.start()
	_update_clock()

func _update_clock() -> void:
	$Taskbar/Clock.text = "%s  ·  %s" % [game.clock.text(), game.clock.date_text()]

func open_app(id: String) -> void:
	if not TITLES.has(id): return
	if id != "workday" and game.career.get("phase", "") == "day": game.paused = true
	$StartMenu.hide()
	if windows.has(id):
		windows[id].show()
		_focus(id)
		return
	var window: PanelContainer = preload("res://scenes/workos/window.tscn").instantiate()
	$Windows.add_child(window)
	window.configure(TITLES[id])
	if id == "music": window.size = Vector2(660, 560)
	if id in ["calendar", "archive", "messenger"]: window.size = Vector2(920, 600)
	if id == "workday": window.size = Vector2(1220, 640)
	window.position = Vector2(300, 75) + Vector2(28, 24) * windows.size()
	window.position = window.position.clamp(Vector2.ZERO, $Windows.size - window.size)
	windows[id] = window
	window.activated.connect(_focus.bind(id))
	window.closed.connect(_close.bind(id))
	window.minimized.connect(_minimize.bind(id))
	var task := Button.new()
	task.text = TITLES[id]
	task.custom_minimum_size = Vector2(105, 38)
	task.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	task.tooltip_text = TITLES[id]
	task.toggle_mode = true
	$Taskbar/Tasks.add_child(task)
	tasks[id] = task
	task.pressed.connect(func() -> void:
		if window.visible and current_app == id:
			window.hide()
			_minimize(id)
		else:
			window.show()
			_focus(id))
	var app: Control = load("res://scenes/workos/apps/%s.tscn" % id).instantiate()
	window.content.add_child(app)
	match id:
		"workday": app.setup(game, self)
		"calendar": APPS.calendar(app, game)
		"archive": APPS.archive(app, game)
		"messenger": APPS.messenger(app, social)
		"profile": APPS.profile(app, game)
		"backup": APPS.backup(app, game)
		"notes": _build_notes(app)
		"calc": _build_calculator(app)
		"settings": _build_settings(app)
		"music": music.build_ui(app)

	_focus(id)

func _focus(id: String) -> void:
	if not windows.has(id): return
	current_app = id
	$Windows.move_child(windows[id], -1)
	for key in tasks:
		tasks[key].set_pressed_no_signal(key == id and windows[key].visible)

func _minimize(id: String) -> void:
	if id == "workday": game.paused = true
	tasks[id].set_pressed_no_signal(false)
	if current_app == id: current_app = ""

func _close(id: String) -> void:
	if id == "workday":
		game.paused = true
		game.save_game()
	if id == "notes":
		_save_notes()
		notes_editor = null
	windows.erase(id)
	tasks[id].queue_free()
	tasks.erase(id)
	if current_app == id: current_app = ""

func _build_notes(parent: Control) -> void:
	notes_editor = parent.get_node("Editor")
	notes_editor.text = str(settings.get_value("notes", "text", ""))
	notes_editor.text_changed.connect(func() -> void: save_timer.start())
	notes_editor.grab_focus()

func _save_notes() -> void:
	if is_instance_valid(notes_editor):
		settings.set_value("notes", "text", notes_editor.text)
		settings.save(SAVE_PATH)

func _exit_tree() -> void:
	_save_notes()

func _build_calculator(parent: Control) -> void:
	var display: LineEdit = parent.get_node("Display")
	display.text_submitted.connect(func(_text: String) -> void: _calculate(display))
	for button in parent.get_node("Keys").get_children():
		button.pressed.connect(_calculator_key.bind(button.text, display))

func _calculator_key(key: String, display: LineEdit) -> void:
	match key:
		"C": display.text = ""
		"⌫": display.text = display.text.left(-1)
		"=": _calculate(display)
		_: display.text += key

func _calculate(display: LineEdit) -> void:
	for character in display.text:
		if not character in "0123456789.+-*/() ":
			display.text = "Erro"
			return
	var expression := Expression.new()
	if expression.parse(display.text) != OK:
		display.text = "Erro"
		return
	var result: Variant = expression.execute([], null, false)
	display.text = "Erro" if expression.has_execute_failed() else str(result)

func _build_settings(parent: Control) -> void:
	var options: OptionButton = parent.get_node("Wallpapers")
	for wall in WALLPAPERS: options.add_item(wall.replace("-", " ").capitalize())
	options.selected = maxi(0, WALLPAPERS.find(str(settings.get_value("desktop", "wallpaper", "lago-primavera"))))
	options.item_selected.connect(func(index: int) -> void: _set_wallpaper(WALLPAPERS[index]))
	var preview: TextureRect = parent.get_node("Preview")
	preview.texture = $Wallpaper.texture
	options.item_selected.connect(func(_index: int) -> void: preview.texture = $Wallpaper.texture)

func _set_wallpaper(id: String, persist := true) -> void:
	if not id in WALLPAPERS: id = "lago-primavera"
	$Wallpaper.texture = load("res://assets/ui/workos/wallpapers/%s.png" % id)
	if persist:
		settings.set_value("desktop", "wallpaper", id)
		settings.save(SAVE_PATH)

func dismiss_menu() -> bool:
	if $StartMenu.visible:
		$StartMenu.hide()
		return true
	if current_app == "workday" and game.career.get("phase", "") == "day" and not game.paused:
		if game.events.has("boss"): game.dodge_boss()
		else: game.paused = true
		return true
	return false

func set_monitor_focus(value: bool) -> void:
	game.set_focus(value)

func suspend_input() -> void:
	game.set_focus(false)
	_save_notes()
	$StartMenu.hide()
	for window in windows.values(): window.dragging = false
	get_viewport().gui_release_focus()
