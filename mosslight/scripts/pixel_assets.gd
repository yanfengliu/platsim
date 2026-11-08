extends RefCounted

## Original integer-grid art. Textures are authored once, then shared by every view.
## All source pixels are opaque or transparent; the renderer supplies live lighting.
const INK := Color("121b2d")
const SHADOW := Color("263047")
const SLATE := Color("46516a")
const STONE := Color("718099")
const WOOD := Color("624453")
const COPPER := Color("a96852")
const BRASS := Color("d79a60")
const GOLD := Color("f4c178")
const CREAM := Color("ffebbd")
const LEAF_DARK := Color("254c50")
const LEAF := Color("387d70")
const JADE := Color("64b58a")
const MINT := Color("b1dc9b")
const WATER_DARK := Color("285268")
const WATER := Color("3f8b9c")
const CYAN := Color("75c9c5")
const ICE := Color("d4eee0")
const SIZES := {
	"bed": Vector2i(40, 22), "farm": Vector2i(36, 28),
	"airfern": Vector2i(32, 38), "lamp": Vector2i(20, 36),
	"generator": Vector2i(40, 36), "cistern": Vector2i(34, 36),
	"beacon": Vector2i(28, 40)
}
static var _buildings: Dictionary = {}
static var _backdrop: Texture2D

static func building_size(kind: String) -> Vector2i:
	return SIZES.get(kind, Vector2i.ZERO)

static func building(kind: String) -> Texture2D:
	if not SIZES.has(kind):
		return null
	if not _buildings.has(kind):
		var dimensions: Vector2i = SIZES[kind]
		var image := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		match kind:
			"bed": _bed(image)
			"farm": _farm(image)
			"airfern": _airfern(image)
			"lamp": _lamp(image)
			"generator": _generator(image)
			"cistern": _cistern(image)
			"beacon": _beacon(image)
		_buildings[kind] = ImageTexture.create_from_image(image)
	return _buildings[kind]

static func _rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	var area := Rect2i(x, y, width, height).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if area.has_area():
		image.fill_rect(area, color)

static func _line(image: Image, start: Vector2i, finish: Vector2i, color: Color, thickness: int = 1) -> void:
	var x := start.x
	var y := start.y
	var dx := absi(finish.x - x)
	var dy := -absi(finish.y - y)
	var sx := 1 if x < finish.x else -1
	var sy := 1 if y < finish.y else -1
	var error := dx + dy
	while true:
		_rect(image, x, y, thickness, thickness, color)
		if x == finish.x and y == finish.y:
			break
		var twice := error * 2
		if twice >= dy:
			error += dy
			x += sx
		if twice <= dx:
			error += dx
			y += sy

static func _poly(image: Image, points: Array, color: Color, step: int = 1) -> void:
	var low := image.get_height()
	var high := 0
	for point: Vector2i in points:
		low = mini(low, point.y)
		high = maxi(high, point.y)
	for y in range(maxi(0, low), mini(image.get_height(), high + 1), step):
		var crossings: Array[int] = []
		for index in range(points.size()):
			var a: Vector2i = points[index]
			var b: Vector2i = points[(index + 1) % points.size()]
			if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
				crossings.append(int(a.x + float(y - a.y) * float(b.x - a.x) / float(b.y - a.y)))
		crossings.sort()
		for index in range(0, crossings.size() - 1, 2):
			var x := floori(float(crossings[index]) / step) * step
			var end := ceili(float(crossings[index + 1]) / step) * step
			_rect(image, x, y, end - x, step, color)

static func _bed(image: Image) -> void:
	# A low camp cot: copper brackets, folded quilt and a square canvas pillow.
	_rect(image, 2, 9, 3, 12, INK)
	_rect(image, 35, 11, 3, 10, INK)
	_rect(image, 3, 7, 3, 11, WOOD)
	_rect(image, 4, 8, 1, 8, BRASS)
	_rect(image, 3, 15, 34, 5, INK)
	_rect(image, 5, 16, 30, 2, COPPER)
	_rect(image, 6, 18, 3, 3, WOOD)
	_rect(image, 31, 18, 3, 3, WOOD)
	_rect(image, 6, 18, 1, 2, BRASS)
	_rect(image, 31, 18, 1, 2, BRASS)
	_rect(image, 5, 10, 30, 6, LEAF_DARK)
	_rect(image, 7, 8, 25, 7, LEAF)
	_rect(image, 14, 9, 19, 5, JADE)
	_rect(image, 17, 9, 2, 6, LEAF)
	_rect(image, 25, 9, 2, 6, LEAF)
	_rect(image, 15, 9, 16, 1, MINT)
	_rect(image, 7, 9, 7, 5, STONE)
	_rect(image, 7, 8, 6, 4, CREAM)
	_rect(image, 8, 8, 4, 1, ICE)
	_rect(image, 35, 12, 2, 4, COPPER)
	_rect(image, 35, 12, 1, 2, GOLD)

