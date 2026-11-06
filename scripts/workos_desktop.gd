extends Control
## Área de trabalho do WorkOS (porte de osIcons/osStart/osTaskBtn/osWindow de 09-telas.js e do CSS 80-entrega3/
## 99-workos-materials): ícones em pixel art, barra de tarefas com orbe do Iniciar, botões por janela, relógio,
## menu Iniciar em duas colunas (XP com Windows 7) e avisos no canto. Tudo montado em código; os aplicativos
## continuam nas cenas de scenes/workos/apps/.

signal exit_requested
signal video_changed(world: String, crt: bool)

const MUSIC_SCRIPT := preload("res://scripts/workos_music.gd")
const GAME_SCRIPT := preload("res://scripts/workos/game_state.gd")
const SOCIAL_SCRIPT := preload("res://scripts/workos/social_state.gd")
const EFFECTS_SCRIPT := preload("res://scripts/workos/effects.gd")
const WINDOW_SCRIPT := preload("res://scripts/workos/os_window.gd")
const APPS := preload("res://scripts/workos/apps.gd")
const PIXEL := preload("res://scripts/workos/pixel.gd")
const STYLE := preload("res://scripts/workos/os_style.gd")
const SAVE_PATH := "user://workos.cfg"
const WORLD_EFFECTS := ["off", "psx", "vhs", "psx_vhs"]
const WORLD_EFFECT_NAMES := ["Desligado", "PSX", "VHS", "PSX + VHS"]
const WALLPAPERS := ["xadrez-workos", "cerejeira-luar", "deserto-por-do-sol", "espaco-terra", "farol-por-do-sol", "lago-primavera", "outono-dourado", "planeta-aneis", "praia-tropical"]
const TASKBAR_HEIGHT := 46
## Nome na barra de título (como os .EXE do original) e rótulo do ícone na área de trabalho.
const APP_INFO := {
	"workday": ["PORTAL_RH.EXE", "PORTAL_RH.EXE"],
	"calendar": ["CALENDARIO.EXE", "Calendário"],
	"calc": ["CALCULADORA.EXE", "Calculadora"],
	"notes": ["NOTAS.TXT", "Bloco de notas"],
	"music": ["RADIO.EXE", "Rádio"],
	"settings": ["PERSONALIZAR.EXE", "Personalizar"],
	"profile": ["PERFIL.EXE", "Perfil"],
	"archive": ["ARQUIVO.EXE", "Arquivo"],
	"messenger": ["MSWORKN.EXE", "MSWORKN.EXE"],
	"backup": ["BACKUP.EXE", "Backup"],
	"about": ["SOBRE.TXT", "Sobre o WorkOS"],
}
const DESKTOP_ICONS := ["workday", "calendar", "calc", "notes", "music", "settings", "profile", "archive", "messenger"]
const WINDOW_SIZES := {"workday": Vector2(1080, 620), "calendar": Vector2(900, 600), "archive": Vector2(900, 600), "messenger": Vector2(900, 600),
	"music": Vector2(640, 540), "calc": Vector2(380, 520), "notes": Vector2(620, 480), "settings": Vector2(620, 560), "profile": Vector2(640, 560),
	"backup": Vector2(620, 460), "about": Vector2(560, 420)}

var music: Node
var game: Node
var social: Node
var fx: Node
var settings := ConfigFile.new()
var windows: Dictionary = {}
var tasks: Dictionary = {}
var current_app := ""
var notes_editor: TextEdit
var save_timer: Timer
var clock_timer: Timer
var wallpaper: TextureRect
var icon_layer: Control
var icon_buttons: Dictionary = {}
var window_layer: Control
var taskbar: Control
var task_row: HBoxContainer
var start_button: TextureButton
var start_menu: Control
var clock_label: Label
var toast_layer: VBoxContainer

