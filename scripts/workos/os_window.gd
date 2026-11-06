extends Control
## Janela do WorkOS (porte de osWindow/winChrome + 80-entrega3.css): moldura contínua window-chrome-frame
## (9 px em cima, 10 nas laterais, 14 embaixo), faixa de título com ícone do app, botões minimizar/maximizar/fechar
## e papel. Animações em degraus como no HTML: abrir desenha do centro para fora (primeiro uma linha, depois a altura),
## fechar faz o caminho inverso (monitor CRT desligando) e minimizar "escorre" até o botão da barra de tarefas.

signal closed
signal minimized
signal minimize_requested
signal activated

const STYLE := preload("res://scripts/workos/os_style.gd")
const MOTION := preload("res://scripts/workos/motion.gd")
const UI := "res://assets/ui/workos/"
const TITLE_HEIGHT := 40
const FRAME := Vector4(10, 9, 10, 14)
const DESATURATE := "shader_type canvas_item; uniform float amount = 0.0; uniform float lift = 0.0;
void fragment() { vec4 c = texture(TEXTURE, UV) * COLOR; float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
c.rgb = mix(c.rgb, vec3(g), amount) * (1.0 + lift); COLOR = c; }"

var content: VBoxContainer
var paper: PanelContainer
var title_label: Label
var icon_rect: TextureRect
var title_strip: TextureRect
var buttons: Dictionary = {}
var dragging := false
var maximized := false
var active := true
var animating := false
var closable := true
var drag_offset := Vector2.ZERO
var restore_rect := Rect2()
var _strip_material: ShaderMaterial

func configure(title: String, icon: Texture2D = null) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = STYLE.theme()
	var frame := NinePatchRect.new()
	frame.texture = STYLE.frame_texture()
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.patch_margin_left = int(FRAME.x)
	frame.patch_margin_top = int(FRAME.y)
	frame.patch_margin_right = int(FRAME.z)
	frame.patch_margin_bottom = int(FRAME.w)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = FRAME.x
	column.offset_top = FRAME.y
	column.offset_right = -FRAME.z
	column.offset_bottom = -FRAME.w
	add_child(column)
	# Faixa de título: gradiente de 1x40 repetido na horizontal.
	title_strip = TextureRect.new()
	title_strip.texture = load(UI + "window-chrome-title.png")
	title_strip.stretch_mode = TextureRect.STRETCH_TILE
	title_strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_strip.custom_minimum_size = Vector2(0, TITLE_HEIGHT)
	title_strip.mouse_filter = Control.MOUSE_FILTER_STOP
	_strip_material = ShaderMaterial.new()
	_strip_material.shader = Shader.new()
	_strip_material.shader.code = DESATURATE
	title_strip.material = _strip_material
	column.add_child(title_strip)
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.offset_left = 8
	bar.offset_right = -5
	bar.add_theme_constant_override("separation", 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_strip.add_child(bar)
	icon_rect = TextureRect.new()
	icon_rect.texture = icon if icon != null else load(UI + "icon-monitor.png")
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(icon_rect)
	title_label = Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", STYLE.PAPER)
	title_label.add_theme_color_override("font_shadow_color", STYLE.BLUE_LO)
	title_label.add_theme_constant_override("shadow_offset_x", 1)
	title_label.add_theme_constant_override("shadow_offset_y", 1)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(title_label)
	for action in ["min", "max", "close"]:
		var button := TextureButton.new()
		button.texture_normal = load(UI + "window-chrome-%s.png" % action)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.custom_minimum_size = Vector2(31, 31)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.mouse_entered.connect(func() -> void: button.position.y -= 1)
		button.mouse_exited.connect(func() -> void: button.position.y += 1)
		button.pressed.connect(_action.bind(action))
		bar.add_child(button)
		buttons[action] = button
	# Papel com margem interna.
	paper = PanelContainer.new()
	# Papel liso: a textura window-paper.png tem riscos claros perto do canto de baixo.
	var paper_box := STYLE.flat(STYLE.CREAM, STYLE.BEIGE, 1, 14)
	paper.add_theme_stylebox_override("panel", paper_box)
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(paper)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paper.add_child(content)
	title_strip.gui_input.connect(_title_input)
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed: activated.emit())
	pivot_offset = size / 2.0
	resized.connect(func() -> void: pivot_offset = size / 2.0)

