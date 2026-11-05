@tool
extends Node3D
## Additive pose edits, applied after animation and before hand IK.
@export_enum("Sentado", "Digitando", "Em pe", "Levantando", "Sentando") var previa := 0
@export_range(0.0, 30.0, 0.01) var instante_animacao := 0.0
@export var usar_zona_digitacao := true
@export_range(-10.0, 35.0, 0.5) var inclinacao_digitacao_graus := 10.0
@export_category("Corpo - deslocamentos locais")
@export var quadril_posicao := Vector3.ZERO
@export var quadril_rotacao := Vector3.ZERO
@export var coluna_rotacao := Vector3.ZERO
@export var peito_rotacao := Vector3.ZERO
@export var coxa_esquerda_rotacao := Vector3.ZERO
@export var coxa_direita_rotacao := Vector3.ZERO
@export var joelho_esquerdo_rotacao := Vector3.ZERO
@export var joelho_direito_rotacao := Vector3.ZERO
@export_category("Ossos adicionais - graus")
## Bone names from Skeleton3D; values are additive local Euler angles.
@export var rotacoes_ossos: Dictionary[StringName, Vector3] = {}
@export_category("Dedos - mao esquerda")
## X, Y e Z controlam a dobra das tres falanges, em graus.
@export var polegar_esquerdo := Vector3.ZERO
## X, Y e Z controlam a dobra das tres falanges, em graus.
@export var indicador_esquerdo := Vector3.ZERO
## X, Y e Z controlam a dobra das tres falanges, em graus.
@export var medio_esquerdo := Vector3.ZERO
## X, Y e Z controlam a dobra das tres falanges, em graus.
@export var anelar_esquerdo := Vector3.ZERO
## X, Y e Z controlam a dobra das tres falanges, em graus.
@export var mindinho_esquerdo := Vector3.ZERO
@export_category("Dedos - mao direita")
## X, Y e Z controlam a dobra das tres falanges, em graus.
@export var polegar_direito := Vector3.ZERO
## X, Y e Z controlam a dobra das tres falanges, em graus.
@export var indicador_direito := Vector3.ZERO
## X, Y e Z controlam a dobra das tres falanges, em graus.
@export var medio_direito := Vector3.ZERO
## X, Y e Z controlam a dobra das tres falanges, em graus.
@export var anelar_direito := Vector3.ZERO
## X, Y e Z controlam a dobra das tres falanges, em graus.
@export var mindinho_direito := Vector3.ZERO
var last_signature := ""
func _process(_delta: float) -> void:
	if not Engine.is_editor_hint(): return
	var handles_changed := false
	for handle in handles():
		if handle.capture_edit(): handles_changed = true
	var signature := ""
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_EDITOR: signature += str(get(property.name))
	if signature != last_signature or handles_changed:
		last_signature = signature
		if get_parent().is_node_ready(): get_parent()._apply_seated_pose()
func rotate_bone(rig: Skeleton3D, name: String, degrees: Vector3) -> void:
	if degrees.is_zero_approx(): return
	var index := rig.find_bone(name)
	if index >= 0:
		rig.set_bone_pose_rotation(index, rig.get_bone_pose_rotation(index) * Quaternion.from_euler(degrees * PI / 180.0))
func apply_body(rig: Skeleton3D) -> void:
	var hips := rig.find_bone("Hips_01")
	if hips >= 0:
		rig.set_bone_pose_position(hips, rig.get_bone_pose_position(hips) + rig.global_basis.inverse() * get_parent().get_node("Character").global_basis.orthonormalized() * quadril_posicao)
	var edits := {"Hips_01":quadril_rotacao,"Spine_02":coluna_rotacao,"Spine2_04":peito_rotacao,"LeftUpLeg_057":coxa_esquerda_rotacao,"RightUpLeg_062":coxa_direita_rotacao,"LeftLeg_058":joelho_esquerdo_rotacao,"RightLeg_063":joelho_direito_rotacao}
	for bone in edits: rotate_bone(rig,bone,edits[bone])
func is_finger(bone: String) -> bool:
	return "Hand" in bone and ("Thumb" in bone or "Index" in bone or "Middle" in bone or "Ring" in bone or "Pinky" in bone)
func is_arm_pose(bone: String) -> bool:
	return "Hand" in bone or "Shoulder" in bone or "ForeArm" in bone or bone.begins_with("LeftArm") or bone.begins_with("RightArm")
func neutral_standing_fingers(rig: Skeleton3D, weight: float) -> void:
	if weight <= 0: return
	# Explicitly release source keyframes and seated hand edits. Locomotion
	# captures can contain static fingers, so relying on those keys is insufficient.
	for index in rig.get_bone_count():
		var name := rig.get_bone_name(index)
		if not is_finger(name): continue
		var bend := 0.0
		if "1_" in name: bend = 6.0
		elif "2_" in name: bend = 10.0
		elif "3_" in name: bend = 6.0
		if "Thumb" in name: bend *= 0.4
		var relaxed := rig.get_bone_rest(index).basis.orthonormalized().get_rotation_quaternion() * Quaternion(Vector3.RIGHT, deg_to_rad(bend))
		rig.set_bone_pose_rotation(index, rig.get_bone_pose_rotation(index).slerp(relaxed, clampf(weight, 0, 1)))
func apply_fingers(rig: Skeleton3D, seated_weight: float = 1.0) -> void:
	for bone in rotacoes_ossos:
		var weight := seated_weight if is_arm_pose(str(bone)) else 1.0
		rotate_bone(rig,str(bone),rotacoes_ossos[bone] * weight)
	var names := {"polegar":"Thumb","indicador":"Index","medio":"Middle","anelar":"Ring","mindinho":"Pinky"}
	for side in ["Left", "Right"]:
		for finger in names:
			var value: Vector3 = get(finger + ("_esquerdo" if side == "Left" else "_direito")) * seated_weight
			if value.is_zero_approx(): continue
			for joint in 3:
				var prefix: String = side + "Hand" + str(names[finger]) + str(joint+1) + "_"
				for index in rig.get_bone_count():
					if rig.get_bone_name(index).begins_with(prefix):
						rotate_bone(rig, rig.get_bone_name(index), Vector3(value[joint],0,0))

func handles() -> Array[Node]:
	var result: Array[Node] = []
	for child in find_children("*", "Marker3D", true, false):
		if child.has_method("capture_edit"): result.append(child)
	return result
func apply_handles(rig: Skeleton3D, seated_weight: float = 1.0) -> void:
	for handle in handles():
		handle.apply_to(rig, seated_weight if is_arm_pose(str(handle.osso)) else 1.0)
func sync_handles(rig: Skeleton3D) -> void:
	if not Engine.is_editor_hint(): return
	rig.force_update_all_bone_transforms()
	for handle in handles():
		var index: int = handle.bone_index(rig)
		if index >= 0: handle.display_at(rig.global_transform * rig.get_bone_global_pose(index))
