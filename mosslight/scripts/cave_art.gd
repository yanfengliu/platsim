extends RefCounted

## Original pixel clusters. Solid-cell edges remain authoritative for traversal.
var canvas: CanvasItem
const STONE := Color("34384f")
const DEEP := Color("1d2235")
const EDGE := Color("797b91")
const MOSS := Color("427565")
const PALE := Color("a5d5a0")
const PIXEL := 1.0 / 24.0
const DiggingMotion = preload("res://scripts/digging_motion.gd")
const PixelSettler = preload("res://scripts/pixel_settler.gd")

func _init(target: CanvasItem) -> void:
	canvas = target

func block(rect: Rect2, color: Color) -> void:
	canvas.draw_rect(rect, color)

func ellipse(center: Vector2, radius: Vector2, color: Color, _steps: int = 20) -> void:
	# Scanline clusters have hard edges. Cap rows for world-space building shadows.
	var pixel := maxf(PIXEL, ceilf(radius.y * 2.0 / 24.0)) if radius.y > 1.0 else PIXEL
	var first := floori((center.y - radius.y) / pixel)
	var last := ceili((center.y + radius.y) / pixel)
	for row in range(first, maxi(first + 1, last)):
		var y := (row + 0.5) * pixel
		var normalized := clampf((y - center.y) / maxf(radius.y, pixel), -1.0, 1.0)
		var half_width := maxf(pixel * 0.5, radius.x * sqrt(maxf(0.0, 1.0 - normalized * normalized)))
		var left := floorf((center.x - half_width) / pixel) * pixel
		var right := ceilf((center.x + half_width) / pixel) * pixel
		block(Rect2(left, row * pixel, maxf(pixel, right - left), pixel), color)

func stroke(points: Array, color: Color, width: float) -> void:
	# A pixel brush follows the continuous rig; animation clocks are never quantized.
	var thickness := maxi(1, roundi(width / PIXEL))
	for index in range(points.size() - 1):
		var start: Vector2 = points[index]
		var finish: Vector2 = points[index + 1]
		var distance: Vector2 = (finish - start).abs() / PIXEL
		var count := maxi(1, ceili(maxf(distance.x, distance.y)))
		for sample in range(count + 1):
			var point := start.lerp(finish, float(sample) / count)
			var pixel_point := (point / PIXEL).round() - Vector2.ONE * floorf(thickness * 0.5)
			block(Rect2(pixel_point * PIXEL, Vector2.ONE * thickness * PIXEL), color)

func _tile_rect(x: int, y: int, width: int, height: int, color: Color) -> void:
	block(Rect2(float(x) / 16.0, float(y) / 16.0, float(width) / 16.0, float(height) / 16.0), color)

