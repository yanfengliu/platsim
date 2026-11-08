extends SceneTree

const Motion = preload("res://scripts/presentation_motion.gd")
const VISUAL_KEYS: Array[String] = ["pos", "visual_walk_weight", "visual_work_weight", "visual_climb_weight", "visual_phase", "visual_clock", "visual_facing", "visual_resting"]
var checks: int = 0
var failures: Array[String] = []

## Adapter of e97177b world_view._draw_colonist's direct Vector2(colonist.pos).
## It accepts the same 10 Hz snapshots and render frames as the new helper.
## This is a behavioral counterfactual, not a missing-file/API assertion.
class DirectPositionBaseline extends RefCounted:
	var clock: float = 0.0
	func reset(_colonists: Array) -> void:
		clock = 0.0
	func begin_step(_colonists: Array) -> void:
		pass
	func end_step(_colonists: Array) -> void:
		pass
	func present(_alpha: float, delta: float, _speed: float, running: bool, _reduced_motion: bool = false) -> void:
		if running:
			clock += delta
	func pose(colonist: Dictionary) -> Dictionary:
		var result: Dictionary = colonist.duplicate(true)
		result.visual_phase = clock * 8.0
		return result

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	if "--pause-only" in OS.get_cmdline_user_args():
		_test_pause_accumulator("--reset-accumulator-on-pause" in OS.get_cmdline_user_args())
		print("Mosslight pause accumulator: %d checks, %d failures" % [checks, failures.size()])
		quit(0 if failures.is_empty() else 1)
		return
	var baseline: bool = "--direct-position-baseline" in OS.get_cmdline_user_args()
	_test_render_cadence(baseline)
	if not baseline:
		_test_authority_and_endpoints()
		_test_pause_resume_reset()
		_test_pause_accumulator(false)
		await _test_main_pause_lifecycle()
		_test_activity_and_facing()
		_test_bed_arrival()
		_test_rest_death_and_reduced_motion()
		_test_baseline_negative_control()
	print("Mosslight motion%s: %d checks, %d failures" % [" direct-position baseline" if baseline else "", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func _actor(position: Vector2 = Vector2.ZERO) -> Dictionary:
	return {"id": 0, "pos": position, "alive": true, "resting": false, "task": "Going to work", "job": 7, "path": [Vector2i(40, 20)], "health": 100.0}

func _frame_values(pose: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in VISUAL_KEYS:
		result[key] = pose.get(key, false)
	return result

func _run_travel(helper: RefCounted, frames_per_second: int, speed: float, direction: Vector2) -> Dictionary:
	var actor: Dictionary = _actor()
	var actors: Array = [actor]
	helper.reset(actors)
	var frame_delta: float = 1.0 / float(frames_per_second)
	var accumulator: float = 0.0
	var last: Vector2 = actor.pos
	var distances: Array[float] = []
	var distance_total: float = 0.0
	var maximum: float = 0.0
	var repeats: int = 0
	var phase_start: float = helper.pose(actor).visual_phase
	for frame in range(frames_per_second * 2):
		accumulator += frame_delta * speed
		while accumulator + 0.0000001 >= 0.1:
			helper.begin_step(actors)
			actor.pos = Vector2(actor.pos) + direction.normalized() * 0.21
			helper.end_step(actors)
			accumulator = maxf(0.0, accumulator - 0.1)
		helper.present(accumulator / 0.1, frame_delta, speed, true)
		var position: Vector2 = helper.pose(actor).pos
		var distance: float = position.distance_to(last)
		distance_total += distance
		if frame >= frames_per_second / 2:
			distances.append(distance)
			maximum = maxf(maximum, distance)
			if distance < 0.000001:
				repeats += 1
		last = position
	return {"distances": distances, "maximum": maximum, "repeats": repeats, "distance_total": distance_total, "pose": helper.pose(actor), "phase_start": phase_start, "actor": actor, "helper": helper}

func _test_render_cadence(baseline: bool) -> void:
	for frames_per_second in [60, 120]:
		for speed in [1.0, 3.0]:
			for direction in [Vector2.RIGHT, Vector2(1, -1), Vector2.UP]:
				var helper: RefCounted = DirectPositionBaseline.new() if baseline else Motion.new()
				var result: Dictionary = _run_travel(helper, frames_per_second, speed, direction)
				var label: String = "%dfps %dx direction %s" % [frames_per_second, int(speed), direction]
				var ideal: float = 2.1 * speed / float(frames_per_second)
				var repeat_fraction: float = float(result.repeats) / float(result.distances.size())
				print("Motion %s: repeated=%.1f%% maximum_step=%.5f expected=%.5f tiles" % [label, repeat_fraction * 100.0, result.maximum, ideal])
				check(repeat_fraction < 0.02, label + " updates its position on every steady render frame")
				check(result.maximum <= ideal * 1.03, label + " has no 10 Hz position jumps")
				var bounded: bool = true
				for distance in result.distances:
					if absf(distance - ideal) > ideal * 0.03:
						bounded = false
				check(bounded, label + " has even frame-to-frame travel")
				if baseline:
					continue
				check(absf(result.pose.visual_phase - result.phase_start - result.distance_total * TAU / Motion.STRIDE_TILES) < 0.001, label + " gait phase follows actual rendered distance")
				check(result.pose.visual_walk_weight > 0.99, label + " blends into a full walking pose")
				check(absf(result.pose.visual_climb_weight - absf(direction.normalized().y)) < 0.01, label + " climbing responds to actual vertical movement")

func _test_authority_and_endpoints() -> void:
	var actor: Dictionary = _actor(Vector2(3, 4))
	var actors: Array = [actor]
	var helper = Motion.new()
	helper.reset(actors)
	helper.begin_step(actors)
	actor.pos = Vector2(3.21, 3.79)
	helper.end_step(actors)
	var authoritative_copy: Dictionary = actor.duplicate(true)
	helper.present(0.5, 1.0 / 60.0, 1.0, true)
	var display: Dictionary = helper.pose(actor)
	check(Vector2(display.pos).distance_to(Vector2(3.105, 3.895)) < 0.00001, "diagonal interpolation is the segment midpoint")
	display.pos = Vector2(999, 999)
	display.path.clear()
	display.health = -100
	check(actor == authoritative_copy, "rendering cannot mutate simulation positions, paths or health")
	helper.present(1.0, 1.0 / 60.0, 1.0, true)
	check(helper.pose(actor).pos == actor.pos, "alpha one reaches the sampled endpoint without extrapolation")
	helper.present(8.0, 1.0 / 60.0, 1.0, true)
	check(helper.pose(actor).pos == actor.pos, "out-of-range alpha cannot extrapolate through terrain")
	helper.present(NAN, NAN, INF, true)
	var guarded: Dictionary = helper.pose(actor)
	check(Vector2(guarded.pos).is_finite() and is_finite(guarded.visual_phase) and is_finite(guarded.visual_clock), "invalid timing inputs cannot poison visual state")
	check(actor == authoritative_copy, "sampling and invalid timing never change authoritative data")

func _test_pause_resume_reset() -> void:
	var actor: Dictionary = _actor()
	var actors: Array = [actor]
	var helper = Motion.new()
	helper.reset(actors)
	helper.begin_step(actors)
	actor.pos = Vector2(0.21, 0)
	helper.end_step(actors)
	helper.present(0.6, 1.0 / 60.0, 1.0, true)
	var frozen: Dictionary = _frame_values(helper.pose(actor))
	for frame in range(30):
		helper.present(float(frame % 6) / 6.0, 1.0 / 60.0, 3.0, false)
	check(_frame_values(helper.pose(actor)) == frozen, "pause preserves every rendered pose value despite accumulator and speed changes")
	helper.present(0.6 + 1.0 / 6.0, 1.0 / 60.0, 1.0, true)
	check(absf(helper.pose(actor).pos.x - frozen.pos.x - 0.035) < 0.00001, "first resume frame advances the retained fractional segment normally")
	var last: Vector2 = frozen.pos
	var forward_only: bool = true
	var bounded: bool = true
	for frame in range(1, 3):
		helper.present(0.6 + float(frame) / 6.0, 1.0 / 60.0, 1.0, true)
		var position: Vector2 = helper.pose(actor).pos
		forward_only = forward_only and position.x >= last.x
		bounded = bounded and position.distance_to(last) <= 0.03501
		last = position
	check(forward_only and bounded, "resume proceeds smoothly without moving backward or jumping a simulation tick")
	helper.begin_step(actors)
	actor.pos = Vector2(0.42, 0)
	helper.end_step(actors)
	helper.present(0.1, 1.0 / 60.0, 1.0, true)
	check(Vector2(helper.pose(actor).pos).distance_to(last) <= 0.03501, "next authoritative segment joins the resumed segment continuously")
	actor.pos = Vector2(40, 20)
	helper.reset(actors)
	check(helper.pose(actor).pos == actor.pos, "reset immediately adopts a distant new colony position")
	helper.present(0.4, 1.0 / 60.0, 1.0, true)
	check(helper.pose(actor).pos == actor.pos and helper.pose(actor).visual_walk_weight == 0.0, "reset never interpolates across maps or retains a walking pose")
	var added: Dictionary = _actor(Vector2(2, 8))
	added.id = 9
	helper.begin_step([added])
	helper.end_step([added])
	check(helper.pose(added).pos == added.pos and helper.pose(added).visual_walk_weight == 0.0, "new actor identity receives independent initial history")

func _test_activity_and_facing() -> void:
	var result: Dictionary = _run_travel(Motion.new(), 60, 1.0, Vector2.LEFT)
	var helper: RefCounted = result.helper
	var actor: Dictionary = result.actor
	check(helper.pose(actor).visual_facing == -1.0, "leftward rendered movement turns the settler left")
	var actors: Array = [actor]
	helper.begin_step(actors)
	actor.pos += Vector2(0, -0.21)
	helper.end_step(actors)
	helper.present(1.0, 1.0 / 60.0, 1.0, true)
	check(helper.pose(actor).visual_facing == -1.0, "vertical movement preserves horizontal facing")
	actor.path = []
	actor.task = "Digging"
	helper.begin_step(actors)
	helper.end_step(actors)
	var before_weight: float = helper.pose(actor).visual_walk_weight
	helper.present(0.0, 1.0 / 60.0, 1.0, true)
	check(helper.pose(actor).visual_walk_weight > 0.0 and helper.pose(actor).visual_walk_weight < before_weight, "stopping eases the walking pose rather than snapping it off")
	check(helper.pose(actor).visual_work_weight > 0.0 and helper.pose(actor).visual_work_weight < 0.3, "work pose begins with a blend rather than an instant lift")
	var phase_at_stop: float = helper.pose(actor).visual_phase
	var work_clock: float = helper.pose(actor).visual_clock
	var intermediate_work: Array[float] = []
	for frame in range(60):
		helper.present(float(frame % 6) / 6.0, 1.0 / 60.0, 1.0, true)
		intermediate_work.append(helper.pose(actor).visual_work_weight)
	check(helper.pose(actor).visual_walk_weight == 0.0 and helper.pose(actor).visual_climb_weight == 0.0, "stationary worker reaches a stable non-walking pose")
	check(helper.pose(actor).visual_work_weight > 0.99 and intermediate_work[1] > intermediate_work[0], "work pose continues changing between 10 Hz simulation ticks")
	check(helper.pose(actor).visual_phase == phase_at_stop, "stationary work does not fake walking distance")
	check(absf(helper.pose(actor).visual_clock - work_clock - 1.0) < 0.00001, "work clock advances at render cadence")
	actor.job = -1
	actor.task = "Ready to help"
	helper.begin_step(actors)
	helper.end_step(actors)
	for frame in range(60):
		helper.present(0.5, 1.0 / 60.0, 1.0, true)
	check(helper.pose(actor).visual_work_weight == 0.0 and helper.pose(actor).visual_phase == phase_at_stop, "idle actor settles without stray walking or work cycles")
	check(helper.pose(actor).visual_facing == -1.0, "idle actor keeps the last visible facing")

func _test_rest_death_and_reduced_motion() -> void:
	var actor: Dictionary = _actor()
	actor.resting = true
	actor.task = "Going to bed"
	var actors: Array = [actor]
	var helper = Motion.new()
	helper.reset(actors)
	helper.begin_step(actors)
	actor.pos = Vector2(0.21, 0)
	helper.end_step(actors)
	helper.present(0.5, 1.0 / 60.0, 1.0, true)
	check(helper.pose(actor).visual_walk_weight > 0.0, "bed reservation does not disable walking on the way to bed")
	check(not helper.pose(actor).visual_resting, "bed reservation does not select the lying-down body while approaching")
	actor.path = []
	actor.task = "Resting"
	helper.begin_step(actors)
	helper.end_step(actors)
	# Complete the remaining visible movement before measuring the resting pose.
	helper.present(1.0, 1.0 / 60.0, 1.0, true)
	var resting_phase: float = helper.pose(actor).visual_phase
	var resting_clock: float = helper.pose(actor).visual_clock
	for frame in range(60):
		helper.present(0.5, 1.0 / 60.0, 1.0, true)
	check(helper.pose(actor).visual_walk_weight == 0.0 and helper.pose(actor).visual_work_weight == 0.0, "resting actor has no walking or work pose")
	check(helper.pose(actor).visual_phase == resting_phase and helper.pose(actor).visual_clock == resting_clock, "resting actor has stable animation phase and clock")
	check(helper.pose(actor).visual_resting, "settled bed arrival publishes the shared resting-body flag")
	actor.alive = false
	actor.resting = false
	actor.task = "Lost"
	helper.begin_step(actors)
	helper.end_step(actors)
	for frame in range(60):
		helper.present(0.5, 1.0 / 60.0, 3.0, true)
	check(helper.pose(actor).visual_phase == resting_phase and helper.pose(actor).visual_clock == resting_clock, "dead actor does not continue its breathing or work clock")
	check(not helper.pose(actor).visual_resting, "dead actor is handled separately from the resting-body flag")
	actor.alive = true
	actor.task = "Going to work"
	actor.path = [Vector2i(4, 0)]
	helper.begin_step(actors)
	actor.pos += Vector2(0.21, 0)
	helper.end_step(actors)
	var before: Vector2 = helper.pose(actor).pos
	helper.present(0.5, 1.0 / 60.0, 1.0, true, true)
	check(Vector2(helper.pose(actor).pos).x > before.x, "reduced motion retains smooth positional interpolation")
	check(helper.pose(actor).visual_phase == resting_phase and helper.pose(actor).visual_clock == resting_clock, "reduced motion suppresses decorative pose cycles")
	actor.task = "Resting on the ground — needs a reachable bed"
	actor.path = []
	helper.begin_step(actors)
	helper.end_step(actors)
	for frame in range(60):
		helper.present(1.0, 1.0 / 60.0, 1.0, true)
	check(helper.pose(actor).visual_resting, "ground-rest task prefix publishes the same resting-body flag as a bed")

func _test_bed_arrival() -> void:
	var actor: Dictionary = _actor()
	actor.resting = true
	actor.task = "Going to bed"
	var actors: Array = [actor]
	var helper = Motion.new()
	helper.reset(actors)
	helper.begin_step(actors)
	actor.pos = Vector2(0.21, 0)
	actor.path = []
	actor.task = "Resting"
	helper.end_step(actors)
	helper.present(0.25, 1.0 / 60.0, 1.0, true)
	var approaching: Dictionary = helper.pose(actor)
	check(approaching.pos.x < actor.pos.x and approaching.visual_walk_weight > 0.0, "authoritative bed arrival retains gait while the rendered actor is still approaching")
	check(not approaching.visual_resting, "authoritative arrival alone cannot make the still-moving render pose lie down")
	check(approaching.visual_phase > 0.0 and approaching.visual_clock > 0.0, "final visible bed approach advances the functional gait phase and clock")
	helper.present(0.5, 1.0 / 60.0, 1.0, true)
	var halfway: Dictionary = helper.pose(actor)
	check(halfway.pos.x > approaching.pos.x and halfway.pos.x < actor.pos.x and halfway.visual_phase > approaching.visual_phase, "gait continues between render frames until visible bed arrival")
	helper.present(1.0, 1.0 / 60.0, 1.0, true)
	var arrived: Dictionary = helper.pose(actor)
	check(arrived.pos == actor.pos, "interpolated bed arrival reaches the authoritative resting position")
	for frame in range(60):
		helper.present(1.0, 1.0 / 60.0, 1.0, true)
	var resting: Dictionary = helper.pose(actor)
	check(resting.visual_phase == arrived.visual_phase and resting.visual_clock == arrived.visual_clock, "visible bed arrival freezes gait phase and clock while settling")
	check(resting.pos == actor.pos and resting.visual_walk_weight == 0.0 and resting.visual_work_weight == 0.0, "bed arrival eases into a stable stationary resting pose")
	check(resting.visual_resting, "visible arrival and settled gait select the shared resting pose")
	var reduced = Motion.new()
	actor.pos = Vector2.ZERO
	actor.path = [Vector2i(1, 0)]
	actor.task = "Going to bed"
	reduced.reset(actors)
	reduced.begin_step(actors)
	actor.pos = Vector2(0.21, 0)
	actor.path = []
	actor.task = "Resting"
	reduced.end_step(actors)
	reduced.present(0.5, 1.0 / 60.0, 1.0, true, true)
	check(reduced.pose(actor).visual_walk_weight == 0.0 and not reduced.pose(actor).visual_resting, "reduced-motion zero gait weight cannot trigger resting before rendered arrival")
	reduced.present(1.0, 1.0 / 60.0, 1.0, true, true)
	check(reduced.pose(actor).visual_resting, "reduced-motion actor rests when its rendered position actually arrives")

func _test_main_pause_lifecycle() -> void:
	# Exercise production lifecycle methods; a copied driver alone would not catch
	# an accumulator clear reintroduced into the UI's actual pause/menu handlers.
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node = scene.instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(main)
	await process_frame
	main.set("started", true)
	main.set("paused", false)
	main.call("_close_overlay")
	main.set("_accumulator", 0.073)
	main.call("_toggle_pause")
	check(main.get("paused") and main.get("_accumulator") == 0.073, "production pause retains the fractional simulation accumulator")
	main.call("_toggle_pause")
	check(not main.get("paused") and main.get("_accumulator") == 0.073, "production resume retains the same fractional accumulator")
	main.call("_on_focus_lost")
	check(main.get("paused") and main.get("_accumulator") == 0.073, "production focus loss pauses without dropping fractional simulation time")
	main.set("paused", false)
	main.call("_show_menu")
	check(main.get("_accumulator") == 0.073, "production menu opening preserves the fractional accumulator")
	main.call("_close_overlay")
	check(main.get("_accumulator") == 0.073, "production menu closing preserves the fractional accumulator")
	main.call("_restart")
	check(main.get("_accumulator") == 0.0 and main.get("simulation").elapsed == 0.0, "production new colony resets both authoritative time and the accumulator")
	main.queue_free()
	await process_frame

func _test_baseline_negative_control() -> void:
	var result: Dictionary = _run_travel(DirectPositionBaseline.new(), 60, 1.0, Vector2.RIGHT)
	check(float(result.repeats) / float(result.distances.size()) > 0.8, "old direct-position path demonstrably repeats more than 80% of 60fps frames")
	check(result.maximum > 0.20, "old direct-position path demonstrably jumps a full 10 Hz movement step")

func _resume_trace(frames_per_second: int, speed: float, paused_fraction: float, turn: bool, reset_accumulator: bool) -> Dictionary:
	var actor: Dictionary = _actor()
	var actors: Array = [actor]
	var helper = Motion.new()
	helper.reset(actors)
	helper.begin_step(actors)
	actor.pos = Vector2(0.21, 0)
	helper.end_step(actors)
	var frame_delta: float = 1.0 / float(frames_per_second)
	var accumulator: float = paused_fraction * 0.1
	helper.present(paused_fraction, frame_delta, speed, true)
	var paused_pose: Dictionary = _frame_values(helper.pose(actor))
	if reset_accumulator:
		accumulator = 0.0
	for frame in range(20):
		helper.present(accumulator / 0.1, frame_delta, speed, false)
	var frozen: bool = _frame_values(helper.pose(actor)) == paused_pose
	var last: Vector2 = paused_pose.pos
	var deltas: Array[float] = []
	var positions_on_path: bool = true
	var total: float = 0.0
	# Same ordering as main._process: accumulate active time, bracket every 10 Hz
	# step, then present the remaining fractional tick. Paused time adds nothing.
	for frame in range(12):
		accumulator = minf(accumulator + minf(frame_delta, 0.25) * speed, 0.75)
		while accumulator + 0.0000001 >= 0.1:
			helper.begin_step(actors)
			actor.pos += (Vector2.UP if turn else Vector2.RIGHT) * 0.21
			helper.end_step(actors)
			accumulator = maxf(0.0, accumulator - 0.1)
		helper.present(accumulator / 0.1, frame_delta, speed, true)
		var position: Vector2 = helper.pose(actor).pos
		var distance: float = position.distance_to(last)
		deltas.append(distance)
		total += distance
		if turn:
			var horizontal_leg: bool = absf(position.y) < 0.00001 and position.x >= 0.0 and position.x <= 0.21001
			var vertical_leg: bool = absf(position.x - 0.21) < 0.00001 and position.y <= 0.0
			positions_on_path = positions_on_path and (horizontal_leg or vertical_leg)
		last = position
	return {"frozen": frozen, "deltas": deltas, "total": total, "positions_on_path": positions_on_path}

func _test_pause_accumulator(reset_accumulator: bool) -> void:
	for frames_per_second in [60, 120]:
		for speed in [1.0, 3.0]:
			for fraction in [0.0, 1.0 / 6.0, 1.0 / 3.0, 0.5, 2.0 / 3.0, 5.0 / 6.0, 0.95]:
				var label: String = "resume %dfps %dx alpha %.3f" % [frames_per_second, int(speed), fraction]
				var ideal: float = 2.1 * speed / float(frames_per_second)
				var straight: Dictionary = _resume_trace(frames_per_second, speed, fraction, false, reset_accumulator)
				check(straight.frozen, label + " keeps paused frames exactly stable")
				check(absf(straight.deltas[0] - ideal) <= ideal * 0.03, label + " first resumed frame travels its ordinary frame distance")
				var even: bool = true
				for distance in straight.deltas:
					if absf(distance - ideal) > ideal * 0.03:
						even = false
				check(even, label + " has no repeated frame or doubled step across resumed simulation ticks")
				check(absf(straight.total - ideal * straight.deltas.size()) < ideal * 0.03, label + " retains elapsed fractional travel")
				var corner: Dictionary = _resume_trace(frames_per_second, speed, fraction, true, reset_accumulator)
				check(corner.positions_on_path, label + " stays on sampled horizontal and vertical legs without cutting the corner")
				var bounded: bool = true
				for distance in corner.deltas:
					if distance <= 0.000001 or distance > ideal * 1.03:
						bounded = false
				check(bounded, label + " turns continuously with no paused or oversized frame")
