extends Node3D
## Luz e janelas do escritório.
## - Janelas de verdade: as paredes esquerda e direita ganham aberturas; o que se vê lá fora é um exterior (cúpula de céu,
##   rua, calçada, prédios com janelas acesas e postes) que acompanha o relógio do jogo.
## - Sol: DirectionalLight3D com sombras; só entra no escritório pelas aberturas, desenhando manchas no chão, e feixes
##   de luz (raios) aditivos com poeira marcam o caminho. Cortinas fechadas bloqueiam sol, vista e raios.
## - Noite: postes lá fora jogam luz pelas janelas; com as luzes do teto acesas, a luz também sai pelas janelas e ilumina
##   a calçada.
## - Interruptor (ao lado da porta): liga/desliga as lâmpadas do teto. Cortina: mirar na janela + E.

const SKY_SHADER := preload("res://assets/shaders/exterior_sky.gdshader")
const SHAFT_SHADER := preload("res://assets/shaders/light_shaft.gdshader")
const BUILDING_SHADER := preload("res://assets/shaders/exterior_building.gdshader")
const CURTAIN_SHADER := preload("res://assets/shaders/curtain_fabric.gdshader")
const PATCH_SHADER := preload("res://assets/shaders/light_patch.gdshader")
const WINDOW_W := 1.3
const WINDOW_H := 1.35
const SILL := 0.95
const HEAD := SILL + WINDOW_H
const WALL_T := 0.12
## wall: "left" (x = -4.5, vista para -x) ou "right" (x = 5.94, vista para +x); c = centro da janela em z.
const WINDOWS := [{"wall": "left", "c": -1.5}, {"wall": "left", "c": 1.2}, {"wall": "right", "c": -1.4}]
const LEFT_X := -4.5
const RIGHT_X := 5.94

var main: Node3D
var game: Node
var tasks: Node3D
var fx: Node
var sky_material: ShaderMaterial
var building_materials: Array[ShaderMaterial] = []
var sun: DirectionalLight3D
var fills: Array[DirectionalLight3D] = []
var lamps: Array[OmniLight3D] = []
var street_lamps: Array[Dictionary] = []
var window_nodes: Array[Dictionary] = []
var lights_on := true
var lamp_level := 1.0
var env: Environment
var minute_override := -1.0
var accumulated := 0.0
var last_minute := -1.0
var lamp_bases: Array[float] = []

func configure(host: Node3D, task_node: Node3D) -> void:
	main = host
	game = host.desktop.game
	tasks = task_node
	fx = host.desktop.fx
	name = "LuzDoEscritorio"
	env = host.get_node("WorldEnvironment").environment
	_build_walls()
	_build_exterior()
	_build_windows()
	_build_patches()
	_build_sun()
	_hook_lamps()
	_hook_switch()
	_update(true)

# ---------------------------------------------------------------- Paredes com aberturas

func _wall_material() -> Material:
	var wall: MeshInstance3D = main.get_node("Room/SideWall")
	return wall.get_surface_override_material(0)

func _build_wall(x: float, z0: float, z1: float, centers: Array, source: Node3D) -> void:
	var material := _wall_material()
	var pieces: Array = [[z0, z1, 0.0, SILL], [z0, z1, HEAD, 4.0]]
	var cursor := z0
	for center in centers:
		var a: float = center - WINDOW_W / 2.0
		var b: float = center + WINDOW_W / 2.0
		if a > cursor: pieces.append([cursor, a, SILL, HEAD])
		cursor = b
	if cursor < z1: pieces.append([cursor, z1, SILL, HEAD])
	var holder := Node3D.new()
	holder.name = "ParedeComJanelas"
	add_child(holder)
	for piece in pieces:
		var mesh_node := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(WALL_T, piece[3] - piece[2], piece[1] - piece[0])
		mesh_node.mesh = box
		mesh_node.material_override = material
		holder.add_child(mesh_node)
		mesh_node.global_position = Vector3(x, (piece[2] + piece[3]) / 2.0, (piece[0] + piece[1]) / 2.0)
	source.visible = false

