extends Node
## Mantém o personagem e o WorkOS vivos; troca somente a cena 3D ao redor deles.
## O escritório permanece no main.tscn para preservar as poses e alvos já editados.
const LOCATIONS := {
	"street": "res://scenes/locations/street.tscn",
	"market": "res://scenes/locations/market.tscn",
	"home": "res://scenes/locations/home.tscn",
}

var host: Node3D
var player: CharacterBody3D
var location := "office"
var changing := false
var exterior: Node3D
var current_scene: Node3D
var office_zones: Node3D
var overlay: ColorRect
var feedback: Label
var feedback_until := 0
var office_visible_nodes: Array[Node3D] = []
var office_collision_layers: Dictionary = {}
var market_panel: CanvasLayer
var ui_open := false

func configure(main_scene: Node3D, actor: CharacterBody3D) -> void:
	host = main_scene
	player = actor
	exterior = Node3D.new()
	exterior.name = "ActiveLocation"
	host.add_child(exterior)
	office_zones = Node3D.new()
	office_zones.name = "OfficeInteractionZones"
	host.add_child(office_zones)
	_create_office_interactions()
	for name in ["Room", "OfficeTable", "OfficeChair", "Monitor", "KeyLight", "DirectionalLight3D", "Office2DProps", "DeskCat"]:
		var node := host.get_node_or_null(name) as Node3D
		if node != null:
			office_visible_nodes.append(node)
	for body in host.get_node("WorldCollisions").find_children("*", "CollisionObject3D", true, false):
		office_collision_layers[body] = body.collision_layer
	_build_overlay()
	market_panel = preload("res://scripts/world/market_panel.gd").new()
	market_panel.name = "MarketPanel"
	host.add_child(market_panel)
	market_panel.setup(_game())
	market_panel.closed.connect(_close_ui)

func _game() -> Node:
	return host.desktop.game

func _process(_delta: float) -> void:
	if feedback != null and feedback.visible and Time.get_ticks_msec() >= feedback_until:
		feedback.hide()

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WorldTransitionOverlay"
	layer.layer = 80
	host.add_child(layer)
	overlay = ColorRect.new()
	overlay.color = Color.BLACK
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.modulate.a = 0.0
	layer.add_child(overlay)
	# Anchors are applied again with a parent layout available.
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	feedback = Label.new()
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.add_theme_font_size_override("font_size", 23)
	feedback.add_theme_color_override("font_color", Color.WHITE)
	feedback.add_theme_color_override("font_shadow_color", Color.BLACK)
	feedback.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	feedback.offset_top = 26
	feedback.offset_bottom = 65
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(feedback)
	feedback.hide()

func _message(text: String) -> void:
	feedback.text = text
	feedback_until = Time.get_ticks_msec() + 2200
	feedback.show()

func _office_zone(name: String, position: Vector3, action: StringName, text: String, door: NodePath = NodePath()) -> void:
	_zone(office_zones, name, position, action, text, door)

func _zone(parent: Node, name: String, position: Vector3, action: StringName, text: String, door: NodePath = NodePath(), radius := 1.25) -> void:
	var zone := Area3D.new()
	zone.name = name
	zone.set_script(preload("res://scripts/world/interaction_zone.gd"))
	zone.action_id = action
	zone.prompt = text
	zone.door_path = door
	zone.position = position
	zone.collision_layer = 0
	zone.collision_mask = 2
	parent.add_child(zone)
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var shape := CollisionShape3D.new()
	shape.shape = sphere
	zone.add_child(shape)