static func _mushroom(image: Image, x: int, y: int, big: bool) -> void:
	var width := 13 if big else 9
	var height := 7 if big else 5
	_rect(image, x + width / 2 - 1, y + height - 1, 3, 9, INK)
	_rect(image, x + width / 2, y + height, 2, 7, CREAM)
	_rect(image, x + 2, y, width - 4, height + 1, INK)
	_rect(image, x, y + 3, width, height - 2, INK)
	_rect(image, x + 2, y + 1, width - 4, height - 1, COPPER)
	_rect(image, x + 1, y + 3, width - 2, height - 3, BRASS)
	_rect(image, x + 3, y + 1, width - 6, 2, GOLD)
	_rect(image, x + 3, y + 2, 2, 1, CREAM)
	_rect(image, x + 2, y + height - 1, width - 4, 1, WOOD)

static func _farm(image: Image) -> void:
	_rect(image, 3, 20, 30, 7, INK)
	_rect(image, 5, 20, 26, 5, WOOD)
	_rect(image, 4, 22, 28, 3, COPPER)
	_rect(image, 4, 20, 28, 2, BRASS)
	_rect(image, 5, 21, 25, 1, GOLD)
	_rect(image, 7, 25, 3, 2, SHADOW)
	_rect(image, 26, 25, 3, 2, SHADOW)
	_rect(image, 8, 22, 2, 3, WOOD)
	_rect(image, 26, 22, 2, 3, WOOD)
	_mushroom(image, 3, 10, false)
	_mushroom(image, 12, 5, true)
	_mushroom(image, 24, 11, false)
	_rect(image, 13, 18, 2, 2, JADE)
	_rect(image, 27, 19, 3, 1, LEAF)

static func _frond(image: Image, start: Vector2i, tip: Vector2i, bright: bool) -> void:
	_line(image, start, tip, LEAF_DARK, 2)
	var direction := Vector2(tip - start)
	for index in range(1, 6):
		var t := float(index) / 6.0
		var point := start + Vector2i(direction * t)
		var spread := 5 - index / 2
		var color := JADE if bright else LEAF
		_line(image, point, point + Vector2i(-spread, -spread + 1), color, 2)
		_line(image, point + Vector2i(1, 0), point + Vector2i(spread, -spread), color, 2)
	_line(image, start + Vector2i(1, 0), tip + Vector2i(1, 0), JADE if bright else LEAF)
	_rect(image, tip.x, tip.y, 2, 2, MINT if bright else JADE)

static func _airfern(image: Image) -> void:
	# A split slate planter frames a broad fern fan, unlike the round old pot.
	_rect(image, 5, 28, 22, 8, INK)
	_rect(image, 7, 34, 18, 3, INK)
	_rect(image, 6, 29, 20, 5, SLATE)
	_rect(image, 7, 29, 4, 4, STONE)
	_rect(image, 12, 30, 12, 4, SHADOW)
	_rect(image, 7, 27, 18, 3, INK)
	_rect(image, 8, 28, 16, 1, COPPER)
	_frond(image, Vector2i(15, 28), Vector2i(6, 12), false)
	_frond(image, Vector2i(16, 28), Vector2i(25, 11), false)
	_frond(image, Vector2i(15, 27), Vector2i(11, 6), true)
	_frond(image, Vector2i(16, 27), Vector2i(21, 5), true)
	_frond(image, Vector2i(15, 27), Vector2i(15, 2), true)
	_rect(image, 11, 33, 2, 1, CYAN)
	_rect(image, 22, 30, 2, 2, BRASS)

