extends Control

const Simulation = preload("res://scripts/simulation.gd")
const WorldView = preload("res://scripts/world_view.gd")
const UISettings = preload("res://scripts/ui_settings.gd")
const MINT := Color("9ed9be")
const TEXT := Color("e4e6ed")
const MUTED := Color("929db5")
const GOLD := Color("ecc585")
const BUILD_CATEGORIES := ["access", "furniture", "life_support", "power"]
const CATEGORY_NAMES := {"access": "Access", "furniture": "Furniture", "life_support": "Life support", "power": "Power"}
const CATEGORY_ITEMS := {"access": ["ladder"], "furniture": ["bed"], "life_support": ["farm", "airfern", "cistern"], "power": ["lamp", "generator", "beacon"]}
const SHORT_NAMES := {"inspect": "Inspect", "dig": "Dig", "ladder": "Ladder", "bed": "Cot", "farm": "Mushrooms", "airfern": "Airfern", "lamp": "Lamp", "generator": "Generator", "cistern": "Cistern", "beacon": "Beacon", "cancel": "Cancel job"}
const SHORTCUTS := {"inspect": "0", "dig": "1", "cancel": "X"}
const DESCRIPTIONS := {"ladder": "Connect levels so settlers can reach jobs.", "bed": "A place for one settler to rest.", "farm": "Needs light + water. Grows food.", "airfern": "Needs light + water. Refreshes room air.", "lamp": "Lights plants within 5 tiles. Uses power.", "generator": "Burns biomass to produce power.", "cistern": "Collects renewable water from the cave.", "beacon": "Keep it powered while the colony thrives."}
var simulation: RefCounted
var world: Control
var started := false
var paused := false
var speed := 1
var selected_tool := "inspect"
var _accumulator := 0.0
var _refresh_timer := 0.0
var _last_status := "playing"
var _compact := false
var _root_margin: MarginContainer
var _layout: VBoxContainer
var _brand: Label
var _subtitle: Label
var _header_row: HBoxContainer
var _time_controls: HBoxContainer
var _resource_grid: GridContainer
var _resource_labels := {}
var _pause_button: Button
var _speed_one: Button
var _speed_three: Button
var _air_button: Button
var _objective: Label
var _objective_bar: ProgressBar
var _crew_label: Label
var _tool_title: Label
var _tool_description: Label
var _details_scroll: ScrollContainer
var _feedback: Label
var _inspection: Label
var _world_hint: Label
var _tool_buttons := {}
var _controls := {}
var _overlay: Control
var _overlay_card: PanelContainer
var _overlay_kind := ""
var _start_button: Button
var _how_button: Button
var _current_cell := Vector2i(19, 16)
var _feedback_remaining := 0.0
var _last_message := ""
var _visibility_callback: JavaScriptObject
var _help_scroll: ScrollContainer
var _world_frame: PanelContainer
var _status_row: HBoxContainer
var _tools_panel: PanelContainer
var _tools_grid: GridContainer
var _tools_scroll: ScrollContainer
var _build_button: Button
var _build_browser: VBoxContainer
var _build_grid: GridContainer
var _build_heading: Label
var _build_back: Button
var _build_path: Button
var _category_buttons := {}
var _build_menu_open := false
var _build_category := ""
var _play_area: HBoxContainer
var _sidebar: VBoxContainer
var _desktop_layout := false
var _details_open := false
var _details_button: Button
var _menu_button: Button
var _ui_settings := UISettings.new()
var _ui_scale := 1.0
var _scale_rebuild_pending := false
var _modal_history: Array[Dictionary] = []
var _overlay_scroll: ScrollContainer
var _scale_description: Label
var _scale_buttons := {}
var _last_layout_state: Array = []

