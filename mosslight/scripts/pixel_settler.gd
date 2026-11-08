extends RefCounted

## Original 24-pixel explorers. Shapes use an authored grid; actor positions and
## articulated joints keep the continuous presentation clock of the simulation.
const DiggingMotion = preload("res://scripts/digging_motion.gd")
const PIXEL := 1.0 / 24.0
const INK := Color("171b30")
const TROUSERS := Color("39445f")
const STEEL := Color("8ca6b4")
const LEATHER := Color("72523d")
const COPPER := Color("b87b48")
const LIGHT := Color("ffe2a0")
const COATS := [Color("d69a4f"), Color("5cacb2"), Color("b77d9e"), Color("93ae67")]
const SHADOWS := [Color("986339"), Color("386c81"), Color("774e76"), Color("586f4d")]
const HIGHLIGHTS := [Color("f0c77a"), Color("95d1c3"), Color("dfabc0"), Color("c4d68d")]
const SKINS := [Color("e1b58b"), Color("ae7654"), Color("f0cba0"), Color("c89468")]
const SKIN_SHADOWS := [Color("b77e58"), Color("80513e"), Color("bd9272"), Color("966448")]

static func _rect(art: RefCounted, x: float, y: float, width: float, height: float, color: Color) -> void:
	art.block(Rect2(x * PIXEL, y * PIXEL, width * PIXEL, height * PIXEL), color)

static func _face_rect(art: RefCounted, x: float, y: float, width: float, height: float, color: Color, facing: float) -> void:
	_rect(art, x if facing > 0 else 24.0 - x - width, y, width, height, color)

