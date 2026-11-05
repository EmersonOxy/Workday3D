extends CharacterBody3D
## Slow first-person locomotion, driven by the supplied animation's root travel.
## Runtime only: the main scene keeps its existing seated editor preview.

enum Mode { ROLLING_OUT, ROLLING_IN, SEATED, STANDING_UP, FREE, APPROACHING, ALIGNING, SITTING_DOWN, TO_TYPE, TYPING, FROM_TYPE }
@export_category("Movimentacao")
## Velocidade desejada em metros por segundo; altera tambem o ritmo dos passos.
@export_range(0.2, 1.5, 0.05) var velocidade_caminhada_m_s := 0.7
@export_range(1.0, 15.0, 0.5) var suavidade_direcao := 5.0
## 1 mantém a amplitude original; 0 mantém os braços na postura neutra.
@export_range(0.0, 1.0, 0.05) var amplitude_bracos_caminhada := 0.65
@export_category("Cadeira e computador")
@export_range(0.6, 2.0, 0.05) var chair_interaction_distance := 1.35
@export_range(0.0, 0.5, 0.01) var typing_focus_delay := 0.15
@export_range(0.05, 0.4, 0.01) var animation_blend := 0.16
@export_range(0.2, 1.0, 0.05) var chair_pullback_distance := 0.55
@export var eye_offset := Vector3.ZERO
var camera_offset := Vector3.ZERO
var smoothed_input := Vector2.ZERO
var movement_velocity := Vector3.ZERO
var walk_distance := 0.0
var bob_phase := 0.0
var bob_strength := 0.0
var bob_offset := Vector2.ZERO
var seated_visual_basis := Basis.IDENTITY
var upright_visual_basis := Basis.IDENTITY
var type_exit_wait := 0.0
var type_exit_started := false
var chair_initial := Vector3.ZERO
var chair_collision_initial := Vector3.ZERO
var chair_out := false
var roll_time := 0.0

var mode := Mode.SEATED
var host: Node3D
var rig: Skeleton3D
var animator: AnimationPlayer
var seat := Transform3D.IDENTITY
var seat_camera_position := Vector3.ZERO
var chair_camera_start := Transform3D.IDENTITY
var chair_camera_elapsed := 0.0
var clip := ""
var clock := 0.0
var rate := 1.0
var alignment_time := 0.0
var alignment_start := Quaternion.IDENTITY
var approach_timeout := 0.0
var hint: Label
var head := -1
var neutral_arm_rotations: Dictionary = {}
var feet: Array[int] = []
var last_support := -1
var chair_collision: StaticBody3D
var chair_clearance := true
const LIBRARY := preload("res://assets/animations/generated/player_library.res")

func configure(scene: Node3D) -> void:
	host = scene
	rig = host._find_skeleton($OfficeWorker)
	animator = $AnimationPlayer
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	head = rig.find_bone("Head_06")
	var idle := LIBRARY.get_animation("idle")
	for track in idle.get_track_count():
		if idle.track_get_type(track) != Animation.TYPE_ROTATION_3D: continue
		var path := idle.track_get_path(track)
		if path.get_subname_count() == 0: continue
		var bone_name := str(path.get_subname(0))
		if bone_name in ["LeftShoulder_010", "LeftArm_011", "LeftForeArm_012", "RightShoulder_033", "RightArm_034", "RightForeArm_035"]:
			var index := rig.find_bone(bone_name)
			if index >= 0: neutral_arm_rotations[index] = idle.rotation_track_interpolate(track, 0.0)
	feet.assign([rig.find_bone("LeftFoot_059"), rig.find_bone("RightFoot_064")])
	seat = global_transform
	var authored_basis := seat.basis.orthonormalized()
	seat.basis = Basis(Vector3.UP, seat.basis.get_euler().y)
	upright_visual_basis = $OfficeWorker.basis
	seated_visual_basis = seat.basis.inverse() * authored_basis * upright_visual_basis
	# Preserve authored vertical edits relative to the original seated scene.
	$OfficeWorker.position.y += seat.origin.y + 0.44503438
	$OfficeWorker.basis = seated_visual_basis
	seat.origin.y = 0.0
	global_transform = seat
	seat_camera_position = host.get_node("ChairCameraTargets/SeatedView").global_position
	# The FBX already contains the sitting pelvis height; don't retain the old
	# -0.445 m offset used for the procedural pose.
	_play("sit_idle")
	animator.advance(0)
	_hide_head()
	preload("res://scripts/first_person_body.gd").configure($OfficeWorker, rig, host.camera)
	rig.force_update_all_bone_transforms()
	camera_offset = seat.basis.inverse() * (seat_camera_position - rig.to_global(rig.get_bone_global_pose(head).origin))
	chair_initial = host.get_node("OfficeChair").position
	chair_collision = host.get_node("WorldCollisions/Chair")
	chair_collision_initial = chair_collision.position
	add_collision_exception_with(chair_collision)
	$BodyShape.disabled = true
	collision_mask = 1
	floor_snap_length = 0.18
	hint = host.get_node("AimHUD/InteractionHint")
	_update_hint()