func _build_walls() -> void:
	var left: Array = []
	var right: Array = []
	for window in WINDOWS:
		(left if window.wall == "left" else right).append(float(window.c))
	left.sort()
	right.sort()
	_build_wall(LEFT_X, -6.0, 6.0, left, main.get_node("Room/SideWall"))
	_build_wall(RIGHT_X, -5.94, 3.25, right, main.get_node("OfficeLayout/Paredes/Direita"))

# ---------------------------------------------------------------- Exterior

func _box(size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = position
	return node

func _flat(color: Color, roughness := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _build_exterior() -> void:
	var outside := Node3D.new()
	outside.name = "Exterior"
	add_child(outside)
	# Cúpula de céu.
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 140.0
	sphere.height = 280.0
	sphere.radial_segments = 48
	sphere.rings = 24
	dome.mesh = sphere
	dome.material_override = sky_material
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outside.add_child(dome)
	# Chão, calçada e rua (esquerda e direita).
	outside.add_child(_box(Vector3(400, 0.2, 400), Vector3(0, -0.2, 0), _flat(Color("#1a1c21"))))
	for side in [-1, 1]:
		var base_x: float = LEFT_X - 0.4 if side < 0 else RIGHT_X + 0.4
		var sidewalk := _flat(Color("#4a4d55"))
		var road := _flat(Color("#23252b"))
		var inner_x: float = base_x + side * 4.0
		outside.add_child(_box(Vector3(8.0, 0.14, 120), Vector3(inner_x, -0.07, 0), sidewalk))
		outside.add_child(_box(Vector3(14.0, 0.1, 120), Vector3(base_x + side * 15.0, -0.1, 0), road))
		outside.add_child(_box(Vector3(0.25, 0.02, 120), Vector3(base_x + side * 15.0, -0.04, 0), _flat(Color("#d9c36b"))))
		# Prédios do outro lado da rua.
		var rng := RandomNumberGenerator.new()
		rng.seed = 41 + side
		var z := -60.0
		while z < 60.0:
			var width := rng.randf_range(9.0, 17.0)
			var height := rng.randf_range(7.0, 20.0)
			var depth := rng.randf_range(10.0, 16.0)
			var material := ShaderMaterial.new()
			material.shader = BUILDING_SHADER
			material.set_shader_parameter("seed", rng.randf() * 50.0)
			var tint := rng.randf_range(0.8, 1.2)
			material.set_shader_parameter("wall_color", Color(0.34 * tint, 0.38 * tint, 0.46 * tint))
			building_materials.append(material)
			outside.add_child(_box(Vector3(depth, height, width), Vector3(base_x + side * (42.0 + depth / 2.0), height / 2.0, z + width / 2.0), material))
			z += width + rng.randf_range(0.5, 2.5)
		# Postes: um perto de cada janela, com lâmpada e luz que entra pela abertura.
		for window in WINDOWS:
			if (window.wall == "left") != (side < 0): continue
			var pole_x: float = base_x + side * 5.2
			var pole_z: float = float(window.c) - 1.6
			var pole := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.06
			cylinder.bottom_radius = 0.09
			cylinder.height = 5.4
			pole.mesh = cylinder
			pole.material_override = _flat(Color("#2d3138"))
			pole.position = Vector3(pole_x, 2.7, pole_z)
			outside.add_child(pole)
			var arm := _box(Vector3(1.0, 0.07, 0.07), Vector3(pole_x - side * 0.5, 5.4, pole_z), _flat(Color("#2d3138")))
			outside.add_child(arm)
			var bulb := MeshInstance3D.new()
			var orb := SphereMesh.new()
			orb.radius = 0.2
			orb.height = 0.34
			bulb.mesh = orb
			var glow := StandardMaterial3D.new()
			glow.albedo_color = Color("#ffd9a0")
			glow.emission_enabled = true
			glow.emission = Color("#ffcf80")
			glow.emission_energy_multiplier = 0.0
			bulb.material_override = glow
			bulb.position = Vector3(pole_x - side * 1.0, 5.3, pole_z)
			outside.add_child(bulb)
			street_lamps.append({"bulb": bulb, "glow": glow, "window_z": window.c, "side": side})
	# Nada lá fora precisa projetar sombra no escritório (só as paredes e a esquadria), e as sombras dos prédios
	# custavam centenas de chamadas de desenho nas luzes com sombra.
	for mesh in outside.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ---------------------------------------------------------------- Janelas: moldura, cortina, feixes, luz que sai

var _projector: ImageTexture

## Textura projetada pela luz dos postes: preto fora da janela e quatro vidros claros separados pelas divisões.
func _window_projector() -> ImageTexture:
	if _projector != null: return _projector
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_L8)
	for y in size:
		for x in size:
			var u := float(x) / (size - 1)
			var v := float(y) / (size - 1)
			var inside := smoothstep(0.14, 0.17, u) * smoothstep(0.86, 0.83, u) * smoothstep(0.14, 0.17, v) * smoothstep(0.86, 0.83, v)
			var bar := 1.0 - (smoothstep(0.012, 0.0, absf(u - 0.5)) + smoothstep(0.012, 0.0, absf(v - 0.5)))
			image.set_pixel(x, y, Color(inside * clampf(bar, 0.0, 1.0), 0, 0))
	_projector = ImageTexture.create_from_image(image)
	return _projector

func _shaft_node(color: Color) -> Dictionary:
	var node := MeshInstance3D.new()
	var material := ShaderMaterial.new()
	material.shader = SHAFT_SHADER
	material.set_shader_parameter("shaft_color", color)
	material.set_shader_parameter("intensity", 0.0)
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	return {"node": node, "material": material}

func _build_windows() -> void:
	var trim := _flat(Color("#d9d1c0"), 0.7)
	for window in WINDOWS:
		var left: bool = window.wall == "left"
		var normal := Vector3(1, 0, 0) if left else Vector3(-1, 0, 0)
		var face_x: float = LEFT_X + WALL_T / 2.0 if left else RIGHT_X - WALL_T / 2.0
		var center := Vector3(face_x, SILL + WINDOW_H / 2.0, float(window.c))
		var holder := Node3D.new()
		holder.name = "Janela_%s_%d" % [window.wall, window_nodes.size()]
		add_child(holder)
		holder.look_at_from_position(center, center + normal, Vector3.UP, true)
		# Moldura, peitoril e divisões.
		for part in [[Vector3(WINDOW_W + 0.16, 0.08, 0.1), Vector3(0, WINDOW_H / 2.0 + 0.04, 0.03)], [Vector3(WINDOW_W + 0.3, 0.06, 0.2), Vector3(0, -WINDOW_H / 2.0 - 0.03, 0.08)],
				[Vector3(0.08, WINDOW_H, 0.1), Vector3(-WINDOW_W / 2.0 - 0.04, 0, 0.03)], [Vector3(0.08, WINDOW_H, 0.1), Vector3(WINDOW_W / 2.0 + 0.04, 0, 0.03)],
				[Vector3(0.05, WINDOW_H, 0.05), Vector3(0, 0, 0.0)], [Vector3(WINDOW_W, 0.05, 0.05), Vector3(0, 0, 0.0)]]:
			var bar := _box(part[0], part[1], trim)
			holder.add_child(bar)
		# Vidro: reflexo leve (não bloqueia a vista).
		var glass := MeshInstance3D.new()
		var pane := QuadMesh.new()
		pane.size = Vector2(WINDOW_W, WINDOW_H)
		glass.mesh = pane
		var glass_material := StandardMaterial3D.new()
		glass_material.albedo_color = Color(0.8, 0.9, 1.0, 0.07)
		glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass_material.roughness = 0.05
		glass_material.metallic = 0.3
		glass.material_override = glass_material
		glass.position = Vector3(0, 0, -0.02)
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(glass)
		# Cortina em duas folhas: o pivô fica na borda de fora e a folha escala em direção a ela.
		var curtain_root := Node3D.new()
		curtain_root.position = Vector3(0, 0.08, 0.14)
		holder.add_child(curtain_root)
		var pivots: Array[Node3D] = []
		var cloth := ShaderMaterial.new()
		cloth.shader = CURTAIN_SHADER
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * (WINDOW_W / 2.0 + 0.16), 0, 0)
			curtain_root.add_child(pivot)
			var panel := _box(Vector3(WINDOW_W / 2.0 + 0.2, WINDOW_H + 0.45, 0.035), Vector3(-side * (WINDOW_W / 4.0 + 0.1), 0, 0), cloth)
			pivot.add_child(panel)
			pivots.append(pivot)
		var rod := _box(Vector3(WINDOW_W + 0.55, 0.035, 0.035), Vector3(0, WINDOW_H / 2.0 + 0.27, 0.14), _flat(Color("#2b2f38")))
		holder.add_child(rod)
		var entry := {"holder": holder, "center": center, "normal": normal, "left": left, "pivots": pivots, "cloth": cloth, "open": 1.0, "tween": null,
			"sun": _shaft_node(Color(1.0, 0.9, 0.65)), "lamp": _shaft_node(Color(1.0, 0.82, 0.5)), "out": _shaft_node(Color(1.0, 0.85, 0.55)),
			"spill": SpotLight3D.new()}
		var spill: SpotLight3D = entry.spill
		spill.spot_angle = 45.0
		spill.spot_range = 14.0
		spill.light_energy = 0.0
		spill.light_color = Color("#ffd9a0")
		spill.shadow_enabled = false
		add_child(spill)
		# A luz que SAI aponta para fora (direção -normal) e um pouco para baixo.
		spill.look_at_from_position(center - normal * 0.4, center - normal * 8.0 - Vector3(0, 3.2, 0), Vector3.UP)
		window_nodes.append(entry)
		_apply_curtain(entry)
		var index := window_nodes.size() - 1
		tasks.register(holder, "curtain", 0.75, func() -> String: return "E · Fechar a cortina" if window_nodes[index].open > 0.5 else "E · Abrir a cortina", func() -> void: toggle_curtain(index), center + Vector3(0, -0.15, 0))