static func draw(art: RefCounted, pos: Vector2, unit: float, colonist: Dictionary, clock: float, facing: float) -> void:
	var canvas: CanvasItem = art.canvas
	canvas.draw_set_transform(pos, 0, Vector2.ONE * unit)
	var index := posmod(int(colonist.id), 4)
	var coat: Color = COATS[index]
	var shade: Color = SHADOWS[index]
	var highlight: Color = HIGHLIGHTS[index]
	var skin: Color = SKINS[index]
	var skin_shadow: Color = SKIN_SHADOWS[index]
	var path: Array = colonist.get("path", [])
	var walk_weight: float = colonist.get("visual_walk_weight", 1.0 if not path.is_empty() else 0.0)
	var work_weight: float = colonist.get("visual_work_weight", 0.0)
	var climb_weight: float = colonist.get("visual_climb_weight", 0.0)
	var phase: float = colonist.get("visual_phase", clock * 8.0 + index)
	var resting: bool = colonist.get("visual_resting", false)
	var digging := bool(colonist.get("visual_digging", false))
	var dig: Dictionary = DiggingMotion.pose(float(colonist.get("visual_dig_clock", 0.0)), Vector2(colonist.get("visual_dig_target", Vector2.RIGHT)), facing) if digging else {}
	var body: Vector2 = dig.body_offset if digging else Vector2.ZERO
	var stride := sin(phase) * 0.13 * walk_weight * (1.0 - climb_weight)
	var breath := sin(clock * 2.0 + index) * 0.012
	_rect(art, 4, 23, 16, 2, Color(0.05, 0.06, 0.12, 0.4))
	if not colonist.alive or resting:
		canvas.draw_set_transform(pos, 0, Vector2(1.6, 1.0) * unit)
		_resting(art, coat, shade, skin, skin_shadow, resting)
		canvas.draw_set_transform(Vector2.ZERO)
		return

	# Boots, knees and upper legs retain the distance-driven gait and climbing lift.
	for pair in [[0.37, stride, 0.0], [0.65, -stride, PI]]:
		var x: float = pair[0]
		var shift: float = pair[1]
		var lift := maxf(0.0, sin(phase + float(pair[2]))) * (0.055 * walk_weight + 0.2 * climb_weight)
		var hip := Vector2(x, 0.48) + body
		var knee := Vector2(x + shift * 0.7 + body.x * 0.5, 0.73 - lift * 0.5 + body.y * 0.5)
		var ankle := Vector2(x + shift, 0.91 - lift)
		art.stroke([hip, knee, ankle], INK, 5.0 * PIXEL)
		art.stroke([hip, knee, ankle], TROUSERS, 3.0 * PIXEL)
		art.block(Rect2(knee - Vector2(PIXEL, PIXEL), Vector2(2, 2) * PIXEL), shade)
		var foot := Vector2(x + shift - 3.0 * PIXEL, 22.0 * PIXEL - lift)
		art.block(Rect2(foot, Vector2(6, 3) * PIXEL), INK)
		art.block(Rect2(foot + Vector2(PIXEL, 0), Vector2(4, 2) * PIXEL), LEATHER)
		art.block(Rect2(foot + Vector2(PIXEL, 2.0 * PIXEL), Vector2(5, 1) * PIXEL), STEEL)

	if digging:
		art._digging_arm(dig, "back", shade)
	canvas.draw_set_transform(pos + body * unit, 0, Vector2.ONE * unit)
	# A square canvas pack, clipped shoulder corners and utility overalls form
	# a different silhouette from the previous round coat and leather cap.
	var pack_x := 1.0 if facing > 0 else 16.0
	_rect(art, pack_x, 0, 7, 11, INK)
	_rect(art, pack_x + 1, 1, 5, 8, LEATHER)
	_rect(art, pack_x + 1, 1, 4, 2, COPPER)
	_rect(art, pack_x + 3, 2, 1, 7, STEEL)
	_rect(art, 6, -1, 11, 2, INK)
	_rect(art, 5, 1, 13, 10, INK)
	_rect(art, 6, 11, 11, 2, INK)
	_rect(art, 6, 1, 11, 9, shade)
	_rect(art, 7, 1 + breath * 24.0, 8, 7, coat)
	_rect(art, 7, 1 + breath * 24.0, 6, 2, highlight)
	_rect(art, 8, 2, 1, 8, TROUSERS)
	_rect(art, 14, 2, 1, 8, TROUSERS)
	_rect(art, 9, 5, 5, 5, TROUSERS)
	_rect(art, 10, 6, 3, 2, shade)
	_rect(art, 6, 10, 11, 2, LEATHER)
	_rect(art, 11, 10, 2, 2, LIGHT)
	_rect(art, 15, 8, 2, 2, COPPER)

	var arm_tip := Vector2(0.82, 0.38 - stride)
	var swing := sin(clock * 5.0 + index)
	arm_tip = arm_tip.lerp(Vector2(0.8, 0.08 + sin(phase) * 0.24), climb_weight)
	var building_weight := work_weight if str(colonist.get("task", "")).begins_with("Building") else 0.0
	arm_tip = arm_tip.lerp(Vector2(0.87 + swing * 0.06, 0.02 + swing * 0.2), building_weight)
	var other_hand := Vector2(0.2, 0.36 + stride).lerp(Vector2(0.2, 0.08 - sin(phase) * 0.24), climb_weight)
	if not digging:
		art.stroke([Vector2(0.73, 0.04), Vector2(0.83, 0.2), arm_tip], INK, 5.0 * PIXEL)
		art.stroke([Vector2(0.73, 0.04), Vector2(0.83, 0.2), arm_tip], coat, 3.0 * PIXEL)
		art.block(Rect2(arm_tip - Vector2.ONE * PIXEL, Vector2(3, 3) * PIXEL), skin)
		art.stroke([Vector2(0.27, 0.06), Vector2(0.18, 0.2), other_hand], INK, 5.0 * PIXEL)
		art.stroke([Vector2(0.27, 0.06), Vector2(0.18, 0.2), other_hand], shade, 3.0 * PIXEL)
		art.block(Rect2(other_hand - Vector2.ONE * PIXEL, Vector2(3, 3) * PIXEL), skin_shadow)
	if building_weight > 0.001:
		art.stroke([arm_tip + Vector2(-0.08, 0.17), arm_tip + Vector2(0.15, -0.24)], Color(Color("a18c5c"), work_weight), 0.055)
		art.stroke([arm_tip + Vector2(0, -0.29), arm_tip + Vector2(0.15, -0.24), arm_tip + Vector2(0.31, -0.16)], Color(Color("b7c3b5"), work_weight), 0.08)

	# The whole helmet follows the same dodge as the face, keeping the already
	# verified pick/head clearance. Its outline remains inside the old cap bounds.
	var head_offset: Vector2 = Vector2(dig.head_offset) if digging else Vector2.ZERO
	canvas.draw_set_transform(pos + (body + head_offset + Vector2(0, breath)) * unit, 0, Vector2.ONE * unit)
	_rect(art, 7, -7, 10, 8, INK)
	_rect(art, 8, 1, 8, 1, INK)
	_rect(art, 8, -6, 8, 7, skin_shadow)
	_face_rect(art, 9, -5, 8, 5, skin, facing)
	_face_rect(art, 17, -3, 2, 2, skin_shadow, facing)
	_face_rect(art, 8, -5, 2, 4, LEATHER, facing)
	_face_rect(art, 10, -5, 7, 1, INK, facing)
	_face_rect(art, 14, -4, 2, 2, INK, facing)
	_face_rect(art, 14, -4, 1, 1, LIGHT, facing)
	_face_rect(art, 13, -1, 3, 1, skin_shadow, facing)
	_rect(art, 8, -12, 8, 1, INK)
	_rect(art, 6, -11, 12, 5, INK)
	_rect(art, 7, -10, 10, 3, shade)
	_rect(art, 8, -10, 7, 2, coat)
	_rect(art, 9, -10, 5, 1, highlight)
	_rect(art, 5, -7, 14, 2, INK)
	_rect(art, 6, -7, 12, 1, STEEL)
	_face_rect(art, 16, -10, 3, 3, INK, facing)
	_face_rect(art, 16, -9, 2, 2, COPPER, facing)
	_face_rect(art, 17, -9, 1, 1, LIGHT, facing)

	if digging:
		canvas.draw_set_transform(pos, 0, Vector2.ONE * unit)
		art._digging_arm(dig, "front", coat)
		art._digging_tool(dig, skin, work_weight)
	canvas.draw_set_transform(Vector2.ZERO)

static func _resting(art: RefCounted, coat: Color, shade: Color, skin: Color, skin_shadow: Color, asleep: bool) -> void:
	_rect(art, 3, 16, 18, 6, INK)
	_rect(art, 7, 17, 12, 4, shade)
	_rect(art, 8, 17, 9, 2, coat)
	_rect(art, 17, 19, 5, 3, TROUSERS)
	_rect(art, 20, 19, 3, 3, LEATHER)
	_rect(art, 2, 15, 6, 6, INK)
	_rect(art, 3, 16, 4, 4, skin_shadow)
	_rect(art, 3, 16, 3, 3, skin)
	_rect(art, 2, 15, 5, 2, shade)
	_rect(art, 3, 18, 2, 1, INK)
	if asleep:
		# A three-pixel Z is legible without a font or a soft arc.
		_rect(art, 4, 9, 3, 1, STEEL)
		_rect(art, 5, 10, 1, 1, STEEL)
		_rect(art, 4, 11, 3, 1, STEEL)
