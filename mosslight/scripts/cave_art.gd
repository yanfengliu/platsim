extends RefCounted

## Authored foreground forms. Every floor and wall follows authoritative solid cells.
var canvas: CanvasItem
const STONE := Color("3f5148")
const DEEP := Color("263e3a")
const EDGE := Color("8a9472")
const MOSS := Color("648359")
const PALE := Color("b8c98b")
const LIMESTONE = preload("res://assets/illustration/limestone.webp")
const DiggingMotion = preload("res://scripts/digging_motion.gd")

func _init(target: CanvasItem) -> void:
	canvas = target

func ellipse(center: Vector2, radius: Vector2, color: Color, steps: int = 20) -> void:
	var points := PackedVector2Array()
	for index in range(steps):
		var angle := TAU * index / steps
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	canvas.draw_colored_polygon(points, color)

func stroke(points: Array, color: Color, width: float) -> void:
	var path := PackedVector2Array()
	for point in points:
		path.append(point)
	canvas.draw_polyline(path, color, width, true)
	canvas.draw_circle(path[0], width * 0.5, color)
	canvas.draw_circle(path[-1], width * 0.5, color)

func leaf(base: Vector2, tip: Vector2, width: float, color: Color) -> void:
	var direction := tip - base
	var normal := Vector2(-direction.y, direction.x).normalized() * width
	var middle := base + direction * 0.48
	canvas.draw_colored_polygon(PackedVector2Array([base, middle + normal, tip, middle - normal]), color)
	canvas.draw_line(base, tip, color.lightened(0.14), width * 0.16, true)

func curved_stroke(start: Vector2, control_a: Vector2, control_b: Vector2, end: Vector2, color: Color, width: float) -> void:
	var points := []
	for index in range(13):
		var t := index / 12.0
		var inverse := 1.0 - t
		points.append(start * inverse * inverse * inverse + control_a * 3.0 * inverse * inverse * t + control_b * 3.0 * inverse * t * t + end * t * t * t)
	stroke(points, color, width)