func _ready() -> void:
	theme = STYLE.theme()
	settings.load(SAVE_PATH)
	game = GAME_SCRIPT.new()
	add_child(game)
	social = SOCIAL_SCRIPT.new()
	add_child(social)
	social.setup(game)
	fx = EFFECTS_SCRIPT.new()
	add_child(fx)
	music = MUSIC_SCRIPT.new()
	add_child(music)
	music.configure(settings, SAVE_PATH)
	for child in get_children():
		if child is CanvasItem and not child in [game, social, fx, music]: child.queue_free()
	_build_wallpaper()
	_build_icons()
	window_layer = Control.new()
	window_layer.name = "Windows"
	window_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window_layer.offset_bottom = -TASKBAR_HEIGHT
	window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(window_layer)
	_build_toasts()
	_build_taskbar()
	_build_start_menu()
	_set_wallpaper(str(settings.get_value("desktop", "wallpaper", "xadrez-workos")), false)
	game.notice.connect(func(message: String) -> void: toast("WorkOS", message))
	social.incoming.connect(func(npc: String, message: String) -> void:
		toast("MSworkN · " + str(game.data.cast[npc].name), message, "messenger")
		_refresh_badges())
	social.changed.connect(_refresh_badges)
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
	_refresh_badges()
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed: _close_start_menu())

# ---------------------------------------------------------------- Papel de parede

func _build_wallpaper() -> void:
	wallpaper = TextureRect.new()
	wallpaper.name = "Wallpaper"
	wallpaper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallpaper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wallpaper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wallpaper)

## Fundo padrão do WorkOS no HTML: xadrez verde-petróleo discreto.
func _checker_texture() -> Texture2D:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color("1f4a52"))
	image.fill_rect(Rect2i(0, 0, 8, 8), Color("234f57"))
	image.fill_rect(Rect2i(8, 8, 8, 8), Color("234f57"))
	return ImageTexture.create_from_image(image)

func _set_wallpaper(id: String, persist := true) -> void:
	if not id in WALLPAPERS: id = "xadrez-workos"
	if id == "xadrez-workos":
		wallpaper.texture = _checker_texture()
		wallpaper.stretch_mode = TextureRect.STRETCH_TILE
	else:
		wallpaper.texture = load("res://assets/ui/workos/wallpapers/%s.png" % id)
		wallpaper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if persist:
		settings.set_value("desktop", "wallpaper", id)
		settings.save(SAVE_PATH)

# ---------------------------------------------------------------- Ícones

func _build_icons() -> void:
	icon_layer = Control.new()
	icon_layer.name = "Icons"
	icon_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_layer.offset_bottom = -TASKBAR_HEIGHT
	icon_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_layer)
	var per_column := 7
	for index in DESKTOP_ICONS.size():
		var id: String = DESKTOP_ICONS[index]
		var tile := Button.new()
		tile.name = id
		tile.flat = true
		tile.focus_mode = Control.FOCUS_NONE
		tile.position = Vector2(14 + (index / per_column) * 108, 12 + (index % per_column) * 88)
		tile.size = Vector2(104, 84)
		for state in ["normal", "hover", "pressed", "focus"]: tile.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var icon := TextureRect.new()
		icon.texture = PIXEL.app_icon(id, 3)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position = Vector2((104 - 36) / 2.0, 2)
		icon.size = Vector2(36, 36)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(icon)
		var caption := Label.new()
		caption.name = "Caption"
		caption.text = APP_INFO[id][1]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.position = Vector2(0, 42)
		caption.size = Vector2(104, 40)
		caption.add_theme_font_size_override("font_size", 17)
		caption.add_theme_color_override("font_color", STYLE.PAPER)
		caption.add_theme_color_override("font_shadow_color", STYLE.INK)
		caption.add_theme_constant_override("shadow_offset_x", 0)
		caption.add_theme_constant_override("shadow_offset_y", 2)
		caption.add_theme_constant_override("line_spacing", -4)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(caption)
		var badge := Label.new()
		badge.name = "Badge"
		badge.visible = false
		badge.position = Vector2(70, 0)
		badge.add_theme_font_size_override("font_size", 15)
		badge.add_theme_color_override("font_color", STYLE.PAPER)
		badge.add_theme_stylebox_override("normal", STYLE.flat(Color("ef4b3f"), STYLE.INK, 1, 2))
		tile.add_child(badge)
		# Um clique abre (como no HTML); a legenda fica destacada enquanto o mouse está em cima.
		tile.mouse_entered.connect(func() -> void: caption.add_theme_stylebox_override("normal", STYLE.flat(Color(STYLE.BLUE, 0.85), STYLE.INK, 1, 1)))
		tile.mouse_exited.connect(func() -> void: caption.remove_theme_stylebox_override("normal"))
		tile.pressed.connect(func() -> void:
			fx.sound("click")
			open_app(id))
		icon_layer.add_child(tile)
		icon_buttons[id] = tile

