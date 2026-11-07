extends Control
class_name MosslightWorldView

class PaintLayer extends Control:
	var owner_view: Control
	var kind: String
	func _draw() -> void:
		owner_view._paint_layer(kind, self)

signal cell_activated(cell: Vector2i)
signal cell_hovered(cell: Vector2i)
signal cancel_requested

const TILE := 28.0
const MAX_ZOOM := 2.5
const CACHE_TILE := TILE * MAX_ZOOM
const INK := Color("08171e")
const MINT := Color("7fe0b0")
const GOLD := Color("e8bb73")
const CaveArt = preload("res://scripts/cave_art.gd")
const BACKDROP = preload("res://assets/illustration/cavern-backdrop.webp")
const BUILDINGS_UPPER = preload("res://assets/illustration/buildings-upper.webp")
const BUILDINGS_LOWER = preload("res://assets/illustration/buildings-lower.webp")
const BUILDING_REGIONS := {"bed": Rect2(467, 214, 394, 193), "farm": Rect2(911, 141, 396, 266), "airfern": Rect2(1348, 41, 392, 366), "lamp": Rect2(142, 69, 163, 333), "generator": Rect2(467, 39, 387, 364), "cistern": Rect2(933, 36, 347, 366), "beacon": Rect2(1419, 42, 264, 360)}
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
var _font: Font
var _terrain_art: RefCounted
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
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var terrain := _make_cache("terrain")
	_terrain_viewport = terrain.viewport
	_terrain_painter = terrain.painter
	_terrain_display = terrain.display
	_terrain_art = CaveArt.new(_terrain_painter)
	_air_layer = _make_painter("air", self)
	var infrastructure := _make_cache("infrastructure")
	_infrastructure_viewport = infrastructure.viewport
	_infrastructure_painter = infrastructure.painter
	_infrastructure_display = infrastructure.display
	_infrastructure_art = CaveArt.new(_infrastructure_painter)
	_dynamic_layer = _make_painter("dynamic", self)
	_dynamic_art = CaveArt.new(_dynamic_layer)

func _process(delta: float) -> void:
	if not reduced_motion and not simulation_paused:
		_clock += minf(delta, 0.1)
	_stabilize_dig_view()
	_refresh_caches()
	_air_layer.queue_redraw()
	_dynamic_layer.queue_redraw()

func _make_painter(kind: String, parent_node: Node) -> PaintLayer:
	var painter := PaintLayer.new()
	painter.kind = kind
	painter.owner_view = self
	painter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painter.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	add_child(viewport)
	var painter := _make_painter(kind, viewport)
	var display := TextureRect.new()
	display.name = kind.capitalize() + "Surface"
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	# Transparent viewport textures contain premultiplied RGB. Preserve soft edges/glows.
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
			occupied.append(building.cell)
			infrastructure.append([building.cell, building.kind, building.get("active", true)])
		_terrain_hash = hash([simulation.tiles, occupied])
		_infrastructure_hash = hash(infrastructure)
	var view_changed := camera != _cached_camera or zoom_level != _cached_zoom or size != _cached_size
	# Render in world space at the maximum supported zoom. Panning, zooming and
	# resizing only transform these textures; even the closest view loses no detail.
	var pixel_size := Vector2i(ceili(simulation.width * CACHE_TILE), ceili(simulation.height * CACHE_TILE))
	if _terrain_hash != _cached_terrain_hash:
		_terrain_viewport.size = pixel_size
		_terrain_painter.size = Vector2(pixel_size)
		_terrain_painter.queue_redraw()
		_terrain_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_cached_terrain_hash = _terrain_hash
	if _infrastructure_hash != _cached_infrastructure_hash:
		_infrastructure_viewport.size = pixel_size
		_infrastructure_painter.size = Vector2(pixel_size)
		_infrastructure_painter.queue_redraw()
		_infrastructure_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_cached_infrastructure_hash = _infrastructure_hash
	if view_changed:
		var unit := TILE * zoom_level
		for display in [_terrain_display, _infrastructure_display]:
			display.position = size * 0.5 - camera * unit
			display.size = Vector2(simulation.width, simulation.height) * unit
		queue_redraw()
	_cached_camera = camera
	_cached_zoom = zoom_level
	_cached_size = size

