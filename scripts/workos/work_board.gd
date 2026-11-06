extends Control
## Tabuleiro do expediente (porte de 18-tabuleiro.js + body.office #board do CSS): papel quadriculado, colunas
## tracejadas, bandejas coloridas com o glifo do setor e o documento caindo (faixa e ícone do setor, balanço de
## ±0,7°, carimbo URGENTE piscando, arquivo morto tracejado). Animações de resposta: pontos subindo (+N),
## bandeja pulando/escurecendo, tremida no erro, café, chefe e "não respondendo".

const PIXEL := preload("res://scripts/workos/pixel.gd")
const STYLE := preload("res://scripts/workos/os_style.gd")
const SECTOR_COLORS := {"fin": Color("6fbf73"), "rh": Color("f0915f"), "jur": Color("6f93d9"), "ti": Color("a983d6")}
const GLYPHS := {"fin": "glyphFin", "rh": "glyphHr", "jur": "glyphJur", "ti": "glyphTi"}
const PAPER := Color("f3e6cc")
const CARD := Color("fff8ec")
const MUTED := Color("8f7d63")
const DANGER := Color("ef4b3f")
const TRAY_HEIGHT := 56.0
const FILE_HEIGHT := 62.0

var game: Node
var app: Node
var dragging := false
var time := 0.0
var floats: Array = []
var tray_flash := {}
var shake := 0.0
var tip_until := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(520, 360)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true
	gui_input.connect(_board_input)
	game.scored.connect(_on_scored)
	game.failed.connect(_on_failed)
	game.landed.connect(_on_landed)
	tip_until = 7.0 if int(game.career.get("day", 1)) == 1 else 0.0

func _exit_tree() -> void:
	if game == null: return
	if game.scored.is_connected(_on_scored): game.scored.disconnect(_on_scored)
	if game.failed.is_connected(_on_failed): game.failed.disconnect(_on_failed)
	if game.landed.is_connected(_on_landed): game.landed.disconnect(_on_landed)

func _lane_width() -> float:
	return size.x / 4.0

func _on_scored(points: int) -> void:
	var lane := int(game.file.get("lane", 1)) if not game.file.is_empty() else 1
	floats.append({"text": "+%d" % points, "x": (lane + 0.5) * _lane_width(), "y": size.y - TRAY_HEIGHT - 18, "t": 0.0, "color": Color("2f8a45")})

func _on_failed(message: String) -> void:
	shake = 0.3
	floats.append({"text": message, "x": size.x / 2.0, "y": size.y * 0.45, "t": 0.0, "color": DANGER})
	if app != null and app.desktop != null: app.desktop.fx.sound("error")

func _on_landed(lane: int, correct: bool) -> void:
	tray_flash[lane] = {"t": 0.0, "ok": correct}
	if app != null and app.desktop != null and correct: app.desktop.fx.sound("success")

func _process(delta: float) -> void:
	time += delta
	shake = maxf(0.0, shake - delta)
	tip_until = maxf(0.0, tip_until - delta)
	for item in floats: item.t += delta
	floats = floats.filter(func(item: Dictionary) -> bool: return item.t < 1.0)
	for lane in tray_flash.keys():
		tray_flash[lane].t += delta
		if tray_flash[lane].t > 0.45: tray_flash.erase(lane)
	queue_redraw()

