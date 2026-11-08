extends SceneTree

## Headless lifetime and load-budget regression, not a GPU/driver stability test.
## Optional: -- --soak-seconds=180 runs the normal main loop at wall-clock speed.
const MainScene = preload("res://scenes/main.tscn")
const WorldView = preload("res://scripts/world_view.gd")
const Simulation = preload("res://scripts/simulation.gd")
const WINDOW_SIZE := Vector2i(1920, 1080)
const MAIN_CYCLES := 6
const WARMUP_CYCLES := 2
# After the exercised scales/modals, allow a few lazy engine resource wrappers.
# Node and orphan counts remain exact; an old interface/world is never tolerated.
const OBJECT_TOLERANCE := 16
# Soak can acquire one normal outcome overlay and its theme/font resources.
const SOAK_NODE_TOLERANCE := 32
const SOAK_OBJECT_TOLERANCE := 96
const SOAK_MEMORY_TOLERANCE := 8 * 1024 * 1024
var checks: int = 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func _run() -> void:
	# Observe startup policy before any fixture can change it. Never set the cap here.
	check(Engine.max_fps == 60, "fresh engine applies the production 60 FPS cap")
	check(int(ProjectSettings.get_setting("application/run/max_fps", 0)) == 60, "project declares the same 60 FPS cap")
	check(DisplayServer.get_name() == "headless", "runtime stability suite uses the headless display")
	if DisplayServer.get_name() != "headless":
		printerr("This diagnostic requires --headless; it does not exercise a graphics driver.")
		quit(1)
		return
	var soak_seconds: int = 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--soak-seconds="):
			var value: String = argument.trim_prefix("--soak-seconds=")
			if not value.is_valid_int() or int(value) < 15 or int(value) > 900:
				check(false, "soak duration must be an integer from 15 to 900 seconds")
				quit(1)
				return
			soak_seconds = int(value)
	root.size = WINDOW_SIZE
	await _test_main_lifetimes()
	await _test_dimension_lifetimes()
	if soak_seconds > 0 and failures.is_empty():
		await _soak(soak_seconds)
	print("Mosslight runtime stability: %d checks, %d failures (headless; GPU stability untested)" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _settle() -> void:
	# Real frame boundaries drain queue_free, layout and deferred startup work.
	for _frame in range(4):
		await process_frame

func _node_ids(node: Node, skip: Node = null) -> Array[int]:
	var result: Array[int] = []
	if node == skip:
		return result
	result.append(node.get_instance_id())
	for child in node.get_children():
		result.append_array(_node_ids(child, skip))
	return result

func _all_freed(ids: Array[int]) -> bool:
	for id in ids:
		if is_instance_id_valid(id):
			return false
	return true

func _counts() -> Dictionary:
	return {
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"static_bytes": OS.get_static_memory_usage()
	}

func _bounded_counts(current: Dictionary, baseline: Dictionary, label: String) -> void:
	check(current.nodes == baseline.nodes, label + ": exact node count after deferred frees")
	check(current.orphans == baseline.orphans, label + ": no accumulating orphan nodes")
	check(current.objects <= baseline.objects + OBJECT_TOLERANCE, label + ": object count remains within warmed resource allowance")

func _cache_stats(view: Control) -> Dictionary:
	var chunks: Dictionary = view.get("_terrain_chunks")
	var pixels: int = 0
	for chunk in chunks.values():
		var dimensions: Vector2i = chunk.viewport.size
		pixels += dimensions.x * dimensions.y
	var infrastructure: SubViewport = view.get("_infrastructure_viewport")
	pixels += infrastructure.size.x * infrastructure.size.y
	var source: SubViewport = view.get("_terrain_viewport")
	pixels += source.size.x * source.size.y
	var painters: int = 0
	for pair in view.get("_terrain_cells").values():
		painters += pair.size()
	# Two base viewports: the disabled terrain source and infrastructure surface.
	return {"targets": chunks.size() + 2, "pixels": pixels, "painters": painters}

func _check_cache_budget(view: Control, dimensions: Vector2i, label: String) -> void:
	var columns: int = ceili(dimensions.x / 4.0)
	var rows: int = ceili(dimensions.y / 4.0)
	var stats: Dictionary = _cache_stats(view)
	var world_pixels: Vector2i = dimensions * 70
	# Each internal chunk boundary contributes two guard texels on both sides.
	var terrain_pixels: int = (world_pixels.x + (columns - 1) * 4) * (world_pixels.y + (rows - 1) * 4)
	var infrastructure: SubViewport = view.get("_infrastructure_viewport")
	check(stats.targets == columns * rows + 2, label + ": bounded render-target count")
	check(stats.painters == dimensions.x * dimensions.y * 2, label + ": one rock/growth pair per cell")
	var exact_pairs: bool = true
	for pair in view.get("_terrain_cells").values():
		exact_pairs = exact_pairs and pair.size() == 2
	check(exact_pairs, label + ": every retained cell owns exactly two painters")
	check(infrastructure.size == world_pixels, label + ": infrastructure dimensions match the current map")
	# Godot 4.7.2 Viewport::_set_size clamps each dimension with p_size.maxi(2),
	# so the disabled source requested as 1x1 still contributes four pixels.
	check(stats.pixels == terrain_pixels + world_pixels.x * world_pixels.y + 4, label + ": exact bounded cache pixel area including the minimum-size source")
	var target_count: int = 0
	for id in _node_ids(view):
		if instance_from_id(id) is SubViewport:
			target_count += 1
	check(target_count == stats.targets, label + ": no extra target nodes outside the cache registry")
	var source: SubViewport = view.get("_terrain_viewport")
	check(source.size == Vector2i(2, 2), label + ": terrain source stays at Godot's two-pixel minimum dimensions")
	check(source.render_target_update_mode == SubViewport.UPDATE_DISABLED, label + ": full terrain source remains disabled")

func _new_main() -> Control:
	var app: Control = MainScene.instantiate()
	root.add_child(app)
	await _settle()
	return app

func _test_main_lifetimes() -> void:
	var baseline_live: Dictionary = {}
	var baseline_empty: Dictionary = {}
	for cycle in range(MAIN_CYCLES):
		var app: Control = await _new_main()
		var world_id: int = app.world.get_instance_id()
		var title_ids: Array[int] = _node_ids(app._overlay)
		app._controls.start.pressed.emit()
		app._controls.pause.pressed.emit()
		await _settle()
		check(app.started and app.paused and app._overlay_kind == "", "cycle %d starts and pauses through real controls" % cycle)
		check(_all_freed(title_ids), "cycle %d frees the title subtree" % cycle)
		await _exercise_settings(app, cycle)
		# Outcome state is a fixture; the new-colony button and reset path are real.
		app.simulation.status = "lost"
		await _settle()
		check(app._overlay_kind == "outcome", "cycle %d main loop observes the outcome" % cycle)
		var outcome_ids: Array[int] = _node_ids(app._overlay)
		app._controls.restart.pressed.emit()
		app._controls.pause.pressed.emit()
		await _settle()
		check(_all_freed(outcome_ids), "cycle %d frees the outcome subtree on new colony" % cycle)
		check(app.simulation.status == "playing" and app.simulation.elapsed < 0.2 and app.paused, "cycle %d new colony resets simulation through production controls" % cycle)
		check(app.world.get_instance_id() == world_id, "cycle %d scale and new-colony actions preserve exactly one world" % cycle)
		check(app._modal_history.is_empty(), "cycle %d unwinds modal history" % cycle)
		_check_cache_budget(app.world, Vector2i(48, 26), "main cycle %d" % cycle)
		var live: Dictionary = _counts()
		if cycle == WARMUP_CYCLES - 1:
			baseline_live = live
		elif cycle >= WARMUP_CYCLES:
			_bounded_counts(live, baseline_live, "main cycle %d live" % cycle)
		var all_ids: Array[int] = _node_ids(app)
		app.queue_free()
		await _settle()
		check(_all_freed(all_ids), "cycle %d releases every main, world, interface and cache node" % cycle)
		var empty: Dictionary = _counts()
		if cycle == WARMUP_CYCLES - 1:
			baseline_empty = empty
		elif cycle >= WARMUP_CYCLES:
			_bounded_counts(empty, baseline_empty, "main cycle %d freed" % cycle)
		print("STABILITY " + JSON.stringify({"stage": "main_cycle_freed", "cycle": cycle, "counts": empty}))

func _exercise_settings(app: Control, cycle: int) -> void:
	app._controls.menu.pressed.emit()
	await _settle()
	app._controls.settings.pressed.emit()
	await _settle()
	var world_id: int = app.world.get_instance_id()
	var cache_ids: Array[int] = []
	for chunk in app.world.get("_terrain_chunks").values():
		cache_ids.append(chunk.viewport.get_instance_id())
	for percent in [150, 200, 100]:
		var old_ids: Array[int] = _node_ids(app._root_margin, app.world)
		old_ids.append_array(_node_ids(app.world.get_node("WorldUI")))
		old_ids.append_array(_node_ids(app._overlay))
		app._controls["scale_%d" % percent].pressed.emit()
		await _settle()
		check(roundi(app._ui_scale * 100) == percent, "cycle %d applies %d%% through the settings button" % [cycle, percent])
		check(_all_freed(old_ids), "cycle %d scale %d frees replaced interface and overlay subtrees" % [cycle, percent])
		check(app.world.get_instance_id() == world_id, "cycle %d scale %d preserves the world" % [cycle, percent])
		var retained: bool = true
		for id in cache_ids:
			retained = retained and is_instance_id_valid(id)
		check(retained, "cycle %d scale %d reuses every terrain target" % [cycle, percent])
		_check_cache_budget(app.world, Vector2i(48, 26), "scale %d cycle %d" % [percent, cycle])
	var settings_ids: Array[int] = _node_ids(app._overlay)
	app._controls.back_settings.pressed.emit()
	await _settle()
	check(_all_freed(settings_ids) and app._overlay_kind == "menu", "cycle %d Back frees settings and restores the menu" % cycle)
	var menu_ids: Array[int] = _node_ids(app._overlay)
	app._controls.resume.pressed.emit()
	await _settle()
	check(_all_freed(menu_ids) and app._overlay_kind == "", "cycle %d Resume frees the menu" % cycle)

func _set_dimensions(sim: RefCounted, dimensions: Vector2i) -> void:
	sim.width = dimensions.x
	sim.height = dimensions.y
	sim.tiles.clear()
	for y in range(dimensions.y):
		var row: Array = []
		row.resize(dimensions.x)
		row.fill(1)
		sim.tiles.append(row)
	sim.colonists.clear()
	sim.jobs.clear()
	sim.rooms.clear()
	# Vary infrastructure state too, so its production invalidation sees a change.
	# Dimensions do not change in the current game; this fixture tests future resets.
	sim.buildings.clear()
	sim.buildings.append({"cell": Vector2i(dimensions.x - 2, dimensions.y - 2), "kind": "ladder", "active": true})
	sim.elapsed = 0.0

func _terrain_ids(view: Control) -> Array[int]:
	var result: Array[int] = []
	for pair in view.get("_terrain_cells").values():
		for painter in pair:
			result.append(painter.get_instance_id())
	for chunk in view.get("_terrain_chunks").values():
		result.append(chunk.viewport.get_instance_id())
		result.append(chunk.display.get_instance_id())
	return result

func _test_dimension_lifetimes() -> void:
	var sim: RefCounted = Simulation.new()
	_set_dimensions(sim, Vector2i(9, 5))
	var view: Control = WorldView.new()
	view.simulation = sim
	view.size = Vector2(640, 360)
	root.add_child(view)
	await _settle()
	var baseline: Dictionary = {}
	for cycle in range(6):
		for dimensions in [Vector2i(13, 11), Vector2i(9, 5)]:
			var old_ids: Array[int] = _terrain_ids(view)
			_set_dimensions(sim, dimensions)
			view.reset_motion()
			await _settle()
			check(_all_freed(old_ids), "dimension cycle %d %s frees every old terrain painter/target/display" % [cycle, dimensions])
			_check_cache_budget(view, dimensions, "dimension cycle %d %s" % [cycle, dimensions])
		var current: Dictionary = _counts()
		if cycle == 1:
			baseline = current
		elif cycle > 1:
			_bounded_counts(current, baseline, "dimension cycle %d" % cycle)
	var all_ids: Array[int] = _node_ids(view)
	view.queue_free()
	await _settle()
	check(_all_freed(all_ids), "dimension fixture releases every remaining node")

func _soak(seconds: int) -> void:
	var app: Control = await _new_main()
	app._controls.start.pressed.emit()
	await _settle()
	var start_ms: int = Time.get_ticks_msec()
	var start_frames: int = Engine.get_process_frames()
	var baseline: Dictionary = {}
	var next_report_ms: int = 0
	var last: Dictionary = {}
	while Time.get_ticks_msec() - start_ms < seconds * 1000:
		await process_frame
		var elapsed_ms: int = Time.get_ticks_msec() - start_ms
		if baseline.is_empty() and elapsed_ms >= 5000:
			baseline = _counts()
		if elapsed_ms < next_report_ms:
			continue
		next_report_ms = elapsed_ms + 15000
		last = _counts()
		var record: Dictionary = {"stage": "soak", "wall_seconds": elapsed_ms / 1000.0, "frames": Engine.get_process_frames() - start_frames, "simulation_seconds": app.simulation.elapsed, "status": app.simulation.status, "engine_max_fps": Engine.max_fps, "counts": last, "cache": _cache_stats(app.world)}
		print("STABILITY " + JSON.stringify(record))
		if not baseline.is_empty():
			_check_soak_counts(last, baseline)
			if not failures.is_empty():
				break
	last = _counts()
	if not baseline.is_empty():
		_check_soak_counts(last, baseline)
	check(Engine.max_fps == 60, "soak preserves the production frame cap")
	var wall_seconds: float = (Time.get_ticks_msec() - start_ms) / 1000.0
	var frame_count: int = Engine.get_process_frames() - start_frames
	check(frame_count <= ceili(wall_seconds * 63.0) + 2, "wall-clock soak does not run an uncapped or artificially accelerated frame loop")
	check(app.simulation.elapsed >= minf(5.0, wall_seconds * 0.5), "soak exercises the real advancing production simulation")
	check(app.simulation.elapsed <= wall_seconds + 0.5, "soak keeps simulation at ordinary one-times wall-clock speed")
	if app.simulation.status == "playing":
		check(not app.paused and app.simulation.elapsed >= wall_seconds * 0.8, "live soak continues simulating throughout the measurement")
	_check_cache_budget(app.world, Vector2i(48, 26), "soak final")
	print("STABILITY " + JSON.stringify({"stage": "soak_complete", "wall_seconds": wall_seconds, "frames": frame_count, "simulation_seconds": app.simulation.elapsed, "baseline": baseline, "counts": last}))
	var all_ids: Array[int] = _node_ids(app)
	app.queue_free()
	await _settle()
	check(_all_freed(all_ids), "soak releases every owned main/world/interface/cache node")

func _check_soak_counts(current: Dictionary, baseline: Dictionary) -> void:
	check(current.nodes <= baseline.nodes + SOAK_NODE_TOLERANCE, "soak node growth stays within one outcome-overlay allowance")
	check(current.orphans <= baseline.orphans, "soak creates no accumulating orphan nodes")
	check(current.objects <= baseline.objects + SOAK_OBJECT_TOLERANCE, "soak object growth stays within outcome and lazy-resource allowance")
	check(current.static_bytes <= baseline.static_bytes + SOAK_MEMORY_TOLERANCE, "soak tracked static memory stays within an 8 MiB cache/allocation allowance")