func _ready() -> void:
	simulation = Simulation.new()
	_build_theme()
	_build_interface()
	resized.connect(_responsive_layout)
	get_tree().root.focus_exited.connect(_on_focus_lost)
	if OS.has_feature("web"):
		_visibility_callback = JavaScriptBridge.create_callback(_on_browser_visibility)
		JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", _visibility_callback)
		world.reduced_motion = bool(JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches", true))
	_responsive_layout()
	call_deferred("_initial_view")
	_refresh()
	_show_title()

func _initial_view() -> void:
	# Container minimums settle over layout passes. Fit the actual world area.
	await get_tree().process_frame
	await get_tree().process_frame
	world.fit_colony()
	_publish_snapshot()

func _build_theme() -> void:
	var skin := Theme.new()
	skin.default_font_size = _px(14)
	skin.set_color("font_color", "Label", TEXT)
	skin.set_color("font_color", "Button", TEXT)
	skin.set_color("font_hover_color", "Button", Color("f2f5d8"))
	skin.set_color("font_pressed_color", "Button", Color("071e21"))
	skin.set_color("font_focus_color", "Button", Color("f2f5d8"))
	skin.set_stylebox("normal", "Button", _panel(Color("242b42"), Color("4a526c"), 7, 10))
	skin.set_stylebox("hover", "Button", _panel(Color("344159"), Color("81b995"), 7, 10))
	skin.set_stylebox("pressed", "Button", _panel(Color("91cda8"), MINT, 7, 10))
	skin.set_stylebox("focus", "Button", _panel(Color(0, 0, 0, 0), GOLD, 7, 0, 2))
	skin.set_stylebox("disabled", "Button", _panel(Color("1c2133"), Color("30384e"), 7, 10))
	skin.set_stylebox("panel", "PanelContainer", _panel(Color("1c2338"), Color("414b64"), 10, 14))
	skin.set_stylebox("background", "ProgressBar", _panel(Color("1b383b"), Color("1b383b"), 3, 0))
	skin.set_stylebox("fill", "ProgressBar", _panel(Color("77bc92"), Color("77bc92"), 3, 0))
	theme = skin

func _panel(fill: Color, border: Color, radius: int, padding: int, border_width: int = 1) -> StyleBoxFlat:
	radius = mini(radius, 2)
	var box := StyleBoxFlat.new()
	box.anti_aliasing = false
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(_px(border_width))
	box.set_corner_radius_all(_px(radius))
	box.content_margin_left = _px(padding)
	box.content_margin_right = _px(padding)
	box.content_margin_top = _px(padding)
	box.content_margin_bottom = _px(padding)
	return box

func _label(text_value: String, font_size: int = 14, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", _px(font_size))
	label.add_theme_color_override("font_color", color)
	return label

func _button(text_value: String, action: Callable, key: String = "") -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = _px(40)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	if key != "":
		button.name = key
		_controls[key] = button
	return button

func _px(value: float) -> int:
	return roundi(value * _ui_scale)

func _build_interface() -> void:
	_root_margin = MarginContainer.new()
	_root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root_margin)
	_layout = VBoxContainer.new()
	_layout.add_theme_constant_override("separation", _px(10))
	_root_margin.add_child(_layout)
	_header_row = HBoxContainer.new()
	_header_row.add_theme_constant_override("separation", _px(16))
	_layout.add_child(_header_row)
	var branding := VBoxContainer.new()
	branding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	branding.add_theme_constant_override("separation", 0)
	_header_row.add_child(branding)
	_brand = _label("MOSSLIGHT", 27, MINT)
	branding.add_child(_brand)
	_subtitle = _label("A little light. A place to belong.", 12, MUTED)
	branding.add_child(_subtitle)
	_time_controls = HBoxContainer.new()
	_time_controls.add_theme_constant_override("separation", _px(5))
	_header_row.add_child(_time_controls)
	_pause_button = _button("Pause", _toggle_pause, "pause")
	_time_controls.add_child(_pause_button)
	_speed_one = _button("1x", func(): _set_speed(1), "speed_1")
	_speed_one.toggle_mode = true
	_speed_one.button_pressed = true
	_time_controls.add_child(_speed_one)
	_speed_three = _button("3x", func(): _set_speed(3), "speed_3")
	_speed_three.toggle_mode = true
	_time_controls.add_child(_speed_three)
	_menu_button = _button("Menu", _show_menu, "menu")
	_menu_button.tooltip_text = "Menu (Escape) · Settings and how to play"
	_time_controls.add_child(_menu_button)
	_resource_grid = GridContainer.new()
	_resource_grid.columns = 6
	_resource_grid.add_theme_constant_override("h_separation", _px(8))
	_resource_grid.add_theme_constant_override("v_separation", _px(5))
	_layout.add_child(_resource_grid)
	for item in [["food", "FOOD", Color("e8bd83")], ["water", "WATER", Color("86c6d0")], ["air", "AIR", Color("9fe6bd")], ["power", "POWER", Color("e9d28d")], ["ore", "STONE", Color("c3bbb1")], ["biomass", "BIOMASS", Color("b1cd8a")]]:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _panel(Color("1c2338"), Color("243e40"), 7, 7))
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_resource_grid.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", _px(4))
		panel.add_child(row)
		var name_label := _label(item[1], 10, MUTED)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var value := _label("—", 16, item[2])
		row.add_child(value)
		_resource_labels[item[0]] = value
	_world_frame = PanelContainer.new()
	_world_frame.add_theme_stylebox_override("panel", _panel(Color("08171e"), Color("345049"), 9, 1))
	_world_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_world_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_world_frame.custom_minimum_size.y = 140
	_layout.add_child(_world_frame)
	if not is_instance_valid(world):
		world = WorldView.new()
		world.name = "World"
		world.simulation = simulation
		world.cell_activated.connect(_activate_cell)
		world.cell_hovered.connect(_hover_cell)
		world.cancel_requested.connect(func(): _select_tool("inspect"))
		_world_frame.add_child(world)
	else:
		world.reparent(_world_frame)
		var previous_overlay := world.get_node_or_null("WorldUI")
		if previous_overlay:
			world.remove_child(previous_overlay)
			previous_overlay.queue_free()
	var world_overlay := MarginContainer.new()
	world_overlay.name = "WorldUI"
	world_overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	world_overlay.offset_left = _px(12)
	world_overlay.offset_right = -_px(12)
	world_overlay.offset_top = _px(10)
	world_overlay.offset_bottom = _px(45)
	world_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(world_overlay)
	var world_top := HBoxContainer.new()
	world_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_overlay.add_child(world_top)
	_world_hint = _label("HOLLOW 01    /    A NEW BEGINNING", 11, Color("9cb5a7"))
	_world_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_world_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_top.add_child(_world_hint)
	_air_button = _button("Air", _toggle_air, "air")
	_air_button.custom_minimum_size = Vector2(_px(48), _px(32))
	_air_button.toggle_mode = true
	world_top.add_child(_air_button)
	var home_button := _button("Home", func(): world.fit_colony(); world.grab_focus(), "home")
	home_button.custom_minimum_size.y = _px(32)
	world_top.add_child(home_button)
	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", _px(12))
	_layout.add_child(_status_row)
	var goal_column := VBoxContainer.new()
	goal_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_column.add_theme_constant_override("separation", _px(5))
	_status_row.add_child(goal_column)
	_objective = _label("DAY 1 / 5 · Find your footing", 13, TEXT)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_column.add_child(_objective)
	_objective_bar = ProgressBar.new()
	_objective_bar.custom_minimum_size.y = _px(4)
	_objective_bar.show_percentage = false
	goal_column.add_child(_objective_bar)
	_crew_label = _label("", 12, MUTED)
	_crew_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_row.add_child(_crew_label)
	_tools_panel = PanelContainer.new()
	_tools_panel.add_theme_stylebox_override("panel", _panel(Color("1c2338"), Color("29473f"), 9, 9))
	_layout.add_child(_tools_panel)
	var tools_column := VBoxContainer.new()
	tools_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tools_column.add_theme_constant_override("separation", _px(5))
	_tools_panel.add_child(tools_column)
	var title_row := HBoxContainer.new()
	tools_column.add_child(title_row)
	_tool_title = _label("MAKE YOURSELF AT HOME", 11, MINT)
	_tool_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_tool_title)
	var legend := _label("B Build | Space pause", 11, MUTED)
	legend.name = "ToolLegend"
	title_row.add_child(legend)
	_details_button = _button("Info", func(): _details_open = not _details_open; _responsive_layout(), "details")
	_details_button.custom_minimum_size.y = _px(32)
	title_row.add_child(_details_button)
	_tools_grid = GridContainer.new()
	_tools_grid.columns = 4
	_tools_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tools_grid.add_theme_constant_override("h_separation", _px(4))
	_tools_grid.add_theme_constant_override("v_separation", _px(4))
	tools_column.add_child(_tools_grid)
	for kind in ["inspect", "dig", "build", "cancel"]:
		var button: Button
		if kind == "build":
			button = _button("Build", _open_build_menu, "build")
			_build_button = button
			button.tooltip_text = "Build (B) · Choose a category, then an item."
		else:
			button = _button("Cancel" if kind == "cancel" else SHORT_NAMES[kind], func(): _select_tool(kind), "tool_" + kind)
			button.tooltip_text = "%s (%s)" % [SHORT_NAMES[kind], SHORTCUTS[kind]]
			_tool_buttons[kind] = button
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", _px(13))
		button.toggle_mode = true
		button.button_pressed = kind == selected_tool
		_tools_grid.add_child(button)
	_build_path = _button("", func(): _open_build_menu(_build_category), "build_path")
	_build_path.add_theme_font_size_override("font_size", _px(12))
	_build_path.custom_minimum_size.y = _px(44)
	tools_column.add_child(_build_path)
	_build_browser = VBoxContainer.new()
	_build_browser.add_theme_constant_override("separation", _px(5))
	tools_column.add_child(_build_browser)
	var browse_header := HBoxContainer.new()
	_build_browser.add_child(browse_header)
	_build_back = _button("Back", _back_build_menu, "build_back")
	_build_back.custom_minimum_size.y = _px(30)
	browse_header.add_child(_build_back)
	_build_heading = _label("BUILD / CATEGORIES", 11, MINT)
	_build_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	browse_header.add_child(_build_heading)
	_tools_scroll = ScrollContainer.new()
	_tools_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tools_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_tools_scroll.follow_focus = true
	_tools_scroll.custom_minimum_size.y = _px(112)
	_build_browser.add_child(_tools_scroll)
	_build_grid = GridContainer.new()
	_build_grid.columns = 2
	_build_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_grid.add_theme_constant_override("h_separation", _px(5))
	_build_grid.add_theme_constant_override("v_separation", _px(5))
	_tools_scroll.add_child(_build_grid)
	for category in BUILD_CATEGORIES:
		var category_button := _button(CATEGORY_NAMES[category], func(): _show_build_category(category), "category_" + category)
		category_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		category_button.custom_minimum_size.y = _px(52)
		category_button.add_theme_font_size_override("font_size", _px(13))
		_build_grid.add_child(category_button)
		_category_buttons[category] = category_button
		for kind in CATEGORY_ITEMS[category]:
			var dimensions: Vector2i = simulation.building_size(kind)
			var button := _button("%s · %dx%d\n%s" % [SHORT_NAMES[kind], dimensions.x, dimensions.y, _cost_text(Simulation.CATALOG[kind].cost).replace(", ", "\n")], func(): _select_tool(kind), "tool_" + kind)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size.y = _px(68 if Simulation.CATALOG[kind].cost.size() > 1 else 52)
			button.add_theme_font_size_override("font_size", _px(12))
			button.tooltip_text = DESCRIPTIONS[kind]
			button.toggle_mode = true
			_build_grid.add_child(button)
			_tool_buttons[kind] = button
	_render_build_menu()
	_details_scroll = ScrollContainer.new()
	_details_scroll.name = "ToolDetails"
	_details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_details_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_details_scroll.follow_focus = true
	_details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tools_column.add_child(_details_scroll)
	var details_column := VBoxContainer.new()
	details_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_column.add_theme_constant_override("separation", _px(5))
	_details_scroll.add_child(details_column)
	_tool_description = _label("Inspect · Click a colonist, building or cave tile to learn about it.", 13, TEXT)
	_tool_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tool_description.custom_minimum_size.y = _px(30)
	_tool_description.max_lines_visible = 3
	details_column.add_child(_tool_description)
	_inspection = _label("Tip: extend the lower root ladder to reach the quarry.", 12, MUTED)
	_inspection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspection.custom_minimum_size.y = _px(28)
	_inspection.max_lines_visible = 2
	details_column.add_child(_inspection)
	_feedback = _label("Welcome to the First Hollow.", 12, GOLD)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size.y = _px(18)
	_feedback.max_lines_visible = 2
	_layout.add_child(_feedback)
	_play_area = HBoxContainer.new()
	_play_area.add_theme_constant_override("separation", _px(14))
	_play_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_play_area.visible = false
	_layout.add_child(_play_area)
	_sidebar = VBoxContainer.new()
	_sidebar.custom_minimum_size.x = _px(264)
	_sidebar.add_theme_constant_override("separation", _px(12))
	_play_area.add_child(_sidebar)

