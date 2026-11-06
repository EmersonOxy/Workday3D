extends Node3D
## Tarefas físicas do expediente no escritório 3D (mirar com o ponto central + E):
## - Telefone na mesa: toca na ligação (`call`); mirar e SEGURAR E até completar a barra.
## - Impressora no canto: na pendência `printer`, círculos brilhantes aparecem ao redor; mirar em cada um e apertar E.
## - Lixo: bolas de papel aparecem no chão fora do campo de visão; pegar (E), levar até a lixeira e soltar (E).
## - Chefe: entra pela porta; é preciso correr até a cadeira e sentar antes do prazo.
## - Café: na máquina (E) pega a xícara; voltar à mesa e deixá-la (E) alivia estresse e deixa o tempo mais lento.
## E-mail, spam e vírus continuam no WorkOS. O tempo do expediente corre fora do computador (game_state.active()).

const FIT := preload("res://scripts/props/fitted_prop.gd")
const MODELS := "res://assets/models/biblioteca/"
## Quando os modelos de café forem adicionados, basta salvar os GLB com estes nomes (ou trocar os caminhos).
const COFFEE_MACHINE_MODEL := "res://assets/models/biblioteca/coffee-machine/coffee_machine.glb"
const COFFEE_CUP_MODEL := "res://assets/models/biblioteca/coffee-cup/coffee_cup.glb"
const AIM_RANGE := 3.4
const ROOM_MIN := Vector2(-3.9, -5.0)
const ROOM_MAX := Vector2(5.2, 2.7)
## Retângulos (x0, z0, x1, z1) onde não nascem bolas de lixo: móveis, porta e cantos de uso.
const BLOCKED := [Rect2(-1.2, -1.9, 2.8, 2.9), Rect2(2.2, -3.8, 2.0, 4.4), Rect2(-4.6, -4.9, 1.6, 3.0), Rect2(-4.6, 1.9, 1.8, 1.3), Rect2(4.3, 1.4, 1.6, 1.8), Rect2(1.9, -6.0, 1.4, 1.6), Rect2(0.1, 2.1, 1.8, 1.2)]

var main: Node3D
var player: CharacterBody3D
var camera: Camera3D
var game: Node
var fx: Node

var targets: Array = []
var carried := ""
var carried_node: Node3D

var phone: Node3D
var phone_ring := 0.0
var hold := 0.0
var circles: Array = []
var balls: Array = []
var litter_in := 35.0
var boss: Node3D
var boss_state := ""
var boss_time := 0.0
var machine: Node3D
var cup_on_desk: Node3D
var desk_spot := Vector3.ZERO
var bin_spot := Vector3(1.15, 0.5, 0.4)
var printer_center := Vector3(5.2, 0.65, 2.5)
var coffee_ready_at := 0.0
var brewing_until := 0.0
var aimed: Dictionary = {}
var message := ""
var message_until := 0.0

func configure(host: Node3D) -> void:
	main = host
	player = host.player
	camera = host.camera
	game = host.desktop.game
	fx = host.desktop.fx
	name = "OfficeTasks"
	_build_phone()
	_build_peripherals()
	_build_coffee_corner()
	game.physical_task.connect(_on_physical_task)

func _in_office() -> bool:
	return main.travel.location == "office"

func _ready() -> void:
	set_process(true)

# ---------------------------------------------------------------- Construção dos objetos

func _table_surface() -> float:
	return main._table_top_height()

func _add_target(node: Node3D, kind: String, radius: float, extra := {}) -> Dictionary:
	var entry := {"node": node, "kind": kind, "radius": radius, "active": true}
	entry.merge(extra, true)
	targets.append(entry)
	return entry

## Alvo interativo genérico (cortina, interruptor): `label` devolve o texto da dica e `action` é chamada com E.
func register(node: Node3D, kind: String, radius: float, label: Callable, action: Callable, offset := Vector3.ZERO) -> void:
	var entry := _add_target(node, kind, radius)
	entry["label"] = label
	entry["call"] = action
	if offset != Vector3.ZERO: entry["world"] = offset

func _model(path: String, size: float, fit_by := 0) -> Node3D:
	var holder := Node3D.new()
	if ResourceLoader.exists(path):
		holder.set_script(FIT)
		holder.set("model", load(path))
		holder.set("fit_by", fit_by)
		holder.set("size", size)
	return holder