## Mancha de luz do poste no chão: os quatro cantos da janela projetados a partir da lâmpada até o piso.
func _build_patches() -> void:
	for entry in window_nodes:
		for lamp in street_lamps:
			if absf(float(lamp.window_z) - entry.center.z) > 0.01 or (lamp.side < 0) != entry.left: continue
			var source: Vector3 = lamp.bulb.position
			var corners: Array[Vector3] = []
			var uvs: Array[Vector2] = [Vector2(0.14, 0.14), Vector2(0.86, 0.14), Vector2(0.86, 0.86), Vector2(0.14, 0.86)]
			for corner in [Vector3(-1, 1, 0), Vector3(1, 1, 0), Vector3(1, -1, 0), Vector3(-1, -1, 0)]:
				var point: Vector3 = entry.center + Vector3(0, 0, corner.x * WINDOW_W / 2.0) + Vector3(0, corner.y * WINDOW_H / 2.0, 0)
				var t := (0.012 - source.y) / (point.y - source.y)
				corners.append(source + (point - source) * t)
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for index in [0, 1, 2, 0, 2, 3]:
				tool.set_uv(uvs[index])
				tool.add_vertex(corners[index])
			var material := ShaderMaterial.new()
			material.shader = PATCH_SHADER
			material.set_shader_parameter("pattern", _window_projector())
			var node := MeshInstance3D.new()
			node.mesh = tool.commit()
			node.material_override = material
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			entry["patch"] = {"node": node, "material": material}

