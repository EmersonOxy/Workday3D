extends VBoxContainer
## PORTAL_RH.EXE (porte de showMenu/pickDifficulty/telas do expediente do HTML).
## Portal: foto, logotipo WORKDAY caindo, slogan, três caixas de números e botões com ícones que entram em sequência.
## Expediente: cabeçalho WORKDAY.EXE com relógio verde, tabuleiro de papel quadriculado (work_board.gd) e as
## pendências em cartões à direita, com barra de prazo.

const BOARD := preload("res://scripts/workos/work_board.gd")
const PIXEL := preload("res://scripts/workos/pixel.gd")
const STYLE := preload("res://scripts/workos/os_style.gd")
const MOTION := preload("res://scripts/workos/motion.gd")
const SECTOR_COLORS := {"fin": Color("6fbf73"), "rh": Color("f0915f"), "jur": Color("6f93d9"), "ti": Color("a983d6")}
const MUTED := Color("8f7d63")
const OK := Color("2f8a45")
const DANGER := Color("ef4b3f")
const WARN := Color("ffb938")
const TASK_TITLES := {"button": "pending", "email": "newEmail", "type": "fill", "call": "ringing", "printer": "printer", "video": "videoCall"}

var game: Node
var desktop: Control
var phase := ""
var screen := ""
var board: Control
var hud: Dictionary = {}
var task_box: VBoxContainer
var event_box: VBoxContainer
var bars: Dictionary = {}
var task_signature := ""
var event_signature := ""
var elapsed := 0.0
var break_button: Button

func setup(state: Node, host: Control) -> void:
	game = state
	desktop = host
	size_flags_vertical = SIZE_EXPAND_FILL
	size_flags_horizontal = SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	_render()

func ui() -> Dictionary:
	return game.texts().ui

## Textos do original que eram funções JS (exportados como código-fonte): aplica os parâmetros mais comuns.
func ui_text(key: String, fallback: String, value: Variant = null) -> String:
	var raw: Variant = ui().get(key, fallback)
	if raw is Dictionary and raw.has("source_function"):
		var source: String = raw.source_function
		var start := source.find("`")
		var end := source.rfind("`")
		if start >= 0 and end > start:
			var body := source.substr(start + 1, end - start - 1)
			var regex := RegEx.create_from_string("\\$\\{[^}]*\\}")
			return regex.sub(body, str(value), true) if value != null else regex.sub(body, "", true)
		return fallback
	return str(raw)

static func strip_html(value: String) -> String:
	return RegEx.create_from_string("<[^>]+>").sub(value, "", true).strip_edges()

func label(text: String, parent: Node = null, size := 20, color := STYLE.INK) -> Label:
	var item := Label.new()
	item.text = text
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	(parent if parent != null else self).add_child(item)
	return item

func button(text: String, callback: Callable, parent: Node = null, icon: Texture2D = null) -> Button:
	var item := Button.new()
	item.text = text
	item.icon = icon
	item.focus_mode = Control.FOCUS_NONE
	item.pressed.connect(func() -> void:
		if desktop != null and desktop.fx != null: desktop.fx.sound("click"))
	item.pressed.connect(callback)
	(parent if parent != null else self).add_child(item)
	return item

func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	bars.clear()
	hud.clear()
	board = null
	task_signature = ""
	event_signature = ""

func _render() -> void:
	_clear()
	phase = str(game.career.get("phase", "menu"))
	match phase:
		"day": _render_day()
		"promotion": _render_promotion()
		_: _render_portal()

func _process(delta: float) -> void:
	if game == null: return
	if phase != str(game.career.get("phase", "menu")):
		_render()
		return
	elapsed += delta
	if phase == "day" and elapsed >= 0.08:
		elapsed = 0
		_refresh()

# ---------------------------------------------------------------- Portal

## Entrada em sequência (sceneIn do HTML): cada item aparece alguns centésimos depois do anterior, em degraus.
func _stagger(items: Array, start := 0.3, step := 0.045) -> void:
	for index in items.size():
		var item: CanvasItem = items[index]
		item.modulate.a = 0.0
		var tween := item.create_tween()
		tween.tween_interval(start + index * step)
		tween.tween_property(item, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_LINEAR)