func _create_office_interactions() -> void:
	# Provisórios: permitem posicionamento e substituição por modelos de porta/ponto.
	var panel := MeshInstance3D.new()
	panel.name = "PontoVisual"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.48, 0.67, 0.12)
	panel.mesh = mesh
	panel.position = Vector3(-3.0, 1.46, -5.82)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#465a73")
	panel.material_override = mat
	office_zones.add_child(panel)
	var clock_face := MeshInstance3D.new()
	clock_face.name = "VisorPonto"
	var face := BoxMesh.new()
	face.size = Vector3(0.34, 0.19, 0.04)
	clock_face.mesh = face
	clock_face.position = Vector3(-3.0, 1.55, -5.73)
	var green := StandardMaterial3D.new()
	green.albedo_color = Color("#91e0b5")
	clock_face.material_override = green
	office_zones.add_child(clock_face)
	_office_zone("Ponto", Vector3(-3.0, 1.0, -4.7), &"clock", "Bater ponto")
	var door := Node3D.new()
	door.name = "OfficeDoor"
	door.position = Vector3(2.5 - 0.65, 1.12, -5.83)
	office_zones.add_child(door)
	var door_visual := MeshInstance3D.new()
	door_visual.name = "Visual"
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(1.3, 2.25, 0.11)
	door_visual.mesh = door_mesh
	door_visual.position = Vector3(0.65, 0, 0)
	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_color = Color("#866957")
	door_visual.material_override = door_mat
	door.add_child(door_visual)
	_office_zone("OfficeExit", Vector3(2.5, 1.0, -4.6), &"office_exit", "Sair do escritório", NodePath("../OfficeDoor"))

func _active_zones() -> Array[Area3D]:
	var zones: Array[Area3D] = []
	var container: Node = office_zones if location == "office" else current_scene
	if container == null:
		return zones
	for candidate in container.find_children("*", "Area3D", true, false):
		if candidate.has_method("contains_player"):
			zones.append(candidate)
	return zones

func _nearest_zone() -> Area3D:
	if player == null or changing or location == "office" and not office_zones.visible:
		return null
	var candidate: Area3D
	var best := INF
	for zone in _active_zones():
		if not zone.contains_player(player):
			continue
		var distance := player.global_position.distance_squared_to(zone.global_position)
		if distance < best:
			best = distance
			candidate = zone
	return candidate

func interaction_prompt() -> String:
	if player == null or player.mode != player.Mode.FREE:
		return ""
	var zone := _nearest_zone()
	if zone == null:
		return ""
	match str(zone.action_id):
		"clock":
			return "E · Registrar saída" if _game().on_premises() else "E · Registrar entrada"
		"office_exit":
			return "E · Bata o ponto para sair" if _game().on_premises() else "E · Abrir porta / sair"
		_:
			return "E · " + zone.prompt

func try_interact() -> bool:
	if player == null or player.mode != player.Mode.FREE or changing:
		return false
	var zone := _nearest_zone()
	if zone == null:
		return false
	match str(zone.action_id):
		"clock":
			_message(_game().punch())
		"office_exit":
			if _game().on_premises():
				_message("Antes de sair, registre a saída no relógio de ponto.")
			else:
				_start_travel(zone, "street", "FromOffice")
		"street_office":
			_start_travel(zone, "office", "Door")
		"street_market":
			_start_travel(zone, "market", "FromStreet")
		"market_exit":
			_start_travel(zone, "street", "FromMarket")
		"street_bus":
			_start_travel(zone, "home", "FromBus")
		"home_exit":
			_start_travel(zone, "street", "FromHome")
		"home_sleep":
			var refusal: String = _game().can_sleep()
			if refusal.is_empty(): _sleep()
			else: _message(refusal)
		"market_shelf":
			_open_ui("shelf")
		"market_checkout":
			_open_ui("checkout")
		_:
			return false
	return true

func _start_travel(zone: Area3D, destination: String, spawn_name: String) -> void:
	if changing or not LOCATIONS.has(destination) and destination != "office":
		return
	_do_travel(zone, destination, spawn_name)

