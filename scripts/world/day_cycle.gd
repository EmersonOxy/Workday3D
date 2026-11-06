extends Node
## Iluminação por horário fora do escritório (rua, mercado e casa), a partir do relógio do jogo (game_clock.gd).
## Sol nasce às 06:00, fica a pino ao meio-dia e se põe às 18:00; à noite entra a lua e acendem as luzes do
## grupo "luz_noturna" (postes, luminária de casa). O céu usa assets/shaders/sky_day_night.gdshader.

const SKY_SHADER := preload("res://assets/shaders/sky_day_night.gdshader")
const NIGHT_GROUP := "luz_noturna"

var game: Node
var world_env: WorldEnvironment
var office_env: Environment
var outdoor_env: Environment
var location := "office"
var sun: DirectionalLight3D
var moon: DirectionalLight3D
## Debug (tecla H): passa o horário fora do escritório a 60 minutos por segundo, só no visual (não muda o save).
var debug_fast := false
var debug_offset := 0.0

func setup(environment_node: WorldEnvironment, state: Node) -> void:
	world_env = environment_node
	office_env = environment_node.environment
	game = state
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	sky_material.set_shader_parameter("stars_texture", _stars_texture())
	var sky := Sky.new()
	sky.sky_material = sky_material
	outdoor_env = Environment.new()
	outdoor_env.background_mode = Environment.BG_SKY
	outdoor_env.sky = sky
	outdoor_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	outdoor_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

## Chamado pelo world_travel.gd a cada troca de cenário.
func apply(destination: String, scene: Node3D) -> void:
	location = destination
	sun = null
	moon = null
	if destination == "office" or scene == null:
		world_env.environment = office_env
		return
	world_env.environment = outdoor_env
	sun = scene.get_node_or_null("Sun") as DirectionalLight3D
	if sun == null: return
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	moon.light_color = Color(0.62, 0.7, 1.0)
	scene.add_child(moon)
	_update()

func _process(delta: float) -> void:
	if debug_fast: debug_offset = fmod(debug_offset + delta * 60.0, 1440.0)
	if location != "office" and is_instance_valid(sun): _update()

func debug_toggle() -> String:
	debug_fast = not debug_fast
	if not debug_fast: debug_offset = 0.0
	return "Debug: horário acelerado (60 min/s)" if debug_fast else "Debug: horário normal"

func _update() -> void:
	var minute: float = fmod(game.clock.minute() + debug_offset, 1440.0)
	var t := (minute - 360.0) / 720.0
	var elevation := sin(t * PI) * 65.0
	var azimuth := lerpf(-100.0, 100.0, clampf(t, 0.0, 1.0)) + 35.0
	var daylight := clampf(elevation / 15.0, 0.0, 1.0)
	var low_sun := 1.0 - clampf(elevation / 30.0, 0.0, 1.0)
	sun.rotation_degrees = Vector3(-elevation, azimuth, 0.0)
	sun.light_energy = 0.05 + 0.7 * daylight
	sun.light_color = Color(1.0, 0.97, 0.9).lerp(Color(1.0, 0.55, 0.3), low_sun)
	sun.shadow_enabled = daylight > 0.05
	moon.rotation_degrees = Vector3(-maxf(25.0, -elevation), azimuth + 180.0, 0.0)
	moon.light_energy = 0.18 * (1.0 - daylight)
	moon.visible = daylight < 0.5
	outdoor_env.ambient_light_color = Color(0.13, 0.15, 0.27).lerp(Color(0.6, 0.65, 0.75), daylight)
	outdoor_env.ambient_light_energy = 0.5 + 0.1 * daylight
	for light in get_tree().get_nodes_in_group(NIGHT_GROUP):
		light.visible = daylight < 0.35
	# Luzes de casa ficam sempre acesas, mais fortes à noite.
	for light in get_tree().get_nodes_in_group("luz_interna"):
		light.light_energy = lerpf(1.3, 0.7, daylight)

func _stars_texture() -> ImageTexture:
	var image := Image.create(512, 512, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in 900:
		var brightness := rng.randf_range(0.35, 1.0)
		image.set_pixel(rng.randi_range(0, 511), rng.randi_range(0, 511), Color(brightness, brightness, brightness * 1.05))
	return ImageTexture.create_from_image(image)