func _render_portal() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	scroll.add_child(page)
	# Topo: foto + logotipo + slogan (.mw-hero).
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 18)
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(hero)
	var face_frame := PanelContainer.new()
	face_frame.add_theme_stylebox_override("panel", STYLE.flat(Color("c3d5ff"), STYLE.INK, 3, 4))
	hero.add_child(face_frame)
	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(88, 88)
	face.texture = PIXEL.os_pic(str(game.profile.get("os_pic", "gato")), 6)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face_frame.add_child(face)
	var brand := VBoxContainer.new()
	brand.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(brand)
	var logo := TextureRect.new()
	logo.texture = PIXEL.logo(4)
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	brand.add_child(logo)
	label(ui_text("tagline", ""), brand, 18, MUTED).custom_minimum_size.x = 300
	_drop_in(logo)
	# Números (.mw-stats): caixas escuras.
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	page.add_child(stats)
	var stat_items: Array = []
	for pair in [[ui_text("record", "Recorde"), str(int(game.profile.best))], [ui_text("wallet", "Carteira"), "R$ %d" % int(game.profile.wallet)], [ui_text("daysWorked", "Dias trabalhados"), str(int(game.profile.stats.get("days", 0)))]]:
		var box := PanelContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_stylebox_override("panel", STYLE.flat(STYLE.INK, STYLE.INK2, 2, 6))
		stats.add_child(box)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 0)
		box.add_child(column)
		var small := label(pair[0], column, 16, STYLE.TAN)
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var value := label(pair[1], column, 24, STYLE.PAPER)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_items.append(box)
	# Resultado do fim de carreira ou resumo do último dia.
	if phase in ["burnout", "won", "resigned"]:
		var banner := label({"burnout": ui_text("burnoutTitle", "Afastamento por estresse"), "won": ui_text("winTitle", "Carreira concluída"), "resigned": "Demissão registrada"}[phase], page, 24, DANGER if phase != "won" else OK)
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.ready.connect(func() -> void:
			await banner.get_tree().create_timer(0.35).timeout
			MOTION.stamp(banner))
	elif phase == "ended" and game.career.get("summary", {}) is Dictionary and not game.career.summary.is_empty():
		var summary := _summary_card(game.career.summary)
		page.add_child(summary)
		summary.ready.connect(func() -> void:
			await summary.get_tree().create_timer(0.3).timeout
			MOTION.squash(summary))
	# Botões do portal (.menu .pxbtn), centralizados.
	var menu := GridContainer.new()
	menu.columns = 2
	menu.add_theme_constant_override("h_separation", 10)
	menu.add_theme_constant_override("v_separation", 8)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(menu)
	var buttons: Array = []
	var career_open: bool = not game.career.is_empty() and phase in ["ready", "ended"]
	if career_open:
		var next_day: int = game.day() + (1 if phase == "ended" else 0)
		var cont := _menu_button("%s · %s %d" % [ui_text("startDay", "Começar"), ui_text("day", "Dia"), next_day] if phase == "ready" else ui_text("cont", "Continuar", next_day), "cont", menu, true)
		cont.pressed.connect(func() -> void:
			game.start_day()
			_render())
		buttons.append(cont)
	var play := _menu_button(ui_text("play", "Jogar") if not career_open else ui_text("newJob", "Novo emprego"), "play", menu, not career_open)
	play.pressed.connect(_render_difficulty)
	buttons.append(play)
	var how := _menu_button(ui_text("how", "Como jogar"), "how", menu)
	how.pressed.connect(_render_how)
	buttons.append(how)
	var settings := _menu_button(ui_text("settings", "Configurações"), "cfg", menu)
	settings.pressed.connect(func() -> void: desktop.open_app("config"))
	buttons.append(settings)
	var profile := _menu_button(ui_text("profile", "Perfil"), "prof", menu)
	profile.pressed.connect(func() -> void: desktop.open_app("profile"))
	buttons.append(profile)
	var calendar := _menu_button("Calendário", "doc", menu)
	calendar.icon = PIXEL.app_icon("calendar", 2)
	calendar.pressed.connect(func() -> void: desktop.open_app("calendar"))
	buttons.append(calendar)
	_stagger(stat_items + buttons)