func _draw() -> void:
	if game == null or game.career.is_empty(): return
	var font := get_theme_default_font()
	# Tremida no erro (keyframes shake), em degraus de pixel.
	var offset := Vector2.ZERO
	if shake > 0.0:
		var step := int(shake * 20) % 4
		offset = [Vector2(-6, 2), Vector2(5, -3), Vector2(-4, 1), Vector2(3, 0)][step]
	draw_set_transform(offset)
	var slow: bool = float(game.get("slow_time")) > 0.0
	draw_rect(Rect2(Vector2.ZERO, size), Color("fbf3e2") if slow else PAPER)
	# Papel quadriculado (linhas a 6 %) e colunas tracejadas.
	var grid := 26.0
	var line := Color(STYLE.INK, 0.06)
	for x in range(0, int(size.x) + 1, int(grid)): draw_line(Vector2(x, 0), Vector2(x, size.y), line, 1.0)
	for y in range(0, int(size.y) + 1, int(grid)): draw_line(Vector2(0, y), Vector2(size.x, y), line, 1.0)
	var width := _lane_width()
	for lane in range(1, 4):
		draw_dashed_line(Vector2(lane * width, 0), Vector2(lane * width, size.y - TRAY_HEIGHT), Color(STYLE.INK, 0.14), 2.0, 8.0)
	# Bandejas: cor do setor, bisel claro em cima e escuro embaixo, glifo + nome com sombra.
	for lane in 4:
		var sector: String = game.SECTORS[int(game.career.order[lane])]
		var color: Color = SECTOR_COLORS[sector]
		var rect := Rect2(lane * width, size.y - TRAY_HEIGHT, width, TRAY_HEIGHT)
		if tray_flash.has(lane):
			var flash: Dictionary = tray_flash[lane]
			if flash.ok: rect.position.y -= 4.0 if flash.t < 0.2 else 0.0
			color = color.lightened(0.35) if flash.ok else color.darkened(0.45).lerp(DANGER, 0.5)
		draw_rect(rect, color)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5)), Color(1, 1, 1, 0.32))
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 5), Vector2(rect.size.x, 5)), Color(STYLE.INK, 0.28))
		draw_rect(Rect2(rect.position + Vector2(rect.size.x - 2, 0), Vector2(2, rect.size.y)), Color(STYLE.INK, 0.25))
		var glyph: Texture2D = PIXEL.sprite(GLYPHS[sector], 2)
		var name: String = str(game.texts().sectors[sector])
		var text_width := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var start_x := rect.position.x + (rect.size.x - (glyph.get_width() + 8 + text_width)) / 2.0
		draw_texture(glyph, Vector2(start_x, rect.position.y + (rect.size.y - glyph.get_height()) / 2.0 + 2) + Vector2(0, 2), Color(STYLE.INK, 0.4))
		draw_texture(glyph, Vector2(start_x, rect.position.y + (rect.size.y - glyph.get_height()) / 2.0))
		draw_string(font, Vector2(start_x + glyph.get_width() + 8, rect.position.y + rect.size.y / 2.0 + 9), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(STYLE.INK, 0.45))
		draw_string(font, Vector2(start_x + glyph.get_width() + 8, rect.position.y + rect.size.y / 2.0 + 7), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, STYLE.PAPER)
	_draw_file(font, width)
	# Dica do primeiro dia (#tip): faixa marrom no topo.
	if tip_until > 0.0:
		var tip_rect := Rect2(10, 10, size.x - 20, 38)
		draw_rect(tip_rect.grow(2), STYLE.INK)
		draw_rect(tip_rect, Color("6e3b26"))
		draw_rect(Rect2(tip_rect.position, Vector2(tip_rect.size.x, 3)), Color("a8684c"))
		draw_string(font, tip_rect.position + Vector2(12, 26), "Leve o arquivo ao setor da etiqueta com ← →. ↓ acelera.", HORIZONTAL_ALIGNMENT_LEFT, tip_rect.size.x - 20, 20, STYLE.PAPER)
	# Pontos e avisos subindo (.mo-float / keyframes up).
	for item in floats:
		var k: float = floorf(item.t * 10) / 10.0
		var color: Color = item.color
		color.a = 1.0 - k
		var text_size := font.get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
		var at := Vector2(clampf(item.x - text_size.x / 2.0, 6, size.x - text_size.x - 6), item.y - k * 40)
		draw_string(font, at + Vector2(0, 2), item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(CARD, color.a))
		draw_string(font, at, item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, color)
	# Eventos que cobrem o tabuleiro.
	if game.events.has("freeze"):
		draw_rect(Rect2(Vector2.ZERO, size - Vector2(0, TRAY_HEIGHT)), Color(0.12, 0.16, 0.22, 0.86))
		_center_text(font, ui_text("notResponding", "NÃO RESPONDENDO"), size.y * 0.42, 34, STYLE.PAPER)
		_center_text(font, ui_text("shake", "balance o mouse!"), size.y * 0.42 + 36, 24, Color("c3d5ff"))
	if game.events.has("boss"):
		var blink := int(time * 4) % 2 == 0
		var band := Rect2(0, size.y * 0.3, size.x, 70)
		draw_rect(band, DANGER if blink else Color("f4c15d"))
		_center_text(font, ui_text("bossComing", "O CHEFE VEM AÍ!"), band.position.y + 46, 36, STYLE.INK)
	if game.paused and game.career.get("phase", "") == "day":
		draw_rect(Rect2(Vector2.ZERO, size), Color(STYLE.INK, 0.45))
		_center_text(font, "PAUSADO" if not game.career.get("on_break", false) else "INTERVALO · " + game.clock.text(), size.y / 2.0, 40, STYLE.PAPER)
	draw_set_transform(Vector2.ZERO)

