extends SceneTree
const FILES := {"idle":"Idle.fbx", "sit_idle":"Sitting Idle.fbx", "stand_up":"Sit To Stand.fbx", "sit_down":"Stand To Sit.fbx", "to_type":"Sit To Type.fbx", "from_type":"Type To Sit.fbx", "typing":"Typing.fbx", "walk":"Standard Walk.fbx", "walk_start":"Start Walking.fbx", "strafe_left":"Basic Locomotion Pack/left strafe walking.fbx", "strafe_right":"Basic Locomotion Pack/right strafe walking.fbx"}
const LOOPS := ["idle", "sit_idle", "typing", "walk", "strafe_left", "strafe_right"]
func _initialize() -> void:
	call_deferred("bake")
func canonical(value: String) -> String:
	return value.trim_prefix("mixamorig_").trim_prefix("mixamorig:").split("_")[0]
func child_bone(sk: Skeleton3D, index: int) -> int:
	var children := sk.get_bone_children(index)
	for child in children:
		var name := canonical(sk.get_bone_name(child))
		if name.ends_with("end") or "Eye" in name: continue
		return child
	return -1
func bake() -> void:
	var target := load("res://assets/models/the_character_of_an_office_worker.glb").instantiate() as Node3D
	root.add_child(target)
	var rig: Skeleton3D = target.find_children("*", "Skeleton3D", true, false)[0]
	var target_names := {}
	for i in rig.get_bone_count(): target_names[canonical(rig.get_bone_name(i))] = i
	var library := AnimationLibrary.new()
	var report := {}
	for id in FILES:
		var source := load("res://assets/animations/player/" + FILES[id]).instantiate() as Node3D
		root.add_child(source)
		var sk: Skeleton3D = source.find_children("*", "Skeleton3D", true, false)[0]
		var player: AnimationPlayer = source.find_children("*", "AnimationPlayer", true, false)[0]
		var original: Animation
		for key in player.get_animation_list():
			if key != "RESET": original = player.get_animation(key); break
		var mapping := {}
		var rotation_tracks := {}
		var position_tracks := {}
		for i in sk.get_bone_count():
			var name := canonical(sk.get_bone_name(i))
			if target_names.has(name): mapping[i] = target_names[name]
		for i in original.get_track_count():
			var path := original.track_get_path(i)
			if path.get_subname_count() == 0: continue
			var index := sk.find_bone(path.get_subname(0))
			if index < 0: continue
			if original.track_get_type(i) == Animation.TYPE_ROTATION_3D: rotation_tracks[index] = i
			if original.track_get_type(i) == Animation.TYPE_POSITION_3D: position_tracks[index] = i
		var convert := rig.global_basis.orthonormalized().inverse() * sk.global_basis.orthonormalized()
		var source_hip := sk.find_bone("mixamorig_Hips")
		var target_hip: int = target_names.Hips
		var ratio := rig.to_global(rig.get_bone_global_rest(target_hip).origin).y / sk.to_global(sk.get_bone_global_rest(source_hip).origin).y
		var output := Animation.new()
		output.length = original.length
		output.loop_mode = Animation.LOOP_LINEAR if id in LOOPS else Animation.LOOP_NONE
		var output_tracks := {}
		for src in mapping:
			var t := output.add_track(Animation.TYPE_ROTATION_3D)
			output.track_set_path(t, NodePath("OfficeWorker/" + str(target.get_path_to(rig)) + ":" + rig.get_bone_name(mapping[src])))
			output_tracks[src] = t
		var hip_track := output.add_track(Animation.TYPE_POSITION_3D)
		output.track_set_path(hip_track, NodePath("OfficeWorker/" + str(target.get_path_to(rig)) + ":" + rig.get_bone_name(target_hip)))
		var samples := ceili(original.length * 30.0)
		var motion := PackedVector3Array()
		var first := Vector3.ZERO
		for frame in samples + 1:
			var time := minf(frame / 30.0, original.length)
			var globals: Array[Transform3D] = []
			for i in sk.get_bone_count():
				var local := sk.get_bone_rest(i)
				if rotation_tracks.has(i): local.basis = Basis(original.rotation_track_interpolate(rotation_tracks[i], time))
				if position_tracks.has(i): local.origin = original.position_track_interpolate(position_tracks[i], time)
				var parent := sk.get_bone_parent(i)
				globals.append(globals[parent] * local if parent >= 0 else local)
			var hip_world := sk.global_transform * globals[source_hip].origin * ratio
			if frame == 0: first = Vector3(hip_world.x, 0, hip_world.z)
			motion.append(Vector3(hip_world.x, 0, hip_world.z) - first)
			var hip_origin := Vector3(first.x, hip_world.y, first.z)
			var target_local := rig.global_transform.affine_inverse() * hip_origin
			var parent := rig.get_bone_parent(target_hip)
			if parent >= 0: target_local = rig.get_bone_global_rest(parent).affine_inverse() * target_local
			output.position_track_insert_key(hip_track, time, target_local)
			var target_globals := {}
			for src in mapping:
				var dst: int = mapping[src]
				var rest := rig.get_bone_global_rest(dst).basis.orthonormalized()
				var source_rest := convert * sk.get_bone_global_rest(src).basis.orthonormalized()
				var alignment := Basis.IDENTITY
				var sc := child_bone(sk, src)
				var tc := child_bone(rig, dst)
				if sc >= 0 and tc >= 0:
					var sd := convert * (sk.get_bone_global_rest(sc).origin - sk.get_bone_global_rest(src).origin).normalized()
					var td := (rig.get_bone_global_rest(tc).origin - rig.get_bone_global_rest(dst).origin).normalized()
					alignment = Basis(Quaternion(td, sd))
				var desired := convert * globals[src].basis.orthonormalized() * source_rest.inverse() * alignment * rest
				target_globals[dst] = desired
			for src in mapping:
				var dst: int = mapping[src]
				var parent_id := rig.get_bone_parent(dst)
				var parent_basis: Basis = target_globals.get(parent_id, rig.get_bone_global_rest(parent_id).basis if parent_id >= 0 else Basis.IDENTITY)
				output.rotation_track_insert_key(output_tracks[src], time, (parent_basis.inverse() * target_globals[dst]).orthonormalized().get_rotation_quaternion())
		output.set_meta("root_motion", motion)
		output.set_meta("sample_rate", 30.0)
		output.set_meta("source", FILES[id])
		library.add_animation(id, output)
		report[id] = {"seconds":output.length, "mapped_bones":mapping.size(), "travel":str(motion[-1]), "loop":id in LOOPS}
		source.free()
	DirAccess.make_dir_recursive_absolute("res://assets/animations/generated")
	ResourceSaver.save(library, "res://assets/animations/generated/player_library.res")
	var f := FileAccess.open("res://assets/animations/generated/inspection.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	target.free()
	print("Player animation library baked; originals preserved.")
	quit()