func _responsive_layout() -> void:
	if not _root_margin:
		return
	var target_scale := _ui_settings.applied_percent(size) / 100.0
	if not is_equal_approx(target_scale, _ui_scale) and not _scale_rebuild_pending:
		_scale_rebuild_pending = true
		call_deferred("_rebuild_scaled_interface")
	var layout_state := [size, _ui_scale, _details_open, paused, _overlay_kind, _world_frame.size.x, _build_menu_open, _build_category]
	if layout_state == _last_layout_state:
		return
	_last_layout_state = layout_state
	_compact = size.x < _px(580)
	var desktop := size.x >= maxf(1000, _px(750)) and size.y >= 650
	if desktop != _desktop_layout:
		var layout_focus := get_viewport().gui_get_focus_owner()
		var layout_focus_name := str(layout_focus.name) if is_instance_valid(layout_focus) else ""
		_desktop_layout = desktop
		if desktop:
			_world_frame.reparent(_play_area)
			_play_area.move_child(_world_frame, 0)
			_status_row.reparent(_sidebar)
			_tools_panel.reparent(_sidebar)
			_feedback.reparent(_sidebar)
			_layout.move_child(_play_area, 2)
		else:
			for item in [_world_frame, _status_row, _tools_panel, _feedback]:
				item.reparent(_layout)
			_layout.move_child(_world_frame, 2)
			_layout.move_child(_status_row, 3)
			_layout.move_child(_tools_panel, 4)
			_layout.move_child(_feedback, 5)
		_play_area.visible = desktop
		_restore_focus(layout_focus_name)
		_tools_grid.columns = 2 if desktop else 4
		_tools_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if desktop else Control.SIZE_FILL
	_build_browser.size_flags_vertical = Control.SIZE_EXPAND_FILL if desktop else Control.SIZE_FILL
	_tools_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL if desktop else Control.SIZE_FILL
	# Scrollable content must not impose its text or catalog height on the map.
	# Desktop columns share a fixed available height; compact tools reserve a
	# small viewport while leaving the rest to the world.
	_tools_scroll.custom_minimum_size.y = 0 if desktop else _px(80)
	_details_scroll.visible = not _build_menu_open and (desktop or _details_open)
	_details_scroll.custom_minimum_size.y = 0 if desktop else _px(80)
	_details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL if desktop else Control.SIZE_FILL
	_tool_description.visible = true
	_inspection.visible = true
	_details_button.visible = not desktop and not _build_menu_open
	_details_button.text = "Less" if _details_open else "Info"
	_tool_description.max_lines_visible = -1
	_inspection.max_lines_visible = -1
	_feedback.max_lines_visible = 2
	var short_window := size.y < _px(650)
	_world_frame.custom_minimum_size.y = 80 if not desktop and (_build_menu_open or _details_open) else 140
	var padding := _px(10 if _compact or short_window else 20)
	for side in ["left", "right", "top", "bottom"]:
		_root_margin.add_theme_constant_override("margin_" + side, padding)
	_layout.add_theme_constant_override("separation", _px(7 if _compact or short_window else 10))
	_brand.add_theme_font_size_override("font_size", _px(20 if _compact else 27))
	_subtitle.visible = not _compact and not short_window
	_resource_grid.columns = 3 if size.x < _px(680) else 6
	_crew_label.visible = false
	_world_hint.visible = _world_frame.size.x >= _px(600)
	_tool_title.get_parent().get_node("ToolLegend").visible = not desktop and size.x >= _px(600)
	_menu_button.text = "Menu"
	if size.x < _px(420):
		_pause_button.text = "II" if not paused else ">"
		_pause_button.tooltip_text = "Pause / resume (Space)"
	else:
		_pause_button.text = "Resume" if paused else "Pause"
	_header_row.add_theme_constant_override("separation", _px(4 if _compact else 16))
	_time_controls.add_theme_constant_override("separation", _px(3 if _compact else 5))
	if _overlay_card:
		_overlay_card.custom_minimum_size.x = minf(_px(500), maxf(260, size.x - 32))
		_overlay_card.size.x = _overlay_card.custom_minimum_size.x
	if is_instance_valid(_scale_description):
		_scale_description.text = _ui_settings.description(size)
		for percent in _scale_buttons:
			_scale_buttons[percent].disabled = int(percent) > _ui_settings.maximum_percent(size)
		_refresh_settings_focus()

