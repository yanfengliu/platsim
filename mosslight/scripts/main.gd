extends Control

const Simulation = preload("res://scripts/simulation.gd")
const WorldView = preload("res://scripts/world_view.gd")
const MINT := Color("9fe6bd")
const TEXT := Color("dce8d9")
const MUTED := Color("89a59e")
const GOLD := Color("ecc585")
const TOOLS := ["inspect", "dig", "ladder", "bed", "farm", "airfern", "lamp", "generator", "cistern", "beacon", "cancel"]
const SHORT_NAMES := {"inspect": "Inspect", "dig": "Dig", "ladder": "Ladder", "bed": "Cot", "farm": "Mushrooms", "airfern": "Airfern", "lamp": "Lamp", "generator": "Generator", "cistern": "Cistern", "beacon": "Beacon", "cancel": "Cancel job"}
const SHORTCUTS := {"inspect": "0", "dig": "1", "ladder": "2", "bed": "3", "farm": "4", "airfern": "5", "lamp": "6", "generator": "7", "cistern": "8", "beacon": "9", "cancel": "X"}
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
var _focus_before_overlay: Control
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
var _play_area: HBoxContainer
var _sidebar: VBoxContainer
var _desktop_layout := false
var _details_open := false
var _details_button: Button

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
	skin.default_font_size = 14
	skin.set_color("font_color", "Label", TEXT)
	skin.set_color("font_color", "Button", TEXT)
	skin.set_color("font_hover_color", "Button", Color("f2f5d8"))
	skin.set_color("font_pressed_color", "Button", Color("071e21"))
	skin.set_color("font_focus_color", "Button", Color("f2f5d8"))
	skin.set_stylebox("normal", "Button", _panel(Color("17343a"), Color("36524e"), 7, 10))
	skin.set_stylebox("hover", "Button", _panel(Color("244a48"), Color("81b995"), 7, 10))
	skin.set_stylebox("pressed", "Button", _panel(Color("91cda8"), MINT, 7, 10))
	skin.set_stylebox("focus", "Button", _panel(Color(0, 0, 0, 0), GOLD, 7, 0, 2))
	skin.set_stylebox("disabled", "Button", _panel(Color("15292e"), Color("243c3e"), 7, 10))
	skin.set_stylebox("panel", "PanelContainer", _panel(Color("10282e"), Color("28453f"), 10, 14))
	skin.set_stylebox("background", "ProgressBar", _panel(Color("1b383b"), Color("1b383b"), 3, 0))
	skin.set_stylebox("fill", "ProgressBar", _panel(Color("77bc92"), Color("77bc92"), 3, 0))
	theme = skin

