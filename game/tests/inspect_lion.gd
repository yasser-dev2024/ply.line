extends SceneTree


func _init() -> void:
	var packed := load("res://assets/models/lion_poly_by_google.glb") as PackedScene
	if not packed:
		quit(1)
		return
	var instance := packed.instantiate()
	_print_tree(instance, "")
	instance.free()
	quit()


func _print_tree(node: Node, indent: String) -> void:
	var detail := ""
	if node is MeshInstance3D and node.mesh:
		detail = " AABB=%s SURFACES=%d TRANSFORM=%s" % [node.mesh.get_aabb(), node.mesh.get_surface_count(), node.transform]
	print(indent, node.name, " [", node.get_class(), "]", detail)
	for child in node.get_children():
		_print_tree(child, indent + "  ")
