extends RefCounted
## Preserve the entire torso, hips and legs. Remove only head-dominant faces.
## Original geometry stays available for shadows.
static func configure(root: Node3D, rig: Skeleton3D, camera: Camera3D) -> void:
	camera.cull_mask &= ~2
	for candidate in root.find_children("*", "MeshInstance3D", true, false):
		var original := candidate as MeshInstance3D
		if original.mesh == null: continue
		var mesh := ArrayMesh.new()
		for surface in original.mesh.get_surface_count():
			var arrays: Array = original.mesh.surface_get_arrays(surface)
			var bones := PackedInt32Array()
			var weights := PackedFloat32Array()
			if arrays[Mesh.ARRAY_BONES] != null: bones = arrays[Mesh.ARRAY_BONES]
			if arrays[Mesh.ARRAY_WEIGHTS] != null: weights = arrays[Mesh.ARRAY_WEIGHTS]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for i in vertices.size(): indices.append(i)
			var rejected := PackedByteArray()
			rejected.resize(vertices.size())
			if not bones.is_empty():
				var influences := bones.size() / vertices.size()
				for vertex in vertices.size():
					var upper_weight := 0.0
					for influence in int(influences):
						var slot := vertex * int(influences) + influence
						var bind := bones[slot]
						if weights[slot] <= 0.001: continue
						var bone := bind
						var name := ""
						if original.skin != null:
							if bind >= original.skin.get_bind_count(): continue
							bone = original.skin.get_bind_bone(bind)
							name = str(original.skin.get_bind_name(bind))
						if name.is_empty() and bone >= 0 and bone < rig.get_bone_count(): name = rig.get_bone_name(bone)
						if name.begins_with("Head") or name.begins_with("Neck") or "Eye" in name:
							upper_weight += weights[slot]
					if upper_weight > 0.85: rejected[vertex] = 1
			var visible_indices := PackedInt32Array()
			for triangle in indices.size() / 3:
				var a := indices[triangle * 3]
				var b := indices[triangle * 3 + 1]
				var c := indices[triangle * 3 + 2]
				if rejected[a] or rejected[b] or rejected[c]: continue
				visible_indices.append_array(PackedInt32Array([a, b, c]))
			if visible_indices.is_empty(): continue
			arrays[Mesh.ARRAY_INDEX] = visible_indices
			var flags: int = original.mesh.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
			var material: Material = original.get_active_material(surface)
			if material != null:
				material = material.duplicate()
				if material is BaseMaterial3D: material.cull_mode = BaseMaterial3D.CULL_BACK
			mesh.surface_set_material(mesh.get_surface_count() - 1, material)
		original.layers = 2
		if mesh.get_surface_count() == 0: continue
		var view := MeshInstance3D.new()
		view.name = str(original.name) + "FirstPerson"
		view.mesh = mesh
		view.skin = original.skin
		view.skeleton = original.skeleton
		view.transform = original.transform
		view.layers = 1
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		original.get_parent().add_child(view)