func _refresh_badges() -> void:
	var unread := 0
	if social.get("state") is Dictionary and social.state.has("contacts"):
		for contact in social.state.contacts.values():
			unread += int(contact.get("unread", 0)) + (1 if contact.get("status", "") == "request" else 0)
	if icon_buttons.has("messenger"):
		var badge: Label = icon_buttons.messenger.get_node("Badge")
		badge.visible = unread > 0
		badge.text = " %d " % unread

# ---------------------------------------------------------------- Barra de tarefas

func _build_taskbar() -> void:
	taskbar = NinePatchRect.new()
	taskbar.name = "Taskbar"
	taskbar.texture = load("res://assets/ui/workos/taskbar.png")
	taskbar.patch_margin_left = 32
	taskbar.patch_margin_right = 32
	taskbar.patch_margin_top = 8
	taskbar.patch_margin_bottom = 8
	taskbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	taskbar.offset_top = -TASKBAR_HEIGHT
	taskbar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(taskbar)
	task_row = HBoxContainer.new()
	task_row.name = "Tasks"
	task_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	task_row.offset_left = 78
	task_row.offset_right = -330
	task_row.offset_top = 6
	task_row.offset_bottom = -6
	task_row.add_theme_constant_override("separation", 6)
	taskbar.add_child(task_row)
	var tray := HBoxContainer.new()
	tray.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	tray.offset_left = -322
	tray.offset_right = -8
	tray.offset_top = 6
	tray.offset_bottom = -6
	tray.alignment = BoxContainer.ALIGNMENT_END
	tray.add_theme_constant_override("separation", 6)
	taskbar.add_child(tray)
	var leave := Button.new()
	leave.name = "Exit"
	leave.text = "Levantar"
	leave.tooltip_text = "Sair do computador"
	leave.focus_mode = Control.FOCUS_NONE
	_style_task_button(leave, false)
	leave.pressed.connect(func() -> void: exit_requested.emit())
	tray.add_child(leave)
	var clock_box := PanelContainer.new()
	clock_box.add_theme_stylebox_override("panel", STYLE.bevel(STYLE.BEIGE, STYLE.BROWN, STYLE.PAPER, false, STYLE.INK, 2, 2, Vector4(10, 2, 10, 2)))
	tray.add_child(clock_box)
	clock_label = Label.new()
	clock_label.name = "Clock"
	clock_label.add_theme_font_size_override("font_size", 20)
	clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock_box.add_child(clock_label)
	# Orbe do Iniciar (22x22 em escala 3), maior que a barra, como no Windows 7.
	start_button = TextureButton.new()
	start_button.name = "Start"
	start_button.texture_normal = PIXEL.orb(3)
	start_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	start_button.position = Vector2(4, -22)
	start_button.size = Vector2(66, 66)
	start_button.tooltip_text = "WorkOS"
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.mouse_entered.connect(func() -> void: start_button.modulate = Color(1.15, 1.15, 1.15))
	start_button.mouse_exited.connect(func() -> void: start_button.modulate = Color.WHITE)
	start_button.pressed.connect(_toggle_start_menu)
	taskbar.add_child(start_button)

