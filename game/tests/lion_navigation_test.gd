extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		printerr("FAIL: ", message)
		_failed = true


func _run() -> void:
	var scene := load("res://scenes/levels/forest_stage_1.tscn") as PackedScene
	var level := scene.instantiate()
	root.add_child(level)
	await process_frame
	var region := level.get_node("RealForestWorld/ForestNavigationRegion") as NavigationRegion3D
	for frame in range(360):
		if region.has_meta(&"navigation_ready"):
			break
		await process_frame
	_check(region.has_meta(&"navigation_ready"), "اكتمال بناء شبكة التنقل الطبيعية")
	_check(region.navigation_mesh.get_polygon_count() > 0, "احتواء شبكة التنقل على مسارات فعلية")

	var lions := get_nodes_in_group("lion_enemy")
	_check(lions.size() == 2, "وجود أسدين للاختبار الجماعي")
	if lions.size() > 0:
		var lion: CharacterBody3D = lions[0]
		_check(lion.has_node("NavigationAgent3D"), "وجود وكيل تنقل داخل الأسد")
		var player: CharacterBody3D = level.get_node("Player")
		player.global_position = lion.global_position + Vector3(0.0, 0.0, 7.0)
		var seen_states: Dictionary = {}
		for frame in range(190):
			seen_states[lion.get_state_name()] = true
			await physics_frame
		_check(seen_states.has(&"alert"), "دخول الأسد في حالة الترقب")
		_check(seen_states.has(&"stalk") or seen_states.has(&"chase"), "انتقال الأسد من الترقب إلى المطاردة")

	print("LION NAVIGATION TEST ", "FAILED" if _failed else "PASSED")
	quit(1 if _failed else 0)