func _rebuild_scaled_interface() -> void:
	_scale_rebuild_pending = false
	var next_scale := _ui_settings.applied_percent(size) / 100.0
	if is_equal_approx(next_scale, _ui_scale):
		return
	world.clear_pointer_state()
	var focus_owner := get_viewport().gui_get_focus_owner()
	var focus_name := str(focus_owner.name) if is_instance_valid(focus_owner) else "World"
	var modal := _overlay_kind
	var details := _details_open
	var browsing := _build_menu_open
	var category := _build_category
	var feedback_text := _feedback.text
	# Recreate native UI metrics, keeping the same world and simulation instances.
	# Its camera, zoom, motion state and physical coordinate mapping are untouched.
	world.reparent(self)
	remove_child(_root_margin)
	_root_margin.queue_free()
	_controls.clear()
	_tool_buttons.clear()
	_category_buttons.clear()
	_resource_labels.clear()
	_ui_scale = next_scale
	_desktop_layout = false
	_last_layout_state.clear()
	_build_theme()
	_build_interface()
	_select_tool(selected_tool)
	_build_menu_open = browsing
	_build_category = category
	_render_build_menu()
	_details_open = details
	_feedback.text = feedback_text
	_set_speed(speed)
	_air_button.button_pressed = world.show_air
	_responsive_layout()
	_refresh()
	if modal != "":
		_render_overlay(modal)
	_restore_focus(focus_name)
	_publish_snapshot()

func _choose_scale(percent: int) -> void:
	_ui_settings.choose(percent)
	_rebuild_scaled_interface()
	if _overlay_kind == "settings":
		for value in _scale_buttons:
			_scale_buttons[value].button_pressed = int(value) == _ui_settings.requested_percent
		_scale_description.text = _ui_settings.description(size)
	_publish_snapshot()

func _process(delta: float) -> void:
	if simulation == null:
		return
	world.simulation_paused = paused or _overlay_kind != "" or simulation.status != "playing"
	if started and not paused and _overlay_kind == "" and simulation.status == "playing":
		# Keep fractional time through pauses and menus so visual interpolation
		# resumes the same segment. Paused frames never add simulation time.
		_accumulator = minf(_accumulator + minf(delta, 0.25) * speed, 0.75)
		while _accumulator >= 0.1:
			world.begin_simulation_step()
			simulation.step(0.1)
			world.end_simulation_step()
			_accumulator -= 0.1
	world.present_frame(_accumulator / 0.1, delta, speed, started and not paused and _overlay_kind == "" and simulation.status == "playing")
	_refresh_timer += delta
	_feedback_remaining = maxf(0, _feedback_remaining - delta)
	if _refresh_timer >= 0.25:
		_refresh_timer = 0
		_refresh()
		_publish_snapshot()
	if simulation.status != _last_status:
		_last_status = simulation.status
		if simulation.status in ["won", "lost"]:
			_show_outcome()

func _refresh() -> void:
	var air := 100.0
	var count := 0
	var air_total := 0.0
	var alive := 0
	var crew := PackedStringArray()
	for colonist in simulation.colonists:
		if colonist.alive:
			alive += 1
			var room: Dictionary = simulation.room_at(Vector2i(Vector2(colonist.pos).floor()))
			air_total += float(room.get("air", 100))
			count += 1
		crew.append(str(colonist.name))
	if count > 0:
		air = air_total / count
	for key in _resource_labels:
		var value: float = air if key == "air" else float(simulation.resources.get(key, 0))
		_resource_labels[key].text = str(int(floor(value))) + ("%" if key == "air" else "")
		_resource_labels[key].add_theme_color_override("font_color", Color("ed9878") if (key == "air" and value < 45) or (key == "food" and value < 6) else TEXT)
	_objective.text = "DAY %d / 5 · %s" % [mini(simulation.day, 5), "Colony paused" if paused else simulation.objective_reason if simulation.objective_reason != "" else "The hollow is thriving."]
	_objective.tooltip_text = simulation.objective_text()
	_objective_bar.value = simulation.objective_progress * 100.0
	_crew_label.text = "%d / 4 settlers\n%s" % [alive, " · ".join(crew)]
	if _feedback_remaining <= 0:
		if simulation.message != "":
			_feedback.text = simulation.message
		else:
			_feedback.text = "Arrows: tile cursor · Enter: use tool · WASD: pan · Wheel: zoom · H: help"
	if started and _overlay_kind == "":
		_update_inspection()
	_responsive_layout()

func _category_for(kind: String) -> String:
	for category in BUILD_CATEGORIES:
		if kind in CATEGORY_ITEMS[category]:
			return category
	return ""

func _render_build_menu() -> void:
	_build_browser.visible = _build_menu_open
	_tool_title.text = "BUILD YOUR COLONY" if _build_menu_open else "SELECTED: " + str(SHORT_NAMES[selected_tool]).to_upper()
	for kind in ["inspect", "dig", "cancel"]:
		_tool_buttons[kind].button_pressed = not _build_menu_open and selected_tool == kind
	_build_path.visible = not _build_menu_open and Simulation.CATALOG.has(selected_tool)
	_build_button.button_pressed = _build_menu_open or Simulation.CATALOG.has(selected_tool)
	_build_heading.text = "BUILD / " + ("CATEGORIES" if _build_category == "" else str(CATEGORY_NAMES[_build_category]).to_upper())
	_build_back.text = "Close" if _build_category == "" else "Back"
	for category in _category_buttons:
		_category_buttons[category].visible = _build_menu_open and _build_category == ""
	for kind in Simulation.CATALOG:
		_tool_buttons[kind].visible = _build_menu_open and kind in CATEGORY_ITEMS.get(_build_category, [])
	if _build_path.visible:
		var dimensions: Vector2i = simulation.building_size(selected_tool)
		_build_path.text = "%s > %s · %dx%d\n%s · Change" % [CATEGORY_NAMES[_category_for(selected_tool)], SHORT_NAMES[selected_tool], dimensions.x, dimensions.y, _cost_text(Simulation.CATALOG[selected_tool].cost)]
		_build_path.tooltip_text = "Choose another item in " + str(CATEGORY_NAMES[_category_for(selected_tool)])