func rock(cell: Vector2i, pos: Vector2, unit: float, kind: int, exposed: Vector4) -> void:
	canvas.draw_set_transform(pos, 0, Vector2.ONE * unit)
	# One painting spans eight cells in each direction, sampled in world coordinates.
	# Digging changes the authoritative mask without moving or restarting the strata.
	var texture_step := LIMESTONE.get_width() / 8.0
	var source := Rect2(posmod(cell.x, 8) * texture_step, posmod(cell.y, 8) * texture_step, texture_step, texture_step)
	canvas.draw_texture_rect_region(LIMESTONE, Rect2(0, 0, 1, 1), source, Color(0.68, 0.78, 0.69, 1))
	var seed_value := posmod(cell.x * 47 + cell.y * 29, 17)
	if exposed.x > 0: # Ground surface.
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-0.02, 0), Vector2(0.18, -0.025), Vector2(0.43, 0.015), Vector2(0.72, -0.01), Vector2(1.02, 0), Vector2(1.0, 0.2), Vector2(0.74, 0.24), Vector2(0.46, 0.17), Vector2(0.2, 0.22), Vector2(0, 0.15)]), Color("737f62"))
		stroke([Vector2(-0.01, 0), Vector2(0.22, -0.015), Vector2(0.5, 0.01), Vector2(0.8, -0.02), Vector2(1.01, 0)], EDGE, 0.055)
		for i in range(5):
			var x := 0.06 + i * 0.21
			ellipse(Vector2(x, 0.025), Vector2(0.16, 0.06), MOSS)
			ellipse(Vector2(x + 0.03, -0.015), Vector2(0.11, 0.025), Color("8a9f6b"))
	if exposed.y > 0: # Ceiling, with the shadowed underside of a limestone shelf.
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, 0.82), Vector2(0.3, 0.9), Vector2(0.61, 0.78), Vector2(1, 0.86), Vector2(1, 1.02), Vector2(0.77, 1), Vector2(0.55, 1.13), Vector2(0.3, 0.98), Vector2(0, 1.02)]), DEEP)
		stroke([Vector2(0, 0.9), Vector2(0.34, 0.95), Vector2(0.62, 0.87), Vector2(1, 0.96)], Color("536652"), 0.035)
	if exposed.z > 0:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(0.11, 0.13), Vector2(0.07, 0.43), Vector2(0.16, 0.71), Vector2(0.08, 1), Vector2(-0.015, 1)]), Color("71806a"))
		stroke([Vector2(0.015, 0), Vector2(0.025, 0.3), Vector2(-0.015, 0.65), Vector2(0.02, 1)], Color("a0a082"), 0.035)
	if exposed.w > 0:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(0.81, 0), Vector2(0.91, 0.28), Vector2(0.82, 0.62), Vector2(0.93, 1), Vector2(1.02, 1), Vector2(1.01, 0)]), DEEP)
		stroke([Vector2(0.98, 0), Vector2(0.96, 0.42), Vector2(1.01, 0.78), Vector2(0.97, 1)], Color("5b6a54"), 0.035)
	if kind == 2:
		for i in range(3):
			var center := Vector2(0.28 + i * 0.23, 0.47 + sin(i * 3.0 + cell.y) * 0.14)
			ellipse(center + Vector2(0.01, 0.025), Vector2(0.155, 0.13), Color("394b40"), 9)
			ellipse(center, Vector2(0.13, 0.11), Color("a99a76"), 7)
			ellipse(center + Vector2(-0.025, -0.045), Vector2(0.085, 0.04), Color("cebb8f"), 7)
			canvas.draw_line(center + Vector2(-0.04, 0.04), center + Vector2(0.07, -0.04), Color("7d785a"), 0.02, true)
	elif kind == 3:
		var sway := seed_value * 0.015
		curved_stroke(Vector2(0.14, 0.15), Vector2(0.8, 0.1), Vector2(0.05, 0.82), Vector2(0.86, 0.81), Color("4c4e35"), 0.11)
		curved_stroke(Vector2(0.14, 0.14), Vector2(0.8, 0.09), Vector2(0.05, 0.8), Vector2(0.86, 0.79), Color("948459"), 0.055)
		curved_stroke(Vector2(0.51, 0.38), Vector2(0.8, 0.4 + sway), Vector2(0.9, 0.2), Vector2(0.86, 0.1), Color("a18e5f"), 0.033)
		curved_stroke(Vector2(0.45, 0.63), Vector2(0.2, 0.58), Vector2(0.1, 0.79), Vector2(0.18, 0.92), Color("8c8056"), 0.03)
		leaf(Vector2(0.69, 0.32), Vector2(0.87, 0.13), 0.085, Color("8f9e66"))
	elif kind == 4:
		ellipse(Vector2(0.5, 0.52), Vector2(0.3, 0.37), Color(0.16, 0.3, 0.28, 0.35))
		curved_stroke(Vector2(0.3, 0.18), Vector2(0.57, 0.35), Vector2(0.25, 0.6), Vector2(0.65, 0.82), Color("467b79"), 0.065)
		curved_stroke(Vector2(0.3, 0.18), Vector2(0.57, 0.35), Vector2(0.25, 0.6), Vector2(0.65, 0.82), Color("9ab7a8"), 0.016)
	canvas.draw_set_transform(Vector2.ZERO)

func ground_growth(cell: Vector2i, pos: Vector2, unit: float, occupied: bool) -> void:
	canvas.draw_set_transform(pos, 0, Vector2.ONE * unit)
	var seed_value := posmod(cell.x * 23 + cell.y * 37, 11)
	if not occupied and seed_value < 5:
		fern(Vector2(0.5, 0.04), 0.32 + seed_value * 0.045, seed_value * 0.2)
	elif not occupied and seed_value < 8:
		mushroom(Vector2(0.35, 0), 0.43, Color("d8a763"))
		mushroom(Vector2(0.7, 0.015), 0.27, Color("a7bc81"))
	else:
		for i in range(3):
			var x := 0.13 + i * 0.32
			leaf(Vector2(x, 0.02), Vector2(x - 0.1, -0.13), 0.035, MOSS)
			leaf(Vector2(x, 0.02), Vector2(x + 0.07, -0.18), 0.035, Color("9aaf74"))
	canvas.draw_set_transform(Vector2.ZERO)

