extends RefCounted
## Aplicativos do WorkOS montados em código no visual do original (40-eventos.js, 29-perfil.js, 09-telas.js):
## Calendário (mês com dias do expediente, broches dos eventos e balão de detalhes), Perfil (crachá),
## Arquivo (abas com cartões), Configurações (idioma, som, música, movimento) e Catálogo (vitrine da loja).

const PIXEL := preload("res://scripts/workos/pixel.gd")
const STYLE := preload("res://scripts/workos/os_style.gd")
const MOTION := preload("res://scripts/workos/motion.gd")
const MUTED := Color("8f7d63")
const OK := Color("2f8a45")
const SKY := Color("c3d5ff")
const MONTHS := ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
const WEEKDAYS := ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]

static func label(parent: Node, text: String, size := 20, color := STYLE.INK, wrap := true) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	if wrap: item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item)
	return item

static func button(parent: Node, text: String, action: Callable, icon: Texture2D = null) -> Button:
	var item := Button.new()
	item.text = text
	item.icon = icon
	item.focus_mode = Control.FOCUS_NONE
	item.pressed.connect(action)
	parent.add_child(item)
	return item

static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

static func card(parent: Node, fill := STYLE.PAPER, padding := 10.0) -> VBoxContainer:
	var panel := PanelContainer.new()
	var box := STYLE.flat(fill, STYLE.INK, 2, padding)
	box.shadow_color = Color("dcc6a0")
	box.shadow_offset = Vector2(3, 3)
	box.shadow_size = 1
	panel.add_theme_stylebox_override("panel", box)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	return column

static func scroll(parent: Node) -> VBoxContainer:
	var area := ScrollContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(area)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	area.add_child(list)
	return list

# ---------------------------------------------------------------- Calendário

