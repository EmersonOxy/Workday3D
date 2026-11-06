extends HBoxContainer
## MSWORKN.EXE (porte visual de 46-mensageiro.js + 90-mensageiro.css): lateral bege com o próprio perfil em azul
## claro, grupos de contatos com foto, status colorido, recado e selo de não lidas; conversa com cabeçalho, balões
## (contato em azul, você em salmão, com sombra de 3 px), "digitando…", respostas sugeridas e campo de envio.
## A lógica social continua em social_state.gd.

const PIXEL := preload("res://scripts/workos/pixel.gd")
const STYLE := preload("res://scripts/workos/os_style.gd")
const STATUS_NAMES := {"online": "Online", "busy": "Ocupado", "away": "Ausente", "dnd": "Não perturbe", "invisible": "Invisível", "offline": "Offline"}
const STATUS_COLORS := {"online": Color("7ed98c"), "busy": Color("ef4b3f"), "away": Color("ffb938"), "dnd": Color("a8262a"), "invisible": Color("fff8ec"), "offline": Color("fff8ec")}
const MUTED := Color("8f7d63")
const SKY := Color("c3d5ff")
const SALMON := Color("ffd0b0")
const SAND := Color("f3e6cc")

var social: Node
var game: Node
var selected := ""
var list_box: VBoxContainer
var chat_box: VBoxContainer
var signature := ""
var list_signature := ""

func setup(state: Node) -> void:
	social = state
	game = social.game
	size_flags_vertical = SIZE_EXPAND_FILL
	size_flags_horizontal = SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)
	var side := PanelContainer.new()
	var side_box := STYLE.flat(SAND, STYLE.INK, 0, 0)
	side_box.border_width_right = 2
	side.add_theme_stylebox_override("panel", side_box)
	side.custom_minimum_size.x = 270
	add_child(side)
	var side_column := VBoxContainer.new()
	side_column.add_theme_constant_override("separation", 0)
	side.add_child(side_column)
	side_column.add_child(_me_header())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_column.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 0)
	scroll.add_child(list_box)
	chat_box = VBoxContainer.new()
	chat_box.size_flags_horizontal = SIZE_EXPAND_FILL
	chat_box.add_theme_constant_override("separation", 0)
	add_child(chat_box)
	social.changed.connect(_refresh)
	_refresh()

func _exit_tree() -> void:
	if social != null and social.changed.is_connected(_refresh): social.changed.disconnect(_refresh)

static func label(text: String, size := 19, color := STYLE.INK, italic := false) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	item.clip_text = true
	item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if italic: item.add_theme_font_override("font", _italic())
	return item

static var _italic_font: FontVariation
static func _italic() -> FontVariation:
	if _italic_font == null:
		_italic_font = FontVariation.new()
		_italic_font.base_font = STYLE.font()
		_italic_font.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
	return _italic_font

func _picture(id: String, size: int) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", STYLE.flat(STYLE.PAPER, STYLE.INK, 2, 0))
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(size, size)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path := "res://assets/workday/portraits/%s.png" % id
	if ResourceLoader.exists(path): picture.texture = load(path)
	else:
		var pics: Dictionary = PIXEL.ui().msn_pics
		var pic: Dictionary = pics.get(id, pics.get("unknown", {}))
		picture.texture = PIXEL.texture(pic.get("rows", []), 4, pic.get("pal", {}))
	frame.add_child(picture)
	return frame

func _dot(status: String) -> ColorRect:
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.color = STATUS_COLORS.get(status, Color("9aa0ab"))
	dot.size_flags_vertical = SIZE_SHRINK_CENTER
	return dot

