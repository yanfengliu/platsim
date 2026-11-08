extends Control
class_name MosslightWorldView

class PaintLayer extends Control:
	var owner_view: Control
	var kind: String
	func _draw() -> void:
		owner_view._paint_layer(kind, self)

class TerrainCell extends Node2D:
	var owner_view: Control
	var cell: Vector2i
	var growth := false
	func _draw() -> void:
		owner_view._paint_terrain_cell(self, cell, growth)

class TerrainPatch extends Node2D:
	var texture: Texture2D
	var draw_size := Vector2.ZERO
	func _draw() -> void:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, draw_size), false)

signal cell_activated(cell: Vector2i)
signal cell_hovered(cell: Vector2i)
signal cancel_requested

const TILE := 28.0
const MAX_ZOOM := 2.5
const CACHE_TILE := TILE * MAX_ZOOM
const TERRAIN_CHUNK := 4
const CACHE_PADDING := 2
const INK := Color("101524")
const MINT := Color("7fe0b0")
const GOLD := Color("e8bb73")
const CaveArt = preload("res://scripts/cave_art.gd")
const PresentationMotion = preload("res://scripts/presentation_motion.gd")
const PixelAssets = preload("res://scripts/pixel_assets.gd")
const BUILDING_KINDS := ["bed", "farm", "airfern", "lamp", "generator", "cistern", "beacon"]
var _backdrop: Texture2D
var simulation: RefCounted
var camera := Vector2(18.0, 13.5)
var zoom_level := 1.0
var selected_tool := "inspect"
var cursor := Vector2i(19, 16)
var show_air := false
var keyboard_cursor := false
var interactive := false
var reduced_motion := false
var simulation_paused := false
var _dragging := false
var _dig_drag := false
var _dig_view_rect := Rect2()
var _last_drag_cell := Vector2i(-1, -1)
var _clock := 0.0
var _motion := PresentationMotion.new()
var _font: Font
var _terrain_art: RefCounted
var _terrain_cells := {}
var _terrain_signatures := {}
var _terrain_redraw_count := 0
var _terrain_rock_group: Node2D
var _terrain_growth_group: Node2D
var _terrain_dimensions := Vector2i.ZERO
var _terrain_occupied := {}
var _terrain_chunks := {}
var _terrain_chunk_redraw_count := 0
var _terrain_surface: Control
var _infrastructure_art: RefCounted
var _dynamic_art: RefCounted
var _terrain_viewport: SubViewport
var _infrastructure_viewport: SubViewport
var _terrain_painter: PaintLayer
var _infrastructure_painter: PaintLayer
var _terrain_display: TextureRect
var _infrastructure_display: TextureRect
var _air_layer: PaintLayer
var _dynamic_layer: PaintLayer
var _cached_camera := Vector2.INF
var _cached_zoom := -1.0
var _cached_size := Vector2.ZERO
var _cached_terrain_hash := -1
var _cached_infrastructure_hash := -1
var _observed_time := -1.0
var _terrain_hash := 0
var _infrastructure_hash := 0
var _facing := {}
var _last_positions := {}

func _ready() -> void:
	_backdrop = PixelAssets.backdrop()
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var terrain := _make_cache("terrain")
	_terrain_viewport = terrain.viewport
	_terrain_painter = terrain.painter
	_terrain_display = terrain.display
	_terrain_art = CaveArt.new(_terrain_painter)
	_terrain_display.visible = false
	_terrain_surface = Control.new()
	_terrain_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_terrain_surface)
	_terrain_rock_group = Node2D.new()
	_terrain_growth_group = Node2D.new()
	_terrain_painter.add_child(_terrain_rock_group)
	_terrain_painter.add_child(_terrain_growth_group)
	_air_layer = _make_painter("air", self)
	var infrastructure := _make_cache("infrastructure")
	_infrastructure_viewport = infrastructure.viewport
	_infrastructure_painter = infrastructure.painter
	_infrastructure_display = infrastructure.display
	_infrastructure_art = CaveArt.new(_infrastructure_painter)
	_dynamic_layer = _make_painter("dynamic", self)
	_dynamic_art = CaveArt.new(_dynamic_layer)
	reset_motion()

func _process(_delta: float) -> void:
	_stabilize_dig_view()
	_refresh_caches()
	_air_layer.queue_redraw()
	_dynamic_layer.queue_redraw()