func _do_travel(zone: Area3D, destination: String, spawn_name: String) -> void:
	changing = true
	player.set_physics_process(false)
	if zone.has_method("open_door"):
		await zone.open_door()
	await _fade(1.0, 0.28)
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	var in_office := destination == "office"
	office_zones.visible = in_office
	for node in office_visible_nodes:
		node.visible = in_office
	for body in office_collision_layers:
		if is_instance_valid(body):
			body.collision_layer = office_collision_layers[body] if in_office else 0
	if in_office:
		# Reposiciona a porta do escritório após o retorno; ela não é descarregada.
		var office_door := office_zones.get_node_or_null("OfficeDoor") as Node3D
		if office_door != null:
			office_door.rotation.y = 0.0
		player.teleport_from_travel(Vector3(2.5, 0, -3.6), PI)
	else:
		var packed := load(LOCATIONS[destination]) as PackedScene
		if packed == null:
			push_error("Cenário não encontrado: " + destination)
			# Restaura escritório mesmo se faltar recurso externo.
			office_zones.visible = true
			for node in office_visible_nodes:
				node.visible = true
			for body in office_collision_layers:
				if is_instance_valid(body):
					body.collision_layer = office_collision_layers[body]
			player.teleport_from_travel(Vector3(2.5, 0, -3.6), PI)
			destination = "office"
		else:
			current_scene = packed.instantiate() as Node3D
			exterior.add_child(current_scene)
			_add_location_zones(destination)
			var spawn := current_scene.get_node_or_null("Spawns/" + spawn_name) as Marker3D
			if spawn == null:
				push_error("Spawn ausente em " + destination + ": " + spawn_name)
			else:
				player.teleport_from_travel(spawn.global_position, spawn.global_rotation.y)
	if destination != "market": market_panel.clear_cart()
	location = destination
	await get_tree().physics_frame
	await _fade(0.0, 0.32)
	player.set_physics_process(true)
	changing = false
	_message({"office":"Escritório", "street":"Rua comercial", "market":"Mercado", "home":"Casa"}[location])

## Zonas de jogo nos cenários provisórios (criadas aqui para não depender da edição dos blockouts).
func _add_location_zones(destination: String) -> void:
	match destination:
		"home":
			_zone(current_scene, "Dormir", Vector3(-2.5, 1.0, -2.0), &"home_sleep", "Dormir", NodePath(), 1.6)
		"market":
			_zone(current_scene, "PrateleiraA", Vector3(-1.6, 1.0, -1.3), &"market_shelf", "Ver prateleiras", NodePath(), 1.5)
			_zone(current_scene, "PrateleiraB", Vector3(1.3, 1.0, -1.3), &"market_shelf", "Ver prateleiras", NodePath(), 1.5)
			_zone(current_scene, "Caixa", Vector3(-2.4, 1.0, 3.1), &"market_checkout", "Pagar no caixa", NodePath(), 1.4)

func _open_ui(view: String) -> void:
	ui_open = true
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	market_panel.open(view)

func _close_ui() -> void:
	ui_open = false
	player.set_physics_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Porte de src/js/15-dormir-e-acordar.js: escurece, mostra o despertador às 06:00 e acorda no dia seguinte.
func _sleep() -> void:
	changing = true
	player.set_physics_process(false)
	overlay.color = Color("#2b2340")
	await _fade(1.0, 0.52)
	feedback.text = "z  Z  z  Z  z"
	feedback_until = Time.get_ticks_msec() + 3000
	feedback.show()
	await get_tree().create_timer(3.0).timeout
	var alarm := Button.new()
	alarm.text = "⏰  06:00
" + str(_game().texts().ui.get("wakeHint", "Clique no despertador para acordar"))
	alarm.add_theme_font_size_override("font_size", 32)
	alarm.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	overlay.get_parent().add_child(alarm)
	alarm.position -= alarm.get_combined_minimum_size() / 2
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await alarm.pressed
	alarm.queue_free()
	_game().sleep()
	overlay.color = Color.WHITE
	await _fade(0.0, 0.75)
	overlay.color = Color.BLACK
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.set_physics_process(true)
	changing = false
	_message("Bom dia! Dia %d · %s. Vá ao escritório bater o ponto." % [_game().clock.today(), _game().clock.date_text()])

func _fade(target: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", target, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