static func calendar(root: VBoxContainer, game: Node) -> void:
	var state := {"month": 0, "selected": -1}
	var first: Dictionary = game.clock.date(game.clock.today())
	state.year = int(first.year)
	state.month = int(first.month)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	root.add_child(header)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	body.add_child(grid)
	var balloon_holder := VBoxContainer.new()
	balloon_holder.custom_minimum_size.x = 270
	body.add_child(balloon_holder)
	var holder := {}
	var shift := func(delta: int) -> void:
		state.month += delta
		if state.month < 1:
			state.month = 12
			state.year -= 1
		elif state.month > 12:
			state.month = 1
			state.year += 1
		state.selected = -1
		holder.paint.call()
	button(header, "◀", shift.bind(-1))
	var title := label(header, "", 30, STYLE.INK, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(header, "▶", shift.bind(1))
	button(header, "Hoje", func() -> void:
		state.year = int(first.year)
		state.month = int(first.month)
		state.selected = game.clock.today()
		holder.paint.call())
	holder.paint = func() -> void:
		clear(grid)
		clear(balloon_holder)
		title.text = "%s de %d" % [MONTHS[int(state.month) - 1], int(state.year)]
		for weekday in WEEKDAYS:
			var head := label(grid, weekday, 18, MUTED, false)
			head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Dias da carreira que caem neste mês (o dia N da carreira é o N-ésimo dia útil).
		var career_days := {}
		for career_day in range(1, 400):
			var date: Dictionary = game.clock.date(career_day)
			if int(date.year) > int(state.year) or (int(date.year) == int(state.year) and int(date.month) > int(state.month)): break
			if int(date.year) == int(state.year) and int(date.month) == int(state.month): career_days[int(date.day)] = career_day
		var first_unix := Time.get_unix_time_from_datetime_dict({"year": state.year, "month": state.month, "day": 1})
		var lead := int(Time.get_datetime_dict_from_unix_time(first_unix).weekday)
		var days_in_month := 31
		while Time.get_datetime_dict_from_unix_time(first_unix + (days_in_month - 1) * 86400).month != state.month: days_in_month -= 1
		for index in lead: grid.add_child(Control.new())
		for day in range(1, days_in_month + 1):
			var career_day: int = career_days.get(day, 0)
			grid.add_child(_calendar_cell(game, day, career_day, (lead + day - 1) % 7 in [0, 6], func() -> void:
				state.selected = career_day
				holder.paint.call()))
		if int(state.selected) > 0: _calendar_balloon(balloon_holder, game, int(state.selected))
		else: label(balloon_holder, "Clique num dia do expediente para ver os eventos.", 18, MUTED)
	holder.paint.call()

static func _events_on(game: Node, career_day: int) -> Array:
	var found: Array = []
	for event in game.data.special:
		var cycle := int(game.data.cycle)
		var period: Vector2i = game.quest_window(event)
		var current_cycle := floori((game.day() - 1) / float(cycle))
		var target_cycle := floori((career_day - 1) / float(cycle))
		var offset := (target_cycle - current_cycle) * cycle
		if career_day >= period.x + offset and career_day <= period.y + offset: found.append(event)
	return found

static func _calendar_cell(game: Node, day: int, career_day: int, weekend: bool, action: Callable) -> Control:
	var cell := Button.new()
	cell.custom_minimum_size = Vector2(78, 62)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.focus_mode = Control.FOCUS_NONE
	var today: bool = career_day > 0 and career_day == game.clock.today()
	var fill := Color("e9dcc2") if weekend or career_day == 0 else STYLE.PAPER
	var box := STYLE.flat(fill, STYLE.BLUE if today else STYLE.INK, 3 if today else 2, 4)
	cell.add_theme_stylebox_override("normal", box)
	cell.add_theme_stylebox_override("hover", STYLE.flat(SKY, STYLE.INK, 2, 4))
	cell.add_theme_stylebox_override("pressed", STYLE.flat(SKY, STYLE.BLUE, 3, 4))
	cell.disabled = career_day == 0
	cell.add_theme_stylebox_override("disabled", box)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 6
	column.offset_top = 2
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(column)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	label(top, str(day), 22, STYLE.INK if career_day > 0 else MUTED, false)
	if career_day > 0:
		var worked: bool = career_day < game.day() or (career_day == game.day() and game.career.get("phase", "") == "ended")
		var tag := label(top, "  ok" if worked else "", 16, OK, false)
		tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label(column, "Dia %d" % career_day, 15, MUTED, false)
		var icons := HBoxContainer.new()
		icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(icons)
		for event in _events_on(game, career_day):
			var icon := TextureRect.new()
			icon.texture = PIXEL.texture(game.data.pins.get(event.pin, []), 2)
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icons.add_child(icon)
	for node in cell.find_children("*", "Control", true, false): node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.pressed.connect(action)
	return cell

## Balão de detalhes do dia: eventos, progresso, recompensa e participar.
static func _calendar_balloon(holder: VBoxContainer, game: Node, career_day: int) -> void:
	var ev: Dictionary = game.texts().ui.ev
	var date: Dictionary = game.clock.date(career_day)
	var box := card(holder, SKY, 12)
	label(box, "Dia %d · %02d/%02d" % [career_day, int(date.day), int(date.month)], 24)
	var events := _events_on(game, career_day)
	if events.is_empty(): label(box, "Sem evento especial neste dia.", 18, MUTED)
	for event in events:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var icon := TextureRect.new()
		icon.texture = PIXEL.texture(game.data.pins.get(event.pin, []), 3)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		label(row, str(ev.names[event.id]), 21).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label(box, str(ev.desc[event.id]), 17)
		var progress: Dictionary = game.quests.active.get(event.id, {}).get("progress", {})
		for step in event.steps:
			label(box, "· %s: %d / %d" % [_step_name(step[0]), progress.get(step[0], game.profile.decor.size() if step[0] == "decor" else 0), step[1]], 17, MUTED)
		label(box, "Recompensa: " + str(ev.pins[event.pin]), 17, STYLE.BLUE)
		if game.quests.done.has(event.id): label(box, "Concluída", 19, OK)
		else:
			var period: Vector2i = game.quest_window(event)
			var join := button(box, "Participar", func() -> void: game.join_quest(event.id))
			join.disabled = game.day() < period.x or game.day() > period.y
			if event.steps.any(func(step: Array) -> bool: return step[0] == "sign"):
				button(box, "Assinar cartão", func() -> void: game.sign_quest(event.id))

static func _step_name(id: String) -> String:
	return {"files": "Documentos arquivados", "emails": "E-mails respondidos", "typed": "Relatórios digitados", "cafe": "Cafés", "bosses": "Escapar do chefe", "sign": "Assinar cartão", "decor": "Enfeites adquiridos", "duda": "Partidas com Duda", "buy": "Presentes comprados", "calm": "Estresse abaixo de"}.get(id, id)

# ---------------------------------------------------------------- Personalizar

## PERSONALIZAR.EXE (showCustomize de 30-personalizar.js): abas por categoria e prévia viva à direita.
## Papel de parede em miniaturas, cores das janelas e da barra, crachá e cordão, e o vídeo do mundo 3D.
static func customize(root: VBoxContainer, desk: Control) -> void:
	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 6)
	root.add_child(tabs_row)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)
	var options := scroll(body)
	var state := {"tab": "wall"}
	var tab_buttons := {}
	var holder := {}
	var tab_names := {"wall": "Papel de parede", "os": "Cores", "badge": "Crachá", "video": "Tela 3D"}
	for key in tab_names:
		var tab := Button.new()
		tab.text = tab_names[key]
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_NONE
		tab.pressed.connect(func() -> void:
			state.tab = key
			holder.paint.call())
		tabs_row.add_child(tab)
		tab_buttons[key] = tab
	holder.paint = func() -> void:
		clear(options)
		for key in tab_buttons: tab_buttons[key].set_pressed_no_signal(key == state.tab)
		match state.tab:
			"wall": _wallpaper_options(options, desk, holder.paint)
			"os":
				_swatch_row(options, "Cor das janelas", STYLE.ACCENTS, "accent", desk, holder.paint)
				_swatch_row(options, "Barra de tarefas", STYLE.BARS, "bar", desk, holder.paint)
			"badge":
				_swatch_row(options, "Cor do crachá", STYLE.BADGES, "badge", desk, holder.paint)
				_swatch_row(options, "Cordão do crachá", STYLE.BADGES, "lanyard", desk, holder.paint)
			"video": _video_options(options, desk)
	holder.paint.call()

