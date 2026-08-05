extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player_scene := load("res://scenes/characters/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	await process_frame
	var skeleton := player.get("_character_skeleton") as Skeleton3D
	var tree := player.get("_animation_tree") as AnimationTree
	var animation_player := player.get("_animation_player") as AnimationPlayer
	if skeleton == null or tree == null or animation_player == null:
		printerr("HUMAN_RIG_COMPONENT_MISSING")
		quit(1)
		return
	var before := skeleton.get_bone_pose_rotation(3)
	print("SKELETON_PATH=", player.get_node("Visual/HumanModel").get_path_to(skeleton))
	print("ANIMATION_ROOT=", animation_player.root_node)
	var idle := animation_player.get_animation("Idle")
	print("PLAYER_IDLE_TRACK=", idle.track_get_path(0) if idle else "missing")
	if idle:
		for track_index in range(idle.get_track_count()):
			if String(idle.track_get_path(track_index)).contains("RightUpperArm"):
				print("ARM_TRACK=", idle.track_get_path(track_index), " TYPE=", idle.track_get_type(track_index), " KEYS=", idle.track_get_key_count(track_index), " VALUE=", idle.track_get_key_value(track_index, 0))
	for frame in range(12):
		await process_frame
	var after_tree := skeleton.get_bone_pose_rotation(3)
	print("TREE_DELTA=", before.angle_to(after_tree))
	tree.active = false
	animation_player.play("Idle")
	for frame in range(12):
		await process_frame
	var after_direct := skeleton.get_bone_pose_rotation(3)
	var maximum_delta := 0.0
	for bone_index in range(skeleton.get_bone_count()):
		maximum_delta = maxf(maximum_delta, skeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion().angle_to(skeleton.get_bone_pose_rotation(bone_index)))
	print("DIRECT_DELTA=", after_tree.angle_to(after_direct), " MAX_REST_DELTA=", maximum_delta, " PLAYING=", animation_player.current_animation, " POSITION=", animation_player.current_animation_position, " ACTIVE=", animation_player.is_playing())
	var arm_index := skeleton.find_bone("RightUpperArm")
	print("BONE_NAMES=", Array(range(skeleton.get_bone_count())).map(func(index): return skeleton.get_bone_name(index)))
	print("ARM_REST=", skeleton.get_bone_rest(arm_index).basis.get_rotation_quaternion(), " ARM_POSE=", skeleton.get_bone_pose_rotation(arm_index))
	print("ROOT_NODE_CLASS=", animation_player.get_node(animation_player.root_node).get_class())
	quit(0 if maximum_delta > 0.001 else 1)