func ceiling_growth(cell: Vector2i, pos: Vector2, unit: float) -> void:
	if posmod(cell.x * 17 + cell.y * 31, 5) > 1:
		return
	canvas.draw_set_transform(pos, 0, Vector2.ONE * unit)
	var length := 0.6 + posmod(cell.x * 7, 6) * 0.15
	stroke([Vector2(0.25, 0.92), Vector2(0.34, 1.22), Vector2(0.21, 1.5), Vector2(0.4, 1.0 + length)], Color("556a49"), 0.045)
	for i in range(4):
		var anchor := Vector2(0.3, 1.1 + i * length * 0.21)
		leaf(anchor, anchor + Vector2(-0.16, 0.19), 0.08, Color("6f8957"))
		leaf(anchor, anchor + Vector2(0.19, 0.13), 0.07, Color("899c63"))
	canvas.draw_set_transform(Vector2.ZERO)

func fern(base: Vector2, scale_value: float, phase: float = 0) -> void:
	for branch in range(5):
		var angle := -PI * 0.5 + (branch - 2) * 0.43
		var tip := base + Vector2(cos(angle), sin(angle)) * scale_value * (1.0 - absf(branch - 2) * 0.1)
		stroke([base, base.lerp(tip, 0.45) + Vector2(0.03 * sin(phase), 0), tip], Color("657f4c"), 0.025)
		for i in range(1, 5):
			var anchor := base.lerp(tip, i / 6.0)
			var direction := (tip - base).normalized()
			var normal := Vector2(-direction.y, direction.x)
			var length := scale_value * (0.29 - i * 0.035)
			leaf(anchor, anchor + normal * length + direction * 0.1, length * 0.24, Color("9bab69") if branch % 2 == 0 else Color("719561"))
			leaf(anchor, anchor - normal * length + direction * 0.1, length * 0.24, Color("b1be7d") if branch % 2 == 0 else Color("88a56a"))

func mushroom(base: Vector2, height: float, cap: Color) -> void:
	stroke([base, base + Vector2(-height * 0.04, -height * 0.4), base + Vector2(height * 0.03, -height * 0.78)], Color("a2a37c"), height * 0.13)
	ellipse(base + Vector2(0, -height * 0.76), Vector2(height * 0.38, height * 0.11), Color("736b49"))
	ellipse(base + Vector2(0, -height * 0.87), Vector2(height * 0.42, height * 0.23), cap)
	ellipse(base + Vector2(-height * 0.1, -height * 0.96), Vector2(height * 0.24, height * 0.09), cap.lightened(0.25))
	for i in range(3):
		canvas.draw_circle(base + Vector2((i - 1) * height * 0.15, -height * 0.9), height * 0.025, Color("f3db9b"))

func ladder(pos: Vector2, unit: float) -> void:
	canvas.draw_set_transform(pos, 0, Vector2.ONE * unit)
	for x in [0.26, 0.74]:
		stroke([Vector2(x, -0.03), Vector2(x - 0.02, 0.45), Vector2(x, 1.03)], Color("504a35"), 0.11)
		stroke([Vector2(x - 0.02, -0.03), Vector2(x - 0.03, 0.45), Vector2(x - 0.02, 1.03)], Color("b7a36d"), 0.036)
	for i in range(3):
		var y := 0.15 + i * 0.34
		stroke([Vector2(0.21, y), Vector2(0.52, y - 0.015), Vector2(0.79, y + 0.02)], Color("7b7150"), 0.1)
		canvas.draw_line(Vector2(0.25, y - 0.025), Vector2(0.75, y - 0.025), Color("d1bd82"), 0.025, true)
		for x in [0.27, 0.73]:
			stroke([Vector2(x - 0.05, y - 0.07), Vector2(x + 0.045, y + 0.07)], Color("c2b58a"), 0.028)
	canvas.draw_set_transform(Vector2.ZERO)