func _menu_button(text: String, icon: String, parent: Node, main := false) -> Button:
	var item := button(text, func() -> void: pass, parent, PIXEL.menu_icon(icon, 2))
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.custom_minimum_size = Vector2(330, 46)
	item.add_theme_font_size_override("font_size", 24)
	item.add_theme_constant_override("h_separation", 14)
	if main:
		var box := STYLE.bevel(STYLE.INK, STYLE.INK2, Color("120c14"), true, STYLE.INK, 2, 3, Vector4(16, 6, 16, 8))
		item.add_theme_stylebox_override("normal", box)
		item.add_theme_stylebox_override("hover", STYLE.tinted(box, Color(1.25, 1.2, 1.25)))
		item.add_theme_stylebox_override("pressed", STYLE.bevel(STYLE.INK, Color("120c14"), STYLE.INK2, false, STYLE.INK, 2, 3, Vector4(16, 8, 16, 6)))
		for key in ["font_color", "font_hover_color", "font_pressed_color"]: item.add_theme_color_override(key, STYLE.PAPER)
	return item

## Logotipo caindo de cima e quicando (Motion.dropIn), em degraus.
func _drop_in(node: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(node): return
	var final_y := node.position.y
	var tween := node.create_tween()
	tween.tween_method(func(t: float) -> void:
		var s := floorf(t * 8) / 8.0
		var bounce := (1.0 - s) * 40.0 if s < 0.75 else sin((s - 0.75) / 0.25 * PI) * 6.0
		node.position.y = final_y - bounce, 0.0, 1.0, 0.45)

func _summary_card(summary: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", STYLE.bevel(STYLE.PAPER, Color.WHITE, STYLE.PAPER2, true, STYLE.INK, 2, 2, Vector4(14, 10, 14, 10)))
	var column := VBoxContainer.new()
	card.add_child(column)
	label(ui_text("dayDone", "Dia concluído", int(summary.get("day", 1))), column, 24, OK)
	label("%s: %d   ·   %s: R$ %d   ·   %s: %d%%" % [ui_text("points", "Pontos"), int(summary.get("points", 0)), ui_text("salary", "Salário"), int(summary.get("pay", 0)), ui_text("stress", "Estresse"), int(summary.get("stress", 0))], column, 20)
	label("%s: %s" % [ui_text("rank", "Cargo"), str(game.texts().ranks[int(summary.get("rank", 0))])], column, 20, MUTED)
	return card

func _render_how() -> void:
	_clear()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	label(ui_text("how", "Como jogar"), column, 30)
	var raw := ui_text("howText", "")
	for paragraph in raw.split("</p>"):
		var text := strip_html(paragraph)
		if not text.is_empty(): label(text, column, 21)
	button(ui_text("back", "Voltar"), _render, self, PIXEL.menu_icon("cont", 2))

## DIFICULDADE.EXE: quatro cartões e o botão de começar (pickDifficulty).
func _render_difficulty() -> void:
	_clear()
	label(ui_text("diffLabel", "Dificuldade"), self, 28)
	var selected := [str(game.profile.get("difficulty", "normal"))]
	var names: Dictionary = ui().get("diffNames", {})
	var descriptions: Dictionary = ui().get("diffDesc", {})
	var cards: Array = []
	var start := Button.new()
	for id in ["facil", "normal", "dificil", "burnout"]:
		var card := Button.new()
		card.toggle_mode = true
		card.focus_mode = Control.FOCUS_NONE
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.text = "%s\n%s" % [names.get(id, id), descriptions.get(id, "")]
		card.custom_minimum_size = Vector2(0, 64)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_size_override("font_size", 20)
		card.button_pressed = id == selected[0]
		var on := STYLE.bevel(STYLE.INK, Color("120c14"), STYLE.INK2, false, STYLE.INK, 2, 2, Vector4(14, 6, 14, 6))
		card.add_theme_stylebox_override("pressed", on)
		card.add_theme_stylebox_override("hover_pressed", on)
		card.add_theme_color_override("font_pressed_color", STYLE.PAPER)
		card.add_theme_color_override("font_hover_pressed_color", STYLE.PAPER)
		card.pressed.connect(func() -> void:
			selected[0] = id
			for other in cards: other.set_pressed_no_signal(other == card)
			start.text = "%s: %s" % [ui_text("diffStart", "Começar"), names.get(id, id)])
		add_child(card)
		cards.append(card)
	start.text = "%s: %s" % [ui_text("diffStart", "Começar"), names.get(selected[0], selected[0])]
	start.icon = PIXEL.menu_icon("play", 2)
	start.focus_mode = Control.FOCUS_NONE
	start.custom_minimum_size = Vector2(0, 52)
	start.add_theme_font_size_override("font_size", 26)
	start.pressed.connect(func() -> void:
		game.profile.difficulty = selected[0]
		game.new_career()
		_render())
	add_child(start)
	button(ui_text("back", "Voltar"), _render)
	_stagger(cards + [start], 0.05, 0.05)

func _render_promotion() -> void:
	label(ui_text("promo", "Promoção!"), self, 32, OK)
	label(strip_html(ui_text("promoText", "", str(game.texts().ranks[int(game.career.rank)]))), self, 22)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var items: Array = []
	for id in game.data.perks:
		if id in game.career.perks: continue
		var description: Variant = game.texts().get("perks", {}).get(id, [id, ""])
		var title := str(description[0]) + " — " + str(description[1]) if description is Array else str(description)
		var perk := button(title, func() -> void:
			game.choose_perk(id)
			_render(), list)
		perk.alignment = HORIZONTAL_ALIGNMENT_LEFT
		perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		perk.custom_minimum_size.y = 56
		items.append(perk)
	_stagger(items, 0.1, 0.05)

# ---------------------------------------------------------------- Expediente

func _render_day() -> void:
	add_child(_build_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.8
	body.add_child(left)
	board = BOARD.new()
	board.game = game
	board.app = self
	left.add_child(board)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	left.add_child(controls)
	for item in [["←", func() -> void: game.move_file(int(game.file.lane) - 1)], ["↓ Acelerar", func() -> void: game.fast = true], ["→", func() -> void: game.move_file(int(game.file.lane) + 1)], ["Delete", game.delete_file]]:
		button(item[0], item[1], controls).add_theme_font_size_override("font_size", 20)
	event_box = VBoxContainer.new()
	left.add_child(event_box)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	var tools := HFlowContainer.new()
	tools.add_theme_constant_override("h_separation", 6)
	tools.add_theme_constant_override("v_separation", 6)
	right.add_child(tools)
	hud.pause = button("Pausar", func() -> void: game.paused = not game.paused, tools, PIXEL.menu_icon("play", 1))
	hud.coffee = button("Café", game.use_coffee, tools, PIXEL.sprite("mug", 2))
	break_button = button("Intervalo", func() -> void:
		if game.career.get("on_break", false): game.end_break()
		else: game.start_break(), tools)
	var task_scroll := ScrollContainer.new()
	task_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	task_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(task_scroll)
	task_box = VBoxContainer.new()
	task_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_box.add_theme_constant_override("separation", 10)
	task_scroll.add_child(task_box)
	_refresh()

## Cabeçalho do expediente (body.office header): WORKDAY.EXE, relógio verde e números.
func _build_header() -> Control:
	var bar := PanelContainer.new()
	var box := STYLE.flat(STYLE.PAPER, STYLE.INK, 2, 6)
	box.border_width_bottom = 5
	box.border_color = STYLE.INK
	bar.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.custom_minimum_size.x = 150
	title.add_theme_font_size_override("normal_font_size", 26)
	title.text = "WORKDAY[color=#8f7d63].EXE[/color]"
	row.add_child(title)
	var clock := Label.new()
	clock.add_theme_font_size_override("font_size", 26)
	clock.add_theme_color_override("font_color", Color("c4ebb5"))
	clock.add_theme_stylebox_override("normal", STYLE.flat(STYLE.INK, Color.TRANSPARENT, 0, 2))
	row.add_child(clock)
	hud.clock = clock
	for key in ["day", "points", "combo", "rank", "wallet"]:
		var stat := RichTextLabel.new()
		stat.bbcode_enabled = true
		stat.fit_content = true
		stat.scroll_active = false
		stat.autowrap_mode = TextServer.AUTOWRAP_OFF
		stat.add_theme_font_size_override("normal_font_size", 21)
		stat.add_theme_color_override("default_color", MUTED)
		stat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(stat)
		hud[key] = stat
	var stress_column := VBoxContainer.new()
	stress_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stress_column.add_theme_constant_override("separation", 0)
	row.add_child(stress_column)
	label(ui_text("stress", "Estresse"), stress_column, 16, MUTED)
	var stress := ProgressBar.new()
	stress.show_percentage = false
	stress.custom_minimum_size = Vector2(120, 16)
	stress.add_theme_stylebox_override("background", STYLE.flat(Color("d7d9de"), STYLE.INK, 2, 0))
	stress.add_theme_stylebox_override("fill", STYLE.flat(DANGER, Color.TRANSPARENT, 0, 0))
	stress_column.add_child(stress)
	hud.stress = stress
	return bar

func _refresh() -> void:
	if phase != "day" or hud.is_empty(): return
	var on_break: bool = game.career.get("on_break", false)
	hud.clock.text = " " + game.clock.text() + " "
	hud.day.text = "%s [color=#2a1f2d]%d[/color]" % [ui_text("day", "Dia"), game.day()]
	var points_text := "%s [color=#2a1f2d]%d[/color]" % [ui_text("points", "Pontos"), int(game.career.day_score)]
	if hud.points.text != points_text and not hud.points.text.is_empty(): MOTION.punch(hud.points, 1.2)
	hud.points.text = points_text
	var multiplier := 1 + int(game.career.combo) / 8
	# Combo: âmbar a partir de ×4, com sombra em pixel (#combo.hot).
	hud.combo.text = "Combo [color=%s]×%d[/color]" % ["#c47a14" if multiplier >= 4 else "#2a1f2d", multiplier]
	hud.rank.text = "%s [color=#2a1f2d]%s[/color]" % [ui_text("rank", "Cargo"), str(game.texts().ranks[int(game.career.rank)])]
	hud.wallet.text = "%s [color=#2a1f2d]R$ %d[/color]" % [ui_text("wallet", "Carteira"), int(game.profile.wallet)]
	hud.stress.value = float(game.career.stress)
	hud.pause.text = "Continuar" if game.paused else "Pausar"
	hud.coffee.text = "Café ×%d" % int(game.career.inv.get("cafe", 0))
	if is_instance_valid(break_button):
		break_button.visible = game.clock.break_unlocked()
		break_button.text = "Voltar do intervalo" if on_break else "Intervalo"
		break_button.disabled = not on_break and not game.break_available()
	var ids: Array = []
	for task in game.tasks: ids.append(task.id)
	var signature := str(ids)
	if signature != task_signature:
		task_signature = signature
		_build_tasks()
	for id in bars:
		var task: Dictionary = game.get_task(id)
		if task.is_empty(): continue
		var left := maxf(0, 1 - float(task.life) / float(task.ttl))
		bars[id].value = left * 100
		# Barra verde, âmbar quando está acabando e vermelha no fim (.task.soon / .task.late).
		var fill: StyleBoxFlat = bars[id].get_theme_stylebox("fill")
		fill.bg_color = Color("5fa79a") if left > 0.45 else (WARN if left > 0.2 else DANGER)
	var event_key := str(game.events.keys()) + str(game.events.get("virus", 0))
	if event_signature != event_key:
		event_signature = event_key
		_build_events()

func _task_card(task: Dictionary) -> Dictionary:
	var card := PanelContainer.new()
	var box := STYLE.flat(STYLE.PAPER, STYLE.INK, 2, 10)
	box.shadow_color = Color(STYLE.INK, 0.25)
	box.shadow_offset = Vector2(0, 5)
	box.shadow_size = 0
	card.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	column.add_child(head)
	var icons := {"button": "postit", "email": "mail", "type": "postit", "call": "phone", "printer": "printer", "video": "camera"}
	var icon := TextureRect.new()
	icon.texture = PIXEL.sprite(icons.get(task.type, "postit"), 2)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var title := label(ui_text(TASK_TITLES.get(task.type, "pending"), str(task.type)).to_upper(), head, 17, MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not str(task.text).is_empty(): label(str(task.text), column, 20)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	column.add_child(actions)
	var timer := ProgressBar.new()
	timer.show_percentage = false
	timer.custom_minimum_size.y = 8
	timer.add_theme_stylebox_override("background", STYLE.flat(Color("e9dcc2"), Color.TRANSPARENT, 0, 0))
	timer.add_theme_stylebox_override("fill", STYLE.flat(Color("5fa79a"), Color.TRANSPARENT, 0, 0))
	column.add_child(timer)
	# Entrada do cartão: cresce de 90 % e aparece (keyframes pop).
	card.modulate.a = 0.0
	card.ready.connect(func() -> void:
		await card.get_tree().process_frame
		MOTION.pop(card))
	return {"card": card, "actions": actions, "timer": timer}

func _build_tasks() -> void:
	for child in task_box.get_children():
		task_box.remove_child(child)
		child.queue_free()
	bars.clear()
	for task in game.tasks:
		var id := int(task.id)
		var parts := _task_card(task)
		task_box.add_child(parts.card)
		var panel: VBoxContainer = parts.actions
		bars[id] = parts.timer
		match task.type:
			"button", "email":
				if task.variant == "complex":
					for step in 3: button("%d. %s" % [step + 1, ui().prog.steps[step]], game.task_action.bind(id, str(step)), panel)
				elif task.variant == "sector" or task.type == "email":
					if task.type == "button": label("Setor: " + str(game.texts().sectors[task.sector]), panel, 18, MUTED)
					var grid := GridContainer.new()
					grid.columns = 2
					grid.add_theme_constant_override("h_separation", 4)
					grid.add_theme_constant_override("v_separation", 4)
					panel.add_child(grid)
					for sector in game.SECTORS:
						var forward := button(game.texts().sectors[sector], game.task_action.bind(id, sector), grid, PIXEL.sprite({"fin": "glyphFin", "rh": "glyphHr", "jur": "glyphJur", "ti": "glyphTi"}[sector], 1))
						forward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					if task.type == "email" and game.available("spam"): button("Spam", game.task_action.bind(id, "spam"), panel)
				else: button("OK", game.task_action.bind(id, ""), panel)
			"type":
				var input := LineEdit.new()
				input.placeholder_text = ui_text("typeHint", "digite e aperte Enter")
				panel.add_child(input)
				input.text_submitted.connect(func(value: String) -> void: game.task_action(id, value))
			"call":
				label("Atenda o telefone da sua mesa: mire nele e segure E.", panel, 18, MUTED)
			"printer":
				label("A impressora travou! Vá até o canto da sala e conserte os círculos brilhantes.", panel, 18, MUTED)
			"video": button(ui_text("accept", "Aceitar"), game.task_action.bind(id, ""), panel)

func _build_events() -> void:
	for child in event_box.get_children():
		event_box.remove_child(child)
		child.queue_free()
	if game.events.has("boss"):
		var boss := label("%s  Corra até a cadeira e sente!" % ui_text("bossComing", "O CHEFE VEM AÍ!"), event_box, 22, DANGER)
	if game.events.has("virus"):
		var virus := button("%s  ✕ (%d)" % [ui_text("warning", "AVISO!!!"), game.events.virus], game.close_virus, event_box, PIXEL.sprite("virus", 2))
		virus.add_theme_color_override("font_color", DANGER)
	if game.events.has("video"):
		button(ui_text("meeting", "Reunião rápida") + ": responder", func() -> void:
			if not game.active() or not game.events.has("video"): return
			game.success(8)
			game.events.video.left -= 1
			if game.events.video.left <= 0:
				game.events.erase("video")
				game.stat("videos"), event_box, PIXEL.sprite("camera", 2))

func _unhandled_key_input(event: InputEvent) -> void:
	if desktop == null or desktop.current_app != "workday" or not visible or phase != "day" or not game.active(): return
	if not event is InputEventKey: return
	if event.keycode in [KEY_SPACE, KEY_DOWN]:
		game.fast = event.pressed
		get_viewport().set_input_as_handled()
	if not event.pressed or event.echo: return
	match event.keycode:
		KEY_LEFT: game.move_file(int(game.file.lane) - 1)
		KEY_RIGHT: game.move_file(int(game.file.lane) + 1)
		KEY_DELETE: game.delete_file()
		KEY_1: game.use_coffee()
		_:
			for task in game.tasks.duplicate():
				if task.type == "printer": game.task_action(task.id, OS.get_keycode_string(event.keycode))