static func _lamp(image: Image) -> void:
	# Boxy work lantern with a bright four-pixel core and separate metal housing.
	_rect(image, 4, 32, 12, 3, INK)
	_rect(image, 6, 31, 8, 3, COPPER)
	_rect(image, 6, 31, 8, 1, GOLD)
	_rect(image, 8, 20, 4, 12, INK)
	_rect(image, 9, 22, 2, 10, BRASS)
	_rect(image, 4, 6, 12, 18, INK)
	_rect(image, 6, 4, 8, 3, INK)
	_rect(image, 7, 3, 6, 2, BRASS)
	_rect(image, 5, 7, 10, 2, COPPER)
	_rect(image, 5, 9, 10, 12, BRASS)
	_rect(image, 6, 10, 8, 10, GOLD)
	_rect(image, 8, 11, 4, 8, CREAM)
	_rect(image, 9, 12, 2, 5, ICE)
	_rect(image, 5, 21, 10, 2, COPPER)
	_rect(image, 6, 7, 8, 1, GOLD)
	_rect(image, 5, 9, 1, 12, WOOD)
	_rect(image, 14, 9, 1, 12, WOOD)
	_rect(image, 6, 15, 8, 1, BRASS)

static func _generator(image: Image) -> void:
	# A squat workshop press: chimney, cyan gauge, vent fins and external flywheel.
	_rect(image, 2, 31, 36, 4, INK)
	_rect(image, 4, 31, 32, 2, SLATE)
	_rect(image, 4, 4, 8, 16, INK)
	_rect(image, 5, 5, 5, 12, COPPER)
	_rect(image, 5, 6, 1, 9, BRASS)
	_rect(image, 3, 3, 10, 3, INK)
	_rect(image, 4, 3, 8, 1, STONE)
	_rect(image, 3, 15, 24, 17, INK)
	_rect(image, 6, 12, 18, 4, INK)
	_rect(image, 6, 14, 18, 3, COPPER)
	_rect(image, 4, 17, 22, 13, WOOD)
	_rect(image, 5, 17, 18, 3, COPPER)
	_rect(image, 5, 17, 2, 12, BRASS)
	_rect(image, 8, 22, 9, 6, INK)
	for x in [9, 12, 15]:
		_rect(image, x, 23, 1, 4, BRASS)
	_rect(image, 15, 13, 9, 8, INK)
	_rect(image, 17, 14, 5, 5, WATER_DARK)
	_rect(image, 18, 15, 3, 3, CYAN)
	_rect(image, 18, 15, 2, 1, ICE)
	_rect(image, 21, 22, 3, 3, GOLD)
	_rect(image, 26, 16, 8, 18, INK)
	_rect(image, 22, 20, 16, 10, INK)
	_rect(image, 25, 18, 10, 14, COPPER)
	_rect(image, 23, 21, 14, 8, COPPER)
	_rect(image, 27, 20, 6, 10, INK)
	_rect(image, 25, 22, 10, 6, INK)
	_rect(image, 28, 19, 2, 12, BRASS)
	_rect(image, 24, 24, 12, 2, BRASS)
	_rect(image, 27, 23, 5, 5, INK)
	_rect(image, 28, 24, 3, 3, GOLD)
	_rect(image, 25, 19, 3, 1, GOLD)
	_rect(image, 7, 30, 2, 2, GOLD)