func toggle_curtain(index: int) -> void:
	var entry: Dictionary = window_nodes[index]
	var target := 0.0 if entry.open > 0.5 else 1.0
	fx.sound("page")
	if entry.tween != null and entry.tween.is_valid(): entry.tween.kill()
	var tween := create_tween()
	entry.tween = tween
	tween.tween_method(func(value: float) -> void:
		entry.open = value
		_apply_curtain(entry), float(entry.open), target, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func() -> void: _update(true))

func _apply_curtain(entry: Dictionary) -> void:
	var gather := lerpf(1.0, 0.14, float(entry.open))
	for pivot in entry.pivots: pivot.scale.x = gather

# ---------------------------------------------------------------- Sol

func _build_sun() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "SolDasJanelas"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 16.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.light_energy = 0.0
	add_child(sun)
	# As duas luzes de preenchimento do cenário não têm sombra e iluminavam a sala mesmo sem janela ou lâmpada:
	# agora só deixam um mínimo, e a claridade vem do sol, das janelas e das lâmpadas do teto.
	for node_name in ["KeyLight", "DirectionalLight3D"]:
		var fill := main.get_node_or_null(node_name) as DirectionalLight3D
		if fill != null:
			fill.light_energy = 0.1
			fills.append(fill)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.56, 0.7)
	env.ambient_light_energy = 0.3

