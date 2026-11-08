extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const CENTER := Vector2i(3, 3)
const LOCAL_CELLS: Array[Vector2i] = [CENTER, Vector2i(3, 2), Vector2i(3, 4), Vector2i(2, 3), Vector2i(4, 3)]
var checks: int = 0
var failures: Array[String] = []
var drawn_cells: Dictionary = {}
var viewport_completion_available: bool = true

## Record calls from the real WorldView paint methods without drawing expensive
## geometry. Native rendering acceptance separately checks pixels and frame time.
class ArtTrace extends RefCounted:
	var canvas: CanvasItem
	var rocks: Array[Dictionary] = []
	var grounds: Array[Dictionary] = []
	var ceilings: Array[Vector2i] = []
	func clear() -> void:
		rocks.clear()
		grounds.clear()
		ceilings.clear()
	func rock(cell: Vector2i, _pos: Vector2, _unit: float, kind: int, exposed: Vector4) -> void:
		rocks.append({"cell": cell, "kind": kind, "exposed": exposed})
	func ground_growth(cell: Vector2i, _pos: Vector2, _unit: float, occupied: bool) -> void:
		grounds.append({"cell": cell, "occupied": occupied})
	func ceiling_growth(cell: Vector2i, _pos: Vector2, _unit: float) -> void:
		ceilings.append(cell)
	func visited() -> Dictionary:
		var result: Dictionary = {}
		for entry in rocks:
			result[entry.cell] = true
		for entry in grounds:
			result[entry.cell] = true
		for cell in ceilings:
			result[cell] = true
		return result

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func _run() -> void:
	var legacy_path: String = ""
	var legacy_regional_path: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--legacy-world="):
			legacy_path = argument.trim_prefix("--legacy-world=")
		if argument.begins_with("--legacy-regional-world="):
			legacy_regional_path = argument.trim_prefix("--legacy-regional-world=")
	if not legacy_regional_path.is_empty():
		await _test_legacy_raster_footprint(legacy_regional_path)
	elif legacy_path.is_empty():
		await _probe_viewport_completion()
		await _test_retained_terrain()
		await _test_regional_raster_cache()
	else:
		_test_legacy_footprint(legacy_path)
	var suffix: String = " legacy raster footprint" if not legacy_regional_path.is_empty() else " legacy paint footprint" if not legacy_path.is_empty() else ""
	print("Mosslight terrain cache%s: %d checks, %d failures" % [suffix, checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _configure_fixture(sim: RefCounted, width: int = 7, height: int = 7) -> void:
	sim.width = width
	sim.height = height
	sim.tiles.clear()
	for y in range(height):
		var row: Array = []
		row.resize(width)
		row.fill(1)
		sim.tiles.append(row)
	sim.colonists.clear()
	sim.buildings.clear()
	sim.rooms.clear()
	sim.elapsed = 0.0

func _changed_cells(before: Dictionary, after: Dictionary) -> Dictionary:
	var changed: Dictionary = {}
	for cell in after:
		if not before.has(cell) or before[cell] != after[cell]:
			changed[cell] = true
	for cell in before:
		if not after.has(cell):
			changed[cell] = true
	return changed

func _same_cells(actual: Dictionary, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for cell in expected:
		if not actual.has(cell):
			return false
	return true

func _record_draw(cell: Vector2i) -> void:
	drawn_cells[cell] = true

func _connect_draws(view: Control) -> void:
	for cell in view.get("_terrain_cells"):
		for painter in view.get("_terrain_cells")[cell]:
			var callback: Callable = _record_draw.bind(cell)
			if not painter.draw.is_connected(callback):
				painter.draw.connect(callback)

func _refresh(view: Control, sim: RefCounted, tick: bool = true) -> void:
	if tick:
		sim.elapsed += 0.1
	view.call("_refresh_caches")
	_connect_draws(view)
	await process_frame
	await process_frame
	_acknowledge_rendered_regions(view)

func _probe_viewport_completion() -> void:
	# Godot's headless dummy renderer issues CanvasItem.draw callbacks but does
	# not consume viewport UPDATE_ONCE flags. Probe that independently of WorldView.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(8, 8)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	await process_frame
	await process_frame
	viewport_completion_available = viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED
	print("Terrain cache autonomous viewport completion: %s (display=%s)" % [viewport_completion_available, DisplayServer.get_name()])
	check(viewport_completion_available or DisplayServer.get_name() == "headless", "only the headless dummy renderer may require simulated raster completion")
	viewport.queue_free()
	await process_frame

func _acknowledge_rendered_regions(view: Control) -> void:
	if viewport_completion_available:
		return
	# The tests inspect production requests before this acknowledgement. Only
	# native acceptance can verify actual GPU completion; do not pretend otherwise.
	for chunk in view.get("_terrain_chunks").values():
		if chunk.viewport.render_target_update_mode == SubViewport.UPDATE_ONCE:
			chunk.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _paint_changed(view: Control, trace: ArtTrace, changed: Dictionary) -> void:
	trace.clear()
	# Invoke production cell callbacks in the retained group's real pass order.
	for growth in [false, true]:
		for cell in changed:
			var pair: Array = view.get("_terrain_cells")[cell]
			view.call("_paint_terrain_cell", pair[1 if growth else 0], cell, growth)

func _test_retained_terrain() -> void:
	var sim = Simulation.new()
	_configure_fixture(sim)
	var script: Script = load("res://scripts/world_view.gd")
	var view: Control = script.new()
	view.set("simulation", sim)
	view.size = Vector2(640, 360)
	view.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(view)
	var trace := ArtTrace.new()
	view.set("_terrain_art", trace)
	await _refresh(view, sim, false)
	var cells: Dictionary = view.get("_terrain_cells")
	check(cells.size() == 49, "initial cache has one retained rock/growth pair for every fixture cell")
	check(view.get("_terrain_redraw_count") == 49, "initial cache queues each cell exactly once")
	var rock_group: Node = view.get("_terrain_rock_group")
	var growth_group: Node = view.get("_terrain_growth_group")
	check(rock_group.get_parent() == growth_group.get_parent() and rock_group.get_index() < growth_group.get_index(), "all rock commands precede all growth commands in the retained tree")
	var valid_pairs: bool = true
	var ids: Dictionary = {}
	for cell in cells:
		var pair: Array = cells[cell]
		valid_pairs = valid_pairs and pair.size() == 2 and pair[0].get_parent() == rock_group and pair[1].get_parent() == growth_group
		valid_pairs = valid_pairs and pair[0].cell == cell and pair[1].cell == cell and not pair[0].growth and pair[1].growth
		ids[cell] = [pair[0].get_instance_id(), pair[1].get_instance_id()]
	check(valid_pairs, "every cell pair retains distinct correctly owned rock and growth painters")
	# Regional surfaces replace the former full-size GPU target. The fidelity
	# contract is unchanged: exact complete world-space coverage at 70 px/cell.
	check(_regional_core_pixels(view) == Rect2i(0, 0, 490, 490), "retained regions preserve the complete maximum-zoom world-space surface")
	var draw_signals_available: bool = not drawn_cells.is_empty()
	print("Terrain cache CanvasItem.draw signals available: %s" % draw_signals_available)

	var signatures: Dictionary = view.get("_terrain_signatures").duplicate(true)
	var count: int = view.get("_terrain_redraw_count")
	drawn_cells.clear()
	sim.tiles[CENTER.y][CENTER.x] = 0
	await _refresh(view, sim)
	var changed: Dictionary = _changed_cells(signatures, view.get("_terrain_signatures"))
	check(view.get("_terrain_redraw_count") - count == 5, "one interior excavation queues exactly its cell and four neighbors")
	check(_same_cells(changed, LOCAL_CELLS), "excavation signature changes are confined to the exact local footprint")
	check(view.get("_terrain_signatures")[CENTER] == [0], "excavated air clears both prior terrain passes")
	var current: Dictionary = view.get("_terrain_signatures")
	check(current[Vector2i(3, 2)][2] and current[Vector2i(3, 4)][1], "excavation updates ceiling and floor exposure")
	check(current[Vector2i(2, 3)][4] and current[Vector2i(4, 3)][3], "excavation updates both side-wall exposure keys")
	check(current[Vector2i(2, 2)] == signatures[Vector2i(2, 2)], "diagonal terrain keeps its original exposure signature")
	var retained: bool = true
	for cell in cells:
		retained = retained and ids[cell] == [cells[cell][0].get_instance_id(), cells[cell][1].get_instance_id()]
	check(retained, "excavation reuses all painter identities instead of rebuilding the terrain tree")
	if draw_signals_available:
		check(_same_cells(drawn_cells, LOCAL_CELLS), "actual draw signals regenerate only the five affected cell pairs")
	_paint_changed(view, trace, changed)
	check(trace.rocks.size() == 4 and trace.visited().size() == 4, "production paint callbacks rebuild only the four remaining local rock cells")
	check(trace.grounds.size() == 1 and trace.grounds[0].cell == Vector2i(3, 4) and not trace.grounds[0].occupied, "new exposed floor paints unoccupied growth")
	check(trace.ceilings == [Vector2i(3, 2)], "new exposed ceiling paints its own hanging growth")
	trace.clear()
	view.call("_paint_terrain_cell", cells[CENTER][0], CENTER, false)
	view.call("_paint_terrain_cell", cells[CENTER][1], CENTER, true)
	check(trace.visited().is_empty(), "both air-cell callbacks issue no surviving rock or growth commands")

	count = view.get("_terrain_redraw_count")
	sim.tiles[2][3] = 2
	await _refresh(view, sim)
	check(view.get("_terrain_redraw_count") - count == 1, "changing solid material invalidates only that cell, not its neighbors")
	_paint_changed(view, trace, {Vector2i(3, 2): true})
	check(trace.rocks.size() == 1 and trace.rocks[0].kind == 2 and trace.rocks[0].exposed.y == 1.0, "material repaint uses the new kind and preserved ceiling exposure")

	# Clear a real two-cell bed site before testing footprint growth invalidation.
	sim.tiles[3][4] = 0
	await _refresh(view, sim)
	count = view.get("_terrain_redraw_count")
	sim.buildings.append({"id": 1, "kind": "bed", "cell": CENTER, "active": true})
	await _refresh(view, sim)
	check(view.get("_terrain_redraw_count") - count == 2, "a two-cell bed invalidates both supporting floors and no unrelated cells")
	check(view.get("_terrain_signatures")[Vector2i(3, 4)][5] and view.get("_terrain_signatures")[Vector2i(4, 4)][5], "both supporting floor signatures record their occupied cells above")
	_paint_changed(view, trace, {Vector2i(3, 4): true, Vector2i(4, 4): true})
	check(trace.grounds.size() == 2 and trace.grounds[0].occupied and trace.grounds[1].occupied, "production growth callback suppresses vegetation underneath infrastructure")
	count = view.get("_terrain_redraw_count")
	sim.buildings[0].active = false
	await _refresh(view, sim)
	check(view.get("_terrain_redraw_count") == count, "building activity changes redraw infrastructure without rebuilding terrain")
	sim.buildings.clear()
	await _refresh(view, sim)
	check(view.get("_terrain_redraw_count") - count == 2 and not view.get("_terrain_signatures")[Vector2i(3, 4)][5] and not view.get("_terrain_signatures")[Vector2i(4, 4)][5], "removing infrastructure restores both floor growth signatures")
	_paint_changed(view, trace, {Vector2i(3, 4): true, Vector2i(4, 4): true})
	check(trace.grounds.size() == 2 and not trace.grounds[0].occupied and not trace.grounds[1].occupied, "vacated floor restores ordinary growth through the actual paint callback")

	count = view.get("_terrain_redraw_count")
	drawn_cells.clear()
	await _refresh(view, sim, false)
	await _refresh(view, sim)
	view.call("pan", Vector2(0.2, 0.1))
	await _refresh(view, sim, false)
	view.call("_zoom_at", Vector2(100, 100), 1.2)
	await _refresh(view, sim, false)
	view.size = Vector2(720, 560)
	await _refresh(view, sim, false)
	check(view.get("_terrain_redraw_count") == count, "unchanged frames, unchanged simulation ticks, panning, zooming and resizing reuse terrain commands")
	if draw_signals_available:
		check(drawn_cells.is_empty(), "camera and unchanged-tick paths produce no terrain draw callbacks")

	var old_painter: Node = cells[Vector2i(6, 6)][0]
	_configure_fixture(sim, 9, 5)
	sim.tiles[2][4] = 0
	view.call("reset_motion")
	count = view.get("_terrain_redraw_count")
	await _refresh(view, sim, false)
	check(view.get("_terrain_cells").size() == 45 and view.get("_terrain_signatures").size() == 45, "dimension reset replaces the cell and signature domain")
	check(view.get("_terrain_redraw_count") - count == 45, "dimension reset queues each new cell once")
	check(not is_instance_valid(old_painter), "dimension reset frees painters belonging to the discarded map")
	check(view.get("_terrain_rock_group").get_child_count() == 45 and view.get("_terrain_growth_group").get_child_count() == 45, "reset leaves no old painter children in either pass")
	check(_regional_core_pixels(view) == Rect2i(0, 0, 630, 350), "reset updates the complete regional world-space surface dimensions")
	count = view.get("_terrain_redraw_count")
	sim.tiles[1][1] = 3
	view.call("reset_motion")
	await _refresh(view, sim, false)
	check(view.get("_terrain_redraw_count") - count == 1 and view.get("_terrain_signatures")[Vector2i(1, 1)][0] == 3, "same-clock colony reset cannot reuse a stale terrain hash")
	view.queue_free()
	await process_frame
	await process_frame

func _test_legacy_footprint(path: String) -> void:
	var script: Script = _retained_world_script(path)
	if not script:
		return
	for dimensions in [Vector2i(7, 7), Vector2i(13, 11)]:
		var sim = Simulation.new()
		_configure_fixture(sim, dimensions.x, dimensions.y)
		var view: Control = script.new()
		view.set("simulation", sim)
		var trace := ArtTrace.new()
		view.set("_terrain_art", trace)
		# Invoke the retained production method, not a copied full-map loop.
		view.call("_paint_terrain")
		trace.clear()
		sim.tiles[CENTER.y][CENTER.x] = 0
		view.call("_paint_terrain")
		var visited: Dictionary = trace.visited()
		var unrelated: int = 0
		for cell in visited:
			if not LOCAL_CELLS.has(cell):
				unrelated += 1
		print("Legacy %dx%d excavation: production paint visited %d cells, including %d unrelated cells" % [dimensions.x, dimensions.y, visited.size(), unrelated])
		check(visited.size() <= 5, "legacy %dx%d excavation paint footprint is bounded to five cells" % [dimensions.x, dimensions.y])
		check(unrelated == 0, "legacy %dx%d excavation does not rebuild unrelated terrain" % [dimensions.x, dimensions.y])
		view.free()

func _retained_world_script(path: String) -> Script:
	# Remove only the global registration to load the retained class alongside
	# today's registered WorldView. Every production method body stays unchanged.
	var retained_source: String = FileAccess.get_file_as_string(path)
	var script := GDScript.new()
	script.source_code = retained_source.replace("class_name MosslightWorldView", "")
	if retained_source.is_empty() or script.reload() != OK or not script.can_instantiate():
		check(false, "retained legacy WorldView loads for behavioral comparison")
		return null
	return script

func _regional_core_pixels(view: Control) -> Rect2i:
	var result := Rect2i()
	var first: bool = true
	for chunk in view.get("_terrain_chunks").values():
		var region: Rect2i = chunk.region
		var core := Rect2i(region.position * 70, region.size * 70)
		result = core if first else result.merge(core)
		first = false
	return result

func _pending_chunks(view: Control) -> Dictionary:
	var result: Dictionary = {}
	for key in view.get("_terrain_chunks"):
		if view.get("_terrain_chunks")[key].viewport.render_target_update_mode == SubViewport.UPDATE_ONCE:
			result[key] = true
	return result

func _expected_chunks(view: Control, changed: Array, dimensions: Vector2i) -> Dictionary:
	var result: Dictionary = {}
	var world_bounds := Rect2i(Vector2i.ZERO, dimensions)
	# Rectangle intersection is independent of production's per-tile chunk-key
	# enumeration. It checks the complete side/grass/vine footprint, including edges.
	for cell in changed:
		var footprint := Rect2i(Vector2i(cell) - Vector2i.ONE, Vector2i(3, 4)).intersection(world_bounds)
		for key in view.get("_terrain_chunks"):
			var region: Rect2i = view.get("_terrain_chunks")[key].region
			if region.intersects(footprint):
				result[key] = true
	return result

func _test_regional_raster_cache() -> void:
	var sim = Simulation.new()
	var dimensions := Vector2i(21, 17)
	_configure_fixture(sim, dimensions.x, dimensions.y)
	var script: Script = load("res://scripts/world_view.gd")
	var view: Control = script.new()
	view.set("simulation", sim)
	view.size = Vector2(1280, 800)
	view.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(view)
	view.set("_terrain_art", ArtTrace.new())
	await _refresh(view, sim, false)
	var chunks: Dictionary = view.get("_terrain_chunks")
	var master: SubViewport = view.get("_terrain_viewport")
	check(chunks.size() == 30, "21x17 world is partitioned into thirty bounded regional render targets")
	check(master.render_target_update_mode == SubViewport.UPDATE_DISABLED and not view.get("_terrain_display").visible, "master retains geometry without scheduling or displaying a full-surface raster")
	var shared: bool = true
	var padded: bool = true
	var aligned: bool = true
	var transformed: bool = true
	var coverage: Dictionary = {}
	var core_area: int = 0
	for key in chunks:
		var chunk: Dictionary = chunks[key]
		var region: Rect2i = chunk.region
		var viewport: SubViewport = chunk.viewport
		var display: Node2D = chunk.display
		var texture: AtlasTexture = display.texture
		var pixels := Vector2i(region.size * 70)
		var core := Rect2i(region.position * 70, pixels)
		var world_pixels := Rect2i(Vector2i.ZERO, dimensions * 70)
		var raster := core.grow(2).intersection(world_pixels)
		var crop_origin := Vector2(core.position - raster.position)
		shared = shared and viewport.world_2d == master.world_2d
		padded = padded and chunk.raster == raster and viewport.size == raster.size and texture.region == Rect2(crop_origin, Vector2(pixels)) and not texture.filter_clip
		padded = padded and texture.atlas == viewport.get_texture()
		aligned = aligned and region.position == Vector2i(key) * 4 and region.size.x >= 1 and region.size.x <= 4 and region.size.y >= 1 and region.size.y <= 4
		transformed = transformed and (viewport.canvas_transform * Vector2(core.position)).distance_to(crop_origin) < 0.00001
		core_area += pixels.x * pixels.y
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				var cell := Vector2i(x, y)
				coverage[cell] = int(coverage.get(cell, 0)) + 1
	check(shared, "every regional viewport references the exact shared World2D containing unique terrain painters")
	check(padded, "each atlas preserves a full-resolution core with two interior guard texels and clamped outer world edges")
	check(transformed, "regional canvas transforms map their world-space origin to the padded texture origin")
	check(aligned and core_area == dimensions.x * dimensions.y * 70 * 70, "all regional cores preserve exactly seventy pixels per world tile")
	var exact_coverage: bool = coverage.size() == dimensions.x * dimensions.y
	for cell in coverage:
		exact_coverage = exact_coverage and coverage[cell] == 1 and Rect2i(Vector2i.ZERO, dimensions).has_point(cell)
	check(exact_coverage, "regional cores cover every world cell once with no overlap, gap or out-of-world core")
	check(chunks[Vector2i(5, 4)].region == Rect2i(20, 16, 1, 1) and chunks[Vector2i(5, 4)].viewport.size == Vector2i(72, 72), "bottom-right partial chunk retains its one-cell core with only the two interior filtering borders")
	check(view.get("_terrain_cells").size() == dimensions.x * dimensions.y, "regional rendering shares one unique painter pair per world cell")
	check(view.get("_terrain_chunk_redraw_count") == chunks.size() and _pending_chunks(view).is_empty(), "initial cache requests each region once before raster completion is acknowledged")

	var dig := Vector2i(9, 9)
	var affected: Array = [dig, dig + Vector2i.UP, dig + Vector2i.DOWN, dig + Vector2i.LEFT, dig + Vector2i.RIGHT]
	var chunk_count: int = view.get("_terrain_chunk_redraw_count")
	var cell_count: int = view.get("_terrain_redraw_count")
	sim.tiles[dig.y][dig.x] = 0
	sim.elapsed += 0.1
	view.call("_refresh_caches")
	var pending: Dictionary = _pending_chunks(view)
	var expected: Dictionary = _expected_chunks(view, affected, dimensions)
	check(_same_cells(pending, expected.keys()) and pending.size() == 4, "interior excavation schedules exactly four regions covering all five cells' visual overhangs")
	check(pending.size() < chunks.size() / 2 and view.get("_terrain_chunk_redraw_count") - chunk_count == pending.size(), "local excavation raster work stays bounded below half the larger world")
	var scheduled_pixels: int = 0
	for key in pending:
		var raster_size: Vector2i = chunks[key].viewport.size
		scheduled_pixels += raster_size.x * raster_size.y
	var world_pixels: int = dimensions.x * dimensions.y * 70 * 70
	print("Regional %dx%d interior dig schedules %d/%d regions and %d raster pixels out of %d world pixels" % [dimensions.x, dimensions.y, pending.size(), chunks.size(), scheduled_pixels, world_pixels])
	check(scheduled_pixels > 0 and scheduled_pixels < world_pixels / 2, "actual scheduled regional raster area including filtering guards stays below half the full-world surface")
	check(view.get("_terrain_redraw_count") - cell_count == 5, "regional rasterization retains the five-cell CPU command invalidation bound")
	check(pending.has(Vector2i(2, 3)), "ceiling-vine overhang invalidates the region beyond the changed cells' own regions")
	check(master.render_target_update_mode == SubViewport.UPDATE_DISABLED, "excavation never re-enables the full master raster target")
	await process_frame
	await process_frame
	_acknowledge_rendered_regions(view)
	check(_pending_chunks(view).is_empty(), "local raster requests clear after completion without continuous updates")

	chunk_count = view.get("_terrain_chunk_redraw_count")
	view.call("pan", Vector2(1, -1))
	await _refresh(view, sim, false)
	view.call("_zoom_at", Vector2(250, 200), 1.2)
	await _refresh(view, sim, false)
	view.size = Vector2(720, 560)
	await _refresh(view, sim, false)
	await _refresh(view, sim)
	check(view.get("_terrain_chunk_redraw_count") == chunk_count and _pending_chunks(view).is_empty(), "pan, zoom, resize and unchanged simulation ticks transform regional displays without rerasterizing")
	var display_alignment: bool = true
	var unit: float = 28.0 * float(view.get("zoom_level"))
	for chunk in chunks.values():
		var region: Rect2i = chunk.region
		var expected_position: Vector2 = Vector2(region.position) * unit
		display_alignment = display_alignment and Vector2(chunk.display.position).distance_to(expected_position) < 0.0001 and Vector2(chunk.display.draw_size).distance_to(Vector2(region.size) * unit) < 0.0001
	display_alignment = display_alignment and Vector2(view.get("_terrain_surface").position).distance_to(view.size * 0.5 - Vector2(view.get("camera")) * unit) < 0.0001
	check(display_alignment, "transformed displays keep their region cores aligned at the selected camera and zoom")
	for zoom in [0.55, 0.85, 1.12, 2.5]:
		view.set("zoom_level", zoom)
		view.set("camera", Vector2(10.37, 8.19))
		await _refresh(view, sim, false)
		var adjoining: bool = true
		for key in chunks:
			var display: CanvasItem = chunks[key].display
			adjoining = adjoining and not display is Control and display.get_parent() == view.get("_terrain_surface")
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				if not chunks.has(key + direction):
					continue
				var neighbor: Node2D = chunks[key + direction].display
				var end: Vector2 = display.position + display.draw_size * Vector2(direction)
				var distance: float = absf(end.x - neighbor.position.x) if direction == Vector2i.RIGHT else absf(end.y - neighbor.position.y)
				adjoining = adjoining and distance < 0.0001
		check(adjoining, "zoom %.2f keeps adjacent region edges coincident under one shared origin without independent Control snapping" % zoom)
	check(view.get("_terrain_chunk_redraw_count") == chunk_count and _pending_chunks(view).is_empty(), "fractional zoom transforms preserve all cached raster targets")

	var edge := Vector2i(20, 16)
	sim.tiles[edge.y][edge.x] = 0
	sim.elapsed += 0.1
	view.call("_refresh_caches")
	var edge_affected: Array = [edge, edge + Vector2i.UP, edge + Vector2i.LEFT]
	check(_same_cells(_pending_chunks(view), _expected_chunks(view, edge_affected, dimensions).keys()), "edge excavation clips visual footprints to valid full and partial regions")
	await process_frame
	await process_frame
	_acknowledge_rendered_regions(view)
	var old_viewport: Node = chunks[Vector2i(5, 4)].viewport
	var old_display: Node = chunks[Vector2i(5, 4)].display
	_configure_fixture(sim, 9, 5)
	view.call("reset_motion")
	await _refresh(view, sim, false)
	check(view.get("_terrain_chunks").size() == 6, "dimension reset rebuilds exactly the new region domain")
	check(not is_instance_valid(old_viewport) and not is_instance_valid(old_display), "dimension reset releases old regional viewports and texture displays")
	check(_regional_core_pixels(view) == Rect2i(0, 0, 630, 350) and master.render_target_update_mode == SubViewport.UPDATE_DISABLED, "reset preserves complete regional coverage while the master stays disabled")
	view.queue_free()
	await process_frame
	await process_frame

func _test_legacy_raster_footprint(path: String) -> void:
	var script: Script = _retained_world_script(path)
	if not script:
		return
	for dimensions in [Vector2i(21, 17), Vector2i(29, 21)]:
		var sim = Simulation.new()
		_configure_fixture(sim, dimensions.x, dimensions.y)
		var view: Control = script.new()
		view.set("simulation", sim)
		view.size = Vector2(1280, 800)
		view.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(view)
		view.set("_terrain_art", ArtTrace.new())
		await _refresh(view, sim, false)
		var master: SubViewport = view.get("_terrain_viewport")
		# Acknowledge the initial surface explicitly so a dummy-renderer pending
		# flag cannot masquerade as a fresh excavation request in this red proof.
		master.render_target_update_mode = SubViewport.UPDATE_DISABLED
		sim.tiles[9][9] = 0
		sim.elapsed += 0.1
		view.call("_refresh_caches")
		var pixels: int = master.size.x * master.size.y if master.render_target_update_mode == SubViewport.UPDATE_ONCE else 0
		var entire_world: int = dimensions.x * dimensions.y * 70 * 70
		print("Legacy %dx%d interior dig schedules %d raster pixels out of %d world pixels" % [dimensions.x, dimensions.y, pixels, entire_world])
		check(master.render_target_update_mode == SubViewport.UPDATE_DISABLED, "legacy interior dig does not schedule the full master viewport")
		check(pixels < entire_world / 2, "legacy interior dig raster footprint stays below half the larger world")
		view.queue_free()
		await process_frame
		await process_frame
