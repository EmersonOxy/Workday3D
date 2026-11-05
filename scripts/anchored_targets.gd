@tool
extends Node3D
## Keeps editable targets attached to their furniture without inheriting its scale.
@export_node_path("Node3D") var ancora: NodePath
var previous := Transform3D.IDENTITY
var initialized := false
func _ready() -> void:
	sync_anchor()
func _process(_delta: float) -> void:
	sync_anchor()
func sync_anchor() -> void:
	var anchor := get_node_or_null(ancora) as Node3D
	if anchor == null or not is_inside_tree(): return
	if initialized and anchor.global_transform != previous:
		global_transform = anchor.global_transform * previous.affine_inverse() * global_transform
	previous = anchor.global_transform
	initialized = true
