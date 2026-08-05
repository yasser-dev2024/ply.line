extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failed = true
		printerr("FAIL: ", message)


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.quality_level = 0
	var packed := load("res://scenes/levels/forest_stage_1.tscn") as PackedScene
	var level := packed.instantiate()
	root.add_child(level)
	await process_frame
	var world := level.get_node("RealForestWorld")
	_check(world.get_node_or_null("NaturalTreeTrunks") != null, "أشجار الهاتف المجمعة موجودة")
	_check(world.get_node_or_null("NaturalTreeBranches") != null, "أغصان الهاتف المجمعة موجودة")
	_check(world.get_node_or_null("PhotographicLeafCanopies") != null, "أوراق الهاتف الخفيفة موجودة")
	_check(world.get_node_or_null("ForestFernMobile") != null, "نباتات الهاتف الخفيفة موجودة")
	_check(world.get_node_or_null("HeroFir_1") == null, "إيقاف الأشجار التصويرية الثقيلة على الهاتف")
	_check(world.get_node_or_null("BoundaryWest") != null, "حدود المرحلة الخفيفة موجودة")
	print("MOBILE PERFORMANCE TEST ", "FAILED" if _failed else "PASSED")
	quit(1 if _failed else 0)