static func _theme_value(desk: Control, key: String, fallback: String) -> String:
	return str(desk.settings.get_value("theme", key, fallback))

static func _palette_entry(palette: Dictionary, id: String) -> Array:
	return palette[id] if palette.has(id) else palette[palette.keys()[0]]

static func _wallpaper_options(list: VBoxContainer, desk: Control, repaint: Callable) -> void:
	label(list, "Papel de parede", 18, MUTED, false)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	list.add_child(grid)
	var current := str(desk.settings.get_value("desktop", "wallpaper", "xadrez-workos"))
	for id in desk.WALLPAPERS:
		var choice := Button.new()
		choice.toggle_mode = true
		choice.button_pressed = id == current
		choice.focus_mode = Control.FOCUS_NONE
		choice.custom_minimum_size = Vector2(142, 104)
		choice.tooltip_text = desk.wallpaper_name(id)
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.offset_left = 8
		column.offset_top = 6
		column.offset_right = -8
		column.offset_bottom = -6
		column.add_theme_constant_override("separation", 2)
		choice.add_child(column)
		var thumb := TextureRect.new()
		thumb.texture = desk.wallpaper_texture(id)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_TILE if id == "xadrez-workos" else TextureRect.STRETCH_SCALE
		thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(thumb)
		var caption := label(column, desk.wallpaper_name(id), 16, STYLE.INK, false)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.clip_text = true
		choice.pressed.connect(func() -> void:
			desk._set_wallpaper(id)
			desk.fx.sound("click")
			repaint.call())
		grid.add_child(choice)

