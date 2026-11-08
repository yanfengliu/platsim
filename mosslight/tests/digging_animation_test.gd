extends SceneTree

const Motion = preload("res://scripts/presentation_motion.gd")
const Digging = preload("res://scripts/digging_motion.gd")
const WOOD := Color("a18c5c")
const METAL := Color("b7c3b5")
const DIRECTIONS: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
var checks: int = 0
var failures: Array[String] = []

## Invoke the actual production artist inside a valid draw callback. The dynamic
## subclass records strokes/ellipses, then still calls their production methods.
class DrawProbe extends Node2D:
	var art: RefCounted
	var frames: Array = []
	var results: Array = []
	func _draw() -> void:
		results.clear()
		for frame in frames:
			art.recorded_strokes.clear()
			art.recorded_ellipses.clear()
			art.settler(Vector2.ZERO, 1.0, frame.actor, frame.clock, frame.facing)
			results.append({"strokes": art.recorded_strokes.duplicate(true), "ellipses": art.recorded_ellipses.duplicate(true)})

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func _run() -> void:
	var legacy: String = ""
	var approach_source: Script = Digging
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--legacy-art="):
			legacy = argument.trim_prefix("--legacy-art=")
		if argument.begins_with("--legacy-digging="):
			approach_source = load(argument.trim_prefix("--legacy-digging="))
	if "--strike-approach-only" in OS.get_cmdline_user_args():
		_test_strike_approach(approach_source)
		print("Mosslight digging approach: %d checks, %d failures" % [checks, failures.size()])
		quit(0 if failures.is_empty() else 1)
		return
	if legacy.is_empty():
		_test_rig()
		_test_strike_approach(Digging)
		_test_lifecycle()
	await _test_actual_art("res://scripts/cave_art.gd" if legacy.is_empty() else legacy, not legacy.is_empty())
	print("Mosslight digging%s: %d checks, %d failures" % [" legacy art" if not legacy.is_empty() else "", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _actor(position: Vector2 = Vector2(4, 4)) -> Dictionary:
	return {"id": 0, "pos": position, "alive": true, "resting": false, "task": "Digging", "job": 7, "path": [], "health": 100.0}

func _job(cell: Vector2i = Vector2i(5, 4), id: int = 7) -> Dictionary:
	return {"id": id, "kind": "dig", "cell": cell, "assigned": 0, "progress": 0.1}

func _point_on_segment(point: Vector2, start: Vector2, end: Vector2) -> bool:
	var along: Vector2 = end - start
	var t: float = (point - start).dot(along) / along.length_squared()
	return t > 0.02 and t < 0.98 and point.distance_to(start + along * t) < 0.00001

func _angular_span(vectors: Array) -> float:
	var result: float = 0.0
	for a in vectors:
		for b in vectors:
			result = maxf(result, absf(Vector2(a).angle_to(Vector2(b))))
	return result

func _excursion(points: Array) -> float:
	var result: float = 0.0
	for a in points:
		for b in points:
			result = maxf(result, Vector2(a).distance_to(Vector2(b)))
	return result

func _on_target_face(contact: Vector2, target: Vector2) -> bool:
	# A small stone inset is intentional; the tangential contact point is an art
	# choice. This checks the real neighboring tile, not the rig's own formula.
	if target.x != 0.0:
		return absf(contact.x - (1.0 if target.x > 0.0 else 0.0)) <= 0.10 and contact.y >= 0.0 and contact.y <= 1.0
	return absf(contact.y - (1.0 if target.y > 0.0 else 0.0)) <= 0.10 and contact.x >= 0.0 and contact.x <= 1.0

func _test_rig() -> void:
	for direction in DIRECTIONS:
		var vectors: Array = []
		var tips: Array = []
		var rigid: bool = true
		var grips: bool = true
		var bounded: bool = true
		var phases: bool = true
		var length: float = -1.0
		var previous: Dictionary = {}
		var continuous: bool = true
		var debris_seen: bool = false
		var trail_seen: bool = false
		for index in range(121):
			var clock: float = Digging.CYCLE * index / 120.0
			var pose: Dictionary = Digging.pose(clock, direction, signf(direction.x) if direction.x != 0.0 else 1.0)
			var shaft: Vector2 = pose.shaft_top - pose.shaft_bottom
			vectors.append(shaft.normalized())
			tips.append(pose.tip)
			if length < 0.0:
				length = shaft.length()
			rigid = rigid and absf(shaft.length() - length) < 0.00001 and length > 0.5 and length < 1.3
			grips = grips and _point_on_segment(pose.hand_front, pose.shaft_bottom, pose.shaft_top) and _point_on_segment(pose.hand_back, pose.shaft_bottom, pose.shaft_top) and Vector2(pose.hand_front).distance_to(pose.hand_back) > 0.15
			phases = phases and pose.phase >= 0.0 and pose.phase < 1.0 and pose.tip == pose.pick_points[-1]
			bounded = bounded and pose.debris.size() <= 8 and pose.trail.size() <= 8 and pose.impact >= 0.0 and pose.impact <= 1.0
			for particle in pose.debris:
				bounded = bounded and particle.radius > 0.0 and particle.radius < 0.08 and particle.alpha >= 0.0 and particle.alpha <= 1.0 and Vector2(particle.position).distance_to(pose.contact) < 1.3
			debris_seen = debris_seen or not pose.debris.is_empty()
			trail_seen = trail_seen or not pose.trail.is_empty()
			if not previous.is_empty():
				var tip_step: float = Vector2(previous.tip).distance_to(pose.tip)
				if tip_step >= 0.25:
					print("Dig continuity %s: phase %.5f to %.5f moves %.5f tiles" % [direction, previous.phase, pose.phase, tip_step])
				continuous = continuous and tip_step < 0.25
			previous = pose
		check(_angular_span(vectors) > PI / 3.0, "%s pick rotates through a broad swing instead of translating a frozen angle" % direction)
		check(_excursion(tips) > 0.5, "%s pick travels a visible windup-to-contact distance" % direction)
		check(rigid and grips, "%s shaft stays rigid with two distinct hands attached throughout the cycle" % direction)
		check(phases and continuous, "%s phase wraps cleanly and tip motion stays below a quarter tile per sampled frame" % direction)
		check(bounded and debris_seen and trail_seen, "%s finite bounded debris and strike trail occur within the cycle" % direction)
		var windup: Dictionary = Digging.pose(Digging.CYCLE * 0.30, direction, 1.0)
		var strike: Dictionary = Digging.pose(Digging.CYCLE * 0.47, direction, 1.0)
		var contact: Dictionary = Digging.pose(Digging.CYCLE * 0.55, direction, 1.0)
		var late: Dictionary = Digging.pose(Digging.CYCLE * 0.94, direction, 1.0)
		check(_on_target_face(contact.contact, direction) and Vector2(contact.tip).distance_to(contact.contact) < 0.00001, "%s pointed end lands on the selected rock face during contact" % direction)
		check(windup.impact == 0.0 and windup.debris.is_empty() and windup.trail.is_empty() and strike.impact == 0.0 and strike.debris.is_empty() and not strike.trail.is_empty(), "%s windup and airborne strike cannot emit a premature impact" % direction)
		check(contact.impact > 0.0 and not contact.debris.is_empty() and contact.trail.is_empty() and late.impact == 0.0 and late.debris.is_empty(), "%s impact debris starts at contact and expires before the next swing" % direction)
		check(Vector2(windup.body_offset).distance_to(contact.body_offset) > 0.08, "%s body shifts its weight from windup into the strike" % direction)
		var early_a: Dictionary = Digging.pose(Digging.CYCLE * 0.34, direction, 1.0)
		var early_b: Dictionary = Digging.pose(Digging.CYCLE * 0.38, direction, 1.0)
		var late_a: Dictionary = Digging.pose(Digging.CYCLE * 0.46, direction, 1.0)
		var late_b: Dictionary = Digging.pose(Digging.CYCLE * 0.50, direction, 1.0)
		check(Vector2(late_a.tip).distance_to(late_b.tip) > Vector2(early_a.tip).distance_to(early_b.tip) * 1.4, "%s strike accelerates toward the rock" % direction)
	var mirrored: bool = true
	for phase in [0.0, 0.18, 0.41, 0.55, 0.68, 0.9]:
		var right: Dictionary = Digging.pose(phase * Digging.CYCLE, Vector2.RIGHT, 1.0)
		var left: Dictionary = Digging.pose(phase * Digging.CYCLE, Vector2.LEFT, -1.0)
		for key in ["tip", "contact", "hand_front", "hand_back", "shaft_top", "shaft_bottom"]:
			mirrored = mirrored and Vector2(left[key]).distance_to(Vector2(1.0 - right[key].x, right[key].y)) < 0.00001
	check(mirrored, "left-facing digging mirrors both grips, the pick arc and rock contact")

func _test_strike_approach(rig: Script) -> void:
	# The selected tile supplies its own inward normal and face plane. Checking
	# these world-space facts independently catches a swing that starts inside a
	# ceiling and exits down through it, even when its tip ends at the right point.
	for direction in DIRECTIONS:
		for facing in [-1.0, 1.0]:
			var face: Vector2 = Vector2(0.5, 0.5) + direction * 0.5
			var windup: Dictionary = rig.pose(rig.CYCLE * 0.32, direction, facing)
			var airborne: Dictionary = rig.pose(rig.CYCLE * 0.40, direction, facing)
			var windup_depth: float = (Vector2(windup.tip) - face).dot(direction)
			var airborne_depth: float = (Vector2(airborne.tip) - face).dot(direction)
			check(windup_depth < -0.1, "%s facing %.0f winds up on the open side of the selected rock face" % [direction, facing])
			check(airborne_depth < 0.0, "%s facing %.0f begins its strike outside the target rock" % [direction, facing])
			var previous: Vector2 = rig.pose(rig.CYCLE * 0.48, direction, facing).tip
			var inward: bool = true
			var smallest_inward_step: float = INF
			for phase in [0.49, 0.50, 0.51, 0.52]:
				var tip: Vector2 = rig.pose(rig.CYCLE * phase, direction, facing).tip
				var step: float = (tip - previous).dot(direction)
				smallest_inward_step = minf(smallest_inward_step, step)
				inward = inward and step > 0.001
				previous = tip
			check(inward, "%s facing %.0f final strike moves into the rock along its inward normal" % [direction, facing])
			print("Dig approach %s facing %.0f: windup depth %.3f, early-strike depth %.3f, minimum inward step %.3f" % [direction, facing, windup_depth, airborne_depth, smallest_inward_step])

func _test_lifecycle() -> void:
	for fps in [60, 120]:
		for speed in [1.0, 3.0]:
			var actor: Dictionary = _actor()
			var jobs: Array = [_job()]
			var actors: Array = [actor]
			var before: Array = [actors.duplicate(true), jobs.duplicate(true)]
			var helper = Motion.new()
			helper.reset(actors, jobs)
			var accumulator: float = 0.0
			var smooth: bool = true
			var last_clock: float = 0.0
			for frame in range(fps):
				accumulator += speed / fps
				while accumulator + 0.0000001 >= 0.1:
					helper.begin_step(actors, jobs)
					helper.end_step(actors, jobs)
					accumulator = maxf(0.0, accumulator - 0.1)
				helper.present(accumulator / 0.1, 1.0 / fps, speed, true)
				var pose: Dictionary = helper.pose(actor)
				smooth = smooth and pose.visual_digging and absf(pose.visual_dig_clock - last_clock - speed / fps) < 0.00001
				last_clock = pose.visual_dig_clock
			check(smooth and absf(last_clock - speed) < 0.00001, "%d fps %.0fx digging advances continuously at simulation speed between 10 Hz samples" % [fps, speed])
			check(actors == before[0] and jobs == before[1], "%d fps %.0fx presentation leaves authoritative actors and jobs untouched" % [fps, speed])
			var frozen: Dictionary = helper.pose(actor)
			for frame in range(15):
				helper.present(0.0, 1.0 / fps, speed, false)
			check(helper.pose(actor) == frozen, "%d fps %.0fx pause freezes the exact digging pose and job clock" % [fps, speed])
			helper.present(accumulator / 0.1, 1.0 / fps, speed, true)
			check(absf(helper.pose(actor).visual_dig_clock - last_clock - speed / fps) < 0.00001, "%d fps %.0fx resume advances one ordinary frame without catch-up" % [fps, speed])
	var actor: Dictionary = _actor()
	var actors: Array = [actor]
	var jobs: Array = [_job()]
	var helper = Motion.new()
	helper.reset(actors, jobs)
	helper.present(1.0, 0.2, 1.0, true)
	check(helper.pose(actor).visual_dig_target == Vector2.RIGHT, "digging targets the assigned job relative to the rendered worker")
	helper.begin_step(actors, jobs)
	actor.job = 8
	jobs = [_job(Vector2i(3, 4), 8)]
	helper.end_step(actors, jobs)
	check(helper.pose(actor).visual_dig_clock == 0.0, "switching to another dig job starts a new windup")
	helper.present(1.0, 0.01, 1.0, true)
	check(helper.pose(actor).visual_dig_target == Vector2.LEFT and helper.pose(actor).visual_facing == -1.0, "new job retargets and faces the selected rock")
	helper.reset(actors, jobs)
	check(helper.pose(actor).visual_dig_clock == 0.0 and not helper.pose(actor).visual_digging, "colony reset starts without a stale swing or impact")
	for suppression in ["travel", "rest", "death", "reduced", "cancel", "build"]:
		actor = _actor()
		actors = [actor]
		jobs = [_job()]
		helper.reset(actors, jobs)
		helper.present(1.0, 0.2, 1.0, true)
		helper.begin_step(actors, jobs)
		match suppression:
			"travel": actor.path = [Vector2i(5, 4)]
			"rest": actor.resting = true; actor.task = "Resting"
			"death": actor.alive = false
			"cancel": jobs.clear()
			"build": jobs[0].kind = "build"; actor.task = "Building lamp"
		helper.end_step(actors, jobs)
		helper.present(1.0, 0.05, 1.0, true, suppression == "reduced")
		check(not helper.pose(actor).visual_digging, "%s suppresses digging and its impact immediately" % suppression)
		var stopped: float = helper.pose(actor).visual_dig_clock
		helper.present(1.0, 0.05, 3.0, true, suppression == "reduced")
		check(helper.pose(actor).visual_dig_clock == stopped, "%s cannot advance a hidden digging clock" % suppression)
	actor = _actor(Vector2(3.9, 4))
	actor.task = "Going to work"
	actor.path = [Vector2i(4, 4)]
	actors = [actor]
	jobs = [_job()]
	helper.reset(actors, jobs)
	helper.begin_step(actors, jobs)
	actor.pos = Vector2(4, 4)
	actor.task = "Digging"
	actor.path.clear()
	helper.end_step(actors, jobs)
	helper.present(0.0, 0.01, 1.0, true)
	check(not helper.pose(actor).visual_digging, "authoritative arrival cannot start a strike before rendered arrival even on a zero-movement frame")
	helper.present(0.5, 0.05, 1.0, true)
	check(not helper.pose(actor).visual_digging, "worker still approaching the job does not swing while interpolating")
	helper.present(1.0, 0.05, 1.0, true)
	helper.present(1.0, 0.01, 1.0, true)
	check(helper.pose(actor).visual_digging and helper.pose(actor).visual_dig_target == Vector2.RIGHT, "arrived stationary worker begins digging at the actual job face")
	var independent: Dictionary = helper.pose(actor)
	independent.path.append(Vector2i(99, 99))
	independent.visual_dig_target = Vector2(99, 99)
	check(actor.path.is_empty() and helper.pose(actor).visual_dig_target == Vector2.RIGHT, "editing a renderer pose cannot mutate actor paths or stored dig targets")
	helper.present(1.0, 0.01, 1.0, false)
	actor.job = -1
	actor.task = "Idle"
	check(not helper.pose(actor).visual_digging, "paused UI cancellation removes the tool before another simulation step")

func _trace_script(path: String) -> Script:
	var script := GDScript.new()
	script.source_code = "extends \"%s\"\nvar recorded_strokes: Array = []\nvar recorded_ellipses: Array = []\nfunc _init(target: CanvasItem) -> void:\n\tsuper(target)\nfunc stroke(points: Array, color: Color, width: float) -> void:\n\trecorded_strokes.append({\"points\": points.duplicate(), \"color\": color, \"width\": width})\n\tsuper.stroke(points, color, width)\nfunc ellipse(center: Vector2, radius: Vector2, color: Color, steps: int = 20) -> void:\n\trecorded_ellipses.append({\"center\": center, \"radius\": radius, \"color\": color})\n\tsuper.ellipse(center, radius, color, steps)\n" % path.replace("\\", "/")
	if script.reload() != OK:
		check(false, "actual CaveArt trace subclass loads")
		return null
	return script

func _color_stroke(frame: Dictionary, color: Color) -> Dictionary:
	for line in frame.strokes:
		if Vector3(line.color.r, line.color.g, line.color.b).distance_to(Vector3(color.r, color.g, color.b)) < 0.001:
			return line
	return {}

func _test_actual_art(path: String, legacy: bool) -> void:
	var script: Script = _trace_script(path)
	if not script:
		return
	var probe := DrawProbe.new()
	probe.art = script.new(probe)
	for direction in DIRECTIONS:
		for index in range(48):
			var clock: float = Digging.CYCLE * index / 48.0
			var actor: Dictionary = _actor()
			actor.visual_work_weight = 1.0
			actor.visual_walk_weight = 0.0
			actor.visual_digging = true
			actor.visual_dig_clock = clock
			actor.visual_dig_target = direction
			probe.frames.append({"actor": actor, "clock": clock, "facing": -1.0 if direction == Vector2.LEFT else 1.0})
	root.add_child(probe)
	await process_frame
	await process_frame
	check(probe.results.size() == probe.frames.size(), "actual CaveArt executes every sampled pose inside CanvasItem._draw")
	for direction_index in range(DIRECTIONS.size()):
		var vectors: Array = []
		var tips: Array = []
		var matches_rig: bool = true
		var hands_attached: bool = true
		var debris_timed: bool = true
		var impacts: bool = false
		var contact_hit: bool = false
		var direction: Vector2 = DIRECTIONS[direction_index]
		for index in range(48):
			var frame: Dictionary = probe.results[direction_index * 48 + index]
			var wood: Dictionary = _color_stroke(frame, WOOD)
			var metal: Dictionary = _color_stroke(frame, METAL)
			if wood.is_empty() or metal.is_empty():
				matches_rig = false
				continue
			vectors.append((Vector2(wood.points[-1]) - Vector2(wood.points[0])).normalized())
			tips.append(metal.points[-1])
			var pose: Dictionary = Digging.pose(Digging.CYCLE * index / 48.0, direction, -1.0 if direction == Vector2.LEFT else 1.0)
			matches_rig = matches_rig and Vector2(wood.points[0]).distance_to(pose.shaft_bottom) < 0.00001 and Vector2(wood.points[-1]).distance_to(pose.shaft_top) < 0.00001 and Vector2(metal.points[-1]).distance_to(pose.tip) < 0.00001
			var front_found: bool = false
			var back_found: bool = false
			var chips: int = 0
			for mark in frame.ellipses:
				if mark.color.is_equal_approx(Color("e1b58b")):
					front_found = front_found or Vector2(mark.center).distance_to(pose.hand_front) < 0.00001
					back_found = back_found or Vector2(mark.center).distance_to(pose.hand_back) < 0.00001
				if Vector3(mark.color.r, mark.color.g, mark.color.b).distance_to(Vector3(0.7, 0.73, 0.52)) < 0.001:
					chips += 1
					debris_timed = debris_timed and mark.color.a > 0.0 and Vector2(mark.center).distance_to(pose.contact) < 1.3
			hands_attached = hands_attached and front_found and back_found
			debris_timed = debris_timed and chips <= 8 and ((pose.phase >= 0.52 and pose.phase <= 0.90) or chips == 0)
			if pose.phase >= 0.52 and pose.phase < 0.59:
				contact_hit = contact_hit or Vector2(metal.points[-1]).distance_to(pose.contact) < 0.00001
				impacts = impacts or chips > 0
		print("%s art %s: shaft rotation %.1f degrees, tip excursion %.3f tiles, contact=%s impact=%s" % ["Legacy" if legacy else "Production", direction, rad_to_deg(_angular_span(vectors)), _excursion(tips), contact_hit, impacts])
		check(_angular_span(vectors) > PI / 3.0, "%s actual tool strokes rotate broadly throughout the swing" % direction)
		check(_excursion(tips) > 0.5, "%s actual pick head travels a visible arc" % direction)
		check(contact_hit and impacts, "%s actual pick strikes its rock face and draws timed impact debris" % direction)
		if not legacy:
			check(matches_rig, "%s CaveArt consumes the production rig's shaft and pointed pick geometry" % direction)
			check(hands_attached, "%s actual artist draws both hands attached to the rotating shaft throughout the cycle" % direction)
			check(debris_timed, "%s actual debris draw calls are bounded and absent before contact or after recovery" % direction)
	if not legacy:
		probe.frames.clear()
		var suppressed: Dictionary = _actor()
		suppressed.visual_work_weight = 1.0
		suppressed.visual_digging = false
		probe.frames.append({"actor": suppressed, "clock": Digging.CYCLE * 0.55, "facing": 1.0})
		probe.queue_redraw()
		await process_frame
		await process_frame
		check(_color_stroke(probe.results[0], WOOD).is_empty() and _color_stroke(probe.results[0], METAL).is_empty(), "suppressing digging removes actual tool strokes despite a residual blended work weight")
	probe.queue_free()
	await process_frame
	await process_frame
