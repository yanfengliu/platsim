extends RefCounted

## A presentation-only, two-handed pick swing. Coordinates are settler-local tiles.
## The pointed end lands on the job's rock face, not an arbitrary hand offset.
const CYCLE := 0.96
const CONTACT_PHASE := 0.52
const UPPER_ARM := 0.36
const FOREARM := 0.35

static func _curve(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	return a * pow(1.0 - t, 3) + b * 3.0 * pow(1.0 - t, 2) * t + c * 3.0 * (1.0 - t) * t * t + d * t * t * t

static func _elbow(shoulder: Vector2, hand: Vector2, bend: float) -> Vector2:
	var reach := hand - shoulder
	var distance := maxf(reach.length(), 0.0001)
	var along := (UPPER_ARM * UPPER_ARM - FOREARM * FOREARM + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, UPPER_ARM * UPPER_ARM - along * along))
	var axis := reach / distance
	return shoulder + axis * along + Vector2(-axis.y, axis.x) * height * bend

static func _ease(value: float) -> float:
	return smoothstep(0.0, 1.0, clampf(value, 0.0, 1.0))

static func _rig(phase: float, target: Vector2, facing: float) -> Dictionary:
	var side := -1.0 if target.x < -0.1 else 1.0 if target.x > 0.1 else facing
	var local_target := Vector2(target.x * side, target.y)
	var contact := Vector2(local_target.x + 0.035, 0.42)
	var strike_angle := -0.18
	if absf(target.y) > absf(target.x):
		contact = Vector2(0.66, local_target.y + (0.035 if target.y > 0.0 else 0.92))
		strike_angle = 0.92 if target.y > 0.0 else -1.1
	var axis := Vector2.from_angle(strike_angle)
	var normal := Vector2(-axis.y, axis.x)
	var upward := target.y < 0.0 and absf(target.y) > absf(target.x)
	var horizontal := absf(target.x) >= absf(target.y)
	if upward:
		contact.x = 0.95
	var strike_grip := contact - axis * 0.62 - normal * 0.17
	var ready_grip := Vector2(0.78, 0.35)
	var raised_grip := Vector2(0.77, -0.39)
	var windup_angle := -2.4
	var windup_body := Vector2(-0.15 if horizontal else -0.12, -0.035)
	var impact_body := Vector2(0.03, 0.08) if horizontal else Vector2(0.05, 0.12)
	var head_ready := Vector2(-0.1, 0.0)
	var head_raised := Vector2(-0.17 if horizontal else -0.14, 0.06)
	var head_contact := Vector2(head_raised.x, -0.08)
	if upward:
		# Lean clear of the pick and lift into the underside of the ceiling.
		raised_grip = Vector2(0.72, 0.67)
		windup_angle = 0.45
		windup_body = Vector2(-0.12, 0.15)
		impact_body = Vector2(-0.27, 0.15)
		head_raised = Vector2(-0.1, 0.04)
		head_contact = head_raised
	var grip := ready_grip
	var angle := -1.15
	var body := Vector2.ZERO
	var head_offset := head_ready
	if phase < 0.32:
		var t := _ease(phase / 0.32)
		grip = ready_grip.lerp(raised_grip, t) if upward else _curve(ready_grip, Vector2(1.03, 0.15), Vector2(0.95, -0.25), raised_grip, t)
		angle = lerpf(-1.15, windup_angle, t)
		body = windup_body * t
		head_offset = head_ready.lerp(head_raised, t)
	elif phase < CONTACT_PHASE:
		# Author the common grip arc within both arms' reach. Moving a tip and
		# angle independently can otherwise pull the wrists away from the torso.
		var t := pow((phase - 0.32) / 0.2, 1.8)
		angle = lerpf(windup_angle, strike_angle, lerpf(t, _ease(t), 0.07 if upward else 0.7))
		grip = _curve(raised_grip, raised_grip, strike_grip, strike_grip, t) if upward else _curve(raised_grip, Vector2(0.85, -0.29), Vector2(0.42, 0.44), strike_grip, t)
		if horizontal:
			# Preserve an inward tip path while rotating around reachable hands.
			angle = _curve(Vector2(windup_angle, 0), Vector2(-1.52, 0), Vector2(-1.47, 0), Vector2(strike_angle, 0), t).x
			var raised_axis := Vector2.from_angle(windup_angle)
			var raised_tip := raised_grip + raised_axis * 0.62 + Vector2(-raised_axis.y, raised_axis.x) * 0.17
			var tip := raised_tip * (1.0 - t) * (1.0 - t) + Vector2(contact.x, raised_tip.y) * 2.0 * (1.0 - t) * t + contact * t * t
			var swing_axis := Vector2.from_angle(angle)
			grip = tip - swing_axis * 0.62 - Vector2(-swing_axis.y, swing_axis.x) * 0.17
		body = windup_body.lerp(impact_body, t)
		head_offset = head_raised.lerp(head_contact, t)
	elif phase < 0.59:
		grip = strike_grip
		angle = strike_angle
		body = impact_body
		head_offset = head_contact
	elif phase < 0.72:
		var t := _ease((phase - 0.59) / 0.13)
		grip = strike_grip.lerp(strike_grip - axis * 0.12, t)
		angle = lerpf(strike_angle, strike_angle - 0.24, t)
		body = impact_body if upward else impact_body.lerp(Vector2(-0.025, 0.015), t)
		head_offset = head_contact if upward else head_contact.lerp(head_ready, t)
	else:
		var t := _ease((phase - 0.72) / 0.28)
		grip = _curve(strike_grip - axis * 0.12, Vector2(0.78, 0.55), Vector2(0.95, 0.5), ready_grip, t)
		angle = lerpf(strike_angle - 0.24, -1.15, t)
		body = (impact_body if upward else Vector2(-0.025, 0.015)).lerp(Vector2.ZERO, t)
		head_offset = head_contact.lerp(head_ready, t) if upward else head_ready
	axis = Vector2.from_angle(angle)
	normal = Vector2(-axis.y, axis.x)
	var head := grip + axis * 0.62
	var pick := [head - normal * 0.15 - axis * 0.05, head - normal * 0.08 + axis * 0.025, head, head + normal * 0.17]
	var result := {"phase": phase, "body_offset": body, "head_offset": head_offset, "hand_front": grip + axis * 0.08, "hand_back": grip - axis * 0.17, "shaft_bottom": grip - axis * 0.28, "shaft_top": head + axis * 0.055, "pick_points": pick, "tip": pick[-1], "contact": contact}
	result.shoulder_front = (Vector2(0.5, 0.08) if upward else Vector2(0.45, 0.04)) + body
	# The shoulder girdle rises during the overhead stroke, then settles after recoil.
	# This keeps the rear wrist from passing directly through its shoulder socket.
	# The socket stays within the coat and the torso follows its authored motion.
	var shoulder_raise := _ease(phase / 0.32) * (1.0 - _ease((phase - 0.52) / 0.20)) if not upward else 0.0
	result.shoulder_back = Vector2(0.52, 0.18 - 0.20 * shoulder_raise) + body
	result.elbow_front = _elbow(result.shoulder_front, result.hand_front, 1.0)
	result.elbow_back = _elbow(result.shoulder_back, result.hand_back, -1.0)
	if side < 0.0:
		for key in ["shoulder_front", "shoulder_back", "elbow_front", "elbow_back", "hand_front", "hand_back", "shaft_bottom", "shaft_top", "tip", "contact"]:
			result[key] = Vector2(1.0 - result[key].x, result[key].y)
		result.body_offset.x *= -1.0
		result.head_offset.x *= -1.0
		for i in range(pick.size()):
			pick[i] = Vector2(1.0 - pick[i].x, pick[i].y)
	return result

static func pose(clock: float, target: Vector2, facing: float) -> Dictionary:
	var phase := fposmod(maxf(0.0, clock), CYCLE) / CYCLE
	var result := _rig(phase, target, facing)
	var age := (phase - CONTACT_PHASE) * CYCLE
	result.impact = maxf(0.0, 1.0 - age / 0.14) if age >= 0.0 else 0.0
	result.debris = []
	result.trail = []
	if phase > 0.4 and phase < CONTACT_PHASE:
		for i in range(5):
			result.trail.append(_rig(phase - float(i) * 0.012, target, facing).tip)
	if age >= 0.0 and age < 0.34:
		var outward := -target.normalized()
		var tangent := Vector2(-outward.y, outward.x)
		for i in range(6):
			var velocity := outward * (1.0 + float(i % 3) * 0.6) + tangent * (float(i) - 2.5) * 0.65 + Vector2.UP * 1.1
			result.debris.append({"position": result.contact + velocity * age + Vector2.DOWN * 3.4 * age * age, "radius": 0.025 + float(i % 3) * 0.009, "alpha": 1.0 - age / 0.34})
	return result
