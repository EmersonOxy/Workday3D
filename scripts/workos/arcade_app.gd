extends VBoxContainer
## ARCADE.EXE (porte de 32a-arcade-base / 32c-penaltis / 32d-snake / 32i-darts): jogos desenhados numa tela de
## 128x160 pixels ampliada por escala inteira, com HUD em cima e recorde salvo em game.arcade.
## Snake: Duelo (contra a máquina, 75 s, 3 vidas, fruta 10 / abate 30), Pênaltis (3 cobranças de cada lado,
## mira por setor e defesa por setor) e Dardos (mira oscila, segurar carrega a força, 5 lançamentos).

const PIXEL := preload("res://scripts/workos/pixel.gd")
const STYLE := preload("res://scripts/workos/os_style.gd")
const W := 128
const H := 160
const SCALE := 3
const GAMES := [["snake", "Snake: Duelo", "Duas cobras no mesmo campo. Setas ou WASD. Fruta vale 10, derrubar o rival vale 30."],
	["penalty", "Pênaltis do Expediente", "Cobre escolhendo o canto (← ↓ →) e a força; depois defenda adivinhando o lado."],
	["darts", "Dardos", "A mira balança. Segure Espaço ou o clique para carregar e solte para lançar. 5 dardos."]]

var game: Node
var fx: Node
var stage: Control

func setup(state: Node, effects: Node) -> void:
	game = state
	fx = effects
	size_flags_vertical = SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	_menu()

func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

func _record(id: String) -> int:
	return int(game.arcade.get(id, 0))

func _menu() -> void:
	_clear()
	var title := Label.new()
	title.text = "ARCADE DO EXPEDIENTE"
	title.add_theme_font_size_override("font_size", 30)
	add_child(title)
	for item in GAMES:
		var card := Button.new()
		card.focus_mode = Control.FOCUS_NONE
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.text = "%s   ·   recorde %d\n%s" % [item[1], _record(item[0]), item[2]]
		card.custom_minimum_size = Vector2(0, 74)
		card.icon = PIXEL.menu_icon("arc", 3)
		card.add_theme_font_size_override("font_size", 20)
		card.pressed.connect(_start.bind(item[0]))
		add_child(card)

func _start(id: String) -> void:
	_clear()
	var bar := HBoxContainer.new()
	add_child(bar)
	var back := Button.new()
	back.text = "◀ Jogos"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_menu)
	bar.add_child(back)
	var holder := CenterContainer.new()
	holder.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(holder)
	stage = {"snake": SnakeDuel, "penalty": Penalty, "darts": Darts}[id].new()
	stage.custom_minimum_size = Vector2(W * SCALE, H * SCALE)
	stage.set("arcade", self)
	holder.add_child(stage)
	stage.grab_focus()

func finish(id: String, score: int) -> void:
	if score > _record(id):
		game.arcade[id] = score
		game.save_game()
		fx.sound("achieve")
	else: fx.sound("join")

# ---------------------------------------------------------------- Base: tela de 128x160