func _panel(fill: Color, border: Color, radius: int, padding: int, border_width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box

func _label(text_value: String, font_size: int = 14, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text_value: String, action: Callable, key: String = "") -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 40
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	if key != "":
		button.name = key
		_controls[key] = button
	return button

func _build_interface() -> void:
	_root_margin = MarginContainer.new()
	_root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root_margin)
	_layout = VBoxContainer.new()
	_layout.add_theme_constant_override("separation", 10)
	_root_margin.add_child(_layout)
	_header_row = HBoxContainer.new()
	_header_row.add_theme_constant_override("separation", 16)
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
	_time_controls.add_theme_constant_override("separation", 5)
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
	_time_controls.add_child(_button("?", _show_help, "help"))
	_resource_grid = GridContainer.new()
	_resource_grid.columns = 6
	_resource_grid.add_theme_constant_override("h_separation", 8)
	_resource_grid.add_theme_constant_override("v_separation", 5)
	_layout.add_child(_resource_grid)
	for item in [["food", "FOOD", Color("e8bd83")], ["water", "WATER", Color("86c6d0")], ["air", "AIR", Color("9fe6bd")], ["power", "POWER", Color("e9d28d")], ["ore", "STONE", Color("c3bbb1")], ["biomass", "BIOMASS", Color("b1cd8a")]]:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _panel(Color("10282e"), Color("243e40"), 7, 7))
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_resource_grid.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
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
	world = WorldView.new()
	world.simulation = simulation
	world.cell_activated.connect(_activate_cell)
	world.cell_hovered.connect(_hover_cell)
	world.cancel_requested.connect(func(): _select_tool("inspect"))
	_world_frame.add_child(world)
	var world_overlay := MarginContainer.new()
	world_overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	world_overlay.offset_left = 12
	world_overlay.offset_right = -12
	world_overlay.offset_top = 10
	world_overlay.offset_bottom = 45
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
	_air_button.custom_minimum_size = Vector2(48, 32)
	_air_button.toggle_mode = true
	world_top.add_child(_air_button)
	var home_button := _button("Home", func(): world.fit_colony(); world.grab_focus(), "home")
	home_button.custom_minimum_size.y = 32
	world_top.add_child(home_button)
	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 12)
	_layout.add_child(_status_row)
	var goal_column := VBoxContainer.new()
	goal_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_column.add_theme_constant_override("separation", 5)
	_status_row.add_child(goal_column)
	_objective = _label("DAY 1 / 5 · Find your footing", 13, TEXT)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_column.add_child(_objective)
	_objective_bar = ProgressBar.new()
	_objective_bar.custom_minimum_size.y = 4
	_objective_bar.show_percentage = false
	goal_column.add_child(_objective_bar)
	_crew_label = _label("", 12, MUTED)
	_crew_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_row.add_child(_crew_label)
	_tools_panel = PanelContainer.new()
	_tools_panel.add_theme_stylebox_override("panel", _panel(Color("10282e"), Color("29473f"), 9, 9))
	_layout.add_child(_tools_panel)
	var tools_column := VBoxContainer.new()
	tools_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tools_column.add_theme_constant_override("separation", 5)
	_tools_panel.add_child(tools_column)
	var title_row := HBoxContainer.new()
	tools_column.add_child(title_row)
	_tool_title = _label("MAKE YOURSELF AT HOME", 11, MINT)
	_tool_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_tool_title)
	var legend := _label("0–9 tools · Space pause", 11, MUTED)
	legend.name = "ToolLegend"
	title_row.add_child(legend)
	_details_button = _button("Info", func(): _details_open = not _details_open; _responsive_layout(), "details")
	_details_button.custom_minimum_size.y = 32
	title_row.add_child(_details_button)
	var scroll := ScrollContainer.new()
	_tools_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size.y = 56
	tools_column.add_child(scroll)
	_tools_grid = GridContainer.new()
	_tools_grid.columns = TOOLS.size()
	_tools_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tools_grid.add_theme_constant_override("separation", 6)
	_tools_grid.add_theme_constant_override("h_separation", 6)
	_tools_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_tools_grid)
	for kind in TOOLS:
		var button := _button(SHORTCUTS[kind] + "  " + SHORT_NAMES[kind], func(): _select_tool(kind), "tool_" + kind)
		button.custom_minimum_size = Vector2(98, 48)
		button.add_theme_font_size_override("font_size", 13)
		button.toggle_mode = true
		button.button_pressed = kind == "inspect"
		_tools_grid.add_child(button)
		_tool_buttons[kind] = button
	_tool_description = _label("Inspect · Click a colonist, building or cave tile to learn about it.", 13, TEXT)
	_tool_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tool_description.custom_minimum_size.y = 30
	_tool_description.max_lines_visible = 3
	tools_column.add_child(_tool_description)
	_inspection = _label("Tip: extend the lower root ladder to reach the quarry.", 12, MUTED)
	_inspection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspection.custom_minimum_size.y = 28
	_inspection.max_lines_visible = 2
	tools_column.add_child(_inspection)
	_feedback = _label("Welcome to the First Hollow.", 12, GOLD)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size.y = 18
	_feedback.max_lines_visible = 2
	_layout.add_child(_feedback)
	_play_area = HBoxContainer.new()
	_play_area.add_theme_constant_override("separation", 14)
	_play_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_play_area.visible = false
	_layout.add_child(_play_area)
	_sidebar = VBoxContainer.new()
	_sidebar.custom_minimum_size.x = 264
	_sidebar.add_theme_constant_override("separation", 12)
	_play_area.add_child(_sidebar)