func rock(cell: Vector2i, pos: Vector2, unit: float, kind: int, exposed: Vector4) -> void:
	canvas.draw_set_transform(pos, 0, Vector2.ONE * unit)
	var seed_value := posmod(cell.x * 47 + cell.y * 29, 101)
	var band := posmod(floori(cell.x / 3.0) + floori(cell.y / 2.0), 3)
	_tile_rect(0, 0, 16, 16, [STONE, Color("383b53"), Color("30364b")][band])
	# Broad quiet strata and a few stone clusters, never a per-tile box outline.
	for i in range(4):
		var x := posmod(seed_value + i * 7, 12)
		var y := posmod(seed_value * 3 + i * 5, 14)
		var length := mini(16 - x, 3 + posmod(seed_value + i, 5))
		_tile_rect(x, y, length, 1 + i % 2, Color("41465d") if i % 2 == 0 else Color("2c3045"))
		if i == 1:
			_tile_rect(x + 1, y, maxi(1, length - 2), 1, Color("50546b"))
	if exposed.x > 0:
		_tile_rect(0, 0, 16, 3, Color("233c3d"))
		_tile_rect(0, 0, 16, 1, Color("8ac89a"))
		_tile_rect(0, 1, 16, 1, Color("4d8c70"))
		for i in range(4):
			_tile_rect(i * 4 + seed_value % 2, 2, 2, 1 + (seed_value + i) % 3, Color("385e51"))
	if exposed.y > 0:
		_tile_rect(0, 14, 16, 2, DEEP)
		for i in range(3):
			_tile_rect(i * 5 + 1, 13, 3, 1, Color("252a40"))
	if exposed.z > 0:
		_tile_rect(0, 0, 1, 16, Color("73748a"))
		_tile_rect(1, 3, 1, 5, Color("555a73"))
		_tile_rect(1, 11, 2, 4, Color("454d66"))
	if exposed.w > 0:
		_tile_rect(14, 0, 2, 16, DEEP)
		_tile_rect(13, 5, 1, 7, Color("292d42"))
	if kind == 2:
		for i in range(3):
			var x := 3 + i * 4
			var y := 6 + posmod(seed_value + i * 3, 4)
			_tile_rect(x - 1, y, 4, 4, DEEP)
			_tile_rect(x, y, 3, 3, Color("b37558"))
			_tile_rect(x, y, 2, 1, Color("f0c584"))
			_tile_rect(x, y + 1, 1, 1, Color("ffe5ab"))
	elif kind == 3:
		for i in range(5):
			var x := 3 + i * 2
			var y := 3 + i * 2 + (i % 2)
			_tile_rect(x - 1, y, 4, 3, Color("263b35"))
			_tile_rect(x, y, 2, 3, Color("587d54"))
			_tile_rect(x, y, 1, 2, Color("a3b874"))
		_tile_rect(9, 4, 3, 2, Color("6b9a66"))
	elif kind == 4:
		for i in range(3):
			var x := 4 + i * 3
			var y := 4 + i * 2
			_tile_rect(x, y, 2, 5, Color("416e90"))
			_tile_rect(x, y, 1, 4, Color("7fbed0"))
			_tile_rect(x, y - 1, 1, 1, Color("c1e5df"))
	canvas.draw_set_transform(Vector2.ZERO)

func ground_growth(cell: Vector2i, pos: Vector2, unit: float, occupied: bool) -> void:
	canvas.draw_set_transform(pos, 0, Vector2.ONE * unit)
	var seed_value := posmod(cell.x * 23 + cell.y * 37, 11)
	if not occupied and seed_value < 5:
		for i in range(4):
			var x := 4 + i * 2
			var height := 3 + posmod(seed_value + i, 4)
			_tile_rect(x, -height, 1, height, Color("437a63"))
			_tile_rect(x - 1, -height, 3, 1, Color("9bd0a1"))
			_tile_rect(x - 1, -height + 2, 2, 1, Color("62a883"))
	elif not occupied and seed_value < 8:
		_pixel_mushroom(4, 0, 5, Color("dc9e61"))
		_pixel_mushroom(11, 0, 3, Color("86c8b0"))
	else:
		for i in range(3):
			var x := 2 + i * 5
			_tile_rect(x, -2 - i % 2, 1, 3, MOSS)
			_tile_rect(x + 1, -1 - i % 2, 1, 2, Color("75b78d"))
	canvas.draw_set_transform(Vector2.ZERO)

func _pixel_mushroom(x: int, y: int, height: int, cap: Color) -> void:
	_tile_rect(x, y - height, 1, height, Color("b5c5b1"))
	_tile_rect(x - 2, y - height, 5, 2, Color("34514a"))
	_tile_rect(x - 2, y - height - 1, 5, 1, cap)
	_tile_rect(x - 1, y - height - 2, 3, 1, cap)
	_tile_rect(x - 1, y - height - 1, 1, 1, Color("f6d99c"))

