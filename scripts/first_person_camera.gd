extends Camera3D
## Controls the walking sway applied by the player controller.
@export_category("Balanco ao caminhar")
@export var balanco_ativo := true
## Amplitude vertical em metros; zero desativa este eixo.
@export_range(0.0, 0.10, 0.001) var intensidade_vertical := 0.018
## Amplitude lateral em metros; zero desativa este eixo.
@export_range(0.0, 0.10, 0.001) var intensidade_lateral := 0.0
## Distancia percorrida para completar um ciclo do balanco.
@export_range(0.4, 3.0, 0.05) var distancia_por_ciclo := 1.75
@export_range(1.0, 20.0, 0.5) var suavidade_balanco := 8.0

@export_category("Inclinacao ao mover o mouse")
@export var inclinacao_ativa := true
@export_range(0.0, 8.0, 0.1) var inclinacao_maxima_graus := 2.5
@export_range(0.0, 2.0, 0.05) var graus_por_100_pixels_segundo := 0.35
@export_range(1.0, 20.0, 0.5) var suavidade_inclinacao := 8.0
@export_category("Enquadramento do corpo em pe")
## Maior valor aproxima o ponto de vista do corpo e mostra mais dele ao olhar para baixo.
@export_range(0.0, 1.0, 0.05) var corpo_visivel_em_pe := 0.75
@export_range(1.4, 1.85, 0.01) var altura_em_pe := 1.62
@export_range(55.0, 80.0, 1.0) var olhar_baixo_em_pe := 70.0
var mouse_pending := 0.0
var current_roll := 0.0
var base_roll := 0.0
func _ready() -> void:
	base_roll = rotation.z
func add_mouse_sway(relative: Vector2) -> void:
	mouse_pending += relative.x
func clear_mouse_sway() -> void:
	mouse_pending = 0
	current_roll = 0
	rotation.z = base_roll
func _process(delta: float) -> void:
	var host = get_parent().get_parent()
	var target := 0.0
	if inclinacao_ativa and not host.is_zoomed and not host.is_transitioning and host.player.mode in [host.player.Mode.SEATED, host.player.Mode.FREE]:
		var pixels_per_second := mouse_pending / maxf(delta, 0.001)
		target = deg_to_rad(clampf(-pixels_per_second / 100.0 * graus_por_100_pixels_segundo, -inclinacao_maxima_graus, inclinacao_maxima_graus))
	mouse_pending = 0
	current_roll = lerpf(current_roll, target, 1.0 - exp(-suavidade_inclinacao * delta))
	rotation.z = base_roll + current_roll
