@tool
extends Node3D

const SCREEN_SIZE := Vector2(0.86, 0.48)
const VIEWPORT_SIZE := Vector2i(1280, 720)
const DESKTOP_SCREEN_FILL := 0.94
const WORKER_SKIN := preload("res://assets/materials/worker_skin.tres")
@export_range(10.0, 85.0, 1.0) var horizontal_look_limit_degrees := 65.0
@export_range(45.0, 100.0, 1.0) var seated_thigh_angle := 82.0:
	set(value):
		seated_thigh_angle = value
		if is_node_ready():
			_apply_seated_pose()
@export_range(-100.0, -45.0, 1.0) var seated_knee_angle := -82.0:
	set(value):
		seated_knee_angle = value
		if is_node_ready():
			_apply_seated_pose()

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/FirstPersonCamera
@onready var monitor_area: Area3D = $MonitorArea
@onready var monitor_screen: MeshInstance3D = $Monitor/Screen
@onready var pc_setup: Node3D = $PCSetup
@onready var worker_root: Node3D = $Character/OfficeWorker

@onready var desktop_viewport: SubViewport = $DesktopSubViewport
@onready var desktop: Control = $DesktopSubViewport/WorkOSDesktop
var desktop_buttons := 0
var last_desktop_mouse := Vector2.ZERO
var pre_zoom_camera_transform := Transform3D.IDENTITY
var initial_yaw := 0.0
var is_transitioning := false
var mouse_sensitivity := 0.002
var yaw := 0.0
var pitch := -0.14
var is_zoomed := false
var zoom_tween: Tween
var crosshair: Label
var desktop_pointer_over_screen := false
var last_pose_inputs: Array = []

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return
	var pose_inputs: Array = [worker_root.global_transform, $OfficeChair.global_transform]
	for target in $ArmRestTargets.get_children():
		pose_inputs.append(target.global_transform)
	if pose_inputs != last_pose_inputs:
		last_pose_inputs = pose_inputs
		_apply_seated_pose()

func _ready() -> void:
	_apply_model_fixes()
	if Engine.is_editor_hint():
		return

	initial_yaw = camera_pivot.rotation.y
	yaw = 0.0
	pitch = camera_pivot.rotation.x
	_build_desktop()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _apply_model_fixes() -> void:
	# The imported body material renders black in Compatibility. Use the
	# original diffuse swatch (202, 138, 110) without the imported PBR maps.
	for mesh_node in worker_root.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh_node.mesh.get_surface_count():
			var material: Material = mesh_node.mesh.surface_get_material(surface)
			if material != null and material.resource_name == "Wolf3D_Body":
				mesh_node.set_surface_override_material(surface, WORKER_SKIN)
	# The PC GLB includes a 2 x 2 m floor plane intended for a product render.
	var display_plane := pc_setup.find_child("Plane", true, false)
	if display_plane is VisualInstance3D:
		display_plane.visible = false

	# Fold the rig's legs into a static seated pose. The source GLB contains a
	# skeleton but no animation clips, so this is applied both in the editor and
	# when the scene runs.
	_apply_seated_pose()

func _apply_seated_pose() -> void:
	var skeleton := _find_skeleton(worker_root)
	if skeleton == null:
		return
	skeleton.reset_bone_poses()
	_set_bone_rotation(skeleton, "LeftUpLeg_057", seated_thigh_angle)
	_set_bone_rotation(skeleton, "RightUpLeg_062", seated_thigh_angle)
	_set_bone_rotation(skeleton, "LeftLeg_058", seated_knee_angle)
	_set_bone_rotation(skeleton, "RightLeg_063", seated_knee_angle)
	_pose_arm(skeleton, "LeftShoulder_010", "LeftArm_011", "LeftForeArm_012", "LeftHand_013", "LeftHandMiddle1_022", $ArmRestTargets/LeftHand, $ArmRestTargets/LeftElbow)
	_pose_arm(skeleton, "RightShoulder_033", "RightArm_034", "RightForeArm_035", "RightHand_036", "RightHandMiddle1_045", $ArmRestTargets/RightHand, $ArmRestTargets/RightElbow)
	var head_bone := skeleton.find_bone("Head_06")
	if head_bone >= 0:
		skeleton.set_bone_pose_scale(head_bone, Vector3.ZERO)

func _bone_position(skeleton: Skeleton3D, bone: int) -> Vector3:
	return skeleton.get_bone_global_pose(bone).origin

func _aim_bone(skeleton: Skeleton3D, bone: int, child: int, target: Vector3) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	var direction := _bone_position(skeleton, child) - pose.origin
	var desired := target - pose.origin
	if direction.length_squared() < 0.000001 or desired.length_squared() < 0.000001:
		return
	var rotation_delta := Quaternion(direction.normalized(), desired.normalized())
	var global_basis := Basis(rotation_delta) * pose.basis.orthonormalized()
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * global_basis).get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()

