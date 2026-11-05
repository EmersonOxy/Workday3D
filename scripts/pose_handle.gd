@tool
extends Marker3D
## Drag/rotate this marker with the standard Godot transform gizmo.
@export var osso: StringName
@export var permitir_translacao := false
@export_storage var ajuste := Transform3D.IDENTITY
var displayed := Transform3D.IDENTITY
var initialized := false
func capture_edit() -> bool:
	if not initialized or transform.is_equal_approx(displayed): return false
	var delta := displayed.affine_inverse() * transform
	if not permitir_translacao: delta.origin = Vector3.ZERO
	ajuste = ajuste * delta
	displayed = transform
	return true
func display_at(world_pose: Transform3D) -> void:
	global_transform = world_pose
	displayed = transform
	initialized = true
func bone_index(rig: Skeleton3D) -> int:
	var exact := rig.find_bone(osso)
	if exact >= 0: return exact
	for index in rig.get_bone_count():
		if rig.get_bone_name(index).begins_with(str(osso) + "_"): return index
	return -1
func apply_to(rig: Skeleton3D, weight: float = 1.0) -> void:
	if weight <= 0.0: return
	if ajuste.is_equal_approx(Transform3D.IDENTITY): return
	var index := bone_index(rig)
	if index < 0: return
	var pose := Transform3D(Basis(rig.get_bone_pose_rotation(index)), rig.get_bone_pose_position(index))
	pose = pose * Transform3D.IDENTITY.interpolate_with(ajuste, clampf(weight, 0.0, 1.0))
	rig.set_bone_pose_position(index, pose.origin)
	rig.set_bone_pose_rotation(index, pose.basis.orthonormalized().get_rotation_quaternion())
