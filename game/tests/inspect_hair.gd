extends SceneTree


func _init() -> void:
	var packed := load("res://assets/models/characters/quaternius_hair_cc0/origin/Hair_SimpleParted.gltf") as PackedScene
	if not packed:
		push_error("Unable to load hair asset")
		quit(1)
		return
	var instance := packed.instantiate()
	_print_tree(instance, "")
	instance.free()
	quit()


func _print_tree(node: Node, indent: String) -> void:
	var detail := ""
	if node is MeshInstance3D and node.mesh:
		detail = " AABB=%s SURFACES=%d" % [node.mesh.get_aabb(), node.mesh.get_surface_count()]
	if node is Skeleton3D:
		detail += " BONES=%d" % node.get_bone_count()
	print(indent, node.name, " [", node.get_class(), "]", detail)
	for child in node.get_children():
		_print_tree(child, indent + "  ")
