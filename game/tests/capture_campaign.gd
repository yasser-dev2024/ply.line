extends SceneTree


func _initialize() -> void:
	call_deferred("_capture_campaign")


func _capture_campaign() -> void:
	for stage in range(2, 6):
		var packed := load("res://scenes/levels/forest_stage_%d.tscn" % stage) as PackedScene
		if not packed:
			quit(1)
			return
		var level := packed.instantiate()
		root.add_child(level)
		for frame in range(70):
			await process_frame
		var hud := level.get_node_or_null("HUD")
		if hud and hud.get("_toast_label"):
			hud.get("_toast_label").visible = false
		var image := root.get_texture().get_image()
		var output_path := ProjectSettings.globalize_path("res://tests/campaign_stage_%d.png" % stage)
		var result := image.save_png(output_path)
		print("CAPTURE_STAGE=", stage, " PATH=", output_path, " RESULT=", result)
		level.queue_free()
		await process_frame
	quit()
