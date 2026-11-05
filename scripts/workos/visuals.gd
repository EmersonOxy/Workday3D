extends RefCounted

const INK := Color("2a1f2d")
const PAPER := Color("fff8ec")
const BLUE := Color("44609f")
const GREEN := Color("5fa79a")
const RED := Color("c25f3b")
static var cache: Dictionary = {}
static var art: Dictionary = {}

static func data() -> Dictionary:
	if art.is_empty(): art = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/workday_original.json"))
	return art

static func sprite(id: String, sector := "") -> Texture2D:
	var key := id + sector
	if cache.has(key): return cache[key]
	var source := data()
	var rows: Array = source.sprites.get(id, source.app_icons.get(id, source.pins.get(id, [])))
	if rows.is_empty() or not rows[0] is String: return null
	var width := 1
	for row in rows: width = maxi(width, str(row).length())
	var pixels := Image.create(width, rows.size(), false, Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	var palette: Dictionary = source.palette.duplicate()
	var ramps := {"fin": ["#a9dccf", "#5fa79a", "#2f6f78"], "rh": ["#c3d5ff", "#6f93d9", "#44609f"], "jur": ["#ffd0b0", "#f0915f", "#c25f3b"], "ti": ["#e0cff7", "#a983d6", "#7656a8"]}
	if ramps.has(sector):
		palette.F = ramps[sector][1]
		palette.f = ramps[sector][0]
		palette["9"] = ramps[sector][2]
	for y in rows.size():
		for x in str(rows[y]).length():
			var character: String = rows[y][x]
			if palette.has(character): pixels.set_pixel(x, y, Color(palette[character]))
	cache[key] = ImageTexture.create_from_image(pixels)
	return cache[key]

static func app_icon(id: String) -> Texture2D:
	var names := {"workday": "doc", "calendar": "cal", "archive": "arq", "music": "music", "calc": "calc", "notes": "notes", "settings": "paint", "messenger": "envelope", "profile": "badge", "backup": "doc", "about": "gear"}
	var result := sprite(names.get(id, "doc"))
	return result if result != null else load("res://assets/ui/workos/icon-info.png")

static func texture_box(path: String, margin := 7.0, padding := 10.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load("res://assets/ui/workos/" + path + ".png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, margin)
		box.set_content_margin(side, padding)
	return box

static func flat(color: Color, border := INK, width := 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_content_margin_all(10)
	return box

static func decorate_theme(base: Theme) -> Theme:
	var result := base.duplicate(true) as Theme
	var normal := texture_box("dialog-button", 7, 10)
	var hover := normal.duplicate() as StyleBoxTexture
	hover.modulate_color = Color("fff4d6")
	var pressed := normal.duplicate() as StyleBoxTexture
	pressed.modulate_color = Color("b9d2cf")
	pressed.content_margin_top = 12
	pressed.content_margin_bottom = 8
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = GREEN
	focus.set_border_width_all(2)
	for type in ["Button", "OptionButton"]:
		result.set_stylebox("normal", type, normal)
		result.set_stylebox("hover", type, hover)
		result.set_stylebox("pressed", type, pressed)
		result.set_stylebox("focus", type, focus)
		result.set_color("font_color", type, INK)
		result.set_color("font_hover_color", type, INK)
		result.set_color("font_pressed_color", type, INK)
		result.set_color("font_focus_color", type, INK)
		result.set_color("font_disabled_color", type, Color("8f7d63"))
	for type in ["LineEdit", "TextEdit"]:
		result.set_stylebox("normal", type, texture_box("input", 5, 9))
		result.set_stylebox("focus", type, texture_box("input", 5, 9))
		result.set_color("font_color", type, INK)
		result.set_color("caret_color", type, BLUE)
		result.set_color("selection_color", type, Color("a9c1e5"))
		result.set_color("font_selected_color", type, INK)
		result.set_color("font_placeholder_color", type, Color("81716d"))
	for type in ["CheckBox", "CheckButton", "PopupMenu"]:
		result.set_color("font_color", type, INK)
		result.set_color("font_hover_color", type, INK)
	result.set_stylebox("panel", "PopupMenu", texture_box("window-paper", 6, 10))
	result.set_stylebox("hover", "PopupMenu", flat(Color("bdd9d1"), Color.TRANSPARENT, 0))
	result.set_stylebox("background", "ProgressBar", texture_box("progress", 4, 0))
	result.set_stylebox("fill", "ProgressBar", texture_box("progress-fill", 3, 0))
	for type in ["VScrollBar", "HScrollBar"]:
		result.set_stylebox("scroll", type, texture_box("scroll-track", 3, 3))
		result.set_stylebox("grabber", type, texture_box("scroll-thumb", 4, 5))
		result.set_stylebox("grabber_highlight", type, texture_box("scroll-thumb", 4, 5))
		result.set_stylebox("grabber_pressed", type, texture_box("scroll-thumb", 4, 5))
	result.set_stylebox("panel", "TooltipPanel", flat(Color("fff0bc")))
	result.set_color("font_color", "TooltipLabel", INK)
	result.set_font_size("font_size", "TooltipLabel", 22)
	return result

static func icon_rect(texture: Texture2D, pixels := 32) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(pixels, pixels)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

static func card(parent: Node, title: String, icon_id := "doc", color := BLUE) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", texture_box("window-paper", 6, 12))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 8)
	panel.add_child(contents)
	var heading := HBoxContainer.new()
	contents.add_child(heading)
	heading.add_child(icon_rect(sprite(icon_id), 28))
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 26)
	heading.add_child(label)
	return contents