func _hook_lamps() -> void:
	for index in 3:
		var lamp := main.get_node_or_null("OfficeLayout/Luzes/Lampada%d" % (index + 1)) as OmniLight3D
		if lamp != null:
			lamp.light_energy = 2.2
			lamp.omni_range = 8.5
			lamps.append(lamp)
			lamp_bases.append(2.2)

func _hook_switch() -> void:
	var switch_node := main.get_node_or_null("OfficeLayout/Objetos/Equipamentos/Interruptor") as Node3D
	if switch_node == null: return
	tasks.register(switch_node, "switch", 0.32, func() -> String: return "E · Apagar as luzes" if lights_on else "E · Acender as luzes", toggle_lights, Vector3.ZERO)

func toggle_lights() -> void:
	lights_on = not lights_on
	fx.sound("click")
	var tween := create_tween()
	tween.tween_property(self, "lamp_level", 1.0 if lights_on else 0.0, 0.25)
	tween.finished.connect(func() -> void: _update(true))

# ---------------------------------------------------------------- Atualização por horário

func _clock_minute() -> float:
	return minute_override if minute_override >= 0.0 else fmod(game.clock.minute(), 1440.0)

func _process(delta: float) -> void:
	visible = main.travel.location == "office"
	if not visible or game == null: return
	accumulated += delta
	for lamp in lamps: lamp.visible = lamp_level > 0.01
	for index in lamps.size(): lamps[index].light_energy = lamp_bases[index] * lamp_level
	if accumulated > 0.25:
		accumulated = 0.0
		_update(false)

func _sun_direction(minute: float) -> Array:
	var t := clampf((minute - 360.0) / 720.0, 0.0, 1.0)
	var elevation := sin(t * PI) * 62.0
	var azimuth := lerpf(-82.0, 82.0, t)
	var position := Vector3(sin(deg_to_rad(azimuth)) * cos(deg_to_rad(elevation)), sin(deg_to_rad(elevation)), cos(deg_to_rad(azimuth)) * cos(deg_to_rad(elevation)))
	return [position, elevation]

func _update(force: bool) -> void:
	var minute := _clock_minute()
	var data := _sun_direction(minute)
	var sun_position: Vector3 = data[0]
	var elevation: float = data[1]
	var daylight := clampf(elevation / 14.0, 0.0, 1.0)
	var low_sun := 1.0 - clampf(elevation / 32.0, 0.0, 1.0)
	var night_t := fposmod(minute - 1080.0, 1440.0) / 720.0
	var moon_position := Vector3(sin(deg_to_rad(lerpf(80.0, -80.0, clampf(night_t, 0.0, 1.0)))) * 0.7, 0.55 + 0.35 * sin(clampf(night_t, 0.0, 1.0) * PI), -0.5).normalized()
	sky_material.set_shader_parameter("daylight", daylight)
	sky_material.set_shader_parameter("low_sun", low_sun)
	sky_material.set_shader_parameter("sun_dir", sun_position)
	sky_material.set_shader_parameter("moon_dir", moon_position)
	for material in building_materials: material.set_shader_parameter("night", 1.0 - daylight)
	# Sol: a luz viaja do sol para a origem.
	sun.look_at_from_position(sun_position * 40.0, Vector3.ZERO, Vector3.UP)
	sun.light_energy = 1.9 * daylight
	sun.light_color = Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.58, 0.32), low_sun)
	sun.visible = daylight > 0.01
	var openness := 0.0
	for entry in window_nodes: openness += float(entry.open) / window_nodes.size()
	env.ambient_light_energy = 0.12 + (0.12 + 0.3 * daylight * (0.35 + 0.65 * openness)) + 0.15 * (1.0 - daylight)
	env.ambient_light_color = Color(0.55, 0.6, 0.72).lerp(Color(0.25, 0.3, 0.5), 1.0 - daylight)
	var night := 1.0 - daylight
	for lamp in street_lamps:
		var on := night > 0.35
		lamp.glow.emission_energy_multiplier = 3.0 if on else 0.0
	for entry in window_nodes:
		var normal: Vector3 = entry.normal
		var toward := -sun_position   # direção em que a luz do sol viaja
		var enters := toward.dot(normal)
		var open: float = entry.open
		# Raios de sol.
		var sun_strength := 0.0
		if enters > 0.06 and elevation > 2.0: sun_strength = clampf(daylight * (0.35 + enters), 0.0, 1.0) * open
		_set_shaft(entry.sun, entry.center, normal, toward, sun_strength * 0.3, 9.0)
		# Luz do poste entrando.
		var lamp_strength := 0.0
		var lamp_dir := Vector3.ZERO
		for lamp in street_lamps:
			if absf(float(lamp.window_z) - entry.center.z) < 0.01 and (lamp.side < 0) == entry.left:
				lamp_dir = (entry.center - lamp.bulb.position).normalized()
				lamp_strength = night * open * 0.16
		_set_shaft(entry.lamp, entry.center, normal, lamp_dir, lamp_strength if lamp_dir != Vector3.ZERO else 0.0, 6.5)
		# Luz do teto saindo pela janela.
		var out_dir: Vector3 = -normal + Vector3(0, -0.28, 0)
		var out_strength := night * open * lamp_level * 0.12
		_set_shaft_out(entry.out, entry.center, out_dir.normalized(), out_strength, 6.0)
		# Tecido brilha por dentro quando fechado e há sol (ou poste) do outro lado.
		var behind := clampf(daylight * (0.25 + maxf(enters, 0.0)), 0.0, 1.0) * (1.0 - open) + night * 0.3 * (1.0 - open)
		entry.cloth.set_shader_parameter("backlight", behind)
		entry.cloth.set_shader_parameter("backlight_color", Color(1.0, 0.88, 0.62).lerp(Color(1.0, 0.7, 0.4), low_sun) if daylight > 0.1 else Color(1.0, 0.82, 0.55))
		if entry.has("patch"):
			entry.patch.material.set_shader_parameter("intensity", clampf(night * open * 0.34, 0.0, 1.0) if night > 0.35 else 0.0)
		var spill: SpotLight3D = entry.spill
		spill.light_energy = 3.2 * night * open * lamp_level
		spill.visible = spill.light_energy > 0.02