## Linha de amostras quadradas (cseg de 30-personalizar.js): o nome da cor escolhida aparece ao lado do rótulo.
static func _swatch_row(list: VBoxContainer, title: String, palette: Dictionary, key: String, desk: Control, repaint: Callable) -> void:
	var current := _theme_value(desk, key, "bege" if key == "bar" else "azul")
	var head := HBoxContainer.new()
	list.add_child(head)
	label(head, title, 18, MUTED, false)
	var name := label(head, current.capitalize(), 18, STYLE.BLUE, false)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	list.add_child(flow)
	for id in palette:
		var colors: Array = palette[id]
		var swatch := Button.new()
		swatch.toggle_mode = true
		swatch.button_pressed = id == current
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.custom_minimum_size = Vector2(46, 46)
		swatch.tooltip_text = str(id).capitalize()
		var base := Color(colors[0])
		var high := Color(colors[1])
		var shade := Color(colors[2]) if colors.size() > 2 else base.darkened(0.3)
		var box := STYLE.bevel(base, high, shade, true, STYLE.INK, 2, 3, Vector4(0, 0, 0, 0))
		var on_box := STYLE.bevel(base, high, shade, false, Color("f4c15d"), 3, 3, Vector4(0, 0, 0, 0))
		for style_name in ["normal", "hover"]: swatch.add_theme_stylebox_override(style_name, box)
		for style_name in ["pressed", "hover_pressed"]: swatch.add_theme_stylebox_override(style_name, on_box)
		swatch.pressed.connect(func() -> void:
			desk.set_theme_color(key, str(id))
			desk.fx.sound("click")
			repaint.call())
		flow.add_child(swatch)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	list.add_child(gap)

static func _video_options(list: VBoxContainer, desk: Control) -> void:
	label(list, "Efeito de vídeo do mundo 3D", 18, MUTED, false)
	var effects := OptionButton.new()
	for effect_name in desk.WORLD_EFFECT_NAMES: effects.add_item(effect_name)
	effects.selected = maxi(0, desk.WORLD_EFFECTS.find(desk.video_world()))
	list.add_child(effects)
	var crt := CheckBox.new()
	crt.text = "Tela CRT no monitor"
	crt.button_pressed = desk.video_crt()
	list.add_child(crt)
	effects.item_selected.connect(func(index: int) -> void: desk._set_video(desk.WORLD_EFFECTS[index], crt.button_pressed))
	crt.toggled.connect(func(on: bool) -> void: desk._set_video(desk.WORLD_EFFECTS[effects.selected], on))
	label(list, "PSX e VHS mudam a aparência do escritório 3D; a tela CRT só afeta o monitor.", 16, MUTED)

# ---------------------------------------------------------------- Perfil (crachá)