static func _cistern(image: Image) -> void:
	# A suspended collecting canopy drains into a glass tank with a visible waterline.
	_rect(image, 6, 31, 23, 4, INK)
	_rect(image, 7, 31, 21, 2, SLATE)
	_rect(image, 9, 33, 4, 2, STONE)
	_rect(image, 24, 33, 3, 2, STONE)
	_rect(image, 7, 15, 22, 17, INK)
	_rect(image, 9, 13, 18, 3, INK)
	_rect(image, 9, 15, 18, 15, WATER_DARK)
	_rect(image, 10, 21, 16, 9, WATER)
	_rect(image, 10, 20, 7, 2, CYAN)
	_rect(image, 17, 21, 9, 1, CYAN)
	_rect(image, 10, 16, 2, 10, ICE)
	_rect(image, 12, 16, 2, 2, CYAN)
	_rect(image, 25, 16, 1, 12, CYAN)
	_rect(image, 8, 29, 20, 2, COPPER)
	_rect(image, 8, 29, 20, 1, BRASS)
	_rect(image, 15, 9, 5, 7, INK)
	_rect(image, 16, 10, 3, 5, COPPER)
	_poly(image, [Vector2i(2, 4), Vector2i(16, 2), Vector2i(31, 5), Vector2i(21, 11), Vector2i(12, 11)], INK)
	_poly(image, [Vector2i(4, 5), Vector2i(16, 3), Vector2i(29, 5), Vector2i(20, 9), Vector2i(13, 9)], LEAF)
	_line(image, Vector2i(5, 5), Vector2i(16, 4), JADE)
	_line(image, Vector2i(16, 4), Vector2i(27, 5), JADE)
	_line(image, Vector2i(6, 5), Vector2i(17, 8), LEAF_DARK)
	_rect(image, 28, 25, 4, 3, INK)
	_rect(image, 29, 26, 2, 1, BRASS)

static func _beacon(image: Image) -> void:
	# A cut cyan crystal suspended in an angular brass cradle on a slate plinth.
	_rect(image, 2, 35, 24, 4, INK)
	_rect(image, 4, 34, 20, 3, SLATE)
	_rect(image, 5, 34, 17, 1, STONE)
	_rect(image, 7, 30, 14, 5, INK)
	_rect(image, 9, 31, 10, 3, COPPER)
	_poly(image, [Vector2i(14, 2), Vector2i(23, 13), Vector2i(21, 25), Vector2i(14, 30), Vector2i(7, 24), Vector2i(6, 13)], INK)
	_poly(image, [Vector2i(14, 4), Vector2i(21, 14), Vector2i(19, 24), Vector2i(14, 28), Vector2i(9, 23), Vector2i(8, 14)], WATER)
	_poly(image, [Vector2i(14, 4), Vector2i(15, 15), Vector2i(10, 23), Vector2i(8, 14)], CYAN)
	_poly(image, [Vector2i(14, 4), Vector2i(19, 13), Vector2i(15, 15)], ICE)
	_poly(image, [Vector2i(15, 16), Vector2i(19, 15), Vector2i(18, 23), Vector2i(14, 27)], JADE)
	_line(image, Vector2i(4, 23), Vector2i(8, 29), INK, 3)
	_line(image, Vector2i(21, 29), Vector2i(24, 22), INK, 3)
	_line(image, Vector2i(5, 23), Vector2i(9, 29), BRASS, 2)
	_line(image, Vector2i(20, 29), Vector2i(23, 23), COPPER, 2)
	_rect(image, 8, 29, 13, 2, GOLD)
	_rect(image, 12, 34, 4, 2, CYAN)