func _paint_layer(kind: String, surface: CanvasItem) -> void:
	if not simulation:
		return
	match kind:
		"terrain": _paint_terrain()
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
	# Illustrated heads and machinery extend above their logical cells. Inspection
	# follows visible silhouettes; construction and excavation retain exact tile targeting.
	var unit := TILE * zoom_level
	for index in range(simulation.colonists.size() - 1, -1, -1):
		var colonist: Dictionary = simulation.colonists[index]
		var pos := cell_screen(Vector2(colonist.pos)) - Vector2.ONE * unit * 0.5
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
	if not BUILDING_REGIONS.has(kind):
		return Rect2(pos, Vector2.ONE * unit)
	var source: Rect2 = BUILDING_REGIONS[kind]
	var width_factor: float = {"bed": 1.4, "farm": 1.35, "airfern": 1.35, "lamp": 0.8, "generator": 1.35, "cistern": 1.35, "beacon": 1.2}[kind]
	var draw_size := Vector2(unit * width_factor, unit * width_factor * source.size.y / source.size.x)
	var footing := pos + Vector2(0.5, 1.04) * unit
	return Rect2(footing - Vector2(draw_size.x * 0.5, draw_size.y), draw_size)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	if not simulation:
		return
	var scale_value := maxf(size.x / BACKDROP.get_width(), size.y / BACKDROP.get_height()) * 1.1
	var backdrop_size := Vector2(BACKDROP.get_size()) * scale_value
	var parallax := Vector2((camera.x - 18.0) * -1.6, (camera.y - 13.5) * -1.1)
	draw_texture_rect(BACKDROP, Rect2((size - backdrop_size) * 0.5 + parallax, backdrop_size), false, Color(0.86, 0.94, 0.87, 1))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.09, 0.085, 0.1))

func _paint_terrain() -> void:
	var unit := CACHE_TILE
	var occupied := {}
	for building in simulation.buildings:
		occupied[building.cell] = true
	for y in range(simulation.height):
		for x in range(simulation.width):
			var kind: int = simulation.tiles[y][x]
			if kind > 0:
				var cell := Vector2i(x, y)
				var pos := Vector2(cell) * unit
				var exposed := Vector4(float(_open(cell + Vector2i.UP)), float(_open(cell + Vector2i.DOWN)), float(_open(cell + Vector2i.LEFT)), float(_open(cell + Vector2i.RIGHT)))
				_terrain_art.rock(cell, pos, unit, kind, exposed)
	# Plant dressing is anchored to true floor/ceiling surfaces, never imaginary terrain.
	for y in range(simulation.height):
		for x in range(simulation.width):
			var cell := Vector2i(x, y)
			if simulation.tiles[y][x] == 0:
				continue
			var pos := Vector2(cell) * unit
			if _open(cell + Vector2i.UP):
				_terrain_art.ground_growth(cell, pos, unit, occupied.has(cell + Vector2i.UP))
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
		var center := (Vector2(building.cell) + Vector2.ONE * 0.5) * unit
		if building.kind in ["lamp", "beacon", "airfern"] and building.get("active", false):
			_draw_glow(surface, center - Vector2(0, unit * 0.5), unit, building.kind)
	for building in simulation.buildings:
		var center := (Vector2(building.cell) + Vector2.ONE * 0.5) * unit
		_draw_building(surface, _infrastructure_art, center - Vector2.ONE * unit * 0.5, unit, building.kind, building.get("active", true), false)