## Cor das janelas (--os-ac / --os-ac-hi): faixa de título em degraus, realce em cima e contorno de tinta embaixo.
func set_accent(id: String) -> void:
	if not STYLE.ACCENTS.has(id) or id == "azul":
		title_strip.texture = load(UI + "window-chrome-title.png")
		return
	var base := Color(STYLE.ACCENTS[id][0])
	var high := Color(STYLE.ACCENTS[id][1])
	var image := Image.create(1, TITLE_HEIGHT, false, Image.FORMAT_RGBA8)
	for y in TITLE_HEIGHT:
		var color := base
		if y < 2: color = high
		elif y < 5: color = high.lerp(base, float(y - 1) / 4.0)
		elif y >= TITLE_HEIGHT - 3: color = base.darkened(0.45)
		image.set_pixel(0, y, color)
	title_strip.texture = ImageTexture.create_from_image(image)

func set_title(title: String) -> void:
	title_label.text = title

func set_active(value: bool) -> void:
	active = value
	# Inativa: faixa dessaturada e clareada (filter: saturate(.45) brightness(1.18)), botões a 65 %.
	_strip_material.set_shader_parameter("amount", 0.0 if value else 0.55)
	_strip_material.set_shader_parameter("lift", 0.0 if value else 0.18)
	for button in buttons.values(): button.modulate.a = 1.0 if value else 0.65

func _title_input(event: InputEvent) -> void:
	if animating: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		activated.emit()
		if event.double_click and event.pressed:
			_action("max")
			return
		dragging = event.pressed and not maximized
		drag_offset = get_global_mouse_position() - global_position
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		var area := get_parent_control().size
		var next := get_global_mouse_position() - drag_offset - get_parent_control().global_position
		# Sempre sobra um pedaço visível; nunca por cima da barra de tarefas.
		position = Vector2(clampf(next.x, 80 - size.x, area.x - 80), clampf(next.y, 0, area.y - TITLE_HEIGHT - FRAME.y))
		accept_event()

func _action(action: String) -> void:
	if animating: return
	match action:
		"close":
			# O Portal RH não fecha: o X manda para a barra de tarefas, como no original.
			if not closable:
				minimize_requested.emit()
				return
			close()
		"min":
			minimize_requested.emit()
		"max":
			toggle_maximize()

func toggle_maximize() -> void:
	if maximized:
		position = restore_rect.position
		size = restore_rect.size
	else:
		restore_rect = Rect2(position, size)
		position = Vector2.ZERO
		size = get_parent_control().size
	maximized = not maximized
	activated.emit()

## Degraus como o steps(10) do CSS.
static func _step(t: float, steps: int) -> float:
	return MOTION.step(t, steps)

## Recorte animado (clip-path do original): a janela se desenha normalmente, mas só aparece dentro de `reveal`.
## O próprio nó vira máscara (clip_children) enquanto anima; o conteúdo nunca é esticado.
var _reveal := Rect2()
var _clipping := false

func _draw() -> void:
	if _clipping: draw_rect(_reveal, Color.WHITE)

func _begin_clip(rect: Rect2) -> void:
	_clipping = true
	_reveal = rect
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	queue_redraw()

func _set_clip(rect: Rect2) -> void:
	_reveal = rect
	queue_redraw()

func _end_clip() -> void:
	_clipping = false
	clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
	queue_redraw()