func _build_phone() -> void:
	var table: Node3D = main.get_node("OfficeTable")
	var top := _table_surface()
	phone = _model(MODELS + "office-phone/office_phone.glb", 0.24, 1)
	phone.name = "TelefoneMesa"
	add_child(phone)
	phone.global_position = Vector3(table.global_position.x + 0.42, top, table.global_position.z - 0.05)
	phone.rotation_degrees.y = 200.0
	_add_target(phone, "phone", 0.32)
	desk_spot = Vector3(table.global_position.x - 0.55, top, table.global_position.z + 0.22)
	var spot := Node3D.new()
	spot.name = "PontoXicara"
	add_child(spot)
	spot.global_position = desk_spot
	_add_target(spot, "desk", 0.3)

## Teclado e mouse (provisórios, sem modelo no projeto) entre os alvos de mão da digitação.
func _build_peripherals() -> void:
	var left: Node3D = main.get_node("TypingTargets/LeftHand")
	var right: Node3D = main.get_node("TypingTargets/RightHand")
	var top := _table_surface()
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("#2b2f38")
	var key_color := StandardMaterial3D.new()
	key_color.albedo_color = Color("#9aa0ab")
	var keyboard := Node3D.new()
	keyboard.name = "Teclado"
	add_child(keyboard)
	var center := (left.global_position + right.global_position) / 2.0
	keyboard.global_position = Vector3(center.x, top, center.z)
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.44, 0.022, 0.15)
	base.mesh = base_mesh
	base.position = Vector3(0, 0.011, 0)
	base.material_override = dark
	keyboard.add_child(base)
	for row in 4:
		for column in 13:
			var cap := MeshInstance3D.new()
			var cap_mesh := BoxMesh.new()
			cap_mesh.size = Vector3(0.026, 0.008, 0.026)
			cap.mesh = cap_mesh
			cap.position = Vector3(-0.15 + column * 0.0255, 0.026, -0.05 + row * 0.033)
			cap.material_override = key_color
			keyboard.add_child(cap)
	var mouse := MeshInstance3D.new()
	mouse.name = "Mouse"
	var mouse_mesh := BoxMesh.new()
	mouse_mesh.size = Vector3(0.06, 0.03, 0.105)
	mouse.mesh = mouse_mesh
	mouse.material_override = dark
	add_child(mouse)
	mouse.global_position = Vector3(right.global_position.x + 0.2, top + 0.015, right.global_position.z)

func _build_coffee_corner() -> void:
	var corner := Node3D.new()
	corner.name = "CantoDoCafe"
	add_child(corner)
	corner.global_position = Vector3(0.9, 0.0, 2.85)
	var stand := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.82, 0.5)
	stand.mesh = box
	stand.position = Vector3(0, 0.41, 0)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#8a6b4a")
	stand.material_override = wood
	corner.add_child(stand)
	machine = _model(COFFEE_MACHINE_MODEL, 0.46, 0)
	machine.name = "MaquinaDeCafe"
	machine.position = Vector3(0, 0.82, 0)
	if not ResourceLoader.exists(COFFEE_MACHINE_MODEL):
		# Provisório até o modelo ser adicionado: caixa com bico e luz.
		var body := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.3, 0.42, 0.28)
		body.mesh = mesh
		body.position = Vector3(0, 0.21, 0)
		var steel := StandardMaterial3D.new()
		steel.albedo_color = Color("#3b3f48")
		body.material_override = steel
		machine.add_child(body)
		var light := MeshInstance3D.new()
		var bulb := SphereMesh.new()
		bulb.radius = 0.02
		bulb.height = 0.04
		light.mesh = bulb
		light.position = Vector3(0.09, 0.34, 0.15)
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color("#6fbf73")
		glow.emission_enabled = true
		glow.emission = Color("#6fbf73")
		light.material_override = glow
		machine.add_child(light)
	corner.add_child(machine)
	var spot := Node3D.new()
	spot.position = Vector3(0, 1.0, 0.1)
	corner.add_child(spot)
	_add_target(spot, "machine", 0.4)
	# Lixeira: ponto de entrega do lixo (modelo já está no layout do escritório).
	var bin := Node3D.new()
	bin.name = "AlvoLixeira"
	add_child(bin)
	bin.global_position = bin_spot
	_add_target(bin, "bin", 0.45)