func _open_build_menu(category: String = "") -> void:
	_select_tool("inspect")
	_build_menu_open = true
	_build_category = category
	_details_open = false
	_render_build_menu()
	_tools_scroll.scroll_vertical = 0
	_responsive_layout()
	_focus_build_choices()
	_publish_snapshot()

func _show_build_category(category: String) -> void:
	_build_category = category
	_render_build_menu()
	_tools_scroll.scroll_vertical = 0
	_focus_build_choices()
	_publish_snapshot()

func _focus_build_choices() -> void:
	if _build_category == "":
		_category_buttons[BUILD_CATEGORIES.front()].grab_focus()
	else:
		_tool_buttons[CATEGORY_ITEMS[_build_category].front()].grab_focus()

func _back_build_menu() -> void:
	if _build_category != "":
		var previous := _build_category
		_build_category = ""
		_render_build_menu()
		_tools_scroll.scroll_vertical = 0
		_category_buttons[previous].grab_focus()
	else:
		_build_menu_open = false
		_render_build_menu()
		_responsive_layout()
		_build_button.grab_focus()
	_publish_snapshot()

func _select_tool(kind: String) -> void:
	world.clear_pointer_state()
	selected_tool = kind
	world.selected_tool = kind
	_build_menu_open = false
	if Simulation.CATALOG.has(kind):
		_build_category = _category_for(kind)
		_details_open = false
	elif kind != "inspect":
		_details_open = true
	_render_build_menu()
	for key in _tool_buttons:
		_tool_buttons[key].button_pressed = key == kind
	if kind == "inspect":
		_tool_description.text = "Inspect · Click a colonist, building or cave tile to learn about it."
	elif kind == "dig":
		_tool_description.text = "Dig · Mark rock to excavate. Drag across tiles to queue a tunnel."
	elif kind == "cancel":
		_tool_description.text = "Cancel job · Click a planned job. Reserved construction materials return to storage."
	else:
		var entry: Dictionary = Simulation.CATALOG[kind]
		var dimensions: Vector2i = simulation.building_size(kind)
		_tool_description.text = "%s · %d x %d tiles · %s\n%s Place by its bottom-left tile." % [SHORT_NAMES[kind], dimensions.x, dimensions.y, _cost_text(entry.cost), DESCRIPTIONS[kind]]
		_tool_description.tooltip_text = str(entry.description)
	_tool_title.text = "SELECTED: " + str(SHORT_NAMES[kind]).to_upper()
	_update_inspection()
	_responsive_layout()
	if started and _overlay_kind == "":
		world.grab_focus()
	_publish_snapshot()

func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in cost:
		parts.append("%s %s" % [cost[key], "stone" if key == "ore" else key])
	return ", ".join(parts) if not parts.is_empty() else "free"

func _activate_cell(cell: Vector2i) -> void:
	if not started or _overlay_kind != "" or simulation.status != "playing":
		return
	_current_cell = cell
	world.cursor = cell
	var accepted := false
	if selected_tool == "inspect":
		_details_open = true
		_responsive_layout()
		_update_inspection()
		return
	elif selected_tool == "dig":
		accepted = simulation.queue_dig(cell)
	elif selected_tool == "cancel":
		accepted = simulation.cancel_job(cell)
	else:
		var reason: String = simulation.can_build(selected_tool, cell)
		if reason != "":
			_set_feedback(reason)
			return
		accepted = simulation.queue_build(selected_tool, cell)
	if accepted:
		# Keep the viewport stable while the pointer traces an excavation row.
		if selected_tool != "dig":
			_details_open = false
		_set_feedback("%s at %d, %d." % ["Job canceled" if selected_tool == "cancel" else SHORT_NAMES[selected_tool] + " queued", cell.x, cell.y])
	else:
		_set_feedback(simulation.message if simulation.message != "" else "That tile cannot accept this job. Try a reachable, unoccupied tile.")
	_refresh()
	_publish_snapshot()

func _hover_cell(cell: Vector2i) -> void:
	_current_cell = cell
	_update_inspection()

func _update_inspection() -> void:
	if not _inspection:
		return
	if _current_cell.x < 0 or _current_cell.y < 0 or _current_cell.x >= simulation.width or _current_cell.y >= simulation.height:
		_inspection.text = "Move over the hollow to inspect a tile."
		return
	var text_value: String = simulation.cell_info(_current_cell)
	for colonist in simulation.colonists:
		if Vector2i(Vector2(colonist.pos).floor()) == _current_cell:
			text_value = "%s · Health %d · Hunger %d · Rest %d\n%s" % [colonist.name, colonist.health, colonist.hunger, colonist.energy, colonist.task]
			break
	if selected_tool not in ["inspect", "dig", "cancel"]:
		var reason: String = simulation.can_build(selected_tool, _current_cell)
		text_value = ("Ready to build. " if reason == "" else reason + " ") + text_value
	_inspection.text = text_value
	_inspection.tooltip_text = text_value

func _set_feedback(message: String) -> void:
	_feedback.text = message
	_feedback.tooltip_text = message
	_feedback_remaining = 5.0

func _toggle_pause() -> void:
	if not started or _overlay_kind != "" or simulation.status != "playing":
		return
	paused = not paused
	world.clear_pointer_state()
	_set_feedback("Take your time. You can plan construction while paused." if paused else "The hollow is waking up again.")
	_refresh()
	world.grab_focus()

func _set_speed(value: int) -> void:
	speed = value
	_speed_one.button_pressed = speed == 1
	_speed_three.button_pressed = speed == 3
	if started and _overlay_kind == "":
		world.grab_focus()

func _toggle_air() -> void:
	world.show_air = not world.show_air
	_air_button.button_pressed = world.show_air
	_set_feedback("Air overlay: green is healthy, amber is low, coral is dangerous." if world.show_air else "Air overlay hidden.")
	if started and _overlay_kind == "":
		world.grab_focus()

func _on_focus_lost() -> void:
	world.clear_pointer_state()
	if started and simulation.status == "playing":
		paused = true
		_refresh()