## Botão de tarefa: bege com bisel saltado; ativo fica afundado e claro (.os-task / .os-task.on).
func _style_task_button(button: Button, active: bool) -> void:
	var normal := STYLE.bevel(STYLE.BEIGE, STYLE.PAPER, STYLE.BROWN, true, STYLE.INK, 2, 2, Vector4(8, 1, 10, 1))
	var pressed := STYLE.bevel(STYLE.PAPER, STYLE.BROWN, STYLE.PAPER, false, STYLE.INK, 2, 2, Vector4(8, 2, 10, 0))
	button.add_theme_stylebox_override("normal", pressed if active else normal)
	button.add_theme_stylebox_override("hover", pressed if active else STYLE.tinted(normal, Color(1.06, 1.05, 1.02)))
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_font_size_override("font_size", 19)

func _add_task(id: String) -> void:
	var task := Button.new()
	task.text = APP_INFO[id][0]
	task.icon = PIXEL.app_icon(id, 2)
	task.expand_icon = false
	task.custom_minimum_size = Vector2(150, 0)
	task.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task.size_flags_stretch_ratio = 1.0
	task.clip_text = true
	task.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	task.alignment = HORIZONTAL_ALIGNMENT_LEFT
	task.focus_mode = Control.FOCUS_NONE
	task.tooltip_text = APP_INFO[id][0]
	_style_task_button(task, false)
	task_row.add_child(task)
	tasks[id] = task
	task.pressed.connect(func() -> void:
		var window: Control = windows[id]
		if not window.visible: _restore(id)
		elif current_app == id: _minimize(id)
		else: _focus(id))

func _sync_tasks() -> void:
	for id in tasks:
		_style_task_button(tasks[id], id == current_app and windows[id].visible)
		# Largura máxima de 13em como no CSS: sem esticar quando há poucas janelas.
		tasks[id].custom_minimum_size.x = 150
		tasks[id].size_flags_horizontal = Control.SIZE_FILL
		tasks[id].custom_minimum_size.x = clampf((task_row.size.x - 6 * tasks.size()) / maxf(1, tasks.size()), 90, 220)

func _update_clock() -> void:
	clock_label.text = "%s · %s" % [game.clock.text(), game.clock.date_text()]

# ---------------------------------------------------------------- Menu Iniciar