func _cup() -> Node3D:
	var cup := _model(COFFEE_CUP_MODEL, 0.1, 0)
	if not ResourceLoader.exists(COFFEE_CUP_MODEL):
		var body := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.04
		mesh.bottom_radius = 0.03
		mesh.height = 0.09
		body.mesh = mesh
		body.position = Vector3(0, 0.045, 0)
		var white := StandardMaterial3D.new()
		white.albedo_color = Color("#f4ecdc")
		body.material_override = white
		cup.add_child(body)
		var coffee := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.034
		disc.bottom_radius = 0.034
		disc.height = 0.004
		coffee.mesh = disc
		coffee.position = Vector3(0, 0.088, 0)
		var brown := StandardMaterial3D.new()
		brown.albedo_color = Color("#4b2e1c")
		coffee.material_override = brown
		cup.add_child(coffee)
	return cup

# ---------------------------------------------------------------- Mira

func _aim_ray() -> Array:
	return [camera.global_position, -camera.global_basis.z.normalized()]

func _find_aimed() -> Dictionary:
	var ray := _aim_ray()
	var origin: Vector3 = ray[0]
	var direction: Vector3 = ray[1]
	var best: Dictionary = {}
	var best_t := INF
	for entry in targets:
		if not entry.active or not is_instance_valid(entry.node): continue
		var point: Vector3 = entry["world"] if entry.has("world") else entry.node.global_position
		var along := (point - origin).dot(direction)
		if along < 0.1 or along > AIM_RANGE: continue
		var closest := origin + direction * along
		# Tolerância angular: a câmera balança ao andar, então alvos pequenos aceitam uns 2,5° de erro.
		if closest.distance_to(point) > maxf(float(entry.radius), along * 0.045): continue
		if along < best_t:
			best_t = along
			best = entry
	return best

func _usable(entry: Dictionary) -> bool:
	if entry.has("call"): return true
	match str(entry.get("kind", "")):
		"phone": return phone_ring > 0.0
		"circle", "ball": return carried.is_empty() or entry.kind == "circle"
		"bin": return carried == "ball"
		"machine": return carried.is_empty() and Time.get_ticks_msec() / 1000.0 >= coffee_ready_at
		"desk": return carried == "cup"
	return false

func prompt() -> String:
	if not _in_office(): return ""
	var text := _aim_prompt()
	if text.is_empty() and Time.get_ticks_msec() / 1000.0 < message_until: return message
	return text

func _aim_prompt() -> String:
	var entry := aimed
	if entry.is_empty(): return ""
	if entry.has("label"): return entry.label.call()
	if not _usable(entry):
		if entry.kind == "machine" and carried.is_empty() and Time.get_ticks_msec() / 1000.0 < coffee_ready_at: return "Máquina de café: aguarde esfriar"
		return ""
	match entry.kind:
		"phone": return "Segure E · Atender (%d%%)" % int(hold / maxf(_call_need(), 0.1) * 100.0) if hold > 0.0 else "Segure E · Atender o telefone"
		"circle": return "E · Consertar a impressora"
		"ball": return "E · Pegar o lixo"
		"bin": return "E · Jogar o lixo fora"
		"machine": return "E · Pegar um café"
		"desk": return "E · Deixar o café na mesa"
	return ""

func try_interact() -> bool:
	if not _in_office(): return false
	var entry := aimed
	if entry.is_empty() or not _usable(entry): return false
	if entry.has("call"):
		entry.call.call()
		return true
	match entry.kind:
		"phone":
			return true   # o atendimento é por segurar (_process)
		"circle":
			_fix_circle(entry)
		"ball":
			_pick_ball(entry)
		"bin":
			_drop_trash()
		"machine":
			_take_coffee()
		"desk":
			_place_coffee()
	return true

func _say(text: String, seconds := 2.4) -> void:
	message = text
	message_until = Time.get_ticks_msec() / 1000.0 + seconds

# ---------------------------------------------------------------- Telefone

func _call_task() -> Dictionary:
	for task in game.tasks:
		if task.type == "call" and task.get("physical", false): return task
	return {}

func _call_need() -> float:
	var task := _call_task()
	return float(task.get("need", 2.0)) if not task.is_empty() else 2.0

func _printer_task() -> Dictionary:
	for task in game.tasks:
		if task.type == "printer" and task.get("physical", false): return task
	return {}

func _on_physical_task(task: Dictionary) -> void:
	if task.type == "printer": _start_printer(task)

# ---------------------------------------------------------------- Impressora

func _printer_node() -> Node3D:
	return main.get_node_or_null("OfficeLayout/Objetos/Equipamentos/Impressora") as Node3D

