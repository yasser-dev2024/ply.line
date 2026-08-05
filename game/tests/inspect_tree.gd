extends SceneTree


func _initialize() -> void:
	var scene := load("res://assets/models/trees/real_conifer_cc0/tree.glb") as PackedScene
	if not scene:
		printerr("TREE_LOAD_FAILED")
		quit(1)
		return
	var tree := scene.instantiate()
	root.add_child(tree)
	_print_tree(tree, "")
	quit(0)


func _print_tree(node: Node, indent: String) -> void:
	var extra := ""
	if node is MeshInstance3D:
		extra = " aabb=" + str(node.get_aabb()) + " surfaces=" + str(node.mesh.get_surface_count())
	print(indent, node.name, " [", node.get_class(), "]", extra)
	for child in node.get_children():
		_print_tree(child, indent + "  ")