func ui_text(key: String, fallback: String) -> String:
	return str(game.texts().ui.get(key, fallback))

func _center_text(font: Font, text: String, y: float, font_size: int, color: Color) -> void:
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - text_width) / 2.0, y + 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(STYLE.INK, 0.5))
	draw_string(font, Vector2((size.x - text_width) / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

## Documento: papel com faixa do setor em cima, quadrado do setor com o glifo, nome e setor; balança ±0,7°.
func _draw_file(font: Font, width: float) -> void:
	if game.file.is_empty(): return
	var file: Dictionary = game.file
	var dead: bool = file.kind == "dead"
	var urgent: bool = file.kind == "urgent"
	var sector: String = file.sector
	var color: Color = MUTED if dead else SECTOR_COLORS[sector]
	var y := clampf(float(file.y), -0.2, 1.0) * (size.y - TRAY_HEIGHT - FILE_HEIGHT - 6)
	var rect := Rect2(float(file.lane) * width + 10, y, width - 20, FILE_HEIGHT)
	var sway := 0.0 if dead else deg_to_rad(0.7) * sin(time * (TAU / 1.4 if not urgent else TAU / 0.7))
	var center := rect.get_center()
	draw_set_transform(center, sway)
	var local := Rect2(rect.position - center, rect.size)
	var outline := DANGER if urgent and int(time / 0.175) % 2 == 0 else (MUTED if dead else STYLE.INK)
	draw_rect(Rect2(local.position + Vector2(0, 5), local.size), Color(STYLE.INK, 0.18))
	draw_rect(local.grow(2), outline)
	draw_rect(local, Color("e9dcc2") if dead else CARD)
	draw_rect(Rect2(local.position, Vector2(local.size.x, 5)), DANGER if urgent and outline == DANGER else color)
	if dead:
		for x in range(0, int(local.size.x), 10): draw_line(local.position + Vector2(x, local.size.y), local.position + Vector2(x + 5, local.size.y), MUTED, 2.0)
	var tile := Rect2(local.position + Vector2(8, 13), Vector2(38, 38))
	draw_rect(tile, color)
	draw_rect(Rect2(tile.position, Vector2(tile.size.x, 3)), Color(1, 1, 1, 0.35))
	draw_rect(Rect2(tile.position + Vector2(0, tile.size.y - 3), Vector2(tile.size.x, 3)), Color(STYLE.INK, 0.25))
	var glyph: Texture2D = PIXEL.sprite("trash" if dead else GLYPHS[sector], 2) if not dead else PIXEL.sprite("trash", 2)
	if glyph != null: draw_texture(glyph, tile.get_center() - glyph.get_size() / 2.0)
	var tag: String = ui_text("deadFile", "Arquivo morto") if dead else str(file.name)
	var sub: String = ui_text("pressDelete", "aperte Delete") if dead else str(game.texts().sectors[sector])
	draw_string(font, local.position + Vector2(54, 30), tag, HORIZONTAL_ALIGNMENT_LEFT, local.size.x - 60, 22, STYLE.INK)
	draw_string(font, local.position + Vector2(54, 52), sub, HORIZONTAL_ALIGNMENT_LEFT, local.size.x - 60, 19, MUTED)
	if urgent:
		# Carimbo URGENTE vermelho, inclinado 8°, no canto de cima.
		draw_set_transform(center + Vector2(rect.size.x / 2.0 - 30, -rect.size.y / 2.0 - 4), sway + deg_to_rad(8))
		var stamp := ui_text("urgent", "URGENTE")
		var stamp_width := font.get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 10
		draw_rect(Rect2(Vector2(-stamp_width / 2.0, -10), Vector2(stamp_width, 20)).grow(2), STYLE.INK)
		draw_rect(Rect2(Vector2(-stamp_width / 2.0, -10), Vector2(stamp_width, 20)), DANGER)
		draw_string(font, Vector2(-stamp_width / 2.0 + 5, 6), stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, STYLE.PAPER)
	draw_set_transform(Vector2.ZERO)

func _board_input(event: InputEvent) -> void:
	if not game.active(): return
	if event is InputEventMouseMotion:
		game.shake_mouse(event.relative.x)
		if dragging: game.move_file(floori(event.position.x / _lane_width()))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if event.pressed: game.move_file(floori(event.position.x / _lane_width()))
		accept_event()