func is_seated() -> bool:
	return mode in [Mode.SEATED, Mode.TO_TYPE, Mode.TYPING, Mode.FROM_TYPE]

func can_use_computer() -> bool:
	return mode == Mode.SEATED

func begin_typing() -> float:
	mode = Mode.TO_TYPE
	_play("to_type")
	return LIBRARY.get_animation("to_type").length + typing_focus_delay + 0.8

func end_typing() -> float:
	mode = Mode.FROM_TYPE
	type_exit_wait = 0.5
	type_exit_started = false
	return type_exit_wait + LIBRARY.get_animation("from_type").length + 0.25

func interact() -> void:
	if mode == Mode.SEATED:
		mode = Mode.ROLLING_OUT
		_begin_chair_camera()
		roll_time = 0.0
	elif mode == Mode.FREE and _near_chair():
		mode = Mode.APPROACHING
		chair_clearance = true
		add_collision_exception_with(chair_collision)
		approach_timeout = 0
		last_support = -1

func teleport_from_travel(destination: Vector3, facing_yaw: float) -> void:
	# Reaproveita a mesma instância/rig/WorkOS ao mudar o cenário 3D.
	mode = Mode.FREE
	global_position = destination
	global_basis = Basis(Vector3.UP, facing_yaw - PI)
	movement_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
	walk_distance = 0.0
	bob_strength = 0.0
	bob_offset = Vector2.ZERO
	$BodyShape.disabled = false
	$OfficeWorker.basis = upright_visual_basis
	if chair_collision != null:
		remove_collision_exception_with(chair_collision)
	chair_clearance = false
	_play("idle")
	host.camera.clear_mouse_sway()
	host.camera_pivot.rotation = Vector3(0, facing_yaw, 0)
	host.camera_pivot.global_position = destination + Vector3.UP * host.camera.altura_em_pe
	host.initial_yaw = facing_yaw
	host.yaw = 0.0
	host.pitch = 0.0

func _near_chair() -> bool:
	var delta := global_position - _chair_seat().origin
	delta.y = 0
	return delta.length() <= chair_interaction_distance

func _chair_seat() -> Transform3D:
	var result := seat
	if chair_out: result.origin -= seat.basis.z * chair_pullback_distance
	return result

func _roll_chair(delta: float) -> void:
	roll_time += delta
	var fraction := smoothstep(0, 1, minf(roll_time / 0.65, 1))
	if mode == Mode.ROLLING_IN: fraction = 1.0 - fraction
	var offset := -seat.basis.z * chair_pullback_distance * fraction
	global_transform = seat
	global_position += offset
	host.get_node("OfficeChair").position = chair_initial + offset
	host.get_node("WorldCollisions/Chair").position = chair_collision_initial + offset
	_advance(delta)
	if roll_time >= 0.65:
		if mode == Mode.ROLLING_OUT:
			chair_out = true
			mode = Mode.STANDING_UP
			_begin_chair_camera()
			_play("stand_up")
		else:
			chair_out = false
			_finish_chair_camera("SeatedView")
			mode = Mode.SEATED