func _responsive_layout() -> void:
	if not _root_margin:
		return
	_compact = size.x < 580
	var desktop := size.x >= 1000 and size.y >= 650
	if desktop != _desktop_layout:
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
		_tools_grid.columns = 2 if desktop else TOOLS.size()
		_tools_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if desktop else ScrollContainer.SCROLL_MODE_AUTO
		_tools_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if desktop else ScrollContainer.SCROLL_MODE_DISABLED
		_tools_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL if desktop else Control.SIZE_FILL
		_tools_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if desktop else Control.SIZE_FILL
	_tool_description.visible = desktop or _details_open
	_inspection.visible = desktop or _details_open
	_details_button.visible = not desktop
	_details_button.text = "Less" if _details_open else "Info"
	_tool_description.max_lines_visible = 5 if desktop else 3
	_inspection.max_lines_visible = 5 if desktop else 2
	_feedback.max_lines_visible = 4 if desktop else 2
	var padding := 10 if _compact else 20
	for side in ["left", "right", "top", "bottom"]:
		_root_margin.add_theme_constant_override("margin_" + side, padding)
	_layout.add_theme_constant_override("separation", 7 if _compact else 10)
	_brand.add_theme_font_size_override("font_size", 21 if _compact else 27)
	_subtitle.visible = not _compact
	_resource_grid.columns = 3 if size.x < 680 else 6
	_crew_label.visible = false
	_world_hint.visible = size.x >= 600
	_tool_title.get_parent().get_node("ToolLegend").visible = not desktop and size.x >= 600
	if size.x < 420:
		_pause_button.text = "II" if not paused else ">"
		_pause_button.tooltip_text = "Pause / resume (Space)"
	else:
		_pause_button.text = "Resume" if paused else "Pause"
	_header_row.add_theme_constant_override("separation", 4 if _compact else 16)
	_time_controls.add_theme_constant_override("separation", 3 if _compact else 5)
	if _overlay_card:
		_overlay_card.custom_minimum_size.x = minf(500, maxf(260, size.x - 32))
		_overlay_card.size.x = _overlay_card.custom_minimum_size.x
		_overlay_card.position = (size - _overlay_card.size) * 0.5

func _process(delta: float) -> void:
	if simulation == null:
		return
	world.simulation_paused = paused or _overlay_kind != "" or simulation.status != "playing"
	if started and not paused and _overlay_kind == "" and simulation.status == "playing":
		_accumulator = minf(_accumulator + minf(delta, 0.25) * speed, 0.75)
		while _accumulator >= 0.1:
			simulation.step(0.1)
			_accumulator -= 0.1
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

func _select_tool(kind: String) -> void:
	world.clear_pointer_state()
	selected_tool = kind
	world.selected_tool = kind
	if kind != "inspect":
		_details_open = true
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
		_tool_description.text = "%s · %s\n%s" % [SHORT_NAMES[kind], _cost_text(entry.cost), DESCRIPTIONS[kind]]
		_tool_description.tooltip_text = str(entry.description)
	_tool_title.text = "SELECTED: " + str(SHORT_NAMES[kind]).to_upper()
	_update_inspection()
	_responsive_layout()
	if started:
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
	_accumulator = 0
	_set_feedback("Take your time. You can plan construction while paused." if paused else "The hollow is waking up again.")
	_refresh()
	world.grab_focus()

func _set_speed(value: int) -> void:
	speed = value
	_speed_one.button_pressed = speed == 1
	_speed_three.button_pressed = speed == 3
	if started:
		world.grab_focus()