static func backdrop() -> Texture2D:
	if _backdrop != null:
		return _backdrop
	var image := Image.create(512, 288, false, Image.FORMAT_RGBA8)
	image.fill(Color("151b30"))
	# Broad value bands and stepped silhouettes give depth without painted gradients.
	_poly(image, [Vector2i(0, 126), Vector2i(52, 114), Vector2i(112, 122), Vector2i(184, 108), Vector2i(240, 116), Vector2i(304, 98), Vector2i(368, 110), Vector2i(438, 101), Vector2i(512, 119), Vector2i(512, 288), Vector2i(0, 288)], Color("172537"), 2)
	_poly(image, [Vector2i(0, 230), Vector2i(68, 214), Vector2i(128, 222), Vector2i(192, 205), Vector2i(254, 215), Vector2i(318, 196), Vector2i(382, 208), Vector2i(448, 199), Vector2i(512, 213), Vector2i(512, 288), Vector2i(0, 288)], Color("19303c"), 2)
	_poly(image, [Vector2i(278, 0), Vector2i(304, 0), Vector2i(275, 118), Vector2i(243, 214), Vector2i(217, 264), Vector2i(223, 172)], Color("203c43"), 2)
	_poly(image, [Vector2i(282, 0), Vector2i(292, 0), Vector2i(264, 120), Vector2i(235, 214), Vector2i(242, 142)], Color("29494b"), 2)
	_poly(image, [Vector2i(0, 0), Vector2i(144, 0), Vector2i(142, 26), Vector2i(132, 30), Vector2i(132, 66), Vector2i(120, 80), Vector2i(116, 116), Vector2i(101, 132), Vector2i(103, 192), Vector2i(87, 210), Vector2i(78, 288), Vector2i(0, 288)], Color("242a43"), 2)
	_poly(image, [Vector2i(0, 0), Vector2i(88, 0), Vector2i(84, 50), Vector2i(72, 58), Vector2i(78, 103), Vector2i(61, 119), Vector2i(58, 158), Vector2i(40, 170), Vector2i(34, 222), Vector2i(14, 250), Vector2i(0, 288)], Color("30334e"), 2)
	_poly(image, [Vector2i(380, 0), Vector2i(512, 0), Vector2i(512, 288), Vector2i(426, 288), Vector2i(429, 249), Vector2i(407, 232), Vector2i(413, 193), Vector2i(390, 175), Vector2i(398, 139), Vector2i(382, 126), Vector2i(390, 92), Vector2i(373, 62)], Color("203847"), 2)
	_poly(image, [Vector2i(450, 0), Vector2i(512, 0), Vector2i(512, 288), Vector2i(485, 274), Vector2i(479, 240), Vector2i(464, 221), Vector2i(471, 182), Vector2i(448, 160), Vector2i(454, 117), Vector2i(438, 96)], Color("293f50"), 2)
	# Broken high arches and distant stalactites leave the middle playable space quiet.
	_poly(image, [Vector2i(124, 0), Vector2i(252, 0), Vector2i(246, 18), Vector2i(224, 24), Vector2i(215, 49), Vector2i(207, 63), Vector2i(199, 34), Vector2i(172, 36), Vector2i(165, 58), Vector2i(154, 82), Vector2i(149, 49), Vector2i(130, 41)], Color("20283d"), 2)
	_poly(image, [Vector2i(315, 0), Vector2i(402, 0), Vector2i(389, 56), Vector2i(375, 72), Vector2i(367, 40), Vector2i(343, 31), Vector2i(333, 57), Vector2i(325, 23)], Color("1b2b3c"), 2)
	_poly(image, [Vector2i(137, 288), Vector2i(144, 247), Vector2i(158, 224), Vector2i(161, 188), Vector2i(171, 204), Vector2i(183, 248), Vector2i(186, 288)], Color("1c3942"), 2)
	_poly(image, [Vector2i(333, 288), Vector2i(341, 224), Vector2i(351, 209), Vector2i(356, 184), Vector2i(364, 206), Vector2i(369, 250), Vector2i(380, 288)], Color("1c3441"), 2)
	# Deliberately sparse strata: paired horizontal clusters, never single-pixel noise.
	for index in range(42):
		var left := index % 2 == 0
		var x := 8 + posmod(index * 29, 92) if left else 411 + posmod(index * 17, 82)
		var y := 16 + posmod(index * 43, 258)
		var width := 6 + posmod(index * 7, 16)
		_rect(image, x, y, width, 2, Color("39405b") if left else Color("334b5b"))
		_rect(image, x + 2, y + 2, width - 4, 2, Color("2a304a") if left else Color("223947"))
	# Jade mineral seams and tiny distant amber fungi accent only the framing walls.
	for seam in [[38, 29, 26], [92, 112, 32], [439, 45, 35], [479, 176, 26]]:
		var x: int = seam[0]
		var y: int = seam[1]
		var length: int = seam[2]
		_line(image, Vector2i(x, y), Vector2i(x + 6, y + length / 2), Color("385557"), 2)
		_line(image, Vector2i(x + 6, y + length / 2), Vector2i(x + 2, y + length), Color("385557"), 2)
		_rect(image, x + 1, y + 3, 2, 6, Color("547466"))
	for point in [Vector2i(67, 90), Vector2i(28, 194), Vector2i(113, 142), Vector2i(416, 157), Vector2i(470, 81), Vector2i(451, 249)]:
		_rect(image, point.x, point.y, 6, 2, Color("8c7660"))
		_rect(image, point.x + 1, point.y - 2, 4, 2, Color("b99a6d"))
		_rect(image, point.x + 2, point.y + 2, 2, 4, Color("5b665e"))
	_backdrop = ImageTexture.create_from_image(image)
	return _backdrop