func _build_start_menu() -> void:
	start_menu = PanelContainer.new()
	start_menu.name = "StartMenu"
	start_menu.add_theme_stylebox_override("panel", STYLE.bevel(STYLE.CREAM, STYLE.PAPER, STYLE.TAN, true, STYLE.INK, 2, 2, Vector4(3, 3, 3, 3)))
	start_menu.visible = false
	start_menu.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	add_child(start_menu)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	start_menu.add_child(column)
	# Cabeçalho azul com a foto e o nome (.os-sh).
	var header := PanelContainer.new()
	var header_box := STYLE.flat(STYLE.BLUE, Color.TRANSPARENT, 0, 8)
	header_box.border_width_top = 3
	header_box.border_color = STYLE.BLUE_HI
	header.add_theme_stylebox_override("panel", header_box)
	column.add_child(header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	header.add_child(header_row)
	var picture_frame := PanelContainer.new()
	picture_frame.add_theme_stylebox_override("panel", STYLE.flat(STYLE.PAPER, STYLE.INK, 2, 2))
	header_row.add_child(picture_frame)
	var picture := TextureRect.new()
	picture.name = "Picture"
	picture.custom_minimum_size = Vector2(44, 44)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture_frame.add_child(picture)
	var name_label := Label.new()
	name_label.name = "UserName"
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", STYLE.PAPER)
	name_label.add_theme_color_override("font_shadow_color", STYLE.BLUE_LO)
	name_label.add_theme_constant_override("shadow_offset_y", 2)
	name_label.add_theme_constant_override("shadow_offset_x", 0)
	header_row.add_child(name_label)
	# Duas colunas: programas (claro) e sistema (azul claro), como o Iniciar do XP.
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	column.add_child(body)
	var programs := _menu_column(STYLE.PAPER, 250)
	body.add_child(programs.get_parent())
	for id in ["workday", "messenger", "calendar", "archive", "notes", "calc", "music"]:
		_menu_item(programs, APP_INFO[id][1] if id != "workday" else "Portal RH", PIXEL.app_icon(id, 2), open_app.bind(id))
	var places := _menu_column(Color("dfe6f3"), 210)
	body.add_child(places.get_parent())
	for item in [["profile", "Perfil"], ["settings", "Personalizar"], ["backup", "Backup"], ["about", "Sobre o WorkOS"]]:
		_menu_item(places, item[1], PIXEL.app_icon(item[0], 2), open_app.bind(item[0]))
	# Rodapé com "Desligar" (sai do computador).
	var footer := PanelContainer.new()
	var footer_box := STYLE.flat(STYLE.BLUE, Color.TRANSPARENT, 0, 6)
	footer_box.border_width_top = 3
	footer_box.border_color = STYLE.BLUE_HI
	footer.add_theme_stylebox_override("panel", footer_box)
	column.add_child(footer)
	var footer_row := HBoxContainer.new()
	footer_row.alignment = BoxContainer.ALIGNMENT_END
	footer.add_child(footer_row)
	var off := Button.new()
	off.text = "Desligar"
	off.icon = PIXEL.menu_icon("x", 2) if PIXEL.ui().menu_icons.has("x") else null
	off.focus_mode = Control.FOCUS_NONE
	var off_box := STYLE.bevel(Color("d9714a"), Color("f2a27a"), Color("a24a33"), true, STYLE.INK, 2, 2, Vector4(10, 2, 12, 2))
	off.add_theme_stylebox_override("normal", off_box)
	off.add_theme_stylebox_override("hover", STYLE.tinted(off_box, Color(1.1, 1.08, 1.05)))
	off.add_theme_stylebox_override("pressed", STYLE.bevel(Color("a24a33"), Color("6e3b26"), Color("d9714a"), false, STYLE.INK, 2, 2, Vector4(10, 3, 12, 1)))
	off.add_theme_color_override("font_color", STYLE.PAPER)
	off.add_theme_color_override("font_hover_color", STYLE.PAPER)
	off.pressed.connect(func() -> void:
		_close_start_menu()
		fx.sound("close")
		exit_requested.emit())
	footer_row.add_child(off)

func _menu_column(color: Color, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", STYLE.flat(color, Color.TRANSPARENT, 0, 4))
	panel.custom_minimum_size.x = width
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	panel.add_child(list)
	return list

func _menu_item(list: VBoxContainer, text: String, icon: Texture2D, action: Callable) -> void:
	var item := Button.new()
	item.text = text
	item.icon = icon
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.focus_mode = Control.FOCUS_NONE
	item.add_theme_font_size_override("font_size", 21)
	item.add_theme_stylebox_override("normal", STYLE.flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, 5))
	item.add_theme_stylebox_override("hover", STYLE.flat(STYLE.BLUE, Color.TRANSPARENT, 0, 5))
	item.add_theme_stylebox_override("pressed", STYLE.flat(STYLE.BLUE_LO, Color.TRANSPARENT, 0, 5))
	item.add_theme_color_override("font_hover_color", STYLE.PAPER)
	item.add_theme_color_override("font_pressed_color", STYLE.PAPER)
	item.add_theme_constant_override("h_separation", 10)
	item.pressed.connect(func() -> void:
		_close_start_menu()
		action.call())
	list.add_child(item)

func _toggle_start_menu() -> void:
	if start_menu.visible:
		_close_start_menu()
		return
	var picture: TextureRect = start_menu.find_child("Picture", true, false)
	var ids: Array = PIXEL.os_pic_ids()
	var chosen := str(game.profile.get("os_pic", ids[0] if not ids.is_empty() else ""))
	picture.texture = PIXEL.os_pic(chosen, 3)
	start_menu.find_child("UserName", true, false).text = str(game.profile.get("name", "Funcionário"))
	start_menu.reset_size()
	start_menu.position = Vector2(4, size.y - TASKBAR_HEIGHT - start_menu.size.y - 2)
	start_menu.show()
	move_child(start_menu, -1)
	fx.sound("open")
	# Abre de baixo para cima em degraus.
	start_menu.pivot_offset = Vector2(0, start_menu.size.y)
	start_menu.scale = Vector2(1, 0.1)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: start_menu.scale = Vector2(1, maxf(0.1, floorf(t * 6) / 6.0)), 0.0, 1.0, 0.14)

