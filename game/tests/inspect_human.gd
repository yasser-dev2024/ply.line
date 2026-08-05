extends SceneTree


func _initialize() -> void:
	for method in ClassDB.class_get_method_list("AnimationNodeBlendSpace1D"):
		if method.name == "add_blend_point":
			print("BLEND_SIGNATURE=", method)
	var scene := load("res://addons/quaternius_ik_rigged/Godot - UE/Superhero_Male_FullBody.gltf") as PackedScene
	if scene == null:
		printerr("HUMAN_LOAD_FAILED")
		quit(1)
		return
	var human := scene.instantiate()
	root.add_child(human)
	print("HUMAN_ROOT=", human.name)
	var skeleton := human.get_node_or_null("Armature/GeneralSkeleton") as Skeleton3D
	if skeleton == null:
		skeleton = _find_skeleton(human)
	print("HUMAN_BONES=", skeleton.get_bone_count() if skeleton else 0)
	var idle := load("res://addons/quaternius_ik_rigged/Animations/Idle.res") as Animation
	print("IDLE_TRACKS=", idle.get_track_count() if idle else 0)
	if idle and idle.get_track_count() > 0:
		print("IDLE_FIRST_TRACK=", idle.track_get_path(0))
	quit(0)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null