## Cabeçalho da lateral (.msn-me): foto, nome, status e recado pessoal.
func _me_header() -> Control:
	var header := PanelContainer.new()
	var box := STYLE.flat(SKY, STYLE.INK, 0, 8)
	box.border_width_bottom = 2
	header.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	header.add_child(row)
	var pic := PanelContainer.new()
	pic.add_theme_stylebox_override("panel", STYLE.flat(STYLE.PAPER, STYLE.INK, 2, 1))
	var me := TextureRect.new()
	me.texture = PIXEL.os_pic(str(game.profile.get("os_pic", "gato")), 4)
	me.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.add_child(me)
	row.add_child(pic)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	info.add_child(label(str(game.profile.get("name", "Funcionário")), 23))
	var status := OptionButton.new()
	status.focus_mode = Control.FOCUS_NONE
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_stylebox_override("normal", STYLE.flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, 2))
	status.add_theme_stylebox_override("hover", STYLE.flat(STYLE.PAPER, Color.TRANSPARENT, 0, 2))
	var statuses := ["online", "busy", "away", "dnd", "invisible"]
	for id in statuses:
		var swatch := Image.create(10, 10, false, Image.FORMAT_RGBA8)
		swatch.fill(STYLE.INK)
		swatch.fill_rect(Rect2i(1, 1, 8, 8), STATUS_COLORS[id])
		status.add_icon_item(ImageTexture.create_from_image(swatch), STATUS_NAMES[id])
	status.selected = maxi(0, statuses.find(social.state.status))
	status.item_selected.connect(func(index: int) -> void:
		social.state.status = statuses[index]
		game.save_game())
	info.add_child(status)
	var personal := LineEdit.new()
	personal.placeholder_text = "Recado pessoal"
	personal.text = social.state.message
	personal.add_theme_font_override("font", _italic())
	personal.add_theme_font_size_override("font_size", 18)
	personal.add_theme_color_override("font_color", STYLE.BLUE)
	personal.add_theme_stylebox_override("normal", STYLE.flat(STYLE.PAPER, STYLE.BLUE_HI, 1, 3))
	personal.add_theme_stylebox_override("focus", STYLE.flat(STYLE.PAPER, STYLE.BLUE, 2, 3))
	personal.text_submitted.connect(func(value: String) -> void:
		social.state.message = value
		game.save_game())
	info.add_child(personal)
	return header

func _refresh() -> void:
	if not is_inside_tree(): return
	_refresh_list()
	_refresh_chat()

func _refresh_list() -> void:
	var known: Array = []
	var requests: Array = []
	for id in game.data.cast:
		var contact: Dictionary = social.state.contacts[id]
		if contact.status == "known": known.append(id)
		elif contact.status == "request": requests.append(id)
	var next := str(known) + str(requests) + selected
	for id in known: next += str(social.state.contacts[id].unread) + social.presence(id)
	if next == list_signature: return
	list_signature = next
	for child in list_box.get_children():
		list_box.remove_child(child)
		child.queue_free()
	if not requests.is_empty():
		list_box.add_child(_group("Solicitações (%d)" % requests.size(), Color("a8262a")))
		for id in requests: list_box.add_child(_contact_row(id, true))
	list_box.add_child(_group("Contatos (%d)" % known.size(), STYLE.BLUE))
	for id in known: list_box.add_child(_contact_row(id, false))
	if known.is_empty() and requests.is_empty():
		var empty := label("Nenhum contato ainda.", 18, MUTED)
		empty.custom_minimum_size.y = 40
		list_box.add_child(empty)

func _group(text: String, color: Color) -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_child(label(text, 18, color))
	return margin

## Linha de contato (.msn-c): foto, nome + bolinha de status, recado em itálico e selo de não lidas.
func _contact_row(id: String, request: bool) -> Control:
	var contact: Dictionary = social.state.contacts[id]
	var status: String = "offline" if request else social.presence(id)
	var row := Button.new()
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size.y = 50
	var active := id == selected
	var normal := STYLE.flat(STYLE.PAPER if active else Color.TRANSPARENT, Color.TRANSPARENT, 0, 4)
	if active:
		normal.border_width_left = 4
		normal.border_color = STYLE.BLUE_HI
	row.add_theme_stylebox_override("normal", normal)
	row.add_theme_stylebox_override("hover", STYLE.flat(STYLE.PAPER, Color.TRANSPARENT, 0, 4))
	row.add_theme_stylebox_override("pressed", STYLE.flat(SKY, Color.TRANSPARENT, 0, 4))
	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 8
	line.offset_right = -8
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var picture := _picture(id, 34)
	picture.size_flags_vertical = SIZE_SHRINK_CENTER
	if status in ["offline", "invisible"]: picture.modulate = Color(0.75, 0.75, 0.75, 0.85)
	line.add_child(picture)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", -2)
	line.add_child(text)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.add_child(_dot(status))
	var name := label(str(game.data.cast[id].name), 20)
	name.size_flags_horizontal = SIZE_EXPAND_FILL
	name_row.add_child(name)
	text.add_child(name_row)
	var role: Variant = game.data.cast[id].get("role", "")
	text.add_child(label("quer adicionar você" if request else social.text(role), 16, MUTED, true))
	var unread := int(contact.get("unread", 0))
	if unread > 0 or request:
		var badge := label(" + " if request else " %d " % unread, 16, STYLE.PAPER)
		badge.clip_text = false
		badge.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		badge.add_theme_stylebox_override("normal", STYLE.flat(Color("ef4b3f"), STYLE.INK, 2, 1))
		badge.size_flags_vertical = SIZE_SHRINK_CENTER
		line.add_child(badge)
	for node in line.find_children("*", "Control", true, false): node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.pressed.connect(func() -> void:
		selected = id
		social.reading = id
		contact.unread = 0
		signature = ""
		social.changed.emit())
	return row