func _play(name: String, playback: float = 1.0) -> void:
	if clip == name and signf(rate) == signf(playback):
		rate = playback
		animator.speed_scale = absf(playback)
		return
	clip = name
	rate = playback
	clock = LIBRARY.get_animation(name).length if playback < 0 else 0.0
	animator.speed_scale = absf(playback)
	animator.play(name, animation_blend, signf(playback), playback < 0)
	last_support = -1

func _root_at(animation: Animation, time: float) -> Vector3:
	var positions: PackedVector3Array = animation.get_meta("root_motion")
	var loops := floorf(time / animation.length) if animation.loop_mode != Animation.LOOP_NONE else 0.0
	var local_time := fposmod(time, animation.length) if animation.loop_mode != Animation.LOOP_NONE else clampf(time, 0, animation.length)
	var sample := local_time * float(animation.get_meta("sample_rate"))
	var index := mini(floori(sample), positions.size() - 1)
	return positions[index].lerp(positions[mini(index + 1, positions.size() - 1)], sample - index) + positions[-1] * loops

func _advance(delta: float) -> Vector3:
	var animation := LIBRARY.get_animation(clip)
	var before := _root_at(animation, clock)
	clock += delta * rate
	rig.reset_bone_poses()
	animator.advance(delta)
	_reduce_arm_swing()
	_hide_head()
	host.get_node("PoseAdjustments").apply_body(rig)
	_pose_hands()
	var finger_weight := _seated_finger_weight()
	host.get_node("PoseAdjustments").apply_fingers(rig, finger_weight)
	host.get_node("PoseAdjustments").apply_handles(rig, finger_weight)
	host.get_node("PoseAdjustments").neutral_standing_fingers(rig, 1.0 - finger_weight)
	return _root_at(animation, clock) - before

func _reduce_arm_swing() -> void:
	if mode not in [Mode.FREE, Mode.APPROACHING] or clip not in ["walk", "strafe_left", "strafe_right"]: return
	for bone in neutral_arm_rotations:
		var neutral: Quaternion = neutral_arm_rotations[bone]
		rig.set_bone_pose_rotation(bone, neutral.slerp(rig.get_bone_pose_rotation(bone), amplitude_bracos_caminhada))

func _seated_finger_weight() -> float:
	if mode in [Mode.FREE, Mode.APPROACHING, Mode.ALIGNING]: return 0.0
	if mode in [Mode.STANDING_UP, Mode.SITTING_DOWN]:
		var progress := smoothstep(0, 1, clampf(clock / LIBRARY.get_animation(clip).length, 0, 1))
		return 1.0 - progress if mode == Mode.STANDING_UP else progress
	return 1.0

func _finished() -> bool:
	var animation := LIBRARY.get_animation(clip)
	return animation.loop_mode == Animation.LOOP_NONE and (clock >= animation.length if rate > 0 else clock <= 0)

func _hide_head() -> void:
	# The first-person derivative removes upper torso/head geometry. Keep the
	# actual rig intact so scaling the head cannot stretch the neck or clothing.
	if head >= 0: rig.set_bone_pose_scale(head, Vector3.ONE)