func _pose_arm(skeleton: Skeleton3D, clavicle_name: String, arm_name: String, forearm_name: String, hand_name: String, finger_name: String, hand_target: Node3D, elbow_hint: Node3D) -> void:
	var clavicle := skeleton.find_bone(clavicle_name)
	var arm := skeleton.find_bone(arm_name)
	var forearm := skeleton.find_bone(forearm_name)
	var hand := skeleton.find_bone(hand_name)
	var finger := skeleton.find_bone(finger_name)
	if mini(mini(clavicle, arm), mini(forearm, mini(hand, finger))) < 0:
		return
	skeleton.force_update_all_bone_transforms()
	var shoulder_world := skeleton.to_global(_bone_position(skeleton, arm))
	_aim_bone(skeleton, clavicle, arm, skeleton.to_local(shoulder_world + Vector3.DOWN * 0.045))
	var shoulder := _bone_position(skeleton, arm)
	var elbow := _bone_position(skeleton, forearm)
	var wrist := _bone_position(skeleton, hand)
	var upper_length := shoulder.distance_to(elbow)
	var lower_length := elbow.distance_to(wrist)
	var target := skeleton.to_local(hand_target.global_position)
	var direction := (target - shoulder).normalized()
	var distance := clampf(shoulder.distance_to(target), absf(upper_length - lower_length) + 0.001, upper_length + lower_length - 0.001)
	var bend := skeleton.to_local(elbow_hint.global_position) - shoulder
	bend = (bend - direction * bend.dot(direction)).normalized()
	var along := (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(upper_length * upper_length - along * along, 0.0))
	_aim_bone(skeleton, arm, forearm, shoulder + direction * along + bend * height)
	_aim_bone(skeleton, forearm, hand, shoulder + direction * distance)
	var forward: Vector3 = $OfficeChair.global_transform.basis.z.normalized()
	var finger_target := skeleton.to_local(skeleton.to_global(_bone_position(skeleton, hand)) + forward * 0.15)
	_aim_bone(skeleton, hand, finger, finger_target)
	# In this rig +Y points along the fingers and +Z faces the palm.
	var palm_down := Vector3.DOWN
	forward = (forward - palm_down * forward.dot(palm_down)).normalized()
	var world_basis := Basis(forward.cross(palm_down), forward, palm_down)
	var skeleton_basis := skeleton.global_transform.basis.orthonormalized().inverse() * world_basis
	var parent_basis := skeleton.get_bone_global_pose(skeleton.get_bone_parent(hand)).basis.orthonormalized()
	skeleton.set_bone_pose_rotation(hand, (parent_basis.inverse() * skeleton_basis).get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _set_bone_rotation(skeleton: Skeleton3D, bone_name: String, angle_degrees: float, axis: Vector3 = Vector3.RIGHT) -> void:
	var bone_index := skeleton.find_bone(bone_name)
	if bone_index >= 0:
		var rest_rotation := skeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion()
		var hinge_rotation := Quaternion(axis.normalized(), deg_to_rad(angle_degrees))
		skeleton.set_bone_pose_rotation(bone_index, rest_rotation * hinge_rotation)

func _build_desktop() -> void:
	desktop.exit_requested.connect(func() -> void: _set_zoomed(false))

	var screen_material := StandardMaterial3D.new()
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	screen_material.uv1_scale = Vector3(-1.0, 1.0, 1.0)
	screen_material.uv1_offset = Vector3(1.0, 0.0, 0.0)
	screen_material.albedo_texture = desktop_viewport.get_texture()
	monitor_screen.material_override = screen_material

	var hud := CanvasLayer.new()
	hud.name = "AimHUD"
	hud.layer = 5
	add_child(hud)
	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-7, -16)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_theme_font_size_override("font_size", 24)
	crosshair.add_theme_color_override("font_color", Color.WHITE)
	hud.add_child(crosshair)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or is_transitioning:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_zoomed:
			if not desktop.dismiss_menu(): _set_zoomed(false)
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if is_zoomed:
		if event is InputEventKey:
			desktop_viewport.push_input(event.duplicate(), true)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouse:
			_forward_desktop_input(event)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_mouse_look(event.relative)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		var hit := _raycast_from_mouse(event.position)
		if hit.get("collider") == monitor_area:
			_set_zoomed(true)
			get_viewport().set_input_as_handled()

