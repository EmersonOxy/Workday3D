extends Area3D
## Gatilho de proximidade: só executa após a tecla E no controlador principal.
@export var action_id: StringName
@export var prompt: String = "Interagir"
@export var door_path: NodePath

func contains_player(player: CharacterBody3D) -> bool:
	return monitoring and is_inside_tree() and get_overlapping_bodies().has(player)

func open_door() -> void:
	if door_path.is_empty():
		return
	var door := get_node_or_null(door_path) as Node3D
	if door == null:
		return
	var tween := create_tween()
	tween.tween_property(door, "rotation:y", door.rotation.y - deg_to_rad(78.0), 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