func _close_start_menu() -> void:
	if start_menu != null: start_menu.hide()

# ---------------------------------------------------------------- Avisos

func _build_toasts() -> void:
	toast_layer = VBoxContainer.new()
	toast_layer.name = "Toasts"
	toast_layer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	toast_layer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toast_layer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_layer.offset_right = -10
	toast_layer.offset_bottom = -TASKBAR_HEIGHT - 10
	toast_layer.alignment = BoxContainer.ALIGNMENT_END
	toast_layer.add_theme_constant_override("separation", 8)
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_layer)

## Balão no canto (como os avisos do MSworkN no HTML): barra azul com o título e o texto embaixo.
func toast(title: String, message: String, app := "") -> void:
	if message.is_empty(): return
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(340, 0)
	card.add_theme_stylebox_override("panel", STYLE.bevel(STYLE.PAPER, Color.WHITE, STYLE.TAN, true, STYLE.INK, 2, 2, Vector4(0, 0, 0, 6)))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	var head := Label.new()
	head.text = "  " + title
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", STYLE.PAPER)
	head.add_theme_stylebox_override("normal", STYLE.flat(STYLE.BLUE, Color.TRANSPARENT, 0, 2))
	column.add_child(head)
	var text := Label.new()
	text.text = message
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 320
	text.add_theme_font_size_override("font_size", 19)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_child(text)
	column.add_child(margin)
	if app != "":
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				open_app(app)
				card.queue_free())
	toast_layer.add_child(card)
	while toast_layer.get_child_count() > 3: toast_layer.get_child(0).free()
	fx.sound("notify")
	card.modulate.a = 0.0
	var tween := card.create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 0.15)
	tween.tween_interval(4.5)
	tween.tween_property(card, "modulate:a", 0.0, 0.3)
	tween.tween_callback(card.queue_free)

# ---------------------------------------------------------------- Janelas

func open_app(id: String) -> void:
	if not APP_INFO.has(id): return
	if id != "workday" and game.career.get("phase", "") == "day": game.paused = true
	_close_start_menu()
	if windows.has(id):
		if not windows[id].visible: _restore(id)
		else: _focus(id)
		return
	var window: Control = WINDOW_SCRIPT.new()
	window.name = "Window_" + id
	window_layer.add_child(window)
	window.configure(APP_INFO[id][0], PIXEL.app_icon(id, 2))
	window.closable = id != "workday"
	var area := window_layer.size if window_layer.size != Vector2.ZERO else Vector2(1280, 720 - TASKBAR_HEIGHT)
	window.size = WINDOW_SIZES.get(id, Vector2(760, 560)).min(area - Vector2(20, 10))
	var cascade := Vector2(26, 22) * (windows.size() % 6)
	window.position = (((area - window.size) / 2.0).floor() + cascade - Vector2(60, 40)).clamp(Vector2.ZERO, area - window.size)
	windows[id] = window
	window.activated.connect(_focus.bind(id))
	window.closed.connect(_close.bind(id))
	window.minimize_requested.connect(_minimize.bind(id))
	_add_task(id)
	var app: Control = load("res://scenes/workos/apps/%s.tscn" % id).instantiate()
	app.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	fx.sound("open")
	window.play_open()

