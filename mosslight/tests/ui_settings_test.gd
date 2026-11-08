extends SceneTree

const UISettings = preload("res://scripts/ui_settings.gd")
const Main = preload("res://scripts/main.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var settings := UISettings.new()
	check(settings.requested_percent == 100, "Fresh sessions start at100%")
	for viewport in [Vector2(320, 640), Vector2(720, 560), Vector2(420, 640), Vector2(421, 640), Vector2(480, 640), Vector2(481, 640), Vector2(560, 640), Vector2(561, 640)]:
		check(settings.maximum_percent(viewport) == 100, "Compact cap preserves controls at" + str(viewport))
	check(settings.maximum_percent(Vector2(1280, 800)) > 100, "Normal Windows window permits meaningful scaling")
	check(settings.maximum_percent(Vector2(1920, 1080)) == UISettings.SCALE_PRESETS.back(), "Large Windows window permits largest offered size")
	settings.choose(200)
	check(settings.applied_percent(Vector2(320, 640)) == 100, "Requested large scale adapts safely on small windows")
	check(settings.requested_percent == 200, "Resizing does not erase preference")
	check(settings.description(Vector2(320, 640)).contains("Selected 200% · using 100%"), "Cap is explained visibly")
	check(settings.applied_percent(Vector2(1920, 1080)) == 200, "Returning to large window restores chosen scale")
	settings.choose(133)
	check(settings.requested_percent == 200, "Invalid presets leave preference intact")
	settings.choose(100)
	check(settings.applied_percent(Vector2(320, 640)) == 100 and settings.requested_percent == 100, "Reset works at smallest supported width")
	settings.choose(200)
	var previous_limit := 0
	for index in range(20):
		var viewport := Vector2(300 + index * 90, 400 + index * 40)
		var limit: int = settings.maximum_percent(viewport)
		var applied: int = settings.applied_percent(viewport)
		check(limit >= previous_limit and limit in UISettings.SCALE_PRESETS, "Growing windows never shrink the safe size range")
		check(applied > 0 and applied <= limit and applied <= settings.requested_percent, "Applied metrics are bounded positive preferences")
		check(settings.requested_percent == 200, "Repeated layout queries preserve the session choice")
		previous_limit = limit
	await _test_build_menu()
	print("Mosslight UI settings: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _test_build_menu() -> void:
	root.size = Vector2i(320, 640)
	var app := Main.new()
	app.size = Vector2(320, 640)
	root.add_child(app)
	await _settle()
	app._controls.start.pressed.emit()
	app.paused = true
	await _settle()
	check(app._tools_grid.get_child_count() == 4, "Primary actions stay fixed as the build catalog grows")
	for key in ["tool_inspect", "tool_dig", "build", "tool_cancel"]:
		var button: Button = app._controls[key]
		check(button.is_visible_in_tree() and Rect2(Vector2.ZERO, app.size).encloses(button.get_global_rect()), "Primary action is visible at320px: " + key)
	check(not app._build_browser.visible and not app._build_path.visible, "Initial view has no flat build catalog")
	var seen := {}
	for category in Main.BUILD_CATEGORIES:
		for kind in Main.CATEGORY_ITEMS[category]:
			check(not seen.has(kind), "Every building has one clear category: " + kind)
			seen[kind] = true
	check(seen.size() == Main.Simulation.CATALOG.size(), "Every buildable is reachable through categories")
	for kind in Main.Simulation.CATALOG:
		check(seen.has(kind) and not app._controls["tool_" + kind].is_visible_in_tree(), "Build item starts tucked into its category: " + kind)
	var resources: Dictionary = app.simulation.resources.duplicate()
	for category in Main.BUILD_CATEGORIES:
		app._controls.build.pressed.emit()
		await _settle()
		check(app._build_menu_open and app._build_category == "", "Build returns to the category root")
		check(root.gui_get_focus_owner() == app._category_buttons.access, "Build moves keyboard focus into its choices")
		for other in Main.BUILD_CATEGORIES:
			check(app._category_buttons[other].is_visible_in_tree(), "All categories are reachable: " + other)
		app._controls["category_" + category].pressed.emit()
		await _settle()
		check(app._build_category == category and app._controls.build_back.is_visible_in_tree(), "Category has a visible Back control")
		for kind in Main.Simulation.CATALOG:
			check(app._controls["tool_" + kind].is_visible_in_tree() == (kind in Main.CATEGORY_ITEMS[category]), "Only selected category items are shown: " + kind)
		for kind in Main.CATEGORY_ITEMS[category]:
			var button: Button = app._controls["tool_" + kind]
			var footprint: Vector2i = app.simulation.building_size(kind)
			check(button.text.contains("%dx%d" % [footprint.x, footprint.y]) and button.text.contains("stone" if Main.Simulation.CATALOG[kind].cost.has("ore") else "biomass"), "Item shows footprint and materials before selection: " + kind)
			button.pressed.emit()
			await _settle()
			check(app.selected_tool == kind and app.world.selected_tool == kind, "Category item activates placement: " + kind)
			check(not app._build_menu_open and app._build_path.visible and root.gui_get_focus_owner() == app.world, "Selection returns world focus with a Change path: " + kind)
			check(app._build_path.get_global_rect().end.x <= app.size.x, "Selected item summary fits compact width: " + kind)
			app._controls.build_path.pressed.emit()
			await _settle()
			check(app._build_menu_open and app._build_category == category, "Change returns to selected category: " + kind)
		app._controls.build_back.pressed.emit()
		await _settle()
		check(app._build_category == "" and root.gui_get_focus_owner() == app._category_buttons[category], "Back restores the originating category focus")
		app._controls.build_back.pressed.emit()
		await _settle()
		check(not app._build_menu_open and root.gui_get_focus_owner() == app._build_button, "Closing categories restores Build focus")
	check(app.simulation.resources == resources and app.simulation.jobs.is_empty(), "Browsing and changing tools never spends materials or queues construction")
	app._select_tool("dig")
	for key in [KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		app._unhandled_key_input(event)
		check(app.selected_tool == "dig", "Former per-item number shortcuts cannot silently change tools")
	var build_key := InputEventKey.new()
	build_key.keycode = KEY_B
	build_key.pressed = true
	app._unhandled_key_input(build_key)
	check(app._build_menu_open and app._build_category == "", "B opens category selection")
	app._show_build_category("power")
	root.size = Vector2i(1920, 1080)
	app.size = Vector2(1920, 1080)
	await _settle()
	app._choose_scale(150)
	await _settle()
	check(app._build_menu_open and app._build_category == "power", "Changing scale preserves open category")
	check(root.gui_get_focus_owner() == app._controls.tool_lamp, "Changing scale restores focused category item")
	app._controls.tool_generator.pressed.emit()
	await _settle()
	app._choose_scale(200)
	await _settle()
	check(app.selected_tool == "generator" and app._build_path.visible and not app._build_menu_open, "Changing scale preserves chosen placement and its Change path")
	app._open_build_menu()
	app._show_build_category("life_support")
	app._show_menu()
	await _settle()
	check(app._overlay_kind == "menu" and app._controls.category_access.focus_mode == Control.FOCUS_NONE, "Escape menu isolates background category focus")
	app._back_modal()
	await _settle()
	check(app._build_menu_open and app._build_category == "life_support" and root.gui_get_focus_owner() == app._controls.tool_farm, "Returning from menu restores category and keyboard focus")
	await _test_menu_bounds(app)
	root.remove_child(app)
	app.queue_free()
	await _settle()

func _test_menu_bounds(app: Control) -> void:
	for scenario in [[Vector2i(720, 560), 100], [Vector2i(320, 640), 100], [Vector2i(1280, 800), 150], [Vector2i(1920, 1080), 200]]:
		root.size = scenario[0]
		app.size = Vector2(scenario[0])
		app._choose_scale(scenario[1])
		app._select_tool("inspect")
		await _settle()
		await _settle()
		var bounds := Rect2(Vector2.ZERO, app.size)
		var stable_world: Rect2 = app.world.get_global_rect()
		var label: String = str(scenario[0]) + " at" + str(scenario[1]) + "%"
		check(bounds.encloses(stable_world), "Initial map fits viewport: " + label)
		for category in Main.BUILD_CATEGORIES:
			app._open_build_menu()
			app._show_build_category(category)
			await _settle()
			await _settle()
			check(bounds.encloses(app.world.get_global_rect()), "Map stays inside viewport while browsing " + category + ": " + label)
			check(bounds.encloses(app._tools_scroll.get_global_rect()), "Whole catalog scroll viewport fits " + category + ": " + label)
			check(bounds.encloses(app._build_back.get_global_rect()) and bounds.encloses(app._feedback.get_global_rect()), "Back and feedback stay inside viewport: " + label)
			for kind in Main.CATEGORY_ITEMS[category]:
				var item: Button = app._controls["tool_" + kind]
				item.grab_focus()
				app._tools_scroll.ensure_control_visible(item)
				await _settle()
				check(app._tools_scroll.get_global_rect().encloses(item.get_global_rect()), "Focused item is fully readable after normal scrolling: " + kind + " " + label)
				item.pressed.emit()
				await _settle()
				await _settle()
				check(bounds.encloses(app.world.get_global_rect()) and bounds.encloses(app._build_path.get_global_rect()), "Selected item and world fit: " + kind + " " + label)
				if app._desktop_layout:
					check(app.world.get_global_rect().is_equal_approx(stable_world), "Desktop map never shifts after selecting " + kind + ": " + label)
				app._select_tool("cancel")
				# Long inspection text must remain scrollable rather than expanding
				# the desktop map or pushing compact controls beneath the window.
				app._inspection.text = "Reserved construction materials return to storage.\n".repeat(20)
				await _settle()
				await _settle()
				check(bounds.encloses(app.world.get_global_rect()) and bounds.encloses(app._details_scroll.get_global_rect()), "Long inspection stays within bounded panel: " + label)
				if app._desktop_layout:
					check(app.world.get_global_rect().is_equal_approx(stable_world), "Cancel preserves the exact map position and size: " + label)
				app._open_build_menu(category)
				await _settle()