static func profile(root: VBoxContainer, game: Node, on_change: Callable, colors := {}) -> void:
	var page := HBoxContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 18)
	root.add_child(page)
	# Crachá: cordão, cartão com faixa azul, foto, nome, número, cargo e código de barras.
	var badge_column := VBoxContainer.new()
	badge_column.add_theme_constant_override("separation", 0)
	page.add_child(badge_column)
	var strap := ColorRect.new()
	strap.color = Color(colors.get("lanyard", STYLE.BLUE))
	strap.custom_minimum_size = Vector2(26, 34)
	strap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge_column.add_child(strap)
	var clip := ColorRect.new()
	clip.color = Color("9aa0ab")
	clip.custom_minimum_size = Vector2(44, 10)
	clip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge_column.add_child(clip)
	var badge := PanelContainer.new()
	var badge_box := STYLE.flat(STYLE.PAPER, STYLE.INK, 3, 0)
	badge_box.shadow_color = Color(STYLE.INK, 0.3)
	badge_box.shadow_offset = Vector2(5, 5)
	badge_box.shadow_size = 1
	badge.add_theme_stylebox_override("panel", badge_box)
	badge.custom_minimum_size = Vector2(250, 0)
	badge_column.add_child(badge)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	badge.add_child(inner)
	var band := label(inner, "  WORKDAY LTDA.", 22, STYLE.PAPER, false)
	band.add_theme_stylebox_override("normal", STYLE.flat(Color(colors.get("badge", STYLE.BLUE)), Color.TRANSPARENT, 0, 6))
	var photo_frame := PanelContainer.new()
	photo_frame.add_theme_stylebox_override("panel", STYLE.flat(SKY, STYLE.INK, 2, 4))
	photo_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(photo_frame)
	var photo := TextureRect.new()
	photo.texture = PIXEL.os_pic(str(game.profile.get("os_pic", "gato")), 9)
	photo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	photo_frame.add_child(photo)
	var name := label(inner, str(game.profile.name), 28, STYLE.INK, false)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var role := label(inner, str(game.texts().ranks[int(game.career.get("rank", 0))]), 20, MUTED, false)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var number := label(inner, "Nº %d" % int(game.profile.id), 20, STYLE.INK, false)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var barcode := TextureRect.new()
	barcode.texture = _barcode(int(game.profile.id))
	barcode.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	barcode.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(barcode)
	inner.add_child(Control.new())
	# Edição: nome, foto e números.
	var side := scroll(page)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var edit := card(side)
	label(edit, "Nome no crachá", 18, MUTED)
	var row := HBoxContainer.new()
	edit.add_child(row)
	var field := LineEdit.new()
	field.text = game.profile.name
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.max_length = 24
	row.add_child(field)
	var save_name := func() -> void:
		if field.text.strip_edges().is_empty(): return
		game.profile.name = field.text.strip_edges()
		name.text = game.profile.name
		game.save_game()
		on_change.call()
	button(row, "Salvar", save_name)
	field.text_submitted.connect(func(_value: String) -> void: save_name.call())
	label(edit, "Foto", 18, MUTED)
	var pics := HFlowContainer.new()
	pics.add_theme_constant_override("h_separation", 6)
	pics.add_theme_constant_override("v_separation", 6)
	edit.add_child(pics)
	for id in PIXEL.os_pic_ids():
		var choice := Button.new()
		choice.icon = PIXEL.os_pic(id, 3)
		choice.toggle_mode = true
		choice.button_pressed = id == str(game.profile.get("os_pic", "gato"))
		choice.focus_mode = Control.FOCUS_NONE
		choice.add_theme_stylebox_override("pressed", STYLE.bevel(SKY, STYLE.BLUE_HI, STYLE.PAPER, false, STYLE.INK, 2, 2, Vector4(6, 6, 6, 6)))
		choice.pressed.connect(func() -> void:
			game.profile.os_pic = id
			photo.texture = PIXEL.os_pic(id, 9)
			for other in pics.get_children(): other.set_pressed_no_signal(other == choice)
			game.save_game()
			on_change.call())
		pics.add_child(choice)
	var stats := card(side)
	label(stats, "Números", 18, MUTED)
	var ui: Dictionary = game.texts().ui
	for pair in [[ui.get("record", "Recorde"), str(int(game.profile.best))], [ui.get("wallet", "Carteira"), "R$ %d" % int(game.profile.wallet)], [ui.get("daysWorked", "Dias trabalhados"), str(int(game.profile.stats.get("days", 0)))], [ui.get("files", "Arquivos"), str(int(game.profile.stats.get("files", 0)))], [ui.get("careers", "Carreiras"), str(int(game.profile.stats.get("careers", 0)))]]:
		var line := HBoxContainer.new()
		stats.add_child(line)
		label(line, str(pair[0]), 20).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label(line, pair[1], 20, STYLE.BLUE, false)
	var pins_box := card(side)
	label(pins_box, "Broches (%d)" % game.quests.pins.size(), 18, MUTED)
	var pins_row := HFlowContainer.new()
	pins_box.add_child(pins_row)
	for id in game.data.pins:
		var icon := TextureRect.new()
		icon.texture = PIXEL.texture(game.data.pins[id], 3)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.tooltip_text = str(game.texts().ui.ev.pins.get(id, id))
		if not id in game.quests.pins: icon.modulate = Color(0.2, 0.2, 0.25, 0.35)
		pins_row.add_child(icon)