func reset_motion() -> void:
	if simulation:
		_motion.reset(simulation.colonists, simulation.jobs)
	# A reset may reuse the same elapsed time with different terrain.
	_observed_time = -1.0
	_clock = 0.0
	_last_positions.clear()
	_facing.clear()

func begin_simulation_step() -> void:
	_motion.begin_step(simulation.colonists, simulation.jobs)

func end_simulation_step() -> void:
	_motion.end_step(simulation.colonists, simulation.jobs)

func present_frame(alpha: float, delta: float, simulation_speed: float, running: bool) -> void:
	_motion.present(alpha, delta, simulation_speed, running, reduced_motion)
	if running and not reduced_motion:
		_clock += delta * simulation_speed

func _make_painter(kind: String, parent_node: Node) -> PaintLayer:
	var painter := PaintLayer.new()
	painter.kind = kind
	painter.owner_view = self
	painter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent_node.add_child(painter)
	return painter

func _make_cache(kind: String) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = kind.capitalize() + "Cache"
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.size = Vector2i.ONE
	if kind == "terrain":
		viewport.world_2d = World2D.new()
	add_child(viewport)
	var painter := _make_painter(kind, viewport)
	var display := TextureRect.new()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.name = kind.capitalize() + "Surface"
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	# Transparent viewport textures contain premultiplied RGB. Preserve the alpha of cached pixel silhouettes.
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	display.material = blend
	add_child(display)
	return {"viewport": viewport, "painter": painter, "display": display}

func _refresh_caches() -> void:
	if not simulation or size.x < 1 or size.y < 1:
		return
	# Native Array hashing avoids rebuilding any geometry while the simulation is unchanged.
	# Only occupied cells affect surface growth; active state affects infrastructure lighting.
	if simulation.elapsed != _observed_time:
		_observed_time = simulation.elapsed
		var occupied := []
		var infrastructure := []
		for building in simulation.buildings:
			var footprint: Rect2i = simulation.building_rect(building.kind, building.cell)
			for y in range(footprint.position.y, footprint.end.y):
				for x in range(footprint.position.x, footprint.end.x):
					occupied.append(Vector2i(x, y))
			infrastructure.append([building.cell, building.kind, building.get("active", true)])
		_terrain_hash = hash([simulation.tiles, occupied])
		_infrastructure_hash = hash(infrastructure)
	var view_changed := camera != _cached_camera or zoom_level != _cached_zoom or size != _cached_size
	# Render in world space at the maximum supported zoom. Panning, zooming and
	# resizing only transform these textures; even the closest view loses no detail.
	var pixel_size := Vector2i(ceili(simulation.width * CACHE_TILE), ceili(simulation.height * CACHE_TILE))
	if _terrain_hash != _cached_terrain_hash:
		_terrain_painter.size = Vector2(pixel_size)
		_refresh_terrain_cells()
		_cached_terrain_hash = _terrain_hash
	if _infrastructure_hash != _cached_infrastructure_hash:
		_infrastructure_viewport.size = pixel_size
		_infrastructure_painter.size = Vector2(pixel_size)
		_infrastructure_painter.queue_redraw()
		_infrastructure_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_cached_infrastructure_hash = _infrastructure_hash
	if view_changed:
		var unit := TILE * zoom_level
		_infrastructure_display.position = size * 0.5 - camera * unit
		_infrastructure_display.size = Vector2(simulation.width, simulation.height) * unit
		_position_terrain_chunks()
		queue_redraw()
	_cached_camera = camera
	_cached_zoom = zoom_level
	_cached_size = size

func _paint_layer(kind: String, surface: CanvasItem) -> void:
	if not simulation:
		return
	match kind:
		"terrain": pass # Per-cell draw lists are retained below this layer.
		"infrastructure": _paint_infrastructure(surface)
		"air": _paint_air(surface)
		"dynamic": _paint_dynamic(surface)

func cell_screen(cell: Vector2) -> Vector2:
	return (cell + Vector2(0.5, 0.5) - camera) * TILE * zoom_level + size * 0.5

func screen_cell(point: Vector2) -> Vector2i:
	var tile := (point - size * 0.5) / (TILE * zoom_level) + camera
	return Vector2i(floori(tile.x), floori(tile.y))

