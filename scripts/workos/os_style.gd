extends RefCounted
## Estilos do WorkOS: tema único (fonte VT323, botões, campos, rolagem, abas) e caixas em pixel art geradas por código,
## no mesmo desenho dos box-shadow do CSS original (contorno de tinta de 2 px + bisel claro/escuro), sem os riscos
## soltos que vinham em algumas texturas (task-button.png). As texturas boas do pacote original continuam em uso:
## moldura da janela, faixa do título, botões da barra de título, papel e botão de diálogo.

const INK := Color("2a1f2d")
const INK2 := Color("4a3a4e")
const PAPER := Color("fff8ec")
const PAPER2 := Color("f3e6cc")
const CREAM := Color("fbf3e2")
const BEIGE := Color("e9dcc2")
const TAN := Color("c7b595")
const BROWN := Color("8f7d63")
const BLUE := Color("44609f")
const BLUE_HI := Color("6f93d9")
const BLUE_LO := Color("2b2340")
const UI := "res://assets/ui/workos/"

## Paletas do Personalizar (OS_ACCENTS, OS_BARS e BADGE_COLORS de 30-personalizar.js): [cor, realce] e, nas barras, [base, realce, sombra, botão].
const ACCENTS := {"azul": ["44609f", "6f93d9"], "verde": ["2f8a45", "6fbf73"], "uva": ["7656a8", "a983d6"], "tijolo": ["a24a33", "d9714a"], "petroleo": ["2f6f78", "5fa79a"],
	"grafite": ["3b3f48", "626875"], "cereja": ["a8262a", "ef4b3f"], "laranja": ["c25f3b", "f0915f"], "noite": ["2b2340", "463462"], "ouro": ["8a5420", "c98a2e"]}
const BARS := {"bege": ["c7b595", "fff8ec", "8f7d63", "e9dcc2"], "cinza": ["9aa0ab", "d7d9de", "626875", "d7d9de"], "noite": ["2b2340", "4a3a4e", "2a1f2d", "463462"],
	"menta": ["5fa79a", "a9dccf", "2f6f78", "a9dccf"], "creme": ["e9dcc2", "fbf3e2", "c7b595", "fbf3e2"], "lavanda": ["a983d6", "e0cff7", "7656a8", "e0cff7"],
	"pessego": ["f2a27a", "ffd0b0", "d9714a", "ffd0b0"], "madeira": ["a8623a", "d48a4f", "6e3b26", "f0b778"]}
const BADGES := {"azul": ["6f93d9", "44609f"], "vermelho": ["ef4b3f", "a8262a"], "verde": ["6fbf73", "3f8f50"], "amarelo": ["f4c15d", "c98a2e"], "roxo": ["a983d6", "7656a8"],
	"preto": ["4a3a4e", "2a1f2d"], "laranja": ["f0915f", "c25f3b"], "menta": ["5fa79a", "2f6f78"], "cinza": ["9aa0ab", "626875"], "branco": ["fbf3e2", "c7b595"], "coral": ["ff9d86", "c25f3b"]}

static var _theme: Theme
static var _font: FontFile

static func font() -> FontFile:
	if _font == null:
		_font = load("res://assets/fonts/VT323.ttf")
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _font

## Caixa com contorno + bisel em pixels: `raised` = claro em cima/esquerda (botão solto); falso = afundado (pressionado).
static func bevel(fill: Color, light: Color, dark: Color, raised := true, outline := INK, outline_px := 2, bevel_px := 2, padding := Vector4(8, 4, 8, 4)) -> StyleBoxTexture:
	var size := (outline_px + bevel_px) * 2 + 4
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(outline)
	var inner := Rect2i(outline_px, outline_px, size - outline_px * 2, size - outline_px * 2)
	image.fill_rect(inner, fill)
	var top := light if raised else dark
	var bottom := dark if raised else light
	image.fill_rect(Rect2i(inner.position.x, inner.position.y, inner.size.x, bevel_px), top)
	image.fill_rect(Rect2i(inner.position.x, inner.position.y, bevel_px, inner.size.y), top)
	image.fill_rect(Rect2i(inner.position.x, inner.end.y - bevel_px, inner.size.x, bevel_px), bottom)
	image.fill_rect(Rect2i(inner.end.x - bevel_px, inner.position.y, bevel_px, inner.size.y), bottom)
	var box := StyleBoxTexture.new()
	box.texture = ImageTexture.create_from_image(image)
	var margin := outline_px + bevel_px
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: box.set_texture_margin(side, margin)
	box.content_margin_left = padding.x
	box.content_margin_top = padding.y
	box.content_margin_right = padding.z
	box.content_margin_bottom = padding.w
	return box