func settler(pos: Vector2, unit: float, colonist: Dictionary, clock: float, facing: float) -> void:
	canvas.draw_set_transform(pos, 0, Vector2.ONE * unit)
	var index := int(colonist.id) % 4
	var coat: Color = [Color("c9a46b"), Color("69a9a7"), Color("b97e80"), Color("a1ad73")][index]
	var skin: Color = [Color("e1b58b"), Color("b68161"), Color("e6c3a0"), Color("c89f78")][index]
	var hair: Color = [Color("72513c"), Color("3d3631"), Color("8e6146"), Color("5c4939")][index]
	var path: Array = colonist.get("path", [])
	var walk_weight: float = colonist.get("visual_walk_weight", 1.0 if not path.is_empty() else 0.0)
	var work_weight: float = colonist.get("visual_work_weight", 0.0)
	var climb_weight: float = colonist.get("visual_climb_weight", 0.0)
	var phase: float = colonist.get("visual_phase", clock * 8.0 + index)
	var resting: bool = colonist.get("visual_resting", false)
	var digging := bool(colonist.get("visual_digging", false))
	var dig := DiggingMotion.pose(float(colonist.get("visual_dig_clock", 0.0)), Vector2(colonist.get("visual_dig_target", Vector2.RIGHT)), facing) if digging else {}
	var body: Vector2 = dig.body_offset if digging else Vector2.ZERO
	var stride := sin(phase) * 0.13 * walk_weight * (1.0 - climb_weight)
	var breath := sin(clock * 2.0 + index) * 0.012
	ellipse(Vector2(0.5, 0.99), Vector2(0.37, 0.075), Color(0.03, 0.08, 0.07, 0.48))
	if not colonist.alive or resting:
		ellipse(Vector2(0.5, 0.78), Vector2(0.42, 0.15), coat.darkened(0.1))
		ellipse(Vector2(0.17, 0.7), Vector2(0.17, 0.17), skin)
		stroke([Vector2(0.09, 0.72), Vector2(0.19, 0.73)], hair, 0.025)
		if resting:
			canvas.draw_arc(Vector2(0.2, 0.38), 0.08, 0.3, 3.0, 8, Color("c3ddbd"), 0.025, true)
		canvas.draw_set_transform(Vector2.ZERO)
		return
	# Distance drives the gait, so faster travel does not slide over a slow foot cycle.
	for pair in [[0.37, stride, 0.0], [0.65, -stride, PI]]:
		var x: float = pair[0]
		var shift: float = pair[1]
		var lift := maxf(0.0, sin(phase + float(pair[2]))) * (0.055 * walk_weight + 0.2 * climb_weight)
		stroke([Vector2(x, 0.48) + body, Vector2(x + shift * 0.7 + body.x * 0.5, 0.73 - lift * 0.5 + body.y * 0.5), Vector2(x + shift, 0.91 - lift)], Color("314b46"), 0.17)
		stroke([Vector2(x - 0.025, 0.51) + body, Vector2(x + shift * 0.7 - 0.025 + body.x * 0.5, 0.73 - lift * 0.5 + body.y * 0.5), Vector2(x + shift - 0.025, 0.86 - lift)], coat.darkened(0.18), 0.09)
		ellipse(Vector2(x + shift + facing * 0.045, 0.94 - lift), Vector2(0.14, 0.075), Color("403c31"))
		canvas.draw_line(Vector2(x + shift - 0.09, 0.98 - lift), Vector2(x + shift + 0.11, 0.98 - lift), Color("aa9c76"), 0.025, true)
	if digging:
		_digging_arm(dig, "back", coat.darkened(0.18))
	# The pack, straps, shaped coat, belt and pockets have their own materials.
	canvas.draw_set_transform(pos + body * unit, 0, Vector2.ONE * unit)
	ellipse(Vector2(0.5 - facing * 0.26, 0.22), Vector2(0.19, 0.29), Color("3c5144"))
	ellipse(Vector2(0.49 - facing * 0.28, 0.18), Vector2(0.15, 0.23), Color("998963"))
	ellipse(Vector2(0.5, 0.2 + breath), Vector2(0.3, 0.36), coat.darkened(0.28))
	ellipse(Vector2(0.48, 0.15 + breath), Vector2(0.255, 0.31), coat)
	ellipse(Vector2(0.41, 0.06 + breath), Vector2(0.13, 0.19), coat.lightened(0.15))
	stroke([Vector2(0.34, -0.04), Vector2(0.4, 0.42)], Color("76664c"), 0.065)
	stroke([Vector2(0.65, -0.04), Vector2(0.62, 0.42)], Color("76664c"), 0.065)
	stroke([Vector2(0.25, 0.42), Vector2(0.5, 0.45), Vector2(0.76, 0.42)], Color("60503b"), 0.08)
	canvas.draw_rect(Rect2(0.46, 0.405, 0.1, 0.085), Color("d6bd7c"))
	ellipse(Vector2(0.68, 0.37), Vector2(0.09, 0.12), coat.darkened(0.18))
	# Walking, climbing and building keep their existing relaxed arm poses.
	var arm_tip := Vector2(0.82, 0.38 - stride)
	var swing := sin(clock * 5.0 + index)
	arm_tip = arm_tip.lerp(Vector2(0.8, 0.08 + sin(phase) * 0.24), climb_weight)
	var building_weight := work_weight if str(colonist.get("task", "")).begins_with("Building") else 0.0
	arm_tip = arm_tip.lerp(Vector2(0.87 + swing * 0.06, 0.02 + swing * 0.2), building_weight)
	var other_hand := Vector2(0.2, 0.36 + stride).lerp(Vector2(0.2, 0.08 - sin(phase) * 0.24), climb_weight)
	if not digging:
		stroke([Vector2(0.73, 0.04), Vector2(0.83, 0.2), arm_tip], coat.darkened(0.1), 0.15)
		ellipse(arm_tip, Vector2(0.09, 0.09), skin)
		stroke([Vector2(0.27, 0.06), Vector2(0.18, 0.2), other_hand], coat.darkened(0.18), 0.14)
		ellipse(other_hand, Vector2(0.075, 0.08), skin)
	if building_weight > 0.001:
		stroke([arm_tip + Vector2(-0.08, 0.17), arm_tip + Vector2(0.15, -0.24)], Color(Color("a18c5c"), work_weight), 0.055)
		stroke([arm_tip + Vector2(0, -0.29), arm_tip + Vector2(0.15, -0.24), arm_tip + Vector2(0.31, -0.16)], Color(Color("b7c3b5"), work_weight), 0.08)
	if digging:
		canvas.draw_set_transform(pos + (body + Vector2(dig.head_offset)) * unit, 0, Vector2.ONE * unit)
	# Large faces remain readable when zoomed out, with cheek, nose and eye highlights.
	ellipse(Vector2(0.5, -0.18 + breath), Vector2(0.25, 0.26), hair)
	ellipse(Vector2(0.51 + facing * 0.025, -0.15 + breath), Vector2(0.225, 0.24), skin)
	ellipse(Vector2(0.42, -0.2 + breath), Vector2(0.13, 0.17), skin.lightened(0.12))
	ellipse(Vector2(0.5 + facing * 0.23, -0.13 + breath), Vector2(0.07, 0.055), skin.darkened(0.06))
	var eye_x := 0.5 + facing * 0.13
	ellipse(Vector2(eye_x, -0.2 + breath), Vector2(0.025, 0.04), Color("273d36"))
	canvas.draw_circle(Vector2(eye_x - 0.007, -0.215 + breath), 0.009, Color("fff2d5"))
	ellipse(Vector2(eye_x, -0.07 + breath), Vector2(0.06, 0.028), Color("cf9179"))
	stroke([Vector2(eye_x - 0.035, -0.29 + breath), Vector2(eye_x + 0.04, -0.28 + breath)], hair, 0.025)
	# Leather exploration cap, stitched brim, copper headlamp and warm glass.
	ellipse(Vector2(0.49, -0.36 + breath), Vector2(0.27, 0.16), coat.darkened(0.23))
	ellipse(Vector2(0.45, -0.4 + breath), Vector2(0.21, 0.1), coat.lightened(0.1))
	stroke([Vector2(0.23, -0.3 + breath), Vector2(0.52, -0.29 + breath), Vector2(0.79, -0.31 + breath)], Color("8b704e"), 0.055)
	var lamp := Vector2(0.5 + facing * 0.22, -0.35 + breath)
	ellipse(lamp, Vector2(0.09, 0.095), Color("766349"))
	ellipse(lamp, Vector2(0.06, 0.065), Color("f2d69d"))
	canvas.draw_circle(lamp + Vector2(-0.015, -0.025), 0.028, Color("fff4cc"))
	if digging:
		canvas.draw_set_transform(pos, 0, Vector2.ONE * unit)
		_digging_arm(dig, "front", coat)
		_digging_tool(dig, skin, work_weight)
	canvas.draw_set_transform(Vector2.ZERO)

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
