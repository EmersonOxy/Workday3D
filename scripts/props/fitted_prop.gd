@tool
extends Node3D
## Instancia um modelo baixado e o ajusta a um tamanho real em metros, independente da unidade do arquivo
## (FBX em centímetros, GLB gigantes etc.). A base fica em y = 0 e o centro em x/z = 0 deste nó, então basta
## posicionar e girar o nó na cena. O modelo é recriado ao abrir a cena; não é salvo dentro dela.

@export var model: PackedScene:
	set(value):
		model = value
		_rebuild()
@export_enum("Altura", "Maior lado", "Largura (X)", "Profundidade (Z)") var fit_by := 0:
	set(value):
		fit_by = value
		_rebuild()
## Tamanho final em metros na medida escolhida acima.
@export var size := 1.0:
	set(value):
		size = maxf(0.001, value)
		_rebuild()
## Gira o modelo dentro do nó antes de medir (graus), para corrigir modelos deitados ou de costas.
@export var model_rotation := Vector3.ZERO:
	set(value):
		model_rotation = value
		_rebuild()

## Cria uma caixa de colisão do tamanho do modelo (móveis em que o jogador não deve atravessar).
@export var solid := false:
	set(value):
		solid = value
		_rebuild()

var _instance: Node3D
var _body: StaticBody3D

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree(): return
	if _instance != null:
		_instance.queue_free()
		_instance = null
	if _body != null:
		_body.queue_free()
		_body = null
	if model == null: return
	_instance = model.instantiate() as Node3D
	if _instance == null: return
	add_child(_instance, false, Node.INTERNAL_MODE_BACK)
	_instance.rotation_degrees = model_rotation
	var bounds := _local_bounds()
	if bounds.size == Vector3.ZERO: return
	var measure: float = [bounds.size.y, maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)), bounds.size.x, bounds.size.z][fit_by]
	var factor := size / maxf(measure, 0.0001)
	_instance.scale = Vector3.ONE * factor
	var center := bounds.get_center() * factor
	_instance.position = Vector3(-center.x, -bounds.position.y * factor, -center.z)
	if solid and not Engine.is_editor_hint():
		_body = StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = bounds.size * factor
		shape.shape = box
		shape.position = Vector3(0, box.size.y / 2, 0)
		_body.add_child(shape)
		add_child(_body, false, Node.INTERNAL_MODE_BACK)

func _local_bounds() -> AABB:
	var inverse := global_transform.affine_inverse()
	var bounds := AABB()
	var first := true
	for mesh in _instance.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (inverse * mesh.global_transform) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
