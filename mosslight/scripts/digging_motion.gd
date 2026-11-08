extends RefCounted

## A presentation-only, two-handed pick swing. Coordinates are settler-local tiles.
## The pointed end lands on the job's rock face, not an arbitrary hand offset.
const CYCLE := 0.96
const CONTACT_PHASE := 0.52

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
	var strike_grip := contact - axis * 0.62 - normal * 0.25
	var ready_grip := Vector2(0.78, 0.35)
	var raised_grip := Vector2(0.45, -0.2)
	var windup_angle := -2.65
	var windup_body := Vector2(-0.075, -0.035)
	var impact_body := Vector2(0.11, 0.07)
	if target.y < 0.0 and absf(target.y) > absf(target.x):
		# Ceiling hits start below the face and swing upward into its underside.
		# An overhead wind-up would begin inside that rock and strike out of it.
		raised_grip = Vector2(0.6, 0.75)
		windup_angle = 0.45
		windup_body = Vector2(-0.035, 0.075)
		impact_body = Vector2(0.08, -0.055)
	var grip := ready_grip
	var angle := -1.15
	var body := Vector2.ZERO
	if phase < 0.32:
		var t := _ease(phase / 0.32)
		grip = ready_grip.lerp(raised_grip, t)
		angle = lerpf(-1.15, windup_angle, t)
		body = windup_body * t
	elif phase < CONTACT_PHASE:
		# Accelerate into the rock; a uniform sine reads as weightless waving.
		var t := pow((phase - 0.32) / 0.2, 1.8)
		angle = lerpf(windup_angle, strike_angle, t)
		var raised_axis := Vector2.from_angle(windup_angle)
		var raised_tip := raised_grip + raised_axis * 0.62 + Vector2(-raised_axis.y, raised_axis.x) * 0.25
		var control := Vector2(contact.x, raised_tip.y)
		if target.y < 0.0 and absf(target.y) > absf(target.x):
			control = Vector2(raised_tip.x, contact.y + 0.25)
		# Guide the pointed end into the face without an overshoot/reversal before
		# the contact beat. Solve both hands back along the rigid rotating shaft.
		var tip := raised_tip * (1.0 - t) * (1.0 - t) + control * 2.0 * (1.0 - t) * t + contact * t * t
		var swing_axis := Vector2.from_angle(angle)
		grip = tip - swing_axis * 0.62 - Vector2(-swing_axis.y, swing_axis.x) * 0.25
		body = windup_body.lerp(impact_body, t)
	elif phase < 0.59:
		grip = strike_grip
		angle = strike_angle
		body = impact_body
	elif phase < 0.72:
		var t := _ease((phase - 0.59) / 0.13)
		grip = strike_grip.lerp(strike_grip - axis * 0.12, t)
		angle = lerpf(strike_angle, strike_angle - 0.24, t)
		body = impact_body.lerp(Vector2(-0.025, 0.015), t)
	else:
		var t := _ease((phase - 0.72) / 0.28)
		grip = (strike_grip - axis * 0.12).lerp(ready_grip, t)
		angle = lerpf(strike_angle - 0.24, -1.15, t)
		body = Vector2(-0.025, 0.015).lerp(Vector2.ZERO, t)
	axis = Vector2.from_angle(angle)
	normal = Vector2(-axis.y, axis.x)
	var head := grip + axis * 0.62
	var pick := [head - normal * 0.24 - axis * 0.05, head - normal * 0.08 + axis * 0.025, head, head + normal * 0.25]
	var result := {"phase": phase, "body_offset": body, "hand_front": grip + axis * 0.08, "hand_back": grip - axis * 0.17, "shaft_bottom": grip - axis * 0.28, "shaft_top": head + axis * 0.055, "pick_points": pick, "tip": pick[-1], "contact": contact}
	if side < 0.0:
		for key in ["hand_front", "hand_back", "shaft_bottom", "shaft_top", "tip", "contact"]:
			result[key] = Vector2(1.0 - result[key].x, result[key].y)
		result.body_offset.x *= -1.0
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
