extends CanvasLayer

signal pause_requested
signal resume_requested
signal retry_requested
signal menu_requested
signal next_stage_requested

const VirtualJoystickScript := preload("res://scripts/ui/virtual_joystick.gd")
const CameraLookScript := preload("res://scripts/ui/camera_look_area.gd")

var _pieces_label: Label
var _health_label: Label
var _lions_label: Label
var _timer_label: Label
var _objective_label: Label
var _toast_label: Label
var _pause_overlay: Control
var _success_overlay: Control
var _success_title: Label
var _success_details: Label
var _gameplay_controls: Control
var _toast_tween: Tween
var _crosshair: Label
var _ammo_label: Label
var _health_bar: ProgressBar
var _next_stage_button: Button
var _scope_overlay: ColorRect
var _scope_hint: Label
var _scope_locked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()


func connect_player(player: Node) -> void:
	var look_area := _gameplay_controls.get_node("CameraLook")
	look_area.look_dragged.connect(player.rotate_camera)
	if player.has_signal("ammo_changed"):
		player.ammo_changed.connect(set_ammo)
		var ammo_state: Vector3i = player.get_ammo_state()
		set_ammo(ammo_state.x, ammo_state.y, ammo_state.z)
	if player.has_signal("aim_state_changed"):
		player.aim_state_changed.connect(set_scope_state)


func set_pieces(current: int, total: int) -> void:
	# Godot's RTL shaping reverses slash-separated numerals visually.
	_pieces_label.text = "قطع البوصلة  %d / %d" % [total, current]


func set_mission_items(item_name: String, current: int, total: int) -> void:
	_pieces_label.text = "%s  %d / %d" % [item_name, total, current]


func set_time(seconds: float) -> void:
	var minutes := int(seconds) / 60
	var remaining := fmod(seconds, 60.0)
	_timer_label.text = "%02d:%04.1f" % [minutes, remaining]


func set_health(current: int, maximum: int) -> void:
	_health_label.text = "الصحة  %d / %d" % [maximum, current]
	_health_label.add_theme_color_override("font_color", Color("ffb88e") if current <= maximum * 0.35 else Color("d7f4d3"))
	if _health_bar:
		_health_bar.max_value = maximum
		_health_bar.value = current


func set_lions(remaining: int) -> void:
	_lions_label.text = "الأسود: %d" % remaining


func set_ammo(current: int, reserve: int, _magazine: int) -> void:
	_ammo_label.text = "الذخيرة  %02d  |  %02d" % [current, reserve]
	_ammo_label.add_theme_color_override("font_color", Color("ff8b72") if current <= 4 else Color("ffe4a8"))


func flash_crosshair(hit_enemy: bool) -> void:
	_crosshair.add_theme_color_override("font_color", Color("ff5a43") if hit_enemy else Color("ffffff"))
	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.tween_callback(func(): _crosshair.add_theme_color_override("font_color", Color("7dff8a") if _scope_locked else Color("ffffff")))


func set_scope_state(active: bool, target_locked: bool) -> void:
	_scope_locked = target_locked
	if _scope_overlay:
		_scope_overlay.visible = active
	if _scope_hint:
		_scope_hint.text = "الهدف مثبت — أطلق، وسيبقى المنظار فعالًا" if target_locked else "اسحب للتوجيه • اضغط «منظار» مرة أخرى للعودة"
		_scope_hint.add_theme_color_override("font_color", Color("8cff98") if target_locked else Color("f5e7c7"))
	if _crosshair:
		_crosshair.text = "●" if active else "⊕"
		_crosshair.add_theme_color_override("font_color", Color("7dff8a") if target_locked else Color("ffffff"))


func set_objective(text: String) -> void:
	_objective_label.text = text


func show_toast(text: String, duration := 2.4) -> void:
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	_toast_label.visible = true
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(func(): _toast_label.visible = false)


func show_pause(show: bool) -> void:
	_pause_overlay.visible = show
	_gameplay_controls.visible = not show and not _success_overlay.visible


func show_success(elapsed: float, best: float, stage_number: int, reward_coins: int) -> void:
	_success_title.text = "اكتملت المرحلة %d!" % stage_number
	_success_details.text = "أنجزت جميع الأهداف وفتحت المغامرة التالية.\nالمكافأة: %d قطعة ذهبية\nالوقت: %.1f ثانية\nأفضل وقت: %.1f ثانية" % [reward_coins, elapsed, best]
	_next_stage_button.visible = stage_number < 5
	_success_overlay.visible = true
	_gameplay_controls.visible = false


func show_failure(reason: String) -> void:
	_success_title.text = "انتهت المحاولة"
	_success_details.text = reason + "\nأعد المرحلة وغيّر موقعك أثناء التصويب، ولا تسمح للأسود بمحاصرتك."
	_success_overlay.visible = true
	_gameplay_controls.visible = false