func _clear_chat() -> void:
	for child in chat_box.get_children():
		chat_box.remove_child(child)
		child.queue_free()

func _refresh_chat() -> void:
	if selected.is_empty():
		if signature == "pick": return
		signature = "pick"
		_clear_chat()
		var pick := VBoxContainer.new()
		pick.size_flags_vertical = SIZE_EXPAND_FILL
		pick.alignment = BoxContainer.ALIGNMENT_CENTER
		chat_box.add_child(pick)
		var logo := TextureRect.new()
		logo.texture = PIXEL.app_icon("messenger", 6)
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		pick.add_child(logo)
		var title := label("MSworkN", 40, STYLE.BLUE)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pick.add_child(title)
		var hint := label("Escolha um contato para conversar.", 20, MUTED)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pick.add_child(hint)
		return
	var contact: Dictionary = social.state.contacts[selected]
	var options: Array = social.choices(selected)
	var next: String = str(contact) + str(options) + str(social.state.threads.get(selected, {}).get("queue", [])) + social.presence(selected)
	if next == signature: return
	signature = next
	_clear_chat()
	chat_box.add_child(_chat_header(selected, contact))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_stylebox_override("panel", STYLE.flat(STYLE.PAPER, Color.TRANSPARENT, 0, 0))
	chat_box.add_child(scroll)
	var log := VBoxContainer.new()
	log.size_flags_horizontal = SIZE_EXPAND_FILL
	log.add_theme_constant_override("separation", 8)
	var log_margin := MarginContainer.new()
	log_margin.size_flags_horizontal = SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]: log_margin.add_theme_constant_override("margin_" + side, 10)
	log_margin.add_child(log)
	scroll.add_child(log_margin)
	var previous := ""
	for message in contact.log:
		var who: String = "me" if message.mine else selected
		log.add_child(_bubble(who, str(message.text), who == previous))
		previous = who
	if social.state.threads.has(selected) and options.is_empty():
		log.add_child(label(str(game.data.cast[selected].name).split(" ")[0] + " está digitando…", 18, MUTED, true))
	# Rola até o fim depois de montar.
	scroll.call_deferred("set", "scroll_vertical", 1_000_000)
	var reply := VBoxContainer.new()
	reply.add_theme_constant_override("separation", 6)
	var reply_margin := MarginContainer.new()
	for side in ["left", "right", "bottom"]: reply_margin.add_theme_constant_override("margin_" + side, 8)
	reply_margin.add_child(reply)
	chat_box.add_child(reply_margin)
	if contact.status == "request":
		var bio := label(social.text(game.data.cast[selected].get("bio", "")), 18, MUTED)
		bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bio.clip_text = false
		bio.custom_minimum_size.x = 240
		bio.size_flags_horizontal = SIZE_EXPAND_FILL
		reply.add_child(bio)
		reply.add_child(_option("Aceitar contato", social.accept_contact.bind(selected), false))
	elif not options.is_empty():
		for index in options.size(): reply.add_child(_option(social.fill(options[index].t), social.choose.bind(selected, index), false))
	elif not social.state.threads.has(selected):
		for topic in social.topics(selected): reply.add_child(_option(social.text(topic.get("topic", topic.id)), social.start_thread.bind(topic.id), true))
		if selected == "duda" and not social.done("duda_hello"): reply.add_child(_option("Dizer oi ao Duda", social.start_thread.bind("duda_hello"), true))
	chat_box.add_child(_compose(contact))

