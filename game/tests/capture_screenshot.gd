extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene := load("res://scenes/levels/forest_stage_1.tscn") as PackedScene
	if scene == null:
		printerr("Unable to load forest scene")
		quit(1)
		return
	var level := scene.instantiate()
	root.add_child(level)
	for frame in range(95):
		await process_frame
	var hud := level.get_node_or_null("HUD")
	if hud and hud.get("_toast_label"):
		hud.get("_toast_label").visible = false
	var image := root.get_texture().get_image()
	var output_path := ProjectSettings.globalize_path("res://tests/gameplay_capture.png")
	var result := image.save_png(output_path)
	print("CAPTURE: ", output_path, " result=", result)
	quit(0 if result == OK else 1)