## Retângulo de uma faixa centralizada: largura e altura (px) no centro da janela.
func _centered(width: float, height: float) -> Rect2:
	return Rect2((size.x - width) / 2.0, (size.y - height) / 2.0, width, height)

## OS_OPEN: ponto → linha (largura cheia, 2 px) em 35 % → janela inteira, em 10 degraus.
func play_open() -> void:
	animating = true
	if MOTION.reduced:
		modulate.a = 0.0
		await create_tween().tween_property(self, "modulate:a", 1.0, 0.12).finished
		animating = false
		return
	_begin_clip(Rect2())
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var s := _step(t, 10)
		if s < 0.35: _set_clip(_centered(size.x * s / 0.35, 2.0 * s / 0.35))
		else: _set_clip(_centered(size.x, lerpf(2.0, size.y, (s - 0.35) / 0.65))), 0.0, 1.0, 0.3)
	await tween.finished
	_end_clip()
	animating = false

## OS_CLOSE: janela → linha em 60 % → ponto (monitor CRT desligando), em 8 degraus.
func close() -> void:
	if animating: return
	animating = true
	if MOTION.reduced:
		await create_tween().tween_property(self, "modulate:a", 0.0, 0.12).finished
	else:
		_begin_clip(Rect2(Vector2.ZERO, size))
		var tween := create_tween()
		tween.tween_method(func(t: float) -> void:
			var s := _step(t, 8)
			if s < 0.6: _set_clip(_centered(size.x, lerpf(size.y, 2.0, s / 0.6)))
			else: _set_clip(_centered(size.x * (1.0 - (s - 0.6) / 0.4), 2.0 * (1.0 - (s - 0.6) / 0.4))), 0.0, 1.0, 0.26)
		await tween.finished
	closed.emit()
	queue_free()

## Minimizar: recorta até uma faixa de 3 px na base, estreita e escorre até o botão da barra de tarefas (alvo no pai).
func minimize_to(target: Vector2) -> void:
	if animating: return
	animating = true
	var start := position
	var goal := target - Vector2(size.x / 2.0, size.y) if target != Vector2.ZERO else start + Vector2(0, size.y)
	if MOTION.reduced:
		await create_tween().tween_property(self, "modulate:a", 0.0, 0.12).finished
		modulate.a = 1.0
	else:
		_begin_clip(Rect2(Vector2.ZERO, size))
		var tween := create_tween()
		tween.tween_method(func(t: float) -> void:
			var s := _step(t, 10)
			if s < 0.45:
				var height := lerpf(size.y, 3.0, s / 0.45)
				_set_clip(Rect2(0, size.y - height, size.x, height))
			else:
				var k := (s - 0.45) / 0.55
				var width := lerpf(size.x, size.x * 0.3, k)
				_set_clip(Rect2((size.x - width) / 2.0, size.y - 3.0, width, 3.0))
				position = start.lerp(goal, k), 0.0, 1.0, 0.3)
		await tween.finished
		_end_clip()
	hide()
	position = start
	animating = false
	minimized.emit()

## Restaurar: o caminho inverso, do botão da barra de tarefas até a janela inteira.
func restore_from(source: Vector2) -> void:
	show()
	if source == Vector2.ZERO or MOTION.reduced:
		await play_open()
		return
	animating = true
	var target_position := position
	var from := source - Vector2(size.x / 2.0, size.y)
	_begin_clip(Rect2())
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var s := _step(t, 10)
		if s < 0.55:
			var k := s / 0.55
			var width := lerpf(size.x * 0.3, size.x, k)
			_set_clip(Rect2((size.x - width) / 2.0, size.y - 3.0, width, 3.0))
			position = from.lerp(target_position, k)
		else:
			position = target_position
			var height := lerpf(3.0, size.y, (s - 0.55) / 0.45)
			_set_clip(Rect2(0, size.y - height, size.x, height)), 0.0, 1.0, 0.3)
	await tween.finished
	position = target_position
	_end_clip()
	animating = false