func _focus(id: String) -> void:
	if not windows.has(id): return
	current_app = id
	window_layer.move_child(windows[id], -1)
	for key in windows: windows[key].set_active(key == id)
	_sync_tasks()

func _task_center(id: String) -> Vector2:
	if not tasks.has(id): return Vector2.ZERO
	var task: Control = tasks[id]
	return task.global_position + task.size / 2.0 - window_layer.global_position

func _minimize(id: String) -> void:
	if not windows.has(id): return
	if id == "workday": game.paused = true
	fx.sound("min")
	var window: Control = windows[id]
	if current_app == id: current_app = ""
	_sync_tasks()
	await window.minimize_to(_task_center(id))
	_focus_topmost()

func _restore(id: String) -> void:
	fx.sound("max")
	_focus(id)
	windows[id].restore_from(_task_center(id))

func _focus_topmost() -> void:
	for index in range(window_layer.get_child_count() - 1, -1, -1):
		var child := window_layer.get_child(index)
		for id in windows:
			if windows[id] == child and child.visible:
				_focus(id)
				return
	current_app = ""
	_sync_tasks()

func _close(id: String) -> void:
	if id == "workday":
		game.paused = true
		game.save_game()
	if id == "notes":
		_save_notes()
		notes_editor = null
	fx.sound("close")
	windows.erase(id)
	if tasks.has(id):
		tasks[id].queue_free()
		tasks.erase(id)
	if current_app == id: current_app = ""
	_focus_topmost()

# ---------------------------------------------------------------- Aplicativos simples

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
	fx.sound("click")
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
	for wall in WALLPAPERS: options.add_item("Xadrez WorkOS" if wall == "xadrez-workos" else wall.replace("-", " ").capitalize())
	options.selected = maxi(0, WALLPAPERS.find(str(settings.get_value("desktop", "wallpaper", "xadrez-workos"))))
	options.item_selected.connect(func(index: int) -> void: _set_wallpaper(WALLPAPERS[index]))
	var effect_label := Label.new()
	effect_label.text = "Efeito de vídeo do mundo 3D"
	parent.add_child(effect_label)
	var effects := OptionButton.new()
	for effect_name in WORLD_EFFECT_NAMES: effects.add_item(effect_name)
	effects.selected = maxi(0, WORLD_EFFECTS.find(video_world()))
	parent.add_child(effects)
	var crt := CheckBox.new()
	crt.text = "Tela CRT no monitor"
	crt.button_pressed = video_crt()
	parent.add_child(crt)
	effects.item_selected.connect(func(index: int) -> void: _set_video(WORLD_EFFECTS[index], crt.button_pressed))
	crt.toggled.connect(func(on: bool) -> void: _set_video(WORLD_EFFECTS[effects.selected], on))
	for node in [effect_label, effects, crt]: parent.move_child(node, parent.get_node("Preview").get_index())
	var preview: TextureRect = parent.get_node("Preview")
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.texture = wallpaper.texture
	options.item_selected.connect(func(_index: int) -> void: preview.texture = wallpaper.texture)

func video_world() -> String:
	return str(settings.get_value("video", "world", "psx"))

func video_crt() -> bool:
	return bool(settings.get_value("video", "crt", true))

func _set_video(world: String, crt: bool) -> void:
	settings.set_value("video", "world", world)
	settings.set_value("video", "crt", crt)
	settings.save(SAVE_PATH)
	video_changed.emit(world, crt)

# ---------------------------------------------------------------- Integração com o mundo 3D

func dismiss_menu() -> bool:
	if start_menu.visible:
		_close_start_menu()
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
	_close_start_menu()
	for window in windows.values(): window.dragging = false
	get_viewport().gui_release_focus()