func _toggle_air() -> void:
	world.show_air = not world.show_air
	_air_button.button_pressed = world.show_air
	_set_feedback("Air overlay: green is healthy, amber is low, coral is dangerous." if world.show_air else "Air overlay hidden.")
	if started:
		world.grab_focus()

func _on_focus_lost() -> void:
	world.clear_pointer_state()
	if started and simulation.status == "playing":
		paused = true
		_accumulator = 0
		_refresh()

func _on_browser_visibility(_arguments: Array) -> void:
	if bool(JavaScriptBridge.eval("document.hidden", true)):
		_on_focus_lost()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _overlay_kind != "":
		if event.keycode == KEY_ESCAPE and _overlay_kind == "help":
			_close_help()
			get_viewport().set_input_as_handled()
		return
	if not started:
		return
	var handled := true
	match event.keycode:
		KEY_SPACE:
			_toggle_pause()
		KEY_ESCAPE:
			_select_tool("inspect")
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
		KEY_2:
			_select_tool("ladder")
		KEY_3:
			_select_tool("bed")
		KEY_4:
			_select_tool("farm")
		KEY_5:
			_select_tool("airfern")
		KEY_6:
			_select_tool("lamp")
		KEY_7:
			_select_tool("generator")
		KEY_8:
			_select_tool("cistern")
		KEY_9:
			_select_tool("beacon")
		KEY_X:
			_select_tool("cancel")
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	# A focused world owns its arrows, rather than handing them to button navigation.
	if _overlay_kind == "" and get_viewport().gui_get_focus_owner() == world:
		_unhandled_key_input(event)
	elif _overlay_kind == "help" and is_instance_valid(_help_scroll):
		var amount := 0
		match event.keycode:
			KEY_DOWN:
				amount = 40
			KEY_UP:
				amount = -40
			KEY_PAGEDOWN:
				amount = 240
			KEY_PAGEUP:
				amount = -240
		if amount != 0:
			_help_scroll.scroll_vertical += amount
			get_viewport().set_input_as_handled()