func _physics_process(delta: float) -> void:
	if host == null: return
	walk_distance = 0.0
	match mode:
		Mode.ROLLING_OUT, Mode.ROLLING_IN:
			_roll_chair(delta)
		Mode.SEATED, Mode.TYPING:
			_advance(delta)
		Mode.TO_TYPE:
			_advance(delta)
			if _finished(): mode = Mode.TYPING; _play("typing")
		Mode.FROM_TYPE:
			if not type_exit_started:
				type_exit_wait -= delta
				if type_exit_wait <= 0:
					type_exit_started = true
					_play("from_type")
			_advance(delta)
			if type_exit_started and _finished(): mode = Mode.SEATED; _play("sit_idle")
		Mode.STANDING_UP, Mode.SITTING_DOWN:
			var travel := _advance(delta)
			global_position += seat.basis * travel
			if _finished():
				if mode == Mode.STANDING_UP:
					_finish_chair_camera("StandingView")
					mode = Mode.FREE
					$BodyShape.disabled = false
					_play("idle")
					host.yaw = 0.0
					host.initial_yaw = host.camera_pivot.rotation.y
				else:
					global_transform = _chair_seat()
					mode = Mode.ROLLING_IN
					_begin_chair_camera()
					roll_time = 0.0
					_play("sit_idle")
					host.initial_yaw = seat.basis.get_euler().y + PI
					host.yaw = 0
		Mode.FREE, Mode.APPROACHING:
			_walk(delta)
		Mode.ALIGNING:
			alignment_time += delta
			global_basis = Basis(alignment_start.slerp(seat.basis.get_rotation_quaternion(), smoothstep(0, 1, alignment_time / 0.25)))
			_advance(delta)
			if alignment_time >= 0.25:
				mode = Mode.SITTING_DOWN
				_begin_chair_camera()
				$BodyShape.disabled = true
				var end := _root_at(LIBRARY.get_animation("sit_down"), LIBRARY.get_animation("sit_down").length)
				global_position = _chair_seat().origin - seat.basis * end
				_play("sit_down")
	if mode == Mode.FREE and chair_clearance and global_position.distance_to(_chair_seat().origin) > 0.9:
		remove_collision_exception_with(chair_collision)
		chair_clearance = false
	var upright_weight := 1.0 if mode in [Mode.FREE, Mode.APPROACHING, Mode.ALIGNING] else 0.0
	if mode in [Mode.STANDING_UP, Mode.SITTING_DOWN]:
		upright_weight = clampf(clock / LIBRARY.get_animation(clip).length, 0, 1)
		if mode == Mode.SITTING_DOWN: upright_weight = 1.0 - upright_weight
	$OfficeWorker.basis = Basis(seated_visual_basis.get_rotation_quaternion().slerp(upright_visual_basis.get_rotation_quaternion(), smoothstep(0, 1, upright_weight)))
	_update_walk_bob(delta)
	_follow_camera(delta)
	_update_hint()

func _walk(delta: float) -> void:
	var input := Vector2.ZERO
	var direction := Vector3.ZERO
	if mode == Mode.APPROACHING:
		approach_timeout += delta
		var finish := _root_at(LIBRARY.get_animation("sit_down"), LIBRARY.get_animation("sit_down").length)
		var entry := _chair_seat().origin - seat.basis * finish
		direction = entry - global_position
		direction.y = 0
		if direction.length() < 0.045:
			movement_velocity = Vector3.ZERO
			mode = Mode.ALIGNING
			_begin_chair_camera()
			alignment_time = 0
			alignment_start = global_basis.get_rotation_quaternion()
			_play("idle")
			return
		if approach_timeout > 7:
			mode = Mode.FREE
			movement_velocity = Vector3.ZERO
			_play("idle")
			return
		direction = direction.normalized()
		global_basis = Basis(global_basis.get_rotation_quaternion().slerp(Basis.looking_at(-direction, Vector3.UP).get_rotation_quaternion(), 1.0 - exp(-6.0 * delta)))
		input = Vector2(0, -1)
	else:
		# View and torso share heading, so looking around never exposes the back.
		global_basis = Basis(Vector3.UP, host.camera_pivot.rotation.y - PI)
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			input = Input.get_vector("walk_left", "walk_right", "walk_forward", "walk_back")
		var facing := Basis(Vector3.UP, host.camera_pivot.rotation.y)
		direction = facing * Vector3(input.x, 0, input.y)
	var desired_velocity := direction * velocidade_caminhada_m_s
	var acceleration := clampf(suavidade_direcao, 2.0, 8.0)
	movement_velocity = movement_velocity.move_toward(desired_velocity, acceleration * delta)
	var before := global_position
	var falling := velocity.y
	velocity = movement_velocity
	velocity.y = -0.5 if is_on_floor() else falling - 9.8 * delta
	move_and_slide()
	var actual := global_position - before
	actual.y = 0
	walk_distance = actual.length()
	var actual_speed := walk_distance / maxf(delta, 0.001)
	if actual_speed < 0.025:
		_play("idle")
		_advance(delta)
		return
	var local_motion := Basis(Vector3.UP, host.camera_pivot.rotation.y).inverse() * actual
	var next_clip := "walk"
	if absf(local_motion.x) > absf(local_motion.z) * 1.25:
		next_clip = "strafe_left" if local_motion.x < 0 else "strafe_right"
	elif clip in ["strafe_left", "strafe_right"] and absf(local_motion.x) > absf(local_motion.z) * 0.8:
		next_clip = "strafe_left" if local_motion.x < 0 else "strafe_right"
	if mode == Mode.APPROACHING: next_clip = "walk"
	var animation := LIBRARY.get_animation(next_clip)
	var native_speed := _root_at(animation, animation.length).length() / animation.length
	var playback := actual_speed / maxf(native_speed, 0.01)
	if next_clip == "walk" and local_motion.z > 0 and mode != Mode.APPROACHING: playback = -playback
	_play(next_clip, playback)
	_advance(delta)

