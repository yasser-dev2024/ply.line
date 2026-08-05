extends Control

func _ready() -> void:
	_build_interface()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("10241d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var accent := ColorRect.new()
	accent.color = Color("b87436")
	accent.anchor_left = 0.66
	accent.anchor_right = 1.0
	accent.anchor_bottom = 1.0
	background.add_child(accent)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 52)
	safe.add_theme_constant_override("margin_right", 52)
	safe.add_theme_constant_override("margin_top", 36)
	safe.add_theme_constant_override("margin_bottom", 36)
	add_child(safe)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 42)
	safe.add_child(columns)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_child(info)

	var eyebrow := Label.new()
	eyebrow.text = "مغامرة ثلاثية الأبعاد مستقلة"
	eyebrow.add_theme_color_override("font_color", Color("e9b95d"))
	eyebrow.add_theme_font_size_override("font_size", 22)
	info.add_child(eyebrow)

	var title := Label.new()
	title.text = "القتال مع الأسود 3D"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("fff3d7"))
	info.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "خمس مراحل مترابطة: استكشف، اجمع الأدوات، واجه الأسود وأنقذ المستكشف."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color("cbd8d0"))
	info.add_child(subtitle)

	info.add_child(_spacer(22))
	var start_button := _menu_button("ابدأ المرحلة الأولى", Color("d99d3a"))
	start_button.pressed.connect(_start_game)
	info.add_child(start_button)

	var continue_button := _menu_button("متابعة", Color("315e53"))
	continue_button.disabled = GameState.unlocked_level <= 1 and GameState.best_time_seconds <= 0.0
	continue_button.pressed.connect(_continue_game)
	info.add_child(continue_button)

	var stages_button := _menu_button("اختيار المراحل", Color("355c48"))
	stages_button.pressed.connect(_open_level_select)
	info.add_child(stages_button)

	var instructions := _menu_button("التعليمات", Color("29463f"))
	instructions.pressed.connect(_show_instructions)
	info.add_child(instructions)

	if GameState.best_time_seconds > 0.0:
		var best := Label.new()
		best.text = "أفضل وقت: %.1f ثانية" % GameState.best_time_seconds
		best.add_theme_font_size_override("font_size", 18)
		best.add_theme_color_override("font_color", Color("e9b95d"))
		info.add_child(best)

	var visual := TextureRect.new()
	visual.texture = load("res://assets/icons/logo.png")
	visual.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	visual.custom_minimum_size = Vector2(380, 380)
	visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(visual)


func _menu_button(label_text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(390, 58)
	button.add_theme_font_size_override("font_size", 20)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_left = 14
	normal.corner_radius_bottom_right = 14
	button.add_theme_stylebox_override("normal", normal)
	return button


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer


func _start_game() -> void:
	GameState.selected_level = 1
	get_tree().change_scene_to_file(GameState.get_level_scene())


func _continue_game() -> void:
	GameState.selected_level = clampi(GameState.unlocked_level, 1, 5)
	get_tree().change_scene_to_file(GameState.get_level_scene())


func _open_level_select() -> void:
	get_tree().change_scene_to_file("res://scenes/main/level_select.tscn")


func _show_instructions() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "طريقة اللعب"
	dialog.dialog_text = "حرّك العصا اليسرى للمشي والجري، واسحب يمين الشاشة لتدوير الكاميرا. اضغط «منظار» لتكبير المشهد، وجّه العلامة نحو الأسد حتى تصبح خضراء، ثم اضغط «إطلاق». أكمل هدف كل مرحلة لفتح التالية."
	dialog.min_size = Vector2i(620, 260)
	add_child(dialog)
	dialog.popup_centered()