func _new_overlay(kind: String) -> VBoxContainer:
	world.clear_pointer_state()
	_set_background_enabled(false)
	if _overlay:
		_overlay.queue_free()
	_overlay_kind = kind
	world.interactive = false
	_focus_before_overlay = get_viewport().gui_get_focus_owner()
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	var veil := ColorRect.new()
	veil.color = Color(0.015, 0.04, 0.055, 0.74)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	_overlay_card = PanelContainer.new()
	_overlay_card.custom_minimum_size.x = minf(500, maxf(260, size.x - 32))
	_overlay_card.add_theme_stylebox_override("panel", _panel(Color("102b30"), Color("52725e"), 15, 24 if size.x >= 420 else 18))
	center.add_child(_overlay_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_overlay_card.add_child(column)
	return column

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
	_start_button.custom_minimum_size.y = 50
	_start_button.add_theme_stylebox_override("normal", _panel(Color("91cda8"), MINT, 7, 12))
	_start_button.add_theme_color_override("font_color", Color("10292b"))
	_start_button.add_theme_color_override("font_focus_color", Color("10292b"))
	_start_button.add_theme_color_override("font_hover_color", Color("10292b"))
	_start_button.add_theme_stylebox_override("hover", _panel(Color("afe5bf"), MINT, 7, 12))
	column.add_child(_start_button)
	_how_button = _button("How to play", _show_help, "how_to_play")
	_how_button.custom_minimum_size.y = 44
	column.add_child(_how_button)
	_start_button.focus_next = _how_button.get_path()
	_start_button.focus_previous = _how_button.get_path()
	_start_button.focus_neighbor_top = _how_button.get_path()
	_start_button.focus_neighbor_bottom = _how_button.get_path()
	_how_button.focus_next = _start_button.get_path()
	_how_button.focus_previous = _start_button.get_path()
	_how_button.focus_neighbor_top = _start_button.get_path()
	_how_button.focus_neighbor_bottom = _start_button.get_path()
	_overlay_text(column, "A playable first chapter · No live-run saves", 11, MUTED)
	_start_button.grab_focus()

func _start_game() -> void:
	started = true
	paused = false
	_close_overlay()
	_set_feedback("Add mushrooms + an airfern by the lamp. Extend the lower ladder into the quarry.")
	world.grab_focus()
	_publish_snapshot()

func _show_help() -> void:
	var column := _new_overlay("help")
	_overlay_text(column, "FIELD NOTES", 11, GOLD)
	_overlay_text(column, "A hollow worth tending", 25 if size.x >= 420 else 21, MINT)
	var scroll := ScrollContainer.new()
	_help_scroll = scroll
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.custom_minimum_size.y = minf(340, size.y - 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	var help_label := _overlay_text(body, "PLAN, THEN WATCH\nSelect a tool and click a tile. Settlers walk to reachable jobs and do the work. Drag the Dig tool across rock to mark a tunnel.\n\nA LIVING CHAIN\nCisterns gather water. Mushrooms make food, airferns replenish air, and both need nearby light. Generators burn biomass to power lamps and your beacon.\n\nYOUR FIRST STEPS\nYour four settlers need two mushroom beds and two airferns. Place another mushroom planter just left of the generator, and an airfern just left of the glow lamp. Dig the rock beneath the lower ladder, then extend the ladder into the Root Quarry. Gather stone on the right and living roots on the left. The space between the lamp and the first mushrooms is a good home for your beacon.\n\nTHE GOAL\nSurvive five full days (20 minutes at 1x). Keep a powered beacon, healthy settlers, steady food/air/water/power production and 8 food + 10 water in reserve for two minutes. The objective tells you what is missing.\n\nGIVE THEM A WAY THROUGH\nBuild ladders to reach different levels. Inaccessible jobs wait until a route exists. Cancel a planned build to recover its reserved materials.\n\nCONTROLS\n0 Inspect · 1 Dig · 2 Ladder · 3 Cot\n4 Mushrooms · 5 Airfern · 6 Lamp\n7 Generator · 8 Cistern · 9 Beacon\nX Cancel job · Space Pause · V Air\nArrows move the tile cursor · Enter acts\nWASD or middle-drag pans · Wheel zooms\nHome centers the colony · Escape clears tool\nTab moves between buttons.\n\nTake your time. Construction can be planned while paused. Click a building to read why it is not working. This first chapter does not save a live run.", 14, TEXT)
	help_label.focus_mode = Control.FOCUS_ALL
	var close := _button("Back to the hollow" if started else "Back", _close_help, "close_help")
	close.custom_minimum_size.y = 46
	column.add_child(close)
	close.focus_next = scroll.get_path()
	close.focus_previous = scroll.get_path()
	scroll.focus_next = close.get_path()
	scroll.focus_previous = close.get_path()
	help_label.focus_mode = Control.FOCUS_NONE
	close.grab_focus()

func _close_help() -> void:
	if not started:
		_show_title()
	elif simulation.status in ["won", "lost"]:
		_show_outcome()
	else:
		_close_overlay()
		world.grab_focus()

func _close_overlay() -> void:
	world.clear_pointer_state()
	if _overlay:
		_overlay.queue_free()
	_overlay = null
	_overlay_card = null
	_overlay_kind = ""
	_help_scroll = null
	world.interactive = started and simulation.status == "playing"
	_set_background_enabled(world.interactive)
	_accumulator = 0

func _show_outcome() -> void:
	var won: bool = simulation.status == "won"
	var column := _new_overlay("outcome")
	_overlay_text(column, "CHAPTER COMPLETE" if won else "THE HOLLOW FALLS QUIET", 11, GOLD)
	_overlay_text(column, "A light in the dark." if won else "Every home starts somewhere.", 30 if size.x >= 420 else 25, MINT)
	_overlay_text(column, "Your settlers have made a living home beneath the surface. The beacon shines, and the cavern is no longer a lonely place." if won else "The last settler has fallen. A fresh colony brings new supplies and another chance to find your balance.", 15, MUTED)
	_overlay_text(column, "Day %d · %d jobs waiting" % [simulation.day, simulation.jobs.size()], 13)
	var retry := _button("Begin a new colony", _restart, "restart")
	retry.custom_minimum_size.y = 48
	column.add_child(retry)
	retry.focus_next = retry.get_path()
	retry.focus_previous = retry.get_path()
	retry.focus_neighbor_top = retry.get_path()
	retry.focus_neighbor_bottom = retry.get_path()
	retry.focus_neighbor_left = retry.get_path()
	retry.focus_neighbor_right = retry.get_path()
	retry.grab_focus()

func _restart() -> void:
	simulation.reset(42)
	_last_status = "playing"
	paused = false
	speed = 1
	_set_speed(1)
	_select_tool("inspect")
	_start_game()
	world.fit_colony()
	_refresh()

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
			controls[key] = {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y, "text": control.text if control is Button else "", "disabled": control.disabled if control is Button else false, "visible": visible_rect.has_area(), "clip": {"x": visible_rect.position.x, "y": visible_rect.position.y, "width": visible_rect.size.x, "height": visible_rect.size.y}}
	var settlers := []
	for colonist in simulation.colonists:
		settlers.append({"id": colonist.id, "name": colonist.name, "x": colonist.pos.x, "y": colonist.pos.y, "health": colonist.health, "hunger": colonist.hunger, "energy": colonist.energy, "task": colonist.task, "alive": colonist.alive})
	var buildings := []
	for building in simulation.buildings:
		buildings.append({"kind": building.kind, "x": building.cell.x, "y": building.cell.y, "active": building.active, "reason": building.reason})
	var jobs := []
	for job in simulation.jobs:
		jobs.append({"kind": job.kind, "x": job.cell.x, "y": job.cell.y, "progress": job.progress})
	var world_rect: Rect2 = world.get_global_rect()
	var card_rect: Rect2 = _overlay_card.get_global_rect() if is_instance_valid(_overlay_card) else Rect2()
	var focused_control := get_viewport().gui_get_focus_owner()
	var data := {"started": started, "paused": paused, "speed": speed, "overlay": _overlay_kind, "status": simulation.status, "elapsed": simulation.elapsed, "day": simulation.day, "resources": simulation.resources.duplicate(), "selected_tool": selected_tool, "air_overlay": world.show_air, "colonists": settlers, "buildings": buildings, "jobs": jobs, "feedback": _feedback.text, "inspection": _inspection.text, "objective": _objective.text, "objective_progress": simulation.objective_progress, "controls": controls, "cursor": {"x": world.cursor.x, "y": world.cursor.y}, "viewport": {"width": size.x, "height": size.y}, "world": {"x": world_rect.position.x, "y": world_rect.position.y, "width": world_rect.size.x, "height": world_rect.size.y, "camera_x": world.camera.x, "camera_y": world.camera.y, "tile_size": world.TILE * world.zoom_level}, "overlay_card": {"x": card_rect.position.x, "y": card_rect.position.y, "width": card_rect.size.x, "height": card_rect.size.y}, "title_inner": {"x": card_rect.position.x + 1, "y": card_rect.position.y + 1, "width": card_rect.size.x - 2, "height": card_rect.size.y - 2}}
	data["focused_control"] = str(focused_control.name) if is_instance_valid(focused_control) else ""
	data["pointer_state"] = {"dig_drag": world._dig_drag, "pan_drag": world._dragging}
	JavaScriptBridge.eval("window.__MOSSLIGHT_SNAPSHOT__ = " + JSON.stringify(data) + ";", true)