func _build_hud() -> void:
	var root := Control.new()
	root.name = "HUDRoot"
	root.layout_direction = Control.LAYOUT_DIRECTION_RTL
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var player_card := _panel(root, Vector4(0.018, 0.025, 0.27, 0.025), Vector4(0, 0, 0, 92), Color(0.018, 0.035, 0.03, 0.78), 18)
	var player_margin := _margin(player_card, 15, 13)
	var player_box := VBoxContainer.new()
	player_box.add_theme_constant_override("separation", 5)
	player_margin.add_child(player_box)
	_health_label = _label("الصحة  100 / 100", 18, Color("e6f5df"))
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_box.add_child(_health_label)
	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(0, 13)
	_health_bar.max_value = 100
	_health_bar.value = 100
	_health_bar.show_percentage = false
	_health_bar.add_theme_stylebox_override("background", _panel_style(Color(0.04, 0.06, 0.05, 0.9), 7))
	_health_bar.add_theme_stylebox_override("fill", _panel_style(Color("b93332"), 7))
	player_box.add_child(_health_bar)
	var role := _label("حارس الغابة  •  المستوى 7", 14, Color("b4c5b5"))
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_box.add_child(role)

	var mission_top := _panel(root, Vector4(0.35, 0.025, 0.65, 0.025), Vector4(0, 0, 0, 92), Color(0.018, 0.035, 0.03, 0.76), 18)
	var mission_top_margin := _margin(mission_top, 14, 9)
	var mission_top_box := VBoxContainer.new()
	mission_top_box.add_theme_constant_override("separation", 2)
	mission_top_margin.add_child(mission_top_box)
	_timer_label = _label("00:00.0", 25, Color("ffffff"))
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_top_box.add_child(_timer_label)
	_objective_label = _label("المهمة الحالية", 17, Color("f2e8c9"))
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_top_box.add_child(_objective_label)

	var resources := _panel(root, Vector4(0.73, 0.025, 0.982, 0.025), Vector4(0, 0, 0, 92), Color(0.018, 0.035, 0.03, 0.78), 18)
	var resources_margin := _margin(resources, 14, 11)
	var resource_row := HBoxContainer.new()
	resource_row.alignment = BoxContainer.ALIGNMENT_CENTER
	resource_row.add_theme_constant_override("separation", 15)
	resources_margin.add_child(resource_row)
	_lions_label = _label("الأسود  0", 17, Color("ffb080"))
	resource_row.add_child(_lions_label)
	_ammo_label = _label("18  |  72", 18, Color("ffe2a3"))
	resource_row.add_child(_ammo_label)
	var pause_button := _button("Ⅱ", Vector2(48, 48), Color(0.15, 0.23, 0.2, 0.9), 24)
	pause_button.pressed.connect(func(): pause_requested.emit())
	resource_row.add_child(pause_button)

	var mission_card := _panel(root, Vector4(0.018, 0.18, 0.285, 0.18), Vector4(0, 0, 0, 145), Color(0.012, 0.026, 0.022, 0.72), 16)
	var mission_margin := _margin(mission_card, 16, 13)
	var mission_box := VBoxContainer.new()
	mission_box.add_theme_constant_override("separation", 9)
	mission_margin.add_child(mission_box)
	var mission_title := _label("◆  المهمة الرئيسية", 17, Color("f2ad36"))
	mission_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mission_box.add_child(mission_title)
	_pieces_label = _label("آثار الغابة  0 / 5", 18, Color("f4f1e5"))
	_pieces_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mission_box.add_child(_pieces_label)
	var hint := _label("اعبر النهر • فتّش الكوخ • واجه الأسود", 14, Color("9db2a3"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_box.add_child(hint)

	_toast_label = _label("", 23, Color("fff3d1"))
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.anchor_left = 0.31
	_toast_label.anchor_top = 0.15
	_toast_label.anchor_right = 0.69
	_toast_label.anchor_bottom = 0.15
	_toast_label.offset_bottom = 56
	_toast_label.add_theme_stylebox_override("normal", _panel_style(Color(0.04, 0.1, 0.075, 0.86), 14))
	_toast_label.visible = false
	root.add_child(_toast_label)

	_scope_overlay = ColorRect.new()
	_scope_overlay.name = "WeaponScope"
	_scope_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scope_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scope_shader := Shader.new()
	scope_shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 p = UV - vec2(0.5);
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float distance_from_center = length(p);
	float radius = 0.31;
	float outside = smoothstep(radius, radius + 0.018, distance_from_center);
	float ring = 1.0 - smoothstep(0.0, 0.006, abs(distance_from_center - radius));
	float horizontal = (1.0 - smoothstep(0.0015, 0.0035, abs(p.y))) * step(0.035, abs(p.x)) * (1.0 - step(radius - 0.018, abs(p.x)));
	float vertical = (1.0 - smoothstep(0.0015, 0.0035, abs(p.x))) * step(0.035, abs(p.y)) * (1.0 - step(radius - 0.018, abs(p.y)));
	vec4 darkness = vec4(0.0, 0.0, 0.0, outside * 0.94);
	vec4 rim = vec4(0.78, 0.84, 0.75, ring * 0.9);
	vec4 reticle = vec4(0.04, 0.05, 0.04, max(horizontal, vertical) * 0.82);
	COLOR = mix(mix(darkness, reticle, reticle.a), rim, rim.a);
}
"""
	var scope_material := ShaderMaterial.new()
	scope_material.shader = scope_shader
	_scope_overlay.material = scope_material
	_scope_overlay.visible = false
	root.add_child(_scope_overlay)
	_scope_hint = _label("اسحب لتوجيه المنظار نحو الأسد", 18, Color("f5e7c7"))
	_scope_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scope_hint.anchor_left = 0.34
	_scope_hint.anchor_top = 0.73
	_scope_hint.anchor_right = 0.66
	_scope_hint.anchor_bottom = 0.73
	_scope_hint.offset_bottom = 44
	_scope_hint.add_theme_stylebox_override("normal", _panel_style(Color(0.01, 0.025, 0.02, 0.72), 12))
	_scope_overlay.add_child(_scope_hint)

	_crosshair = _label("⊕", 34, Color("ffffff"))
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crosshair.anchor_left = 0.5
	_crosshair.anchor_top = 0.5
	_crosshair.anchor_right = 0.5
	_crosshair.anchor_bottom = 0.5
	_crosshair.offset_left = -25
	_crosshair.offset_top = -30
	_crosshair.offset_right = 25
	_crosshair.offset_bottom = 30
	_crosshair.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_crosshair.add_theme_constant_override("shadow_offset_x", 2)
	_crosshair.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(_crosshair)

	_gameplay_controls = Control.new()
	_gameplay_controls.name = "GameplayControls"
	_gameplay_controls.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_gameplay_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_gameplay_controls)

	var camera_look := CameraLookScript.new()
	camera_look.name = "CameraLook"
	camera_look.anchor_left = 0.34
	camera_look.anchor_right = 1.0
	camera_look.anchor_bottom = 1.0
	_gameplay_controls.add_child(camera_look)

	var joystick := VirtualJoystickScript.new()
	joystick.name = "VirtualJoystick"
	joystick.anchor_top = 1.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 18
	joystick.offset_top = -260
	joystick.offset_right = 270
	joystick.offset_bottom = -10
	_gameplay_controls.add_child(joystick)

	var jump_button := _action_button("↑\nقفز", "jump", Vector2(-112, -146), Vector2(82, 82), Color(0.72, 0.43, 0.1, 0.62))
	_gameplay_controls.add_child(jump_button)
	var run_button := _action_button("»\nجري", "sprint", Vector2(-208, -105), Vector2(72, 72), Color(0.11, 0.28, 0.23, 0.58))
	_gameplay_controls.add_child(run_button)
	var interact_button := _action_button("✦\nتفاعل", "interact", Vector2(-108, -236), Vector2(72, 72), Color(0.16, 0.25, 0.33, 0.58))
	_gameplay_controls.add_child(interact_button)
	var fire_button := _action_button("●\nإطلاق", "fire", Vector2(-116, -344), Vector2(92, 92), Color(0.64, 0.11, 0.06, 0.68))
	_gameplay_controls.add_child(fire_button)
	var aim_button := _toggle_action_button("◉\nمنظار", "aim", Vector2(-211, -268), Vector2(74, 74), Color(0.11, 0.18, 0.25, 0.72))
	_gameplay_controls.add_child(aim_button)
	var reload_button := _action_button("↻", "reload", Vector2(-281, -182), Vector2(62, 62), Color(0.17, 0.2, 0.17, 0.58))
	_gameplay_controls.add_child(reload_button)

	var inventory := _panel(root, Vector4(0.38, 1.0, 0.62, 1.0), Vector4(0, -68, 0, -12), Color(0.012, 0.026, 0.022, 0.66), 15)
	inventory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inventory_margin := _margin(inventory, 8, 7)
	var inventory_row := HBoxContainer.new()
	inventory_row.alignment = BoxContainer.ALIGNMENT_CENTER
	inventory_row.add_theme_constant_override("separation", 8)
	inventory_margin.add_child(inventory_row)
	for item_text in ["✚  x3", "◉  x18", "◆  x2", "▣  خريطة"]:
		var slot := _label(item_text, 15, Color("e2dac1"))
		slot.custom_minimum_size = Vector2(72, 40)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_theme_stylebox_override("normal", _panel_style(Color(0.08, 0.1, 0.085, 0.72), 10))
		inventory_row.add_child(slot)

	_pause_overlay = _build_overlay(root, "متوقف مؤقتًا", "يمكنك العودة إلى المغامرة في أي وقت.")
	var pause_buttons: VBoxContainer = _pause_overlay.get_node("Panel/Margin/Content/Buttons")
	var resume := _button("استئناف", Vector2(330, 58), Color("d99d3a"))
	resume.pressed.connect(func(): resume_requested.emit())
	pause_buttons.add_child(resume)
	var retry := _button("إعادة المرحلة", Vector2(330, 58), Color("315e53"))
	retry.pressed.connect(func(): retry_requested.emit())
	pause_buttons.add_child(retry)
	var menu := _button("القائمة الرئيسية", Vector2(330, 58), Color("263c36"))
	menu.pressed.connect(func(): menu_requested.emit())
	pause_buttons.add_child(menu)
	_pause_overlay.visible = false

	_success_overlay = _build_overlay(root, "", "")
	_success_title = _success_overlay.get_node("Panel/Margin/Content/Title")
	_success_details = _success_overlay.get_node("Panel/Margin/Content/Details")
	var success_buttons: VBoxContainer = _success_overlay.get_node("Panel/Margin/Content/Buttons")
	_next_stage_button = _button("المرحلة التالية", Vector2(330, 58), Color("d99d3a"))
	_next_stage_button.pressed.connect(func(): next_stage_requested.emit())
	success_buttons.add_child(_next_stage_button)
	var again := _button("العب مرة أخرى", Vector2(330, 58), Color("d99d3a"))
	again.pressed.connect(func(): retry_requested.emit())
	success_buttons.add_child(again)
	var back := _button("العودة للقائمة", Vector2(330, 58), Color("315e53"))
	back.pressed.connect(func(): menu_requested.emit())
	success_buttons.add_child(back)
	_success_overlay.visible = false


func _build_overlay(parent: Control, title_text: String, details_text: String) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.025, 0.02, 0.76)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -245
	panel.offset_top = -205
	panel.offset_right = 245
	panel.offset_bottom = 205
	panel.add_theme_stylebox_override("panel", _panel_style(Color("102a22"), 24))
	overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)

	var title := _label(title_text, 32, Color("ffd47a"))
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var details := _label(details_text, 19, Color("eef4ed"))
	details.name = "Details"
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(details)

	var buttons := VBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	content.add_child(buttons)
	return overlay


func _action_button(text: String, action: StringName, bottom_right: Vector2, dimensions: Vector2, color: Color) -> Button:
	var button := _button(text, dimensions, color, int(minf(dimensions.x, dimensions.y) * 0.5))
	button.anchor_left = 1.0
	button.anchor_top = 1.0
	button.anchor_right = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = bottom_right.x
	button.offset_top = bottom_right.y
	button.offset_right = bottom_right.x + dimensions.x
	button.offset_bottom = bottom_right.y + dimensions.y
	button.button_down.connect(func(): Input.action_press(action))
	button.button_up.connect(func(): Input.action_release(action))
	button.tree_exiting.connect(func(): Input.action_release(action))
	return button


func _toggle_action_button(text: String, action: StringName, bottom_right: Vector2, dimensions: Vector2, color: Color) -> Button:
	var button := _button(text, dimensions, color, int(minf(dimensions.x, dimensions.y) * 0.5))
	button.anchor_left = 1.0
	button.anchor_top = 1.0
	button.anchor_right = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = bottom_right.x
	button.offset_top = bottom_right.y
	button.offset_right = bottom_right.x + dimensions.x
	button.offset_bottom = bottom_right.y + dimensions.y
	button.toggle_mode = true
	button.toggled.connect(func(active: bool):
		if active:
			Input.action_press(action)
		else:
			Input.action_release(action)
	)
	button.tree_exiting.connect(func(): Input.action_release(action))
	return button


func _button(text: String, dimensions: Vector2, color: Color, radius := 16) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = dimensions
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _panel_style(color, radius))
	button.add_theme_stylebox_override("hover", _panel_style(color.lightened(0.08), radius))
	button.add_theme_stylebox_override("pressed", _panel_style(color.darkened(0.12), radius))
	return button


func _panel(parent: Control, anchors: Vector4, offsets: Vector4, color: Color, radius: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = anchors.x
	panel.anchor_top = anchors.y
	panel.anchor_right = anchors.z
	panel.anchor_bottom = anchors.w
	panel.offset_left = offsets.x
	panel.offset_top = offsets.y
	panel.offset_right = offsets.z
	panel.offset_bottom = offsets.w
	panel.add_theme_stylebox_override("panel", _panel_style(color, radius))
	parent.add_child(panel)
	return panel


func _margin(parent: Control, horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	parent.add_child(margin)
	return margin


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _panel_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
