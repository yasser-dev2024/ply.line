extends Control


func _ready() -> void:
	_build_interface()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("0c1e18")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 48)
	safe.add_theme_constant_override("margin_right", 48)
	safe.add_theme_constant_override("margin_top", 34)
	safe.add_theme_constant_override("margin_bottom", 34)
	add_child(safe)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	safe.add_child(content)

	var title := Label.new()
	title.text = "اختر المرحلة"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("ffe3a1"))
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "حملة مترابطة: لا تُفتح المرحلة التالية إلا بعد إكمال كل أهداف المرحلة الحالية."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 19)
	subtitle.add_theme_color_override("font_color", Color("c9d9cf"))
	content.add_child(subtitle)

	var cards := GridContainer.new()
	cards.columns = 5
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("h_separation", 12)
	cards.add_theme_constant_override("v_separation", 12)
	content.add_child(cards)

	var data := [
		["المرحلة 1", "إشارة الحارس", "خريطة مفقودة • أسدان • إرسال إنقاذ"],
		["المرحلة 2", "كمين النهر", "معدات الجسر • عبور إلزامي • منارة"],
		["المرحلة 3", "عرين الملك", "مصابيح الكهف • دخول العرين • زعيم"],
		["المرحلة 4", "القلعة المهدمة", "أربعة مفاتيح • خمسة حراس • بوابة"],
		["المرحلة 5", "نداء الإنقاذ", "حصن الوادي • إنقاذ مستكشف • زعيم أخير"],
	]
	for index in range(data.size()):
		cards.add_child(_stage_card(index + 1, data[index]))

	var back := Button.new()
	back.text = "العودة للقائمة"
	back.custom_minimum_size = Vector2(260, 54)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_size_override("font_size", 19)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn"))
	content.add_child(back)


func _stage_card(number: int, data: Array) -> PanelContainer:
	var unlocked := number <= GameState.unlocked_level
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(210, 330)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17372d") if unlocked else Color("1d2824")
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("bd8131") if unlocked else Color("3c4a44")
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	card.add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var number_label := Label.new()
	number_label.text = data[0]
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.add_theme_font_size_override("font_size", 22)
	number_label.add_theme_color_override("font_color", Color("e5ad4e"))
	column.add_child(number_label)

	var name_label := Label.new()
	name_label.text = data[1]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 23)
	name_label.add_theme_color_override("font_color", Color("fff2d2"))
	column.add_child(name_label)

	var description := Label.new()
	description.text = data[2]
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.add_theme_font_size_override("font_size", 15)
	description.add_theme_color_override("font_color", Color("c8d5cd"))
	column.add_child(description)

	var play := Button.new()
	play.text = "ابدأ" if unlocked else "مقفلة"
	play.disabled = not unlocked
	play.custom_minimum_size = Vector2(170, 54)
	play.add_theme_font_size_override("font_size", 20)
	play.pressed.connect(_play_stage.bind(number))
	column.add_child(play)
	return card


func _play_stage(number: int) -> void:
	GameState.selected_level = number
	get_tree().change_scene_to_file(GameState.get_level_scene())