## Moldura da janela em pixel art limpa (substitui window-chrome-frame.png, que tem ruído e riscos claros):
## 9 px em cima, 10 nas laterais e 14 embaixo, contorno de tinta com cantos cortados, bisel creme (claro em
## cima/esquerda, escuro embaixo/direita) e um filete lilás junto ao conteúdo, como a moldura original.
static func frame_texture() -> Texture2D:
	var w := 40
	var h := 40
	var top := 9
	var side := 10
	var bottom := 14
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(0, 0, w, h), INK)
	for corner in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]: image.set_pixelv(corner, Color.TRANSPARENT)
	image.fill_rect(Rect2i(2, 2, w - 4, h - 4), CREAM)
	image.fill_rect(Rect2i(2, 2, w - 4, 2), PAPER)
	image.fill_rect(Rect2i(2, 2, 2, h - 4), PAPER)
	image.fill_rect(Rect2i(2, h - 5, w - 4, 3), TAN)
	image.fill_rect(Rect2i(w - 4, 2, 2, h - 4), TAN)
	image.fill_rect(Rect2i(2, h - 2, w - 4, 1), BROWN)
	# Filete lilás em volta da área interna e o miolo vazio (onde ficam a faixa de título e o papel).
	image.fill_rect(Rect2i(side - 2, top - 2, w - side * 2 + 4, h - top - bottom + 4), Color("6a5f9e"))
	image.fill_rect(Rect2i(side - 1, top - 1, w - side * 2 + 2, h - top - bottom + 2), INK)
	image.fill_rect(Rect2i(side, top, w - side * 2, h - top - bottom), Color.TRANSPARENT)
	return ImageTexture.create_from_image(image)

## Textura do pacote original em nove partes.
static func sliced(file: String, margins: Vector4, padding := Vector4(8, 6, 8, 6)) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(UI + file)
	box.texture_margin_left = margins.x
	box.texture_margin_top = margins.y
	box.texture_margin_right = margins.z
	box.texture_margin_bottom = margins.w
	box.content_margin_left = padding.x
	box.content_margin_top = padding.y
	box.content_margin_right = padding.z
	box.content_margin_bottom = padding.w
	return box