func fit_colony() -> void:
	if size.x >= 800 and size.y >= 420:
		camera = Vector2(18.0, 13.5)
		zoom_level = clampf(minf(size.x / (30.0 * TILE), size.y / (20.0 * TILE)), 0.8, 1.8)
	else:
		# Compact screens focus on the active terrace; pan to the roost or quarry.
		camera = Vector2(22.0, 15.0)
		zoom_level = clampf(size.x / ((24.0 if size.x >= 600 else 12.0) * TILE), 0.85, 1.5)
	queue_redraw()

func pan(direction: Vector2) -> void:
	camera += direction
	_clamp_camera()

func move_cursor(direction: Vector2i) -> void:
	if not simulation:
		return
	keyboard_cursor = true
	cursor = Vector2i(clampi(cursor.x + direction.x, 0, simulation.width - 1), clampi(cursor.y + direction.y, 0, simulation.height - 1))
	var point := cell_screen(Vector2(cursor))
	if point.x < 40 or point.x > size.x - 40 or point.y < 40 or point.y > size.y - 40:
		camera = Vector2(cursor) + Vector2(0.5, 0.5)
	cell_hovered.emit(cursor)

func _clamp_camera() -> void:
	if simulation:
		camera.x = clampf(camera.x, 0, simulation.width)
		camera.y = clampf(camera.y, 0, simulation.height)

func clear_pointer_state() -> void:
	_dragging = false
	_dig_drag = false
	_last_drag_cell = Vector2i(-1, -1)

func _stabilize_dig_view() -> void:
	if not _dig_drag:
		return
	var current_rect := get_global_rect()
	if current_rect != _dig_view_rect:
		# Feedback may wrap during a stroke. Keep every world point at its screen
		# position even when the surrounding containers change the viewport bounds.
		camera += (current_rect.get_center() - _dig_view_rect.get_center()) / (TILE * zoom_level)
		_dig_view_rect = current_rect

func _gui_input(event: InputEvent) -> void:
	_stabilize_dig_view()
	# Releases always clear their latch, including when a modal suspends interaction.
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dig_drag = false
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = false
	if not interactive:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_requested.emit()
			_dig_drag = false
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.12)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 1.0 / 1.12)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dig_drag = event.pressed and selected_tool == "dig"
			if _dig_drag:
				_dig_view_rect = get_global_rect()
			if event.pressed:
				grab_focus()
				keyboard_cursor = false
				cursor = _inspect_cell(event.position) if selected_tool == "inspect" else screen_cell(event.position)
				_last_drag_cell = cursor
				cell_activated.emit(cursor)
			accept_event()
	elif event is InputEventMouseMotion:
		if _dragging:
			camera -= event.relative / (TILE * zoom_level)
			_clamp_camera()
		else:
			cursor = _inspect_cell(event.position) if selected_tool == "inspect" else screen_cell(event.position)
			keyboard_cursor = false
			cell_hovered.emit(cursor)
			if _dig_drag and cursor != _last_drag_cell:
				_last_drag_cell = cursor
				cell_activated.emit(cursor)

func _zoom_at(point: Vector2, factor: float) -> void:
	var before := (point - size * 0.5) / (TILE * zoom_level) + camera
	zoom_level = clampf(zoom_level * factor, 0.45, MAX_ZOOM)
	camera = before - (point - size * 0.5) / (TILE * zoom_level)
	_clamp_camera()

func _inspect_cell(point: Vector2) -> Vector2i:
	# Pixel heads and machinery extend above their logical cells. Inspection
	# follows visible silhouettes; construction and excavation retain exact tile targeting.
	var unit := TILE * zoom_level
	for index in range(simulation.colonists.size() - 1, -1, -1):
		var colonist: Dictionary = simulation.colonists[index]
		var pos := cell_screen(Vector2(_motion.pose(colonist).pos)) - Vector2.ONE * unit * 0.5
		var bounds := Rect2(pos + Vector2(-0.03, -0.59) * unit, Vector2(1.25, 1.65) * unit)
		if bounds.has_point(point):
			return Vector2i(Vector2(colonist.pos).floor())
	for index in range(simulation.buildings.size() - 1, -1, -1):
		var building: Dictionary = simulation.buildings[index]
		var pos := cell_screen(Vector2(building.cell)) - Vector2.ONE * unit * 0.5
		if _building_rect(pos, unit, building.kind).has_point(point):
			return building.cell
	return screen_cell(point)