func _global_aabb(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var local: AABB = mesh.get_aabb()
		var transform: Transform3D = mesh.global_transform
		for corner in 8:
			var point: Vector3 = transform * local.get_endpoint(corner)
			if first:
				box = AABB(point, Vector3.ZERO)
				first = false
			else: box = box.expand(point)
	return box

## Pontos de conserto NA superfície da impressora (frente, topo e laterais), como os pontos fracos de um material
## que começa a quebrar: um anel que encolhe até o centro, sempre colado na face, virado para fora.
func _start_printer(task: Dictionary) -> void:
	_clear_circles()
	var printer := _printer_node()
	if printer == null: return
	var box := _global_aabb(printer)
	var total := clampi(int(round(float(task.need) / 2.0)), 3, 5)
	var rng: RandomNumberGenerator = game.rng
	# Faces visíveis a partir da sala: frente (-x), topo, lateral -z e lateral +z.
	var faces := [Vector3(-1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 0, 1)]
	var placed: Array[Vector3] = []
	var texture := _ring_texture()
	var index := 0
	var attempts := 0
	while placed.size() < total and attempts < 60:
		attempts += 1
		var normal: Vector3 = faces[index % faces.size()]
		var point := _surface_point(box, normal, rng)
		var close := false
		for other in placed:
			if other.distance_to(point) < 0.17: close = true
		if close: continue
		placed.append(point)
		index += 1
		var marker := Node3D.new()
		add_child(marker)
		marker.look_at_from_position(point + normal * 0.012, point + normal, Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT, true)
		for part in ["Ring", "Dot"]:
			var sprite := Sprite3D.new()
			sprite.name = part
			sprite.texture = texture if part == "Ring" else _dot_texture()
			sprite.shaded = false
			sprite.double_sided = true
			sprite.pixel_size = 0.0013
			sprite.transparent = true
			sprite.render_priority = 6 if part == "Ring" else 5
			sprite.modulate = Color("#ffd35a") if part == "Ring" else Color("#fff1b8")
			marker.add_child(sprite)
		var entry := _add_target(marker, "circle", 0.14)
		entry["phase"] = rng.randf() * TAU
		entry["normal"] = normal
		circles.append(entry)

func _surface_point(box: AABB, normal: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var low := box.position
	var high := box.end
	var x := rng.randf_range(low.x + (high.x - low.x) * 0.2, high.x - (high.x - low.x) * 0.2)
	var y := rng.randf_range(low.y + (high.y - low.y) * 0.25, high.y - (high.y - low.y) * 0.1)
	var z := rng.randf_range(low.z + (high.z - low.z) * 0.2, high.z - (high.z - low.z) * 0.2)
	if normal.x != 0.0: return Vector3(low.x if normal.x < 0 else high.x, y, z)
	if normal.y != 0.0: return Vector3(x, high.y if normal.y > 0 else low.y, z)
	return Vector3(x, y, low.z if normal.z < 0 else high.z)

func _ring_texture() -> Texture2D:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var distance := Vector2(x - 63.5, y - 63.5).length()
			var ring := clampf(1.0 - absf(distance - 52.0) / 6.0, 0.0, 1.0)
			var tick_angle := fposmod(atan2(y - 63.5, x - 63.5) + PI, PI / 2.0)
			var tick := clampf(1.0 - absf(distance - 42.0) / 4.0, 0.0, 1.0) * (1.0 if tick_angle < 0.12 or tick_angle > PI / 2.0 - 0.12 else 0.0)
			image.set_pixel(x, y, Color(1, 1, 1, clampf(ring + tick, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)

func _dot_texture() -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var distance := Vector2(x - 31.5, y - 31.5).length()
			var core := clampf(1.0 - distance / 8.0, 0.0, 1.0)
			var glow := clampf(1.0 - distance / 30.0, 0.0, 1.0) * 0.35
			image.set_pixel(x, y, Color(1, 1, 1, clampf(core + glow, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)

func _sparks(at: Vector3, normal: Vector3) -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 14
	burst.lifetime = 0.45
	burst.explosiveness = 1.0
	burst.direction = normal
	burst.spread = 55.0
	burst.initial_velocity_min = 1.2
	burst.initial_velocity_max = 2.4
	burst.gravity = Vector3(0, -6, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.024
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("#ffd35a")
	glow.emission_enabled = true
	glow.emission = Color("#ffb52e")
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = glow
	burst.mesh = mesh
	add_child(burst)
	burst.global_position = at
	get_tree().create_timer(0.8).timeout.connect(burst.queue_free)

func _shake_printer() -> void:
	var printer := _printer_node()
	if printer == null: return
	var base := printer.position
	var tween := create_tween()
	for step in 5: tween.tween_property(printer, "position", base + Vector3(0, 0, (0.012 if step % 2 == 0 else -0.012)), 0.03)
	tween.tween_property(printer, "position", base, 0.03)

func _fix_circle(entry: Dictionary) -> void:
	_sparks(entry.node.global_position, entry.get("normal", Vector3.UP))
	_shake_printer()
	fx.sound("pop")
	entry.active = false
	if is_instance_valid(entry.node): entry.node.queue_free()
	circles.erase(entry)
	targets.erase(entry)
	if circles.is_empty():
		var task := _printer_task()
		if not task.is_empty(): game.complete_task(int(task.id), 25, "printer")
		_say("Impressora funcionando!")

func _clear_circles() -> void:
	for entry in circles.duplicate():
		if is_instance_valid(entry.node): entry.node.queue_free()
		targets.erase(entry)
	circles.clear()

# ---------------------------------------------------------------- Lixo

func spawn_ball() -> bool:
	if balls.size() >= 6 or not _in_office(): return false
	var rng: RandomNumberGenerator = game.rng
	for attempt in 40:
		var spot := Vector3(rng.randf_range(ROOM_MIN.x, ROOM_MAX.x), 0.1, rng.randf_range(ROOM_MIN.y, ROOM_MAX.y))
		var blocked := false
		for rect in BLOCKED:
			if rect.has_point(Vector2(spot.x, spot.z)): blocked = true
		if blocked: continue
		if player.global_position.distance_to(spot) < 2.2: continue
		if camera.is_position_in_frustum(spot): continue
		var ball := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.1
		mesh.height = 0.19
		mesh.radial_segments = 7
		mesh.rings = 4
		ball.mesh = mesh
		var paper := StandardMaterial3D.new()
		paper.albedo_color = Color("#e9e2d0")
		paper.roughness = 1.0
		ball.material_override = paper
		add_child(ball)
		ball.global_position = spot
		ball.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
		balls.append(_add_target(ball, "ball", 0.28))
		return true
	return false

func _pick_ball(entry: Dictionary) -> void:
	fx.sound("pop")
	entry.active = false
	if is_instance_valid(entry.node): entry.node.queue_free()
	balls.erase(entry)
	targets.erase(entry)
	_carry("ball")

func _drop_trash() -> void:
	_carry("")
	fx.sound("ok")
	game.success(8)
	game.stat("trash")
	_say("Lixo descartado.")

# ---------------------------------------------------------------- Café

func _take_coffee() -> void:
	fx.sound("coffee")
	_carry("cup")
	_say("Leve o café até a mesa.")

func _place_coffee() -> void:
	_carry("")
	if is_instance_valid(cup_on_desk): cup_on_desk.queue_free()
	cup_on_desk = _cup()
	add_child(cup_on_desk)
	cup_on_desk.global_position = desk_spot
	fx.sound("ok")
	game.drink_coffee()
	coffee_ready_at = Time.get_ticks_msec() / 1000.0 + 25.0
	_say("Café na mesa: estresse aliviado.")

func _carry(kind: String) -> void:
	carried = kind
	if is_instance_valid(carried_node): carried_node.queue_free()
	carried_node = null
	if kind.is_empty(): return
	carried_node = _cup() if kind == "cup" else _ball_visual()
	camera.add_child(carried_node)
	carried_node.position = Vector3(0.24, -0.22, -0.55)

func _ball_visual() -> Node3D:
	var ball := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.17
	mesh.radial_segments = 7
	mesh.rings = 4
	ball.mesh = mesh
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color("#e9e2d0")
	ball.material_override = paper
	return ball

# ---------------------------------------------------------------- Chefe

func _spawn_boss() -> void:
	boss = _model(MODELS + "office-worker/the_character_of_an_office_worker.glb", 1.78, 0)
	boss.name = "Chefe"
	add_child(boss)
	boss.global_position = Vector3(2.5, 0.0, -5.2)
	var suit := StandardMaterial3D.new()
	suit.albedo_color = Color(0.25, 0.1, 0.1, 0.55)
	suit.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mesh in boss.find_children("*", "GeometryInstance3D", true, false): mesh.material_overlay = suit
	boss_state = "coming"
	boss_time = 0.0
	fx.sound("alarm")

func _update_boss(delta: float) -> void:
	var has_event: bool = game.events.has("boss")
	if has_event and boss == null: _spawn_boss()
	if boss == null: return
	boss_time += delta
	var seat := Vector3(0.0, 0.0, -0.1)
	var to_seat := seat - boss.global_position
	to_seat.y = 0
	match boss_state:
		"coming":
			if to_seat.length() > 1.3:
				boss.global_position += to_seat.normalized() * 2.1 * delta
				boss.global_position.y = absf(sin(boss_time * 7.0)) * 0.03
				boss.look_at(boss.global_position + to_seat, Vector3.UP, true)
			if has_event and player.is_seated() and boss_time > 1.0:
				game.dodge_boss()
				boss_state = "leaving"
				boss_time = 0.0
			elif not has_event:
				boss_state = "scolding"
				boss_time = 0.0
		"scolding", "leaving":
			if boss_time > 2.0:
				boss.queue_free()
				boss = null
				boss_state = ""

# ---------------------------------------------------------------- Laço

func _process(delta: float) -> void:
	visible = _in_office()
	if not _in_office() or game == null or game.career.is_empty(): return
	var day_running: bool = game.career.get("phase", "") == "day"
	aimed = _find_aimed()
	# Telefone: toca enquanto houver uma ligação física; tremida e som.
	var call := _call_task()
	if not call.is_empty():
		var first := phone_ring <= 0.0
		phone_ring += delta
		if first or fmod(phone_ring, 1.4) < delta: fx.sound("ring")
		phone.rotation_degrees.z = sin(phone_ring * 38.0) * 3.0 if fmod(phone_ring, 1.4) < 0.5 else 0.0
		var pressing: bool = Input.is_physical_key_pressed(KEY_E) and not aimed.is_empty() and aimed.kind == "phone" and not main.is_zoomed
		if pressing:
			hold += delta
			if hold >= float(call.need):
				hold = 0.0
				phone_ring = 0.0
				phone.rotation_degrees.z = 0.0
				fx.sound("join")
				game.complete_task(int(call.id), 30, "calls")
				_say("Ligação atendida.")
		else:
			hold = 0.0
	elif phone_ring > 0.0:
		phone_ring = 0.0
		hold = 0.0
		phone.rotation_degrees.z = 0.0
	# Círculos da impressora pulsam; se a pendência acabou (prazo), somem.
	if not circles.is_empty():
		if _printer_task().is_empty(): _clear_circles()
		else:
			for entry in circles:
				if not is_instance_valid(entry.node): continue
				var cycle := fposmod(Time.get_ticks_msec() / 1000.0 * 1.1 + float(entry.get("phase", 0.0)), 1.0)
				var ring: Sprite3D = entry.node.get_node("Ring")
				ring.scale = Vector3.ONE * lerpf(1.7, 0.85, cycle)
				ring.modulate.a = clampf(cycle * 3.0, 0.0, 1.0) * (1.0 - clampf((cycle - 0.85) * 6.0, 0.0, 1.0))
				var dot: Sprite3D = entry.node.get_node("Dot")
				dot.scale = Vector3.ONE * (0.9 + 0.2 * sin(Time.get_ticks_msec() / 130.0))
	# Lixo: surge de tempos em tempos (a partir do dia 2) e estressa aos poucos enquanto fica no chão.
	if game.active() and (game.day() >= 2 or game.debug_unlock):
		litter_in -= delta
		if litter_in <= 0.0:
			litter_in = game.rng.randf_range(28.0, 45.0)
			spawn_ball()
		if not balls.is_empty(): game.add_stress(0.1 * balls.size() * delta)
	_update_boss(delta)

## Atalhos de depuração (F1 telefone, F2 impressora, F3 lixo, F4 chefe).
func debug_spawn(kind: String) -> String:
	match kind:
		"call": return "Ligação física gerada." if game.debug_spawn("call") else "Não foi possível gerar a ligação."
		"printer": return "Impressora com defeito." if game.debug_spawn("printer") else "Não foi possível gerar a impressora."
		"litter": return "Lixo no chão." if spawn_ball() else "Sem espaço para mais lixo."
		"boss": return "O chefe entrou!" if game.debug_spawn("boss") else "Não foi possível chamar o chefe."
	return ""
