extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var expected_items := [3, 4, 3, 4, 5]
	var landmarks := ["CabinFloor", "LookoutDeck", "CaveDarkness", "FortressFloor", "RescueOutpostPlatform"]
	for stage in range(1, 6):
		var scene := load("res://scenes/levels/forest_stage_%d.tscn" % stage) as PackedScene
		if scene == null:
			printerr("FAIL: stage ", stage, " did not load")
			_failed = true
			continue
		var level := scene.instantiate()
		root.add_child(level)
		await process_frame
		var lions := get_nodes_in_group("lion_enemy").size()
		var expected := stage + 1
		if lions != expected:
			printerr("FAIL: stage ", stage, " lions=", lions, " expected=", expected)
			_failed = true
		else:
			print("PASS: stage ", stage, " lions=", lions)
		var item_count := get_nodes_in_group("collectible").size()
		if item_count != expected_items[stage - 1]:
			printerr("FAIL: stage ", stage, " mission items=", item_count)
			_failed = true
		else:
			print("PASS: stage ", stage, " mission items=", item_count)
		if level.get_node_or_null("RealForestWorld/" + landmarks[stage - 1]) == null:
			printerr("FAIL: stage ", stage, " missing landmark ", landmarks[stage - 1])
			_failed = true
		else:
			print("PASS: stage ", stage, " landmark=", landmarks[stage - 1])
		if stage == 2 and level.get_node_or_null("RealForestWorld/RiverStormRain") == null:
			printerr("FAIL: stage 2 missing rain event")
			_failed = true
		level.queue_free()
		await process_frame
	print("STAGES TEST ", "FAILED" if _failed else "PASSED")
	quit(1 if _failed else 0)