static func flat(fill: Color, border := Color.TRANSPARENT, width := 0, padding := 6.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_content_margin_all(padding)
	box.anti_aliasing = false
	return box

## Quadradinho de marcação em pixel art 16x16: contorno de tinta, fundo papel e "v" verde quando marcado.
static func _check_icon(checked: bool) -> Texture2D:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(INK)
	image.fill_rect(Rect2i(2, 2, 12, 12), PAPER)
	image.fill_rect(Rect2i(2, 2, 12, 2), Color("dcc6a0"))
	if checked:
		for point in [Vector2i(4, 8), Vector2i(5, 9), Vector2i(6, 10), Vector2i(7, 9), Vector2i(8, 8), Vector2i(9, 7), Vector2i(10, 6), Vector2i(11, 5)]:
			image.fill_rect(Rect2i(point.x, point.y, 2, 2), Color("2f8a45"))
	return ImageTexture.create_from_image(image)

static func tinted(box: StyleBoxTexture, color: Color) -> StyleBoxTexture:
	var copy := box.duplicate() as StyleBoxTexture
	copy.modulate_color = color
	return copy

static func theme() -> Theme:
	if _theme != null: return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 20
	# Texto padrão: tinta escura (o HTML tinha botões com texto claro sobre fundo claro; corrigido aqui).
	for type in ["Label", "RichTextLabel", "CheckBox", "CheckButton", "LinkButton"]:
		t.set_color("font_color", type, INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font("normal_font", "RichTextLabel", font())
	# Botões: botão de diálogo do pacote original (9 partes).
	var button := sliced("dialog-button.png", Vector4(9, 9, 9, 9), Vector4(12, 5, 12, 7))
	for type in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, button)
		t.set_stylebox("hover", type, tinted(button, Color(1.08, 1.06, 1.0)))
		var pressed := tinted(button, Color(0.86, 0.84, 0.82))
		pressed.content_margin_top += 2
		pressed.content_margin_bottom -= 2
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("disabled", type, tinted(button, Color(0.9, 0.9, 0.9, 0.6)))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(key, type, INK)
		t.set_color("font_disabled_color", type, Color(INK, 0.45))
		t.set_constant("h_separation", type, 8)
	# Caixas de seleção: sem fundo pesado; o quadradinho marcado já indica o estado.
	for type in ["CheckBox", "CheckButton"]:
		var plain := flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, 4)
		t.set_stylebox("normal", type, plain)
		t.set_stylebox("pressed", type, plain)
		t.set_stylebox("hover", type, flat(Color(BLUE_HI, 0.18), Color.TRANSPARENT, 0, 4))
		t.set_stylebox("hover_pressed", type, flat(Color(BLUE_HI, 0.18), Color.TRANSPARENT, 0, 4))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			t.set_color(key, type, INK)
		t.set_icon("checked", type, _check_icon(true))
		t.set_icon("unchecked", type, _check_icon(false))
	# Campos de texto.
	var field := sliced("input.png", Vector4(7, 7, 7, 7), Vector4(10, 6, 10, 6))
	for type in ["LineEdit", "TextEdit", "SpinBox"]:
		t.set_stylebox("normal", type, field)
		t.set_stylebox("focus", type, field)
		t.set_stylebox("read_only", type, tinted(field, Color(0.95, 0.94, 0.92)))
		t.set_color("font_color", type, INK)
		t.set_color("font_placeholder_color", type, Color(INK, 0.45))
		t.set_color("caret_color", type, INK)
		t.set_color("selection_color", type, Color(BLUE, 0.35))
	# Rolagem.
	var track := StyleBoxTexture.new()
	track.texture = load(UI + "scroll-track.png")
	var thumb := sliced("scroll-thumb.png", Vector4(4, 6, 4, 6), Vector4.ZERO)
	for type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, track)
		t.set_stylebox("grabber", type, thumb)
		t.set_stylebox("grabber_highlight", type, tinted(thumb, Color(1.1, 1.1, 1.15)))
		t.set_stylebox("grabber_pressed", type, tinted(thumb, Color(0.9, 0.9, 0.95)))
	# Abas (TabBar/TabContainer).
	var tab_on := sliced("tab-active.png", Vector4(10, 10, 10, 6), Vector4(12, 6, 12, 6))
	var tab_off := sliced("tab-inactive.png", Vector4(10, 10, 10, 6), Vector4(12, 6, 12, 6))
	for type in ["TabBar", "TabContainer"]:
		t.set_stylebox("tab_selected", type, tab_on)
		t.set_stylebox("tab_unselected", type, tab_off)
		t.set_stylebox("tab_hovered", type, tinted(tab_off, Color(1.06, 1.05, 1.0)))
		t.set_color("font_selected_color", type, INK)
		t.set_color("font_unselected_color", type, INK2)
		t.set_color("font_hovered_color", type, INK)
	t.set_stylebox("panel", "TabContainer", flat(CREAM, INK, 2, 10))
	# Barra de progresso.
	t.set_stylebox("background", "ProgressBar", sliced("progress.png", Vector4(7, 7, 7, 7), Vector4.ZERO))
	t.set_stylebox("fill", "ProgressBar", sliced("progress-fill.png", Vector4(4, 4, 4, 4), Vector4.ZERO))
	t.set_color("font_color", "ProgressBar", INK)
	# Listas suspensas e menus.
	var popup := bevel(CREAM, PAPER, TAN, true, INK, 2, 2, Vector4(4, 4, 4, 4))
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", flat(BLUE, Color.TRANSPARENT, 0, 4))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", PAPER)
	t.set_font("font", "PopupMenu", font())
	t.set_font_size("font_size", "PopupMenu", 20)
	t.set_stylebox("panel", "TooltipPanel", flat(Color("fff4c2"), INK, 2, 6))
	t.set_color("font_color", "TooltipLabel", INK)
	# Painel genérico (caixas internas das janelas).
	t.set_stylebox("panel", "PanelContainer", bevel(PAPER, Color.WHITE, PAPER2, true, Color(INK, 0.85), 2, 2, Vector4(10, 8, 10, 8)))
	t.set_stylebox("panel", "Panel", flat(CREAM, INK, 2, 0))
	_theme = t
	return t
