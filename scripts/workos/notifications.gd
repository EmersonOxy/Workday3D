extends RefCounted
## Cartões de aviso do WorkOS, no desenho dos dois avisos do original:
## - #toast (18-tabuleiro.js): recado do RH com envelope em pixel art, "De: …" em cinza e o texto; entra da direita
##   (canto superior direito no escritório), o envelope "chacoalha" depois de assentar e sai para a direita.
## - .msn-toast (46-mensageiro.js): foto 16×16 do contato com contorno de tinta, "MSworkN" em azul, nome em negrito e
##   até duas linhas de texto cinza, com faixa azul no topo; entra de baixo, clicar abre a conversa.
## Os dois ficam um por vez (o novo substitui o antigo) e respeitam "reduzir movimento".

const PIXEL := preload("res://scripts/workos/pixel.gd")
const STYLE := preload("res://scripts/workos/os_style.gd")
const MOTION := preload("res://scripts/workos/motion.gd")
const MUTED := Color("8f7d63")

static func _box(top_strip := false) -> StyleBoxFlat:
	var box := STYLE.flat(STYLE.PAPER, STYLE.INK, 3, 0)
	box.shadow_color = Color(STYLE.INK, 0.4)
	box.shadow_offset = Vector2(5, 5)
	box.shadow_size = 1
	return box

## Recado do RH (#toast): envelope, "De: …" e texto.
static func notice_card(from: String, text: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 300
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := _box()
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var envelope := TextureRect.new()
	envelope.name = "Envelope"
	envelope.texture = PIXEL.sprite("mail", 3)
	envelope.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	envelope.stretch_mode = TextureRect.STRETCH_KEEP
	envelope.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(envelope)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	row.add_child(column)
	var small := Label.new()
	small.text = "De: " + from
	small.add_theme_font_size_override("font_size", 16)
	small.add_theme_color_override("font_color", MUTED)
	column.add_child(small)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 200
	body.add_theme_font_size_override("font_size", 20)
	column.add_child(body)
	return card

## Aviso do MSworkN (.msn-toast): foto do contato, app, nome e texto. `small` = versão curta ("está online").
static func msn_card(picture: Control, app_name: String, title: String, text: String, small := false) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 250
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override("panel", _box())
	var outer := VBoxContainer.new()
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_theme_constant_override("separation", 0)
	card.add_child(outer)
	var strip := ColorRect.new()
	strip.color = Color("6f93d9")
	strip.custom_minimum_size.y = 4
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(strip)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := 4 if small else 6
	margin.add_theme_constant_override("margin_left", pad + 2)
	margin.add_theme_constant_override("margin_right", pad + 6)
	margin.add_theme_constant_override("margin_top", pad)
	margin.add_theme_constant_override("margin_bottom", pad)
	outer.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	row.add_child(column)
	for entry in [[app_name, 16, STYLE.BLUE], [title, 20, STYLE.INK], [text, 18, MUTED]]:
		if str(entry[0]).is_empty(): continue
		var line := Label.new()
		line.text = str(entry[0])
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_font_size_override("font_size", int(entry[1]))
		line.add_theme_color_override("font_color", entry[2])
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.max_lines_visible = 2
		line.custom_minimum_size.x = 170
		column.add_child(line)
	return card

## Chacoalho do envelope depois que o cartão assenta (3 vezes, 300 ms cada, fill none).
static func wobble(envelope: Control) -> void:
	if MOTION.reduced: return
	for _i in 3:
		if not is_instance_valid(envelope): return
		var tween := MOTION.play(envelope, [MOTION.frame(0.0), MOTION.frame(0.33, Vector2(0, -3), Vector2.ONE, -10.0), MOTION.frame(0.66, Vector2.ZERO, Vector2.ONE, 8.0), MOTION.frame(1.0)],
			0.3, false, Tween.TRANS_CUBIC, Tween.EASE_OUT)
		if tween == null: return
		await tween.finished