func _building_rect(pos: Vector2, unit: float, kind: String) -> Rect2:
	if not BUILDING_KINDS.has(kind):
		return Rect2(pos, Vector2.ONE * unit)
	var source_size := Vector2(PixelAssets.building_size(kind))
	var footprint_size := Vector2(simulation.building_size(kind))
	var scale_value := minf(footprint_size.x * unit / source_size.x, footprint_size.y * unit / source_size.y)
	var draw_size := source_size * scale_value
	var footing := pos + Vector2(footprint_size.x * 0.5, 1.0) * unit
	return Rect2(footing - Vector2(draw_size.x * 0.5, draw_size.y), draw_size)

func _footprint_screen(kind: String, anchor: Vector2i) -> Rect2:
	var area: Rect2i = simulation.building_rect(kind, anchor)
	var unit := TILE * zoom_level
	return Rect2(cell_screen(Vector2(area.position)) - Vector2.ONE * unit * 0.5, Vector2(area.size) * unit)

func _footprint_marks(surface: CanvasItem, bounds: Rect2, color: Color, fill: bool = true) -> void:
	var unit := TILE * zoom_level
	if fill:
		for y in range(roundi(bounds.size.y / unit)):
			for x in range(roundi(bounds.size.x / unit)):
				surface.draw_rect(Rect2(bounds.position + Vector2(x, y) * unit + Vector2.ONE, Vector2.ONE * (unit - 2.0)), Color(color, 0.12))
	var length := minf(unit * 0.3, minf(bounds.size.x, bounds.size.y) * 0.3)
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var point: Vector2 = bounds.position + bounds.size * corner
		var inward: Vector2 = Vector2.ONE - corner * 2.0
		surface.draw_line(point, point + Vector2(inward.x * length, 0), color, 2.0)
		surface.draw_line(point, point + Vector2(0, inward.y * length), color, 2.0)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	if not simulation:
		return
	var scale_value := maxf(size.x / _backdrop.get_width(), size.y / _backdrop.get_height()) * 1.1
	var backdrop_size := Vector2(_backdrop.get_size()) * scale_value
	var parallax := Vector2((camera.x - 18.0) * -1.6, (camera.y - 13.5) * -1.1)
	draw_texture_rect(_backdrop, Rect2((size - backdrop_size) * 0.5 + parallax, backdrop_size), false)


func _refresh_terrain_cells() -> void:
	var dimensions := Vector2i(simulation.width, simulation.height)
	if dimensions != _terrain_dimensions:
		for pair in _terrain_cells.values():
			for painter in pair:
				painter.get_parent().remove_child(painter)
				painter.queue_free()
		_terrain_cells.clear()
		_terrain_signatures.clear()
		_terrain_dimensions = dimensions
		_rebuild_terrain_chunks(dimensions)
	_terrain_occupied.clear()
	for building in simulation.buildings:
		var footprint: Rect2i = simulation.building_rect(building.kind, building.cell)
		for y in range(footprint.position.y, footprint.end.y):
			for x in range(footprint.position.x, footprint.end.x):
				_terrain_occupied[Vector2i(x, y)] = true
	var dirty_chunks := {}
	# Keep Godot's retained drawing commands for unchanged cells. Rebuilding the
	# complete cave's vector art on every dig used to stall the main thread.
	for y in range(simulation.height):
		for x in range(simulation.width):
			var cell := Vector2i(x, y)
			if not _terrain_cells.has(cell):
				var pair := []
				for growth in [false, true]:
					var painter := TerrainCell.new()
					painter.owner_view = self
					painter.cell = cell
					painter.growth = growth
					(_terrain_growth_group if growth else _terrain_rock_group).add_child(painter)
					pair.append(painter)
				_terrain_cells[cell] = pair
			var kind: int = simulation.tiles[y][x]
			var signature := [kind, _open(cell + Vector2i.UP), _open(cell + Vector2i.DOWN), _open(cell + Vector2i.LEFT), _open(cell + Vector2i.RIGHT), _terrain_occupied.has(cell + Vector2i.UP)] if kind > 0 else [0]
			if _terrain_signatures.get(cell) != signature:
				_terrain_signatures[cell] = signature
				_terrain_redraw_count += 1
				for painter in _terrain_cells[cell]:
					painter.queue_redraw()
				# Include the complete art footprint: grass above, side outlines,
				# and ceiling vines reaching more than two cells below their anchor.
				for affected_y in range(cell.y - 1, cell.y + 3):
					for affected_x in range(cell.x - 1, cell.x + 2):
						if affected_x >= 0 and affected_y >= 0 and affected_x < dimensions.x and affected_y < dimensions.y:
							var key := Vector2i(affected_x / TERRAIN_CHUNK, affected_y / TERRAIN_CHUNK)
							dirty_chunks[key] = true
	for key in dirty_chunks:
		_terrain_chunks[key].viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_terrain_chunk_redraw_count += 1