func _on_browser_visibility(_arguments: Array) -> void:
	if bool(JavaScriptBridge.eval("document.hidden", true)):
		_on_focus_lost()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _overlay_kind != "":
		return
	if not started:
		return
	var handled := true
	match event.keycode:
		KEY_SPACE:
			_toggle_pause()
		KEY_H:
			_show_help()
		KEY_V:
			_toggle_air()
		KEY_HOME:
			world.fit_colony()
		KEY_W:
			world.pan(Vector2(0, -1))
		KEY_A:
			world.pan(Vector2(-1, 0))
		KEY_S:
			world.pan(Vector2(0, 1))
		KEY_D:
			world.pan(Vector2(1, 0))
		KEY_LEFT:
			world.move_cursor(Vector2i(-1, 0))
		KEY_RIGHT:
			world.move_cursor(Vector2i(1, 0))
		KEY_UP:
			world.move_cursor(Vector2i(0, -1))
		KEY_DOWN:
			world.move_cursor(Vector2i(0, 1))
		KEY_ENTER, KEY_KP_ENTER:
			_activate_cell(world.cursor)
		KEY_0:
			_select_tool("inspect")
		KEY_1:
			_select_tool("dig")
		KEY_B:
			_open_build_menu()
		KEY_X:
			_select_tool("cancel")
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	# Escape is global, including when a native button or scroll panel has focus.
	if event.keycode == KEY_ESCAPE:
		if _overlay_kind in ["menu", "settings", "help"]:
			_back_modal()
		else:
			_show_menu()
		get_viewport().set_input_as_handled()
		return
	# A focused world owns its arrows, rather than handing them to button navigation.
	if _overlay_kind == "" and get_viewport().gui_get_focus_owner() == world:
		_unhandled_key_input(event)
	elif _overlay_kind == "help" and is_instance_valid(_help_scroll):
		var amount := 0
		match event.keycode:
			KEY_DOWN:
				amount = _px(40)
			KEY_UP:
				amount = -_px(40)
			KEY_PAGEDOWN:
				amount = _px(240)
			KEY_PAGEUP:
				amount = -_px(240)
		if amount != 0:
			_help_scroll.scroll_vertical += amount
			get_viewport().set_input_as_handled()