## Feixe a partir da abertura da janela, ao longo de `direction`, até o chão ou `max_length`.
func _build_shaft(origin: Vector3, normal: Vector3, direction: Vector3, max_length: float) -> ArrayMesh:
	var along := Vector3(0, 0, 1)
	var up := Vector3(0, 1, 0)
	var half_w := WINDOW_W / 2.0 - 0.02
	var half_h := WINDOW_H / 2.0 - 0.02
	var near: Array[Vector3] = [origin + along * -half_w + up * half_h, origin + along * half_w + up * half_h, origin + along * half_w + up * -half_h, origin + along * -half_w + up * -half_h]
	var length := max_length
	if direction.y < -0.02: length = minf(length, (origin.y - half_h * 0.0) / -direction.y)
	var far: Array[Vector3] = []
	for point in near: far.append(point + direction * length)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 4:
		var next := (index + 1) % 4
		for entry in [[near[index], Vector2(0, 0)], [near[next], Vector2(1, 0)], [far[next], Vector2(1, 1)], [near[index], Vector2(0, 0)], [far[next], Vector2(1, 1)], [far[index], Vector2(0, 1)]]:
			tool.set_uv(entry[1])
			tool.add_vertex(entry[0])
	tool.generate_normals()
	return tool.commit()

func _set_shaft(shaft: Dictionary, origin: Vector3, normal: Vector3, direction: Vector3, strength: float, length: float) -> void:
	var node: MeshInstance3D = shaft.node
	if strength < 0.01 or direction == Vector3.ZERO:
		node.visible = false
		return
	node.visible = true
	node.mesh = _build_shaft(origin + normal * 0.02, normal, direction.normalized(), length)
	shaft.material.set_shader_parameter("intensity", strength)

func _set_shaft_out(shaft: Dictionary, origin: Vector3, direction: Vector3, strength: float, length: float) -> void:
	var node: MeshInstance3D = shaft.node
	if strength < 0.01:
		node.visible = false
		return
	node.visible = true
	node.mesh = _build_shaft(origin - direction * 0.0 + Vector3(0, 0, 0), Vector3.ZERO, direction, length)
	shaft.material.set_shader_parameter("intensity", strength)