func ceiling_growth(cell: Vector2i, pos: Vector2, unit: float) -> void:
	if posmod(cell.x * 17 + cell.y * 31, 5) > 1:
		return
	canvas.draw_set_transform(pos, 0, Vector2.ONE * unit)
	var length := 8 + posmod(cell.x * 7, 6) * 2
	for i in range(length):
		var x := 5 + (i / 4) % 2
		_tile_rect(x, 15 + i, 1, 1, Color("355a51"))
		if i % 4 == 1:
			_tile_rect(x - 2, 15 + i, 2, 2, Color("467963"))
			_tile_rect(x + 1, 16 + i, 2, 1, Color("78ac7e"))
	canvas.draw_set_transform(Vector2.ZERO)

func ladder(pos: Vector2, unit: float) -> void:
	canvas.draw_set_transform(pos, 0, Vector2.ONE * unit)
	for x in [4, 11]:
		_tile_rect(x - 1, 0, 3, 16, Color("222536"))
		_tile_rect(x, 0, 1, 16, Color("b77b59"))
		_tile_rect(x + 1, 0, 1, 16, Color("674953"))
	for y in [2, 7, 12]:
		_tile_rect(4, y, 8, 2, Color("704d4e"))
		_tile_rect(4, y, 8, 1, Color("e4b57c"))
		_tile_rect(4, y, 1, 1, Color("ffe0a0"))
	canvas.draw_set_transform(Vector2.ZERO)

func settler(pos: Vector2, unit: float, colonist: Dictionary, clock: float, facing: float) -> void:
	PixelSettler.draw(self, pos, unit, colonist, clock, facing)

func _digging_arm(pose: Dictionary, side: String, coat: Color) -> void:
	var shoulder: Vector2 = pose["shoulder_" + side]
	var elbow: Vector2 = pose["elbow_" + side]
	var hand: Vector2 = pose["hand_" + side]
	# One connected, constant-length chain. A darker cuff and elbow separate
	# the two sleeves instead of turning extended arms into a flat coat blob.
	stroke([shoulder, elbow, hand], coat.darkened(0.3), 0.15)
	stroke([shoulder, elbow], coat, 0.115)
	ellipse(elbow, Vector2(0.065, 0.065), coat)
	stroke([elbow, hand], coat.lightened(0.07), 0.10)
	stroke([hand.lerp(elbow, 0.16), hand], coat.darkened(0.18), 0.115)

func _digging_tool(pose: Dictionary, skin: Color, weight: float) -> void:
	if pose.trail.size() > 1:
		stroke(pose.trail, Color(0.87, 0.9, 0.72, 0.26 * weight), 0.09)
	# Dark edging and a lit metal bevel keep the full swing readable at normal zoom.
	stroke([pose.shaft_bottom, pose.shaft_top], Color(Color("354238"), weight), 0.105)
	stroke([pose.shaft_bottom, pose.shaft_top], Color(Color("a18c5c"), weight), 0.055)
	stroke(pose.pick_points, Color(Color("33423d"), weight), 0.13)
	stroke(pose.pick_points, Color(Color("b7c3b5"), weight), 0.075)
	ellipse(pose.hand_back, Vector2(0.075, 0.08), skin)
	ellipse(pose.hand_front, Vector2(0.085, 0.085), skin)
	var strength: float = pose.impact * weight
	if strength > 0.0:
		var contact: Vector2 = pose.contact
		ellipse(contact, Vector2(0.19, 0.12) * (0.6 + strength * 0.4), Color(0.92, 0.85, 0.58, strength * 0.32))
		for i in range(5):
			var direction := Vector2.from_angle(float(i) * TAU / 5.0 + 0.3)
			stroke([contact + direction * 0.04, contact + direction * (0.13 + strength * 0.12)], Color(1.0, 0.91, 0.64, strength), 0.028)
		# A short dark fracture sits on the same impact point as the pick tip.
		stroke([contact + Vector2(-0.12, -0.04), contact, contact + Vector2(0.08, 0.09), contact + Vector2(0.15, 0.06)], Color(0.12, 0.21, 0.17, strength * 0.85), 0.025)
	for chip in pose.debris:
		ellipse(chip.position, Vector2(chip.radius, chip.radius * 0.65), Color(0.7, 0.73, 0.52, chip.alpha * weight), 5)