static func _barcode(seed: int) -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var image := Image.create(120, 28, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var x := 0
	while x < 120:
		var width := rng.randi_range(1, 3)
		image.fill_rect(Rect2i(x, 0, width, 28), STYLE.INK)
		x += width + rng.randi_range(1, 3)
	return ImageTexture.create_from_image(image)

# ---------------------------------------------------------------- Arquivo

static func archive(root: VBoxContainer, game: Node) -> void:
	var ev: Dictionary = game.texts().ui.ev
	var tabs := TabBar.new()
	tabs.focus_mode = Control.FOCUS_NONE
	for key in ["quests", "pins", "unlocks", "ach"]: tabs.add_tab(str(ev.sections[key]))
	root.add_child(tabs)
	var list := scroll(root)
	var show := func(index: int) -> void:
		clear(list)
		match index:
			0:
				for event in game.data.special:
					var done: bool = game.quests.done.has(event.id)
					_archive_card(list, PIXEL.texture(game.data.pins.get(event.pin, []), 3), str(ev.names[event.id]), str(ev.desc[event.id]), "Concluída" if done else "Pendente", done)
			1:
				for id in game.data.pins:
					var owned: bool = id in game.quests.pins
					_archive_card(list, PIXEL.texture(game.data.pins[id], 3), str(ev.pins.get(id, id)), "", "Na coleção" if owned else "Bloqueado", owned)
			2:
				for id in game.data.locked:
					var open: bool = id in game.quests.unlocks
					_archive_card(list, PIXEL.app_icon("customize", 3), str(ev.unlocks.get(id, id)), "" if open else "Complete: " + str(ev.names[game.data.locked[id]]), "Liberado" if open else "Bloqueado", open)
			3:
				for id in ev.ach:
					var got: bool = game.quests.ach.has(id)
					_archive_card(list, PIXEL.sprite("trophy", 3), str(ev.ach[id][0]), str(ev.ach[id][1]), "Desbloqueada" if got else "Bloqueada", got)
	tabs.tab_changed.connect(show)
	show.call(0)

static func _archive_card(list: VBoxContainer, icon: Texture2D, title: String, description: String, status: String, ok: bool) -> void:
	var box := card(list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var picture := TextureRect.new()
	picture.texture = icon
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	picture.custom_minimum_size = Vector2(48, 48)
	if not ok: picture.modulate = Color(0.45, 0.45, 0.5, 0.6)
	row.add_child(picture)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	label(text, title, 22)
	if not description.is_empty(): label(text, description, 17, MUTED)
	var tag := label(row, " %s " % status, 17, STYLE.PAPER, false)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_theme_stylebox_override("normal", STYLE.flat(OK if ok else Color("9aa0ab"), STYLE.INK, 2, 2))

# ---------------------------------------------------------------- Configurações

static func settings(root: VBoxContainer, desktop: Control) -> void:
	var game: Node = desktop.game
	var list := scroll(root)
	var section := func(title: String) -> VBoxContainer:
		var head := label(list, " " + title, 20, STYLE.PAPER, false)
		head.add_theme_stylebox_override("normal", STYLE.flat(STYLE.INK, Color.TRANSPARENT, 0, 3))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		list.add_child(box)
		return box
	var row := func(parent: VBoxContainer, title: String, control: Control) -> void:
		var line := HBoxContainer.new()
		parent.add_child(line)
		label(line, title, 20).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.custom_minimum_size.x = 260
		line.add_child(control)
	var general: VBoxContainer = section.call("Geral")
	var language := OptionButton.new()
	for item in [["pt", "Português"], ["en", "English"], ["es", "Español"]]: language.add_item(item[1])
	language.selected = maxi(0, ["pt", "en", "es"].find(str(game.profile.language)))
	language.item_selected.connect(func(index: int) -> void:
		game.profile.language = ["pt", "en", "es"][index]
		game.save_game()
		desktop.toast("WorkOS", "Idioma alterado. Os textos do jogo usam o novo idioma."))
	row.call(general, "Idioma dos textos do jogo", language)
	var difficulty := OptionButton.new()
	var diff_ids := ["facil", "normal", "dificil", "burnout"]
	for id in diff_ids: difficulty.add_item(str(game.texts().ui.get("diffNames", {}).get(id, id)))
	difficulty.selected = maxi(0, diff_ids.find(str(game.profile.difficulty)))
	difficulty.disabled = not game.career.is_empty() and game.career.get("phase", "") in ["day", "ready", "ended", "promotion"]
	difficulty.tooltip_text = str(game.texts().ui.get("diffLocked", ""))
	difficulty.item_selected.connect(func(index: int) -> void:
		game.profile.difficulty = diff_ids[index]
		game.save_game())
	row.call(general, "Dificuldade", difficulty)
	var motion := CheckBox.new()
	motion.text = "Ligado"
	motion.button_pressed = desktop.fx.reduced_motion
	motion.toggled.connect(func(on: bool) -> void:
		desktop.fx.reduced_motion = on
		MOTION.reduced = on
		desktop.settings.set_value("workos", "reduced_motion", on)
		desktop.settings.save(desktop.SAVE_PATH))
	row.call(general, "Reduzir movimento", motion)
	var sound: VBoxContainer = section.call("Som")
	var effects := CheckBox.new()
	effects.text = "Ligado"
	effects.button_pressed = desktop.fx.sound_enabled
	effects.toggled.connect(func(on: bool) -> void:
		desktop.fx.sound_enabled = on
		desktop.settings.set_value("workos", "sfx", on)
		desktop.settings.save(desktop.SAVE_PATH)
		desktop.fx.sound("click"))
	row.call(sound, "Efeitos sonoros", effects)
	var effects_volume := HSlider.new()
	effects_volume.max_value = 1.0
	effects_volume.step = 0.05
	effects_volume.value = desktop.fx.volume
	effects_volume.value_changed.connect(func(value: float) -> void:
		desktop.fx.volume = value
		desktop.settings.set_value("workos", "sfx_volume", value)
		desktop.settings.save(desktop.SAVE_PATH))
	effects_volume.drag_ended.connect(func(_changed: bool) -> void: desktop.fx.sound("notify"))
	row.call(sound, "Volume dos efeitos", effects_volume)
	var music := CheckBox.new()
	music.text = "Ligada"
	music.button_pressed = desktop.music.sound_on
	music.toggled.connect(desktop.music.set_sound)
	row.call(sound, "Música (Rádio)", music)
	var music_volume := HSlider.new()
	music_volume.max_value = 1.0
	music_volume.step = 0.05
	music_volume.value = desktop.music.volume
	music_volume.value_changed.connect(desktop.music.set_volume)
	row.call(sound, "Volume da música", music_volume)
	var screen: VBoxContainer = section.call("Tela")
	var open_customize := Button.new()
	open_customize.text = "Abrir Personalizar"
	open_customize.pressed.connect(func() -> void: desktop.open_app("settings"))
	row.call(screen, "Papel de parede e efeitos de vídeo", open_customize)

# ---------------------------------------------------------------- Catálogo

static func catalog(root: VBoxContainer, game: Node) -> void:
	label(root, "Catálogo da loja · os itens são comprados no mercado, perto do escritório.", 18, MUTED)
	var tabs := TabBar.new()
	tabs.focus_mode = Control.FOCUS_NONE
	for title in ["Do dia", "Enfeites"]: tabs.add_tab(title)
	root.add_child(tabs)
	var list := scroll(root)
	var show := func(index: int) -> void:
		clear(list)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(grid)
		for item in game.data.shop:
			var decor: bool = item.kind == "decor"
			if decor != (index == 1): continue
			var box := card(grid)
			box.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			box.add_child(row)
			var icon := TextureRect.new()
			icon.texture = PIXEL.sprite(str(item.spr), 3)
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			icon.custom_minimum_size = Vector2(54, 54)
			row.add_child(icon)
			var text := VBoxContainer.new()
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(text)
			var info: Array = game.shop_name(str(item.id))
			label(text, str(info[0]), 21)
			label(text, str(info[1]), 16, MUTED)
			var owned: bool = decor and item.id in game.profile.decor
			var price := label(row, " Tem " if owned else " R$ %d " % int(item.price), 19, STYLE.PAPER, false)
			price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			price.add_theme_stylebox_override("normal", STYLE.flat(OK if owned else STYLE.BLUE, STYLE.INK, 2, 2))
	tabs.tab_changed.connect(show)
	show.call(0)