class Board extends Control:
	var arcade: Node
	var hud := ""
	var message := ""
	var message_time := 0.0
	var over := false
	var result := ""
	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	func pal(letter: String) -> Color:
		return PIXEL.palette().get(letter, Color.MAGENTA)
	func px(x: float, y: float, w: float, h: float, letter: String) -> void:
		draw_rect(Rect2(floorf(x) * 3, floorf(y) * 3, w * 3, h * 3), pal(letter))
	func text(at: Vector2, value: String, size := 18, color := Color("fff8ec")) -> void:
		var font := get_theme_default_font()
		draw_string(font, at * 3 + Vector2(0, 2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("2a1f2d"))
		draw_string(font, at * 3, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	func pop(value: String) -> void:
		message = value
		message_time = 1.2
	func sound(kind: String) -> void:
		if arcade != null: arcade.fx.sound(kind)
	func draw_overlay() -> void:
		draw_rect(Rect2(0, 0, 128 * 3, 9 * 3), Color("2a1f2d"))
		text(Vector2(2, 7), hud, 18)
		if message_time > 0.0:
			var font := get_theme_default_font()
			var width := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			draw_rect(Rect2((384 - width) / 2.0 - 8, 200, width + 16, 40), Color("2a1f2d"))
			draw_string(font, Vector2((384 - width) / 2.0, 230), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("ffe7a3"))
		if over:
			draw_rect(Rect2(0, 0, 384, 480), Color(0.16, 0.12, 0.18, 0.82))
			var lines := result.split("\n")
			for index in lines.size(): text(Vector2(10, 60 + index * 12), lines[index], 24)
			text(Vector2(10, 60 + lines.size() * 12 + 8), "Clique para voltar aos jogos", 18, Color("c3d5ff"))
	func end_game(id: String, score: int, summary: String) -> void:
		if over: return
		over = true
		result = summary
		arcade.finish(id, score)
	func _gui_input(event: InputEvent) -> void:
		if over and event is InputEventMouseButton and event.pressed:
			arcade._menu()
			accept_event()

# ---------------------------------------------------------------- Snake: Duelo

class SnakeDuel extends Board:
	const COLS := 14
	const ROWS := 16
	const OX := 8
	const OY := 18
	const MAX_TIME := 75.0
	const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var player := {}
	var rival := {}
	var fruit := Vector2i(-1, -1)
	var elapsed := 0.0
	var accum := 0.0
	var skill := 0.7
	func _ready() -> void:
		super._ready()
		player = {"body": [Vector2i(3, 5), Vector2i(2, 5), Vector2i(1, 5)], "dir": 1, "next": 1, "fruits": 0, "kills": 0, "lives": 3}
		rival = {"body": [Vector2i(10, 11), Vector2i(11, 11), Vector2i(12, 11)], "dir": 3, "next": 3, "fruits": 0, "kills": 0, "lives": 3}
		skill = {"facil": 0.55, "normal": 0.7, "dificil": 0.8, "burnout": 0.9}.get(str(arcade.game.profile.difficulty), 0.7)
		fruit = _new_fruit()
		pop("Prepare-se!")
	func inside(p: Vector2i) -> bool:
		return p.x >= 0 and p.x < COLS and p.y >= 0 and p.y < ROWS
	func has(snake: Dictionary, p: Vector2i, skip_tail: bool) -> bool:
		var body: Array = snake.body
		for index in body.size():
			if skip_tail and index == body.size() - 1: continue
			if body[index] == p: return true
		return false
	func occupied(p: Vector2i) -> bool:
		return has(player, p, false) or has(rival, p, false)
	func _new_fruit() -> Vector2i:
		var open: Array = []
		for y in ROWS:
			for x in COLS:
				if not occupied(Vector2i(x, y)): open.append(Vector2i(x, y))
		return open.pick_random() if not open.is_empty() else Vector2i(-1, -1)
	func turn(snake: Dictionary, d: int) -> void:
		if (d + 2) % 4 != snake.dir: snake.next = d
	func _gui_input(event: InputEvent) -> void:
		super._gui_input(event)
		if event is InputEventKey and event.pressed:
			var map := {KEY_UP: 0, KEY_W: 0, KEY_RIGHT: 1, KEY_D: 1, KEY_DOWN: 2, KEY_S: 2, KEY_LEFT: 3, KEY_A: 3}
			if map.has(event.keycode):
				turn(player, map[event.keycode])
				accept_event()
	## IA do original: evita corpos e becos, persegue a fruta e às vezes tenta cortar o jogador.
	func ai_move() -> void:
		var head: Vector2i = rival.body[0]
		var choices: Array = []
		for d in 4:
			if (d + 2) % 4 == rival.dir: continue
			var p: Vector2i = head + DIRS[d]
			if not inside(p) or has(rival, p, true) or has(player, p, true): continue
			var score := float(absi(p.x - fruit.x) + absi(p.y - fruit.y)) if fruit.x >= 0 else 0.0
			var exits := 0
			for e in DIRS:
				var q: Vector2i = p + e
				if inside(q) and not has(rival, q, true) and not has(player, q, true): exits += 1
			score += (4 - exits) * 2.2
			if randf() < 0.3 * skill: score += absf(p.x - player.body[0].x) * 0.13 + absf(p.y - player.body[0].y) * 0.13
			score += (randf() - 0.5) * (2.0 - skill)
			choices.append([d, score])
		choices.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
		if not choices.is_empty(): turn(rival, choices[0][0] if randf() < skill else choices.pick_random()[0])
	func respawn(snake: Dictionary, side: int) -> void:
		var bases := [Vector2i(3, 4), Vector2i(3, 9), Vector2i(3, 13), Vector2i(5, 2)] if side == 0 else [Vector2i(10, 11), Vector2i(10, 5), Vector2i(10, 14), Vector2i(8, 8)]
		for base in bases:
			var body: Array = []
			for i in 3: body.append(base + Vector2i(-i if side == 0 else i, 0))
			if body.all(func(p: Vector2i) -> bool: return inside(p) and not occupied(p)):
				snake.body = body
				snake.dir = 1 if side == 0 else 3
				snake.next = snake.dir
				return
	func step() -> void:
		ai_move()
		for snake in [player, rival]:
			if (snake.next + 2) % 4 != snake.dir: snake.dir = snake.next
		var p: Vector2i = player.body[0] + DIRS[player.dir]
		var q: Vector2i = rival.body[0] + DIRS[rival.dir]
		var eating := [p == fruit, q == fruit]
		var dead := [not inside(p) or has(player, p, not eating[0]) or has(rival, p, not eating[1]), not inside(q) or has(rival, q, not eating[1]) or has(player, q, not eating[0])]
		if p == q or (p == rival.body[0] and q == player.body[0]):
			dead[0] = true
			dead[1] = true
		var snakes := [player, rival]
		for i in 2:
			if dead[i]: continue
			var head: Vector2i = p if i == 0 else q
			snakes[i].body.push_front(head)
			if eating[i]:
				snakes[i].fruits += 1
				sound("pop")
			else: snakes[i].body.pop_back()
		if eating[0] or eating[1]: fruit = _new_fruit()
		for i in 2:
			if not dead[i]: continue
			snakes[i].lives -= 1
			if not dead[1 - i]: snakes[1 - i].kills += 1
			pop("Você bateu!" if i == 0 else "Rival derrubado!")
			sound("err" if i == 0 else "ok")
			if snakes[i].lives > 0: respawn(snakes[i], i)
		if player.lives <= 0 or rival.lives <= 0: finish_match()
	func score_of(snake: Dictionary) -> int:
		return int(snake.fruits) * 10 + int(snake.kills) * 30
	func finish_match() -> void:
		var mine := score_of(player)
		var theirs := score_of(rival)
		end_game("snake", mine, "%s\nVocê %d × %d Rival\nFrutas %d / %d\nVidas %d / %d" % ["VITÓRIA!" if mine > theirs else ("EMPATE" if mine == theirs else "DERROTA"), mine, theirs, player.fruits, rival.fruits, player.lives, rival.lives])
	func _process(delta: float) -> void:
		message_time = maxf(0.0, message_time - delta)
		if not over:
			elapsed += delta
			accum += delta
			var interval := maxf(0.083, 0.155 - floorf(elapsed / 15.0) * 0.01)
			while accum >= interval and not over:
				accum -= interval
				step()
			if elapsed >= MAX_TIME: finish_match()
		hud = "Você %d × %d Rival · %ds" % [score_of(player), score_of(rival), maxi(0, int(MAX_TIME - elapsed))]
		queue_redraw()
	func _draw() -> void:
		px(0, 0, 128, 160, "0")
		px(OX - 2, OY - 2, COLS * 8 + 4, ROWS * 8 + 4, "J")
		for y in ROWS:
			for x in COLS: px(OX + x * 8, OY + y * 8, 8, 8, "X" if (x + y) % 2 else "x")
		if fruit.x >= 0:
			var fx_ := OX + fruit.x * 8
			var fy := OY + fruit.y * 8
			px(fx_ + 1, fy + 2, 6, 6, "k")
			px(fx_ + 2, fy + 2, 4, 4, "R")
			px(fx_ + 4, fy, 2, 3, "G")
		for side in 2:
			var snake: Dictionary = player if side == 0 else rival
			var body: Array = snake.body
			for j in range(body.size() - 1, -1, -1):
				var x: float = OX + body[j].x * 8
				var y: float = OY + body[j].y * 8
				px(x, y, 8, 8, "k")
				px(x + 1, y + 1, 6, 6, "F" if side == 0 else "Y")
				px(x + 1, y + 1, 6, 2, "f" if side == 0 else "z")
				if j == 0:
					px(x + 2, y + 2, 2, 2, "W")
					px(x + 5, y + 2, 2, 2, "W")
					px(x + 3, y + 2, 1, 1, "J")
					px(x + 6, y + 2, 1, 1, "J")
		px(8, 155, 112, 2, "W")
		px(8, 155, int(112 * maxf(0.0, 1.0 - elapsed / MAX_TIME)), 2, "F")
		draw_overlay()

# ---------------------------------------------------------------- Pênaltis

class Penalty extends Board:
	const ZONES := [32, 64, 96]
	var turn := 0
	var mine := 0
	var theirs := 0
	var phase := "aim"
	var aim := 1
	var power := 0.0
	var charging := false
	var keeper := 1
	var ball := Vector2(64, 130)
	var flight := 0.0
	var target := Vector2(64, 42)
	var outcome := ""
	var skill := 0.7
	func _ready() -> void:
		super._ready()
		skill = {"facil": 0.55, "normal": 0.7, "dificil": 0.8, "burnout": 0.9}.get(str(arcade.game.profile.difficulty), 0.7)
		pop("Sua cobrança!")
	func shooting() -> bool:
		return turn % 2 == 0
	func _gui_input(event: InputEvent) -> void:
		super._gui_input(event)
		if over or phase != "aim": return
		if event is InputEventKey:
			var zone: int = {KEY_LEFT: 0, KEY_A: 0, KEY_DOWN: 1, KEY_S: 1, KEY_RIGHT: 2, KEY_D: 2}.get(event.keycode, -1)
			if zone >= 0 and event.pressed:
				aim = zone
				if not shooting(): _resolve()
			if event.keycode == KEY_SPACE and shooting():
				if event.pressed and not event.echo: charging = true
				elif not event.pressed and charging: _resolve()
			accept_event()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			aim = clampi(int(event.position.x / 3.0 / 43.0), 0, 2)
			if shooting():
				if event.pressed: charging = true
				elif charging: _resolve()
			elif event.pressed: _resolve()
	## Cobrança do jogador: força ideal entre 45 % e 85 %; o goleiro adivinha com a habilidade da máquina.
	## Defesa: a máquina chuta (melhor perto da habilidade) e o jogador escolhe o lado.
	func _resolve() -> void:
		charging = false
		phase = "flight"
		flight = 0.0
		ball = Vector2(64, 130)
		var goal := false
		if shooting():
			keeper = aim if randf() < skill * 0.45 else randi_range(0, 2)
			var good := power >= 0.45 and power <= 0.85
			target = Vector2(ZONES[aim], 42 - (12 if power > 0.85 else 0))
			goal = good and keeper != aim
			outcome = "GOL!" if goal else ("Para fora!" if not good else "Defendeu!")
			if goal: mine += 1
		else:
			var shot := randi_range(0, 2)
			keeper = aim
			var miss := randf() > 0.55 + skill * 0.4
			target = Vector2(ZONES[shot], 30 if miss else 42)
			goal = not miss and keeper != shot
			outcome = "Gol do rival" if goal else ("Fora!" if miss else "DEFESA!")
			if goal: theirs += 1
		sound("whoosh")
		power = 0.0
	func _process(delta: float) -> void:
		message_time = maxf(0.0, message_time - delta)
		if charging: power = fmod(power + delta * 0.9, 1.0)
		if phase == "flight":
			flight += delta / 0.6
			ball = Vector2(64, 130).lerp(target, minf(flight, 1.0))
			if flight >= 1.0:
				phase = "result"
				pop(outcome)
				sound("ok" if outcome in ["GOL!", "DEFESA!"] else "err")
				await get_tree().create_timer(1.1).timeout
				if not is_inside_tree(): return
				turn += 1
				if turn >= 6:
					end_game("penalty", mine * 100, "%s\nVocê %d × %d Rival" % ["VITÓRIA!" if mine > theirs else ("EMPATE" if mine == theirs else "DERROTA"), mine, theirs])
				else:
					phase = "aim"
					keeper = 1
					ball = Vector2(64, 130)
					pop("Sua cobrança!" if shooting() else "Defenda! Escolha o lado")
		hud = "Você %d × %d Rival · cobrança %d/6" % [mine, theirs, mini(turn + 1, 6)]
		queue_redraw()
	func _draw() -> void:
		px(0, 0, 128, 160, "h")
		for y in range(0, 160, 16): px(0, y, 128, 8, "G")
		px(14, 22, 100, 2, "W")
		px(14, 22, 2, 34, "W")
		px(112, 22, 2, 34, "W")
		for x in range(16, 112, 6): px(x, 24, 1, 32, "m")
		for y in range(26, 56, 6): px(16, y, 96, 1, "m")
		px(10, 56, 108, 1, "W")
		# Goleiro (azul) e bola.
		var kx: float = ZONES[keeper] - 6
		if phase == "flight" or phase == "result": kx = lerpf(58.0, ZONES[keeper] - 6.0, minf(flight, 1.0))
		px(kx, 38, 12, 14, "k")
		px(kx + 1, 39, 10, 12, "L" if shooting() else "F")
		px(kx + 3, 34, 6, 5, "s")
		px(ball.x - 3, ball.y - 3, 6, 6, "k")
		px(ball.x - 2, ball.y - 2, 4, 4, "W")
		if phase == "aim":
			px(ZONES[aim] - 4, 14, 8, 4, "Y")
			if shooting():
				px(20, 146, 88, 6, "k")
				px(21, 147, 86 * power, 4, "R" if power > 0.85 else ("F" if power >= 0.45 else "Y"))
				px(21 + 86 * 0.45, 145, 1, 8, "W")
				px(21 + 86 * 0.85, 145, 1, 8, "W")
		draw_overlay()

# ---------------------------------------------------------------- Dardos

class Darts extends Board:
	const CENTER := Vector2(64, 69)
	const R := 44.0
	var time := 0.0
	var aim := Vector2(64, 69)
	var charge := 0.0
	var holding := false
	var shots := 0
	var points := 0
	var impacts: Array = []
	func _ready() -> void:
		super._ready()
		pop("5 dardos!")
	func _gui_input(event: InputEvent) -> void:
		super._gui_input(event)
		if over: return
		if event is InputEventMouseMotion: aim = (event.position / 3.0).clamp(Vector2(10, 20), Vector2(118, 120))
		var press: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.keycode == KEY_SPACE)
		if press:
			if event.is_pressed() and not holding: holding = true
			elif not event.is_pressed() and holding: _throw()
			accept_event()
		if event is InputEventKey and event.pressed:
			var nudge: Vector2 = {KEY_LEFT: Vector2(-3, 0), KEY_RIGHT: Vector2(3, 0), KEY_UP: Vector2(0, -3), KEY_DOWN: Vector2(0, 3)}.get(event.keycode, Vector2.ZERO)
			aim = (aim + nudge).clamp(Vector2(10, 20), Vector2(118, 120))
	func sway() -> Vector2:
		return Vector2(sin(time * 2.3) * 6.0 + sin(time * 5.1) * 2.0, cos(time * 1.9) * 5.0)
	## Força ideal ~70 %: muito fraco cai abaixo, muito forte sobe; pontos pelo anel (50 no centro).
	func _throw() -> void:
		holding = false
		var drift := (0.7 - charge) * 24.0
		var hit := aim + sway() + Vector2(randf_range(-2, 2), drift)
		var distance := hit.distance_to(CENTER)
		var value := 0
		for ring in [[4, 50], [10, 25], [20, 15], [32, 10], [R, 5]]:
			if distance <= ring[0]:
				value = ring[1]
				break
		impacts.append(hit)
		points += value
		shots += 1
		charge = 0.0
		pop("+%d" % value if value > 0 else "Fora!")
		sound("ok" if value >= 15 else ("click" if value > 0 else "err"))
		if shots >= 5:
			await get_tree().create_timer(0.8).timeout
			if is_inside_tree(): end_game("darts", points, "FIM DE JOGO\n%d pontos em 5 dardos" % points)
	func _process(delta: float) -> void:
		time += delta
		message_time = maxf(0.0, message_time - delta)
		if holding: charge = minf(1.0, charge + delta * 0.8)
		hud = "Pontos %d · dardo %d/5" % [points, mini(shots + 1, 5)]
		queue_redraw()
	func _draw() -> void:
		px(0, 0, 128, 160, "3")
		for y in range(0, 160, 12): px(0, y, 128, 1, "4")
		var rings := [[R, "k"], [R - 1, "W"], [32, "R"], [20, "W"], [10, "R"], [4, "Y"]]
		for ring in rings: draw_circle(CENTER * 3, ring[0] * 3, pal(ring[1]), true, -1.0, false)
		for hit in impacts:
			px(hit.x - 1, hit.y - 1, 3, 3, "k")
			px(hit.x, hit.y, 1, 1, "Y")
		if not over and shots < 5:
			var at := aim + sway()
			px(at.x - 5, at.y, 11, 1, "W")
			px(at.x, at.y - 5, 1, 11, "W")
			px(20, 146, 88, 6, "k")
			px(21, 147, 86 * charge, 4, "F" if absf(charge - 0.7) < 0.12 else "Y")
			px(21 + 86 * 0.7, 145, 1, 8, "W")
		draw_overlay()
