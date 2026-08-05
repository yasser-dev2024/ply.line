extends SceneTree


func _initialize() -> void:
	var packed := load("res://assets/models/characters/quaternius_soldier_cc0/character_soldier.glb") as PackedScene
	if not packed:
		printerr("SOLDIER LOAD FAILED")
		quit(1)
		return
	var model := packed.instantiate()
	root.add_child(model)
	_walk(model, "")
	quit(0)


func _walk(node: Node, indent: String) -> void:
	var details := ""
	if node is Node3D:
		details = " pos=%s scale=%s" % [node.position, node.scale]
	if node is MeshInstance3D and node.mesh:
		details += " visible=%s aabb=%s" % [node.visible, node.mesh.get_aabb()]
	elif node is Skeleton3D:
		details = " bones=%d names=%s" % [node.get_bone_count(), _bone_names(node)]
	elif node is AnimationPlayer:
		details = " animations=%s" % [node.get_animation_list()]
	print(indent, node.name, " [", node.get_class(), "]", details)
	for child in node.get_children():
		_walk(child, indent + "  ")


func _bone_names(skeleton: Skeleton3D) -> Array[StringName]:
	var names: Array[StringName] = []
	for index in range(skeleton.get_bone_count()):
		names.append(skeleton.get_bone_name(index))
	return names
