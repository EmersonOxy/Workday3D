extends SceneTree
func _initialize() -> void:
	call_deferred("build")
func collect(node: Node, transform: Transform3D, faces: PackedVector3Array) -> void:
	var current := transform
	if node is Node3D: current = transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		for v in node.mesh.get_faces(): faces.append(current * v)
	for child in node.get_children(): collect(child, current, faces)
func owned(node: Node, owner_node: Node) -> void:
	for child in node.get_children(): child.owner = owner_node; owned(child, owner_node)
func box(parent: Node, name: String, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.position = position
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
func build() -> void:
	# Read scene transforms without running its gameplay scripts.
	var scene := load("res://scenes/main.tscn").instantiate() as Node3D
	var group := Node3D.new()
	group.name = "WorldCollisions"
	for item in {"OfficeTable":"Table"}:
		var faces := PackedVector3Array()
		collect(scene.get_node(item), Transform3D.IDENTITY, faces)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		var body := StaticBody3D.new()
		body.name = {"OfficeTable":"Table", "OfficeChair":"Chair"}[item]
		body.set_meta("source_transform", scene.get_node(item).transform)
		group.add_child(body)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		var bounds := AABB(faces[0], Vector3.ZERO)
		for v in faces: bounds = bounds.expand(v)
		print(item, " bounds=",bounds)
	chair_proxy(group, scene.get_node("OfficeChair").transform)
	box(group,"Floor", Vector3(12,0.12,12), Vector3(0,-0.06,0))
	box(group,"BackWall", Vector3(12,4,0.12), Vector3(0,2,3.25))
	box(group,"SideWall", Vector3(0.12,4,12), Vector3(-4.5,2,0))
	box(group,"RightBoundary", Vector3(0.12,4,12), Vector3(6,2,0))
	box(group,"FrontBoundary", Vector3(12,4,0.12), Vector3(0,2,-6))
	owned(group,group)
	var packed := PackedScene.new()
	packed.pack(group)
	ResourceSaver.save(packed,"res://scenes/world_collisions.tscn")
	group.free()
	scene.free()
	quit()

func chair_proxy(parent: Node3D, authored: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.name = "Chair"
	body.set_meta("source_transform", authored)
	parent.add_child(body)
	var original := Transform3D(Basis.from_scale(Vector3(0.01, 0.008, 0.01)), Vector3(0,0,-1.0948821))
	var relative := authored * original.affine_inverse()
	var boxes := [["Seat",Vector3(0.55,0.14,0.52),Vector3(0,0.49,-1.07)],["Back",Vector3(0.56,0.53,0.14),Vector3(0,0.77,-1.4)],["LeftArm",Vector3(0.12,0.13,0.44),Vector3(0.34,0.68,-1.09)],["RightArm",Vector3(0.12,0.13,0.44),Vector3(-0.34,0.68,-1.09)]]
	for entry in boxes:
		var shape := BoxShape3D.new()
		shape.size = entry[1]
		var collision := CollisionShape3D.new()
		collision.name = entry[0]
		collision.shape = shape
		collision.transform = relative * Transform3D(Basis.IDENTITY, entry[2])
		body.add_child(collision)
	var base := CollisionShape3D.new()
	base.name = "Base"
	var shape := CylinderShape3D.new()
	shape.radius = 0.43
	shape.height = 0.25
	base.shape = shape
	base.transform = relative * Transform3D(Basis.IDENTITY, Vector3(0,0.15,-1.095))
	body.add_child(base)