func _forward_desktop_input(event: InputEventMouse) -> void:
	var normal := monitor_screen.global_transform.basis.z.normalized()
	var plane := Plane(normal, monitor_screen.global_position)
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
	if hit == null: return
	var pixel := _screen_to_viewport(hit)
	var inside := Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE)).has_point(pixel)
	if inside != desktop_pointer_over_screen:
		desktop_pointer_over_screen = inside
		if inside: desktop_viewport.notify_mouse_entered()
		else: desktop_viewport.notify_mouse_exited()
	if not inside and desktop_buttons == 0: return
	var mapped := event.duplicate() as InputEventMouse
	mapped.position = pixel
	mapped.global_position = pixel
	if mapped is InputEventMouseButton:
		if mapped.button_index == MOUSE_BUTTON_LEFT:
			desktop_buttons = MOUSE_BUTTON_MASK_LEFT if mapped.pressed else 0
		mapped.button_mask = desktop_buttons
	elif mapped is InputEventMouseMotion:
		mapped.relative = pixel - last_desktop_mouse
		mapped.button_mask = desktop_buttons
	last_desktop_mouse = pixel
	desktop_viewport.push_input(mapped, true)

func _apply_mouse_look(relative: Vector2) -> void:
	var limit := deg_to_rad(horizontal_look_limit_degrees)
	yaw = clampf(yaw - relative.x * mouse_sensitivity, -limit, limit)
	camera_pivot.rotation.y = initial_yaw + yaw
	pitch = clampf(pitch - relative.y * mouse_sensitivity, deg_to_rad(-55.0), deg_to_rad(35.0))
	camera_pivot.rotation.x = pitch

func _raycast_from_mouse(mouse_position: Vector2) -> Dictionary:
	var ray_start := camera.project_ray_origin(mouse_position)
	var ray_end := ray_start + camera.project_ray_normal(mouse_position) * 6.0
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _screen_to_viewport(world_position: Vector3) -> Vector2:
	# The hit box is in front of the display; intersect the display plane
	# itself so close-up clicks still match the displayed pixel.
	var plane := Plane(monitor_screen.global_transform.basis.z.normalized(), monitor_screen.global_position)
	var hit: Variant = plane.intersects_ray(camera.global_position, (world_position - camera.global_position).normalized())
	var local_position := monitor_screen.to_local(hit if hit != null else world_position)
	return Vector2(
		(0.5 - local_position.x / SCREEN_SIZE.x) * float(VIEWPORT_SIZE.x),
		(0.5 - local_position.y / SCREEN_SIZE.y) * float(VIEWPORT_SIZE.y)
	)

func _desktop_view_distance() -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var half_height_tangent := tan(deg_to_rad(camera.fov) * 0.5)
	if camera.keep_aspect == Camera3D.KEEP_WIDTH:
		half_height_tangent /= aspect
	var screen_scale := monitor_screen.global_transform.basis.get_scale()
	var fit_height := SCREEN_SIZE.y * screen_scale.y / (2.0 * half_height_tangent * DESKTOP_SCREEN_FILL)
	var fit_width := SCREEN_SIZE.x * screen_scale.x / (2.0 * half_height_tangent * aspect * DESKTOP_SCREEN_FILL)
	return maxf(fit_height, fit_width)

func _set_zoomed(enabled: bool) -> void:
	if is_zoomed == enabled:
		return
	is_zoomed = enabled
	desktop.set_monitor_focus(enabled)
	if not enabled:
		if desktop_buttons != 0:
			var release := InputEventMouseButton.new()
			release.button_index = MOUSE_BUTTON_LEFT
			release.position = last_desktop_mouse
			release.global_position = last_desktop_mouse
			desktop_viewport.push_input(release, true)
		desktop.suspend_input()
		desktop_buttons = 0
	if zoom_tween != null and zoom_tween.is_running():
		zoom_tween.kill()
	var target_transform: Transform3D
	if enabled:
		pre_zoom_camera_transform = camera_pivot.global_transform
		var forward := monitor_screen.global_transform.basis.z.normalized()
		var up := monitor_screen.global_transform.basis.y.normalized()
		var camera_target := Transform3D(Basis.looking_at(forward, up), monitor_screen.global_position - forward * _desktop_view_distance())
		# Account for the camera's own offset and rotation below the pivot.
		target_transform = camera_target * camera.transform.affine_inverse()
	else:
		target_transform = pre_zoom_camera_transform
	is_transitioning = true
	var start_transform := camera_pivot.global_transform
	zoom_tween = create_tween()
	zoom_tween.tween_method(func(weight: float) -> void:
		camera_pivot.global_transform = start_transform.interpolate_with(target_transform, weight), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	zoom_tween.tween_callback(func() -> void:
		camera_pivot.global_transform = target_transform
		is_transitioning = false)
	if crosshair != null:
		crosshair.visible = not enabled
	if enabled:
		desktop_pointer_over_screen = false
	elif desktop_pointer_over_screen:
		desktop_viewport.notify_mouse_exited()
		desktop_pointer_over_screen = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if enabled else Input.MOUSE_MODE_CAPTURED