func _chat_header(id: String, contact: Dictionary) -> Control:
	var header := PanelContainer.new()
	var box := STYLE.flat(STYLE.CREAM, STYLE.INK, 0, 8)
	box.border_width_bottom = 2
	header.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	header.add_child(row)
	row.add_child(_picture(id, 48))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	info.add_child(label(str(game.data.cast[id].name), 24))
	var status: String = social.presence(id)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 6)
	status_row.add_child(_dot(status))
	status_row.add_child(label("%s · %s" % [STATUS_NAMES.get(status, status), social.text(game.data.cast[id].get("role", ""))], 18, MUTED))
	info.add_child(status_row)
	return header

## Balão (.msn-m): nome em cima (azul o contato, laranja você) e o texto numa caixa com contorno e sombra.
func _bubble(who: String, text: String, continued: bool) -> Control:
	var mine := who == "me"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = SIZE_SHRINK_END if mine else SIZE_SHRINK_BEGIN
	if not continued:
		var name := label("Você" if mine else str(game.data.cast[who].name), 17, Color("c25f3b") if mine else STYLE.BLUE)
		name.clip_text = false
		name.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		name.size_flags_horizontal = SIZE_SHRINK_END if mine else SIZE_SHRINK_BEGIN
		column.add_child(name)
	var box := PanelContainer.new()
	var style := STYLE.flat(SALMON if mine else SKY, STYLE.INK, 2, 8)
	style.shadow_color = Color("dcc6a0")
	style.shadow_offset = Vector2(3, 3)
	style.shadow_size = 0
	box.add_theme_stylebox_override("panel", style)
	box.size_flags_horizontal = SIZE_SHRINK_END if mine else SIZE_SHRINK_BEGIN
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = mini(430, 30 + text.length() * 10)
	body.add_theme_font_size_override("font_size", 20)
	box.add_child(body)
	column.add_child(box)
	return column

func _option(text: String, action: Callable, topic: bool) -> Button:
	var option := Button.new()
	option.text = text
	option.focus_mode = Control.FOCUS_NONE
	option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	option.alignment = HORIZONTAL_ALIGNMENT_LEFT
	option.size_flags_horizontal = SIZE_EXPAND_FILL
	option.custom_minimum_size.x = 240
	option.add_theme_font_size_override("font_size", 19)
	var normal := STYLE.bevel(SAND if topic else STYLE.CREAM, STYLE.PAPER, Color("dcc6a0"), true, STYLE.INK, 2, 2, Vector4(10, 3, 10, 5))
	option.add_theme_stylebox_override("normal", normal)
	option.add_theme_stylebox_override("hover", STYLE.bevel(SKY, STYLE.PAPER, STYLE.BLUE_HI, true, STYLE.INK, 2, 2, Vector4(10, 3, 10, 5)))
	option.add_theme_stylebox_override("pressed", STYLE.bevel(SKY, STYLE.BLUE_HI, STYLE.PAPER, false, STYLE.INK, 2, 2, Vector4(10, 5, 10, 3)))
	if topic: option.add_theme_color_override("font_color", STYLE.BLUE)
	option.pressed.connect(action)
	return option

func _compose(contact: Dictionary) -> Control:
	var bar := PanelContainer.new()
	var box := STYLE.flat(SAND, STYLE.INK, 0, 8)
	box.border_width_top = 2
	bar.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	var input := LineEdit.new()
	input.size_flags_horizontal = SIZE_EXPAND_FILL
	input.placeholder_text = "Digite uma mensagem…"
	input.editable = contact.status == "known"
	row.add_child(input)
	var send := Button.new()
	send.text = "Enviar"
	send.focus_mode = Control.FOCUS_NONE
	send.disabled = not input.editable
	row.add_child(send)
	var submit := func() -> void:
		var value := input.text.strip_edges()
		if value.is_empty() or selected.is_empty(): return
		social.send_text(selected, value)
		input.clear()
	input.text_submitted.connect(func(_value: String) -> void: submit.call())
	send.pressed.connect(submit)
	return bar
