extends SceneTree

const Assets = preload("res://scripts/pixel_assets.gd")
const World = preload("res://scripts/world_view.gd")
const Simulation = preload("res://scripts/simulation.gd")
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _run() -> void:
	var signatures := {}
	for kind in ["bed", "farm", "airfern", "lamp", "generator", "cistern", "beacon"]:
		var texture: Texture2D = Assets.building(kind)
		check(texture != null and texture == Assets.building(kind), kind + " texture is cached across frames")
		var image: Image = texture.get_image()
		check(image.get_size() == Assets.building_size(kind) and image.get_width() <= 48 and image.get_height() <= 48, kind + " retains an authored low-resolution grid")
		var pixels := 0
		var hard_alpha := true
		var colors := {}
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var color := image.get_pixel(x, y)
				hard_alpha = hard_alpha and (color.a == 0.0 or color.a == 1.0)
				if color.a > 0.0:
					pixels += 1
					colors[color.to_rgba32()] = true
		check(hard_alpha and pixels > 50 and pixels < image.get_width() * image.get_height(), kind + " has visible crisp pixels and transparent gutters")
		check(colors.size() >= 4 and colors.size() <= 32, kind + " uses a compact shaded palette")
		signatures[hash(image.get_data())] = true
	check(signatures.size() == 7, "all seven props have distinct authored silhouettes and materials")
	check(Assets.building("unknown") == null and Assets.building_size("unknown") == Vector2i.ZERO, "unknown building kinds are safe to skip")
	var backdrop: Texture2D = Assets.backdrop()
	check(backdrop == Assets.backdrop() and backdrop.get_width() == 512 and backdrop.get_height() == 288, "layered backdrop is cached at its intended pixel resolution")
	check(backdrop.get_image().detect_alpha() == Image.ALPHA_NONE, "distant cave covers the world without transparent holes")
	var view := World.new()
	view.simulation = Simulation.new()
	view.size = Vector2(1000, 700)
	root.add_child(view)
	await process_frame
	await process_frame
	check(view.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "world textures preserve hard pixel edges")
	var nearest := true
	for key in ["_terrain_painter", "_infrastructure_painter", "_dynamic_layer", "_infrastructure_display"]:
		nearest = nearest and view.get(key).texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
	for chunk in view.get("_terrain_chunks").values():
		nearest = nearest and chunk.display.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
	check(nearest, "terrain chunks, buildings and dynamic art all use nearest sampling")
	# Drawn props and interaction previews share authoritative multi-cell geometry.
	for kind in ["bed", "farm", "airfern", "lamp", "generator", "cistern", "beacon"]:
		var anchor := Vector2i(11, 6)
		var footprint: Rect2i = view.simulation.building_rect(kind, anchor)
		var unit := 70.0
		var sprite: Rect2 = view.call("_building_rect", Vector2(anchor) * unit, unit, kind)
		var area := Rect2(Vector2(footprint.position) * unit, Vector2(footprint.size) * unit)
		check(area.grow(0.01).encloses(sprite), kind + " art remains inside its reserved grid footprint")
		check(is_equal_approx(sprite.end.y, area.end.y) and is_equal_approx(sprite.get_center().x, area.get_center().x), kind + " art stands on and is centered over its full foundation")
		for zoom in [0.65, 1.0, 2.5]:
			view.zoom_level = zoom
			var preview: Rect2 = view.call("_footprint_screen", kind, anchor)
			var expected: Vector2 = view.cell_screen(Vector2(footprint.position)) - Vector2.ONE * view.TILE * zoom * 0.5
			check(preview.position.is_equal_approx(expected) and preview.size.is_equal_approx(Vector2(footprint.size) * view.TILE * zoom), kind + " preview reserves every footprint cell at zoom " + str(zoom))
	var bed: Rect2 = view.call("_building_rect", Vector2.ZERO, 70.0, "bed")
	var generator: Rect2 = view.call("_building_rect", Vector2.ZERO, 70.0, "generator")
	check(bed.size.x > 1.7 * 70.0 and generator.size.x > 1.8 * 70.0 and generator.size.y > 1.6 * 70.0, "beds and machinery visibly occupy their intended larger proportions")
	view.queue_free()
	await process_frame
	print("Mosslight pixel art: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