func _paint_dynamic(surface: CanvasItem) -> void:
	var unit := TILE * zoom_level
	for job in simulation.jobs:
		var center := cell_screen(Vector2(job.cell))
		var color := GOLD if job.kind == "dig" else MINT
		surface.draw_rect(Rect2(center - Vector2.ONE * unit * 0.46, Vector2.ONE * unit * 0.92), Color(color, 0.13))
		_corner_marks(surface, center, unit * 0.44, color)
		if job.kind == "dig":
			surface.draw_line(center - Vector2.ONE * unit * 0.15, center + Vector2.ONE * unit * 0.15, color, 1.5, true)
			surface.draw_line(center + Vector2(-1, 1) * unit * 0.15, center + Vector2(1, -1) * unit * 0.15, color, 1.5, true)
		else:
			_draw_building(surface, _dynamic_art, center - Vector2.ONE * unit * 0.5, unit, job.get("building_kind", ""), false, true)
		if job.get("progress", 0.0) > 0:
			surface.draw_rect(Rect2(center + Vector2(-unit * 0.4, unit * 0.35), Vector2(unit * 0.8 * job.progress, 2)), color)
	for colonist in simulation.colonists:
		_draw_colonist(surface, colonist, unit)
	# A bounded set of dust motes sits in the light, below control overlays.
	for index in range(32):
		var world_pos := Vector2(5.0 + fmod(index * 3.71, 29.0), 4.0 + fmod(index * 2.27 + _clock * 0.025, 19.0))
		if _open(Vector2i(world_pos.floor())):
			var point := cell_screen(world_pos)
			surface.draw_circle(point, 0.8 + (index % 3) * 0.3, Color(0.9, 0.9, 0.65, 0.16 + sin(_clock * 0.7 + index) * 0.07))
	if interactive and cursor.x >= 0 and cursor.y >= 0 and cursor.x < simulation.width and cursor.y < simulation.height:
		var center := cell_screen(Vector2(cursor))
		var color := MINT
		if selected_tool == "dig":
			color = GOLD
		elif selected_tool == "cancel" or (selected_tool != "inspect" and simulation.can_build(selected_tool, cursor) != ""):
			color = Color("efb08a")
		surface.draw_rect(Rect2(center - Vector2.ONE * unit * 0.5, Vector2.ONE * unit), Color(color, 0.1))
		_corner_marks(surface, center, unit * 0.5, color)
		if keyboard_cursor:
			surface.draw_string(_font, center + Vector2(-unit * 0.4, -unit * 0.7), "ENTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
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
		surface.draw_line(corner, corner - Vector2(side.x * radius * 0.36, 0), color, 1.5, true)
		surface.draw_line(corner, corner - Vector2(0, side.y * radius * 0.36), color, 1.5, true)

func _draw_glow(surface: CanvasItem, center: Vector2, unit: float, kind: String) -> void:
	var color := Color("e8bb6c") if kind == "lamp" else Color("98dfbb")
	for index in range(14, 0, -1):
		var ratio := index / 14.0
		var tint := Color(color, 0.007 + (1.0 - ratio) * 0.008)
		surface.draw_circle(center, unit * (0.4 + ratio * 3.0), tint)

func _draw_building(surface: CanvasItem, art: RefCounted, pos: Vector2, unit: float, kind: String, active: bool, ghost: bool) -> void:
	if kind == "ladder":
		art.ladder(pos, unit)
		return
	if not BUILDING_REGIONS.has(kind):
		return
	var source: Rect2 = BUILDING_REGIONS[kind]
	var texture: Texture2D = BUILDINGS_UPPER if kind in ["bed", "farm", "airfern"] else BUILDINGS_LOWER
	var bounds := _building_rect(pos, unit, kind)
	var footing := pos + Vector2(0.5, 1.04) * unit
	var tint := Color(1, 1, 1, 0.38) if ghost else Color.WHITE if active or kind == "bed" else Color(0.7, 0.78, 0.72, 1)
	if not ghost:
		art.ellipse(footing + Vector2(0, -unit * 0.04), Vector2(bounds.size.x * 0.44, unit * 0.07), Color(0.025, 0.07, 0.06, 0.48))
	surface.draw_texture_rect_region(texture, bounds, source, tint)
	if not active and not ghost and kind != "bed":
		surface.draw_circle(pos + Vector2(0.88, -0.1) * unit, unit * 0.075, Color("edbb7e"))
		surface.draw_circle(pos + Vector2(0.88, -0.1) * unit, unit * 0.035, Color("5e563b"))

func _draw_colonist(surface: CanvasItem, colonist: Dictionary, unit: float) -> void:
	var point: Vector2 = colonist.pos
	var id: int = colonist.id
	if _last_positions.has(id):
		var delta_x: float = point.x - _last_positions[id].x
		if absf(delta_x) > 0.001:
			_facing[id] = signf(delta_x)
	_last_positions[id] = point
	var pos := cell_screen(point) - Vector2.ONE * unit * 0.5
	_dynamic_art.settler(pos, unit, colonist, _clock, float(_facing.get(id, 1.0)))
	if colonist.health < 70 and colonist.alive:
		surface.draw_rect(Rect2(pos + Vector2(0.18, -0.69) * unit, Vector2(unit * 0.65, 3)), Color("543e36"))
		surface.draw_rect(Rect2(pos + Vector2(0.18, -0.69) * unit, Vector2(unit * 0.65 * colonist.health / 100.0, 3)), Color("e9a181"))
	if unit >= 24 and colonist.alive:
		var font_size := 11
		var text_width := _font.get_string_size(colonist.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var label_pos := pos + Vector2(unit * 0.5 - text_width * 0.5, -unit * 0.72)
		surface.draw_string_outline(_font, label_pos, colonist.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color("29433b"))
		surface.draw_string(_font, label_pos, colonist.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("ece8ce"))