func _begin_chair_camera() -> void:
	host.camera.clear_mouse_sway()
	chair_camera_start = host.camera_pivot.global_transform
	chair_camera_elapsed = 0.0
func _finish_chair_camera(marker: String) -> void:
	host.get_node("ChairCameraTargets").sync_anchor()
	host.camera_pivot.global_transform = host.get_node("ChairCameraTargets/" + marker).global_transform
	host.initial_yaw = host.camera_pivot.rotation.y
	host.yaw = 0
	host.pitch = host.camera_pivot.rotation.x
	if marker == "SeatedView": seat_camera_position = host.camera_pivot.global_position
func _locked_chair_camera(delta: float) -> void:
	chair_camera_elapsed += delta
	host.get_node("ChairCameraTargets").sync_anchor()
	var marker := "StandingView" if mode in [Mode.STANDING_UP, Mode.ALIGNING] else "SeatedView"
	var target: Transform3D = host.get_node("ChairCameraTargets/" + marker).global_transform
	var duration := 0.4
	if mode in [Mode.STANDING_UP, Mode.SITTING_DOWN]: duration = LIBRARY.get_animation(clip).length
	var progress := smoothstep(0, 1, clampf(chair_camera_elapsed / duration, 0, 1))
	host.camera_pivot.global_transform = chair_camera_start.interpolate_with(target, progress)

func _update_walk_bob(delta: float) -> void:
	var camera_controls = host.camera
	var moving: bool = camera_controls.balanco_ativo and mode == Mode.FREE and walk_distance > 0.0001
	if moving: bob_phase = fposmod(bob_phase + TAU * walk_distance / maxf(camera_controls.distancia_por_ciclo, 0.01), TAU)
	var target := clampf(walk_distance / maxf(delta, 0.001) / maxf(velocidade_caminhada_m_s, 0.01), 0.0, 1.0) if moving else 0.0
	bob_strength = lerpf(bob_strength, target, 1.0 - exp(-float(camera_controls.suavidade_balanco) * delta))
	bob_offset = Vector2(sin(bob_phase) * float(camera_controls.intensidade_lateral), (absf(sin(bob_phase)) - 0.5) * float(camera_controls.intensidade_vertical)) * bob_strength

func _follow_camera(delta: float) -> void:
	if host.is_zoomed or host.is_transitioning: return
	if mode in [Mode.ROLLING_OUT, Mode.STANDING_UP, Mode.ALIGNING, Mode.SITTING_DOWN, Mode.ROLLING_IN]:
		_locked_chair_camera(delta)
		return
	if mode == Mode.SEATED:
		host.camera_pivot.global_position = _safe_camera_position(seat_camera_position)
		return
	if mode in [Mode.TO_TYPE, Mode.TYPING, Mode.FROM_TYPE]: return
	if mode in [Mode.APPROACHING, Mode.ALIGNING, Mode.SITTING_DOWN, Mode.ROLLING_IN]:
		host.camera_pivot.rotation.y = lerp_angle(host.camera_pivot.rotation.y, rotation.y + PI, minf(delta * 5.0, 1.0))
	var seated_height := seat_camera_position.y - seat.origin.y
	var height: float = host.camera.altura_em_pe
	if mode in [Mode.ROLLING_OUT, Mode.ROLLING_IN]: height = seated_height
	elif mode in [Mode.STANDING_UP, Mode.SITTING_DOWN]:
		var standing_weight := clampf(clock / LIBRARY.get_animation(clip).length, 0, 1)
		if mode == Mode.SITTING_DOWN: standing_weight = 1.0 - standing_weight
		height = lerpf(seated_height, host.camera.altura_em_pe, smoothstep(0, 1, standing_weight))
	var camera_forward: Vector3 = -host.camera_pivot.global_basis.z
	camera_forward.y = 0
	camera_forward = camera_forward.normalized()
	var advance := lerpf(0.28, 0.03, float(host.camera.corpo_visivel_em_pe)) if mode in [Mode.FREE, Mode.APPROACHING] else 0.2
	var desired_position: Vector3 = global_position + Vector3.UP * height + camera_forward * advance + global_basis * eye_offset
	if mode == Mode.FREE:
		desired_position += host.camera_pivot.global_basis.x * bob_offset.x + Vector3.UP * bob_offset.y
	var previous_y: float = host.camera_pivot.global_position.y
	# Never let X/Z lag behind the torso during a turn.
	host.camera_pivot.global_position = _safe_camera_position(desired_position)
	host.camera_pivot.global_position.y = lerpf(previous_y, desired_position.y, 1.0 - exp(-12.0 * delta))