func _rebuild_terrain_chunks(dimensions: Vector2i) -> void:
	for chunk in _terrain_chunks.values():
		for node in [chunk.display, chunk.viewport]:
			node.get_parent().remove_child(node)
			node.queue_free()
	_terrain_chunks.clear()
	for y in range(0, dimensions.y, TERRAIN_CHUNK):
		for x in range(0, dimensions.x, TERRAIN_CHUNK):
			var region := Rect2i(x, y, mini(TERRAIN_CHUNK, dimensions.x - x), mini(TERRAIN_CHUNK, dimensions.y - y))
			var viewport := SubViewport.new()
			viewport.disable_3d = true
			viewport.transparent_bg = true
			viewport.handle_input_locally = false
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			# Share retained geometry, but rasterize only the changed small regions.
			viewport.world_2d = _terrain_viewport.world_2d
			var pixels := Vector2i(Vector2(region.size) * CACHE_TILE)
			var core := Rect2i(Vector2i(Vector2(region.position) * CACHE_TILE), pixels)
			var bounds := Rect2i(Vector2i.ZERO, Vector2i(Vector2(dimensions) * CACHE_TILE))
			var raster := core.grow(CACHE_PADDING).intersection(bounds)
			viewport.size = raster.size
			_terrain_surface.add_child(viewport)
			# Entering the tree attaches the shared canvas before its transform is set.
			viewport.canvas_transform = Transform2D(0.0, -Vector2(raster.position))
			var texture := AtlasTexture.new()
			texture.atlas = viewport.get_texture()
			texture.region = Rect2(Vector2(core.position - raster.position), Vector2(pixels))
			# The surrounding texel preserves complete pixel coverage at region edges.
			# Outer map edges keep the original full texture's clamped sampling.
			texture.filter_clip = false
			var display := TerrainPatch.new()
			display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			display.texture = texture
			display.material = _terrain_display.material
			_terrain_surface.add_child(display)
			_terrain_chunks[Vector2i(x / TERRAIN_CHUNK, y / TERRAIN_CHUNK)] = {"viewport": viewport, "display": display, "region": region, "raster": raster}
	_position_terrain_chunks()

func _position_terrain_chunks() -> void:
	var unit := TILE * zoom_level
	# Snap the common origin once, as the original full texture did. Individual
	# patches are Node2Ds so GUI Control snapping cannot open fractional-zoom gaps.
	_terrain_surface.position = size * 0.5 - camera * unit
	for chunk in _terrain_chunks.values():
		chunk.display.position = Vector2(chunk.region.position) * unit
		chunk.display.draw_size = Vector2(chunk.region.size) * unit
		chunk.display.queue_redraw()

func _paint_terrain_cell(surface: CanvasItem, cell: Vector2i, growth: bool) -> void:
	var kind: int = simulation.tiles[cell.y][cell.x]
	if kind == 0:
		return
	var unit := CACHE_TILE
	var pos := Vector2(cell) * unit
	_terrain_art.canvas = surface
	if not growth:
		var exposed := Vector4(float(_open(cell + Vector2i.UP)), float(_open(cell + Vector2i.DOWN)), float(_open(cell + Vector2i.LEFT)), float(_open(cell + Vector2i.RIGHT)))
		_terrain_art.rock(cell, pos, unit, kind, exposed)
	else:
		# Separate parent groups preserve all-rocks-before-all-growth ordering,
		# including vines that extend across cell boundaries.
		if _open(cell + Vector2i.UP):
			_terrain_art.ground_growth(cell, pos, unit, _terrain_occupied.has(cell + Vector2i.UP))
		if _open(cell + Vector2i.DOWN):
			_terrain_art.ceiling_growth(cell, pos, unit)

