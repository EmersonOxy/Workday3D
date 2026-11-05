extends Control

var game: Node
const COLORS := [Color("5fa79a"), Color("6f93d9"), Color("f0915f"), Color("b199df")]
var dragging := false

func _ready() -> void:
	custom_minimum_size = Vector2(580, 340)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_STOP
	gui_input.connect(_board_input)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null or game.career.is_empty(): return
	var font := get_theme_default_font()
	var width := size.x / 4.0
	for lane in 4:
		var index := int(game.career.order[lane])
		var color: Color = COLORS[index]
		draw_rect(Rect2(lane * width, 0, width - 2, size.y), Color("eee3cb"))
		draw_rect(Rect2(lane * width, size.y - 44, width - 2, 44), color)
		draw_string(font, Vector2(lane * width + 8, size.y - 13), str(game.texts().sectors[game.SECTORS[index]]), HORIZONTAL_ALIGNMENT_LEFT, width - 12, 23, Color("211f29"))
	if game.file.is_empty(): return
	var file: Dictionary = game.file
	var y := clampf(float(file.y), 0, 1) * (size.y - 124)
	var rect := Rect2(float(file.lane) * width + 7, y, width - 16, 74)
	draw_rect(rect.grow(3), Color("a8262a") if file.kind == "urgent" else Color("2a1f2d"))
	draw_rect(rect, Color("fff8ec"))
	var title: String = "EXCLUIR" if file.kind == "dead" else str(game.texts().sectors[file.sector])
	draw_string(font, rect.position + Vector2(6, 23), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10, 23, Color("2a1f2d"))
	draw_string(font, rect.position + Vector2(6, 49), "MORTO" if file.kind == "dead" else str(file.name), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10, 20, Color("2a1f2d"))
	if file.kind == "urgent": draw_string(font, rect.position + Vector2(6, 68), "URGENTE!", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10, 18, Color("a8262a"))
	if game.events.has("freeze"):
		draw_rect(Rect2(Vector2.ZERO, size - Vector2(0, 44)), Color(0.15, 0.2, 0.3, 0.88))
		draw_string(font, Vector2(20, size.y / 2), "TRAVOU! Mova o mouse para os lados", HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 25, Color.WHITE)

func _board_input(event: InputEvent) -> void:
	if not game.active(): return
	if event is InputEventMouseMotion:
		game.shake_mouse(event.relative.x)
		if dragging: game.move_file(floori(event.position.x / (size.x / 4)))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if event.pressed: game.move_file(floori(event.position.x / (size.x / 4)))
		accept_event()