func follow_view_heading() -> void:
	if mode != Mode.FREE: return
	global_basis = Basis(Vector3.UP, host.camera_pivot.rotation.y - PI)
	_follow_camera(0.0)

func _safe_camera_position(desired: Vector3) -> Vector3:
	var neck := rig.find_bone("Neck_05")
	if neck < 0: return desired
	var neck_position := rig.to_global(rig.get_bone_global_pose(neck).origin)
	var forward: Vector3 = -host.camera_pivot.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var eye: Vector3 = desired + host.camera_pivot.global_basis * host.camera.position
	var clearance := (eye - neck_position).dot(forward)
	var minimum := 0.075 if mode == Mode.FREE else 0.13
	if clearance < minimum: desired += forward * (minimum - clearance)
	return desired

func _pose_hands() -> void:
	var weight := -1.0
	if mode in [Mode.SEATED, Mode.ROLLING_OUT, Mode.ROLLING_IN]: weight = 0
	elif mode == Mode.TO_TYPE: weight = smoothstep(0, 1, clampf(clock / LIBRARY.get_animation("to_type").length, 0, 1))
	elif mode == Mode.TYPING: weight = 1
	elif mode == Mode.FROM_TYPE:
		weight = 1.0 - smoothstep(0, 1, clampf(clock / LIBRARY.get_animation("from_type").length, 0, 1)) if type_exit_started else 1.0
	if weight >= 0:
		host.adjust_typing_lean(rig, weight)
		host.pose_player_hands(rig, weight, clock)
	elif mode in [Mode.STANDING_UP, Mode.SITTING_DOWN]:
		var standing := smoothstep(0, 1, clampf(clock / LIBRARY.get_animation(clip).length, 0, 1))
		if mode == Mode.SITTING_DOWN: standing = 1.0 - standing
		host.pose_transition_hands(rig, standing, clock)
	elif mode not in [Mode.FREE, Mode.APPROACHING, Mode.ALIGNING]:
		host.pose_transition_hands(rig, 1.0, clock)

func typing_overview() -> Transform3D:
	var forward := seat.basis.z.normalized()
	var eye := seat_camera_position + forward * 0.22
	var hands: Vector3 = (host.get_node("TypingTargets/LeftHand").global_position + host.get_node("TypingTargets/RightHand").global_position) * 0.5
	var camera_transform := Transform3D(Basis.looking_at((hands + Vector3.UP * 0.1 - eye).normalized(), Vector3.UP), eye)
	return camera_transform * host.camera.transform.affine_inverse()

func _update_hint() -> void:
	if host.is_zoomed or host.is_transitioning:
		hint.text = ""
	elif mode == Mode.SEATED:
		hint.text = "E · Levantar   |   Clique no monitor · Usar PC"
	elif mode == Mode.FREE:
		var world_prompt: String = host.travel.interaction_prompt() if host.get("travel") != null else ""
		hint.text = world_prompt if not world_prompt.is_empty() else ("E · Sentar" if host.travel.location == "office" and _near_chair() else "W A S D · Caminhar")
	else:
		hint.text = ""