func _paint_air(surface: CanvasItem) -> void:
	var unit := TILE * zoom_level
	if show_air:
		for room in simulation.rooms:
			var air: float = room.get("air", 100.0)
			var color := Color("72dba6") if air > 50 else Color("e9ac59") if air > 25 else Color("df715d")
			color.a = 0.13
			for cell in room.get("cells", []):
				var center := cell_screen(Vector2(cell))
				if center.x > -unit and center.x < size.x + unit and center.y > -unit and center.y < size.y + unit:
					surface.draw_rect(Rect2(center - Vector2.ONE * unit * 0.5, Vector2.ONE * unit), color)

func _paint_infrastructure(surface: CanvasItem) -> void:
	var unit := CACHE_TILE
	for building in simulation.buildings:
		if building.kind in ["lamp", "beacon", "airfern"] and building.get("active", false):
			var bounds := _building_rect(Vector2(building.cell) * unit, unit, building.kind)
			_draw_glow(surface, bounds.position + bounds.size * Vector2(0.5, 0.35), unit, building.kind)
	for building in simulation.buildings:
		_draw_building(surface, _infrastructure_art, Vector2(building.cell) * unit, unit, building.kind, building.get("active", true), false)

func _paint_dynamic(surface: CanvasItem) -> void:
	var unit := TILE * zoom_level
	for job in simulation.jobs:
		var center := cell_screen(Vector2(job.cell))
		var color := GOLD if job.kind == "dig" else MINT
		var bounds := Rect2(center - Vector2.ONE * unit * 0.5, Vector2.ONE * unit) if job.kind == "dig" else _footprint_screen(job.building_kind, job.cell)
		_footprint_marks(surface, bounds.grow(-1), color)
		if job.kind == "dig":
			surface.draw_line(center - Vector2.ONE * unit * 0.15, center + Vector2.ONE * unit * 0.15, color, 1.5, false)
			surface.draw_line(center + Vector2(-1, 1) * unit * 0.15, center + Vector2(1, -1) * unit * 0.15, color, 1.5, false)
		else:
			_draw_building(surface, _dynamic_art, center - Vector2.ONE * unit * 0.5, unit, job.building_kind, false, true)
		if job.get("progress", 0.0) > 0:
			surface.draw_rect(Rect2(bounds.position + Vector2(2, bounds.size.y - 4), Vector2((bounds.size.x - 4) * job.progress, 2)), color)
	for colonist in simulation.colonists:
		_draw_colonist(surface, colonist, unit)
	# A bounded set of dust motes sits in the light, below control overlays.
	for index in range(32):
		var world_pos := Vector2(5.0 + fmod(index * 3.71, 29.0), 4.0 + fmod(index * 2.27 + _clock * 0.025, 19.0))
		if _open(Vector2i(world_pos.floor())):
			var point := cell_screen(world_pos)
			surface.draw_rect(Rect2(point, Vector2.ONE * (1 + index % 2)), Color(0.65, 0.88, 0.8, 0.2 + sin(_clock * 0.7 + index) * 0.06))
	if interactive and cursor.x >= 0 and cursor.y >= 0 and cursor.x < simulation.width and cursor.y < simulation.height:
		var center := cell_screen(Vector2(cursor))
		var color := MINT
		var bounds := Rect2(center - Vector2.ONE * unit * 0.5, Vector2.ONE * unit)
		var construction := selected_tool not in ["inspect", "dig", "cancel"]
		if selected_tool == "dig":
			color = GOLD
		elif selected_tool == "cancel":
			color = Color("efb08a")
			var job: Dictionary = simulation.job_at(cursor)
			if not job.is_empty() and job.kind == "build":
				bounds = _footprint_screen(job.building_kind, job.cell)
		elif construction:
			bounds = _footprint_screen(selected_tool, cursor)
			if simulation.can_build(selected_tool, cursor) != "":
				color = Color("ef8c82")
			_draw_building(surface, _dynamic_art, center - Vector2.ONE * unit * 0.5, unit, selected_tool, false, true)
		else:
			var building: Dictionary = simulation.building_at(cursor)
			if not building.is_empty():
				bounds = _footprint_screen(building.kind, building.cell)
		_footprint_marks(surface, bounds, color)
		var label := "ENTER" if keyboard_cursor else ""
		if construction:
			var dimensions: Vector2i = simulation.building_size(selected_tool)
			label += " %d x %d" % [dimensions.x, dimensions.y]
		if not label.is_empty():
			surface.draw_string(_font, bounds.position + Vector2(2, -5), label.strip_edges(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
	if simulation.get("landmarks") is Array:
		for landmark in simulation.landmarks:
			var point := cell_screen(Vector2(landmark.cell))
			if point.x > 25 and point.x < size.x - 150 and point.y > 25 and point.y < size.y - 20:
				surface.draw_string(_font, point, str(landmark.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.88, 0.68, 0.6))

func _open(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < simulation.width and cell.y < simulation.height and simulation.tiles[cell.y][cell.x] == 0

func _corner_marks(surface: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	for side in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var corner: Vector2 = center + side * radius
		surface.draw_line(corner, corner - Vector2(side.x * radius * 0.36, 0), color, 1.5, false)
		surface.draw_line(corner, corner - Vector2(0, side.y * radius * 0.36), color, 1.5, false)

func _draw_glow(surface: CanvasItem, center: Vector2, unit: float, kind: String) -> void:
	var color := Color("edb96e") if kind == "lamp" else Color("82d9c1")
	# Three stepped halos complement sprites without a smooth painted aura.
	for index in range(3, 0, -1):
		var extent := unit * (0.5 + index * 0.55)
		var tint := Color(color, 0.025)
		surface.draw_rect(Rect2(center - Vector2(extent, extent * 0.6), Vector2(extent * 2, extent * 1.2)), tint)
		surface.draw_rect(Rect2(center - Vector2(extent * 0.65, extent), Vector2(extent * 1.3, extent * 2)), tint)

func _draw_building(surface: CanvasItem, art: RefCounted, pos: Vector2, unit: float, kind: String, active: bool, ghost: bool) -> void:
	if kind == "ladder":
		art.ladder(pos, unit)
		return
	if not BUILDING_KINDS.has(kind):
		return
	var texture: Texture2D = PixelAssets.building(kind)
	var bounds := _building_rect(pos, unit, kind)
	var footing := Vector2(bounds.get_center().x, pos.y + unit)
	var tint := Color(1, 1, 1, 0.38) if ghost else Color.WHITE if active or kind == "bed" else Color(0.7, 0.78, 0.72, 1)
	if not ghost:
		art.ellipse(footing + Vector2(0, -unit * 0.04), Vector2(bounds.size.x * 0.44, unit * 0.07), Color(0.025, 0.07, 0.06, 0.48))
	surface.draw_texture_rect(texture, bounds, false, tint)
	if not active and not ghost and kind != "bed":
		surface.draw_rect(Rect2(bounds.position + Vector2(bounds.size.x - unit * 0.16, 0), Vector2.ONE * unit * 0.16), Color("edbb7e"))
		surface.draw_rect(Rect2(bounds.position + Vector2(bounds.size.x - unit * 0.11, unit * 0.05), Vector2.ONE * unit * 0.06), Color("4a3444"))

func _draw_colonist(surface: CanvasItem, colonist: Dictionary, unit: float) -> void:
	var display_pose: Dictionary = _motion.pose(colonist)
	var point: Vector2 = display_pose.pos
	var id: int = colonist.id
	_facing[id] = float(display_pose.get("visual_facing", 1.0))
	_last_positions[id] = point
	var pos := cell_screen(point) - Vector2.ONE * unit * 0.5
	if bool(display_pose.get("visual_resting", false)) and int(colonist.get("bed", -1)) >= 0:
		for building in simulation.buildings:
			if building.id == colonist.bed:
				pos = cell_screen(Vector2(building.cell)) - Vector2.ONE * unit * 0.5 + Vector2(0.25, -0.2) * unit
				break
	_dynamic_art.settler(pos, unit, display_pose, float(display_pose.get("visual_clock", _clock)), _facing[id])
	if colonist.health < 70 and colonist.alive:
		surface.draw_rect(Rect2(pos + Vector2(0.18, -0.69) * unit, Vector2(unit * 0.65, 3)), Color("543e36"))
		surface.draw_rect(Rect2(pos + Vector2(0.18, -0.69) * unit, Vector2(unit * 0.65 * colonist.health / 100.0, 3)), Color("e9a181"))
	if unit >= 24 and colonist.alive:
		var font_size := 11
		var text_width := _font.get_string_size(colonist.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var label_pos := pos + Vector2(unit * 0.5 - text_width * 0.5, -unit * 0.72)
		surface.draw_string_outline(_font, label_pos, colonist.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color("29433b"))
		surface.draw_string(_font, label_pos, colonist.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("ece8ce"))