func _new_overlay(kind: String) -> VBoxContainer:
	world.clear_pointer_state()
	_set_background_enabled(false)
	if _overlay:
		remove_child(_overlay)
		_overlay.queue_free()
	_help_scroll = null
	_scale_description = null
	_scale_buttons.clear()
	_overlay_kind = kind
	world.interactive = false
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	var veil := ColorRect.new()
	veil.color = Color(0.015, 0.04, 0.055, 0.74)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(veil)
	_overlay_scroll = ScrollContainer.new()
	_overlay_scroll.name = "ModalScroll"
	_overlay_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_scroll.offset_left = 16
	_overlay_scroll.offset_top = 16
	_overlay_scroll.offset_right = -16
	_overlay_scroll.offset_bottom = -16
	_overlay_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_overlay_scroll.follow_focus = true
	_overlay.add_child(_overlay_scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_scroll.add_child(center)
	_overlay_card = PanelContainer.new()
	_overlay_card.custom_minimum_size.x = minf(_px(500), maxf(260, size.x - 32))
	_overlay_card.add_theme_stylebox_override("panel", _panel(Color("102b30"), Color("52725e"), 15, 24 if size.x >= 420 else 18))
	center.add_child(_overlay_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", _px(14))
	_overlay_card.add_child(column)
	return column

func _push_modal(kind: String) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	_modal_history.append({"kind": _overlay_kind, "focus": str(focused.name) if is_instance_valid(focused) else "World"})
	_render_overlay(kind)
	_publish_snapshot()

func _render_overlay(kind: String) -> void:
	match kind:
		"title": _show_title()
		"help": _render_help()
		"menu": _render_menu()
		"settings": _render_settings()
		"outcome": _render_outcome()

func _back_modal() -> void:
	if _modal_history.is_empty():
		if simulation.status in ["won", "lost"]:
			_render_outcome()
		elif not started:
			_show_title()
		else:
			_close_overlay()
			world.grab_focus()
	else:
		var previous: Dictionary = _modal_history.pop_back()
		if previous.kind == "":
			_close_overlay()
		else:
			_render_overlay(str(previous.kind))
		_restore_focus(str(previous.focus))
	_refresh()
	_publish_snapshot()

func _restore_focus(control_name: String) -> void:
	if control_name == "World" and _overlay_kind == "":
		world.grab_focus()
	elif _controls.has(control_name) and is_instance_valid(_controls[control_name]):
		var control: Button = _controls[control_name]
		if control.is_visible_in_tree() and not control.disabled:
			control.grab_focus()

func _trap_focus(controls: Array) -> void:
	for index in range(controls.size()):
		var current: Control = controls[index]
		var next: Control = controls[(index + 1) % controls.size()]
		var previous: Control = controls[posmod(index - 1, controls.size())]
		current.focus_next = next.get_path()
		current.focus_previous = previous.get_path()
		current.focus_neighbor_bottom = next.get_path()
		current.focus_neighbor_top = previous.get_path()

func _show_menu() -> void:
	_push_modal("menu")

func _render_menu() -> void:
	var column := _new_overlay("menu")
	_overlay_text(column, "A MOMENT IN THE HOLLOW", 11, GOLD)
	_overlay_text(column, "Take your time.", 30, MINT)
	_overlay_text(column, "The colony is paused while this menu is open.", 14, MUTED)
	var context := str(_modal_history.back().kind) if not _modal_history.is_empty() else ""
	var resume_text := "Back to title" if context == "title" else "Back to results" if context == "outcome" else "Resume"
	var resume := _button(resume_text, _back_modal, "resume")
	column.add_child(resume)
	var settings := _button("Settings", func(): _push_modal("settings"), "settings")
	column.add_child(settings)
	var help := _button("How to play", _show_help, "menu_help")
	column.add_child(help)
	_overlay_text(column, "Escape goes back · Tab moves between controls", 11, MUTED)
	_trap_focus([resume, settings, help])
	resume.grab_focus()

func _render_settings() -> void:
	var column := _new_overlay("settings")
	_overlay_text(column, "MAKE YOURSELF COMFORTABLE", 11, GOLD)
	_overlay_text(column, "Settings", 30, MINT)
	_overlay_text(column, "Interface size", 17)
	_scale_description = _overlay_text(column, _ui_settings.description(size), 13, MUTED)
	var options := GridContainer.new()
	options.columns = 3
	options.add_theme_constant_override("h_separation", _px(8))
	options.add_theme_constant_override("v_separation", _px(8))
	column.add_child(options)
	var focus_controls: Array = []
	for percent in UISettings.SCALE_PRESETS:
		var button := _button("%d%%" % percent, func(): _choose_scale(percent), "scale_%d" % percent)
		button.toggle_mode = true
		button.button_pressed = percent == _ui_settings.requested_percent
		button.disabled = percent > _ui_settings.maximum_percent(size)
		button.tooltip_text = "Enlarge this window to use this size." if button.disabled else "Resize interface text and controls."
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options.add_child(button)
		_scale_buttons[percent] = button
		if not button.disabled:
			focus_controls.append(button)
	_overlay_text(column, "Changes apply immediately. World zoom stays the same. Your choice lasts for this session, including new colonies; it resets when the game closes.", 13, MUTED)
	var reset := _button("Reset to 100%", func(): _choose_scale(100), "reset_scale")
	column.add_child(reset)
	var back := _button("Back", _back_modal, "back_settings")
	column.add_child(back)
	focus_controls.append(reset)
	focus_controls.append(back)
	_trap_focus(focus_controls)
	back.grab_focus()

func _refresh_settings_focus() -> void:
	var controls: Array = []
	for percent in UISettings.SCALE_PRESETS:
		if _scale_buttons.has(percent) and not _scale_buttons[percent].disabled:
			controls.append(_scale_buttons[percent])
	for key in ["reset_scale", "back_settings"]:
		if _controls.has(key) and is_instance_valid(_controls[key]):
			controls.append(_controls[key])
	if not controls.is_empty():
		_trap_focus(controls)

func _set_background_enabled(enabled: bool) -> void:
	# Mouse veils alone do not remove hidden controls from Godot's focus traversal.
	for key in _controls:
		if is_instance_valid(_controls[key]) and _layout.is_ancestor_of(_controls[key]):
			var control: Button = _controls[key]
			control.disabled = not enabled
			control.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	world.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

func _overlay_text(column: VBoxContainer, text_value: String, font_size: int, color: Color = TEXT) -> Label:
	var label := _label(text_value, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
	return label

func _show_title() -> void:
	var column := _new_overlay("title")
	_overlay_text(column, "A SMALL COLONY. A LIVING WORLD.", 11, GOLD)
	_overlay_text(column, "Mosslight", 48 if size.x >= 420 else 38, MINT)
	_overlay_text(column, "Make a home\nbeneath the surface.", 25 if size.x >= 420 else 22)
	_overlay_text(column, "Four settlers have found a hollow in the dark. Grow food, tend the air, and bring a forgotten cavern to life.", 15, MUTED)
	var divider := HSeparator.new()
	column.add_child(divider)
	_overlay_text(column, "YOUR FIRST CHAPTER", 11, GOLD)
	_overlay_text(column, "Survive five days. Build a beacon. Keep your little colony thriving.", 14)
	_start_button = _button("Enter the hollow", _start_game, "start")
	_start_button.custom_minimum_size.y = _px(50)
	_start_button.add_theme_stylebox_override("normal", _panel(Color("91cda8"), MINT, 7, 12))
	_start_button.add_theme_color_override("font_color", Color("10292b"))
	_start_button.add_theme_color_override("font_focus_color", Color("10292b"))
	_start_button.add_theme_color_override("font_hover_color", Color("10292b"))
	_start_button.add_theme_stylebox_override("hover", _panel(Color("afe5bf"), MINT, 7, 12))
	column.add_child(_start_button)
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", _px(8))
	column.add_child(secondary)
	_how_button = _button("How to play", _show_help, "how_to_play")
	_how_button.custom_minimum_size.y = _px(44)
	_how_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	secondary.add_child(_how_button)
	var menu := _button("Menu", _show_menu, "title_menu")
	secondary.add_child(menu)
	_trap_focus([_start_button, _how_button, menu])
	_overlay_text(column, "A playable first chapter · No live-run saves", 11, MUTED)
	_start_button.grab_focus()

func _start_game() -> void:
	_modal_history.clear()
	started = true
	paused = false
	_close_overlay()
	_set_feedback("Add mushrooms + an airfern by the lamp. Extend the lower ladder into the quarry.")
	world.grab_focus()
	_publish_snapshot()

func _show_help() -> void:
	_push_modal("help")

func _render_help() -> void:
	var column := _new_overlay("help")
	_overlay_text(column, "FIELD NOTES", 11, GOLD)
	_overlay_text(column, "A hollow worth tending", 25 if size.x >= 420 else 21, MINT)
	var scroll := ScrollContainer.new()
	_help_scroll = scroll
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.custom_minimum_size.y = maxf(100, minf(_px(340), size.y - _px(240)))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", _px(12))
	scroll.add_child(body)
	var help_label := _overlay_text(body, "PLAN, THEN WATCH\nSelect Build, choose a category and then an item. Click a tile to place its bottom-left corner. Settlers walk to reachable jobs and do the work. Drag the Dig tool across rock to mark a tunnel.\n\nA LIVING CHAIN\nCisterns gather water. Mushrooms make food, airferns replenish air, and both need nearby light. Generators burn biomass to power lamps and your beacon.\n\nYOUR FIRST STEPS\nYour four settlers need two mushroom beds and two airferns. Place another mushroom planter just right of the generator (21, 16), and an airfern just left of the glow lamp (22, 16). Dig the rock beneath the lower ladder, then extend the ladder into the Root Quarry. Gather stone on the right and living roots on the left. The open upper roost beside the cots has room for a 2-by-3 beacon (11, 6). Large buildings occupy their full footprint; place them by the bottom-left tile with solid ground beneath every column.\n\nTHE GOAL\nSurvive five full days (20 minutes at 1x). Keep a powered beacon, healthy settlers, steady food/air/water/power production and 8 food + 10 water in reserve for two minutes. The objective tells you what is missing.\n\nGIVE THEM A WAY THROUGH\nBuild ladders to reach different levels. Inaccessible jobs wait until a route exists. Cancel a planned build to recover its reserved materials.\n\nCONTROLS\n0 Inspect | 1 Dig | B Build categories\nBuild > category > item | Back returns to categories\nX Cancel job · Space Pause · V Air\nArrows move the tile cursor · Enter acts\nWASD or middle-drag pans · Wheel zooms\nHome centers the colony · Escape opens the menu\nTab moves between buttons.\n\nTake your time. Construction can be planned while paused. Click a building to read why it is not working. This first chapter does not save a live run.", 14, TEXT)
	help_label.focus_mode = Control.FOCUS_ALL
	var close := _button("Back", _close_help, "close_help")
	close.custom_minimum_size.y = _px(46)
	column.add_child(close)
	close.focus_next = scroll.get_path()
	close.focus_previous = scroll.get_path()
	scroll.focus_next = close.get_path()
	scroll.focus_previous = close.get_path()
	help_label.focus_mode = Control.FOCUS_NONE
	close.grab_focus()

func _close_help() -> void:
	_back_modal()

func _close_overlay() -> void:
	world.clear_pointer_state()
	if _overlay:
		remove_child(_overlay)
		_overlay.queue_free()
	_overlay = null
	_overlay_card = null
	_overlay_kind = ""
	_help_scroll = null
	_overlay_scroll = null
	_scale_description = null
	_scale_buttons.clear()
	world.interactive = started and simulation.status == "playing"
	_set_background_enabled(world.interactive)

func _show_outcome() -> void:
	_modal_history.clear()
	_render_outcome()

func _render_outcome() -> void:
	var won: bool = simulation.status == "won"
	var column := _new_overlay("outcome")
	_overlay_text(column, "CHAPTER COMPLETE" if won else "THE HOLLOW FALLS QUIET", 11, GOLD)
	_overlay_text(column, "A light in the dark." if won else "Every home starts somewhere.", 30 if size.x >= 420 else 25, MINT)
	_overlay_text(column, "Your settlers have made a living home beneath the surface. The beacon shines, and the cavern is no longer a lonely place." if won else "The last settler has fallen. A fresh colony brings new supplies and another chance to find your balance.", 15, MUTED)
	_overlay_text(column, "Day %d · %d jobs waiting" % [simulation.day, simulation.jobs.size()], 13)
	var retry := _button("Begin a new colony", _restart, "restart")
	retry.custom_minimum_size.y = _px(48)
	column.add_child(retry)
	var menu := _button("Menu", _show_menu, "outcome_menu")
	column.add_child(menu)
	_trap_focus([retry, menu])
	retry.grab_focus()

func _restart() -> void:
	simulation.reset(42)
	_accumulator = 0
	world.reset_motion()
	_last_status = "playing"
	paused = false
	speed = 1
	_set_speed(1)
	_select_tool("inspect")
	_start_game()
	world.fit_colony()
	_refresh()

func _footprint_snapshot(kind: String, anchor: Vector2i) -> Dictionary:
	var area: Rect2i = simulation.building_rect(kind, anchor)
	return {"x": area.position.x, "y": area.position.y, "width": area.size.x, "height": area.size.y}

func _publish_snapshot() -> void:
	if not OS.has_feature("web") or not world:
		return
	var controls := {}
	for key in _controls:
		if is_instance_valid(_controls[key]) and _controls[key].is_visible_in_tree():
			var control: Control = _controls[key]
			var rect := control.get_global_rect()
			var visible_rect := rect
			var ancestor := control.get_parent()
			while ancestor is Control:
				if ancestor.clip_contents:
					visible_rect = visible_rect.intersection(ancestor.get_global_rect())
				ancestor = ancestor.get_parent()
			controls[key] = {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y, "text": control.text if control is Button else "", "font_size": control.get_theme_font_size("font_size"), "disabled": control.disabled if control is Button else false, "visible": visible_rect.has_area(), "clip": {"x": visible_rect.position.x, "y": visible_rect.position.y, "width": visible_rect.size.x, "height": visible_rect.size.y}}
	var settlers := []
	for colonist in simulation.colonists:
		settlers.append({"id": colonist.id, "name": colonist.name, "x": colonist.pos.x, "y": colonist.pos.y, "health": colonist.health, "hunger": colonist.hunger, "energy": colonist.energy, "task": colonist.task, "alive": colonist.alive})
	var buildings := []
	for building in simulation.buildings:
		buildings.append({"kind": building.kind, "x": building.cell.x, "y": building.cell.y, "active": building.active, "reason": building.reason, "footprint": _footprint_snapshot(building.kind, building.cell)})
	var jobs := []
	for job in simulation.jobs:
		jobs.append({"kind": job.kind, "x": job.cell.x, "y": job.cell.y, "progress": job.progress, "building_kind": job.building_kind, "footprint": _footprint_snapshot(job.building_kind, job.cell) if job.kind == "build" else {"x": job.cell.x, "y": job.cell.y, "width": 1, "height": 1}})
	var world_rect: Rect2 = world.get_global_rect()
	var card_rect: Rect2 = _overlay_card.get_global_rect() if is_instance_valid(_overlay_card) else Rect2()
	var focused_control := get_viewport().gui_get_focus_owner()
	var data := {"started": started, "paused": paused, "speed": speed, "overlay": _overlay_kind, "status": simulation.status, "elapsed": simulation.elapsed, "day": simulation.day, "resources": simulation.resources.duplicate(), "selected_tool": selected_tool, "air_overlay": world.show_air, "colonists": settlers, "buildings": buildings, "jobs": jobs, "feedback": _feedback.text, "inspection": _inspection.text, "objective": _objective.text, "objective_progress": simulation.objective_progress, "controls": controls, "cursor": {"x": world.cursor.x, "y": world.cursor.y}, "viewport": {"width": size.x, "height": size.y}, "world": {"x": world_rect.position.x, "y": world_rect.position.y, "width": world_rect.size.x, "height": world_rect.size.y, "camera_x": world.camera.x, "camera_y": world.camera.y, "tile_size": world.TILE * world.zoom_level}, "overlay_card": {"x": card_rect.position.x, "y": card_rect.position.y, "width": card_rect.size.x, "height": card_rect.size.y}, "title_inner": {"x": card_rect.position.x + 1, "y": card_rect.position.y + 1, "width": card_rect.size.x - 2, "height": card_rect.size.y - 2}}
	var build_scroll_rect := _tools_scroll.get_global_rect()
	data["build_menu"] = {"scroll": {"x": build_scroll_rect.position.x, "y": build_scroll_rect.position.y, "width": build_scroll_rect.size.x, "height": build_scroll_rect.size.y}, "open": _build_menu_open, "category": _build_category, "path": ["Build", CATEGORY_NAMES[_build_category]] if _build_category != "" else ["Build"]}
	data["focused_control"] = str(focused_control.name) if is_instance_valid(focused_control) else ""
	data["pointer_state"] = {"dig_drag": world._dig_drag, "pan_drag": world._dragging}
	data["ui_scale"] = {"requested": _ui_settings.requested_percent, "applied": roundi(_ui_scale * 100), "maximum": _ui_settings.maximum_percent(size), "description": _ui_settings.description(size)}
	data["modal_return"] = str(_modal_history.back().kind) if not _modal_history.is_empty() else ""
	data["modal_scroll"] = _overlay_scroll.scroll_vertical if is_instance_valid(_overlay_scroll) else 0
	JavaScriptBridge.eval("window.__MOSSLIGHT_SNAPSHOT__ = " + JSON.stringify(data) + ";", true)
