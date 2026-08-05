extends SceneTree


func _initialize() -> void:
	var packed := load("res://assets/models/trees/polyhaven_pine_sapling_cc0/pine_sapling_mobile.glb") as PackedScene
	if not packed:
		printerr("TREE LOAD FAILED")
		quit(1)
		return
	var root_node := packed.instantiate()
	root.add_child(root_node)
	_print_nodes(root_node, "")
	quit(0)


func _print_nodes(node: Node, indent: String) -> void:
	var details := ""
	if node is MeshInstance3D and node.mesh:
		details = " surfaces=%d aabb=%s" % [node.mesh.get_surface_count(), node.mesh.get_aabb()]
		for surface in range(node.mesh.get_surface_count()):
			var material: Material = node.mesh.surface_get_material(surface)
			if material:
				details += " material%d=%s/%s" % [surface, material.resource_name, material.get_class()]
	print(indent, node.name, " [", node.get_class(), "]", details)
	for child in node.get_children():
		_print_nodes(child, indent + "  ")
