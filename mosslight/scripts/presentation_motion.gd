class_name MosslightPresentationMotion
extends RefCounted

## Read-only presentation history for the unchanged 10 Hz colony simulation.
## One simulation tick of interpolation latency prevents extrapolated wall crossings.
const STRIDE_TILES: float = 0.8
const BLEND_RATE: float = 14.0
const MOTION_EPSILON: float = 0.00001

var _samples: Dictionary = {}

func reset(colonists: Array) -> void:
	_samples.clear()
	for colonist in colonists:
		_samples[colonist.id] = _new_sample(colonist)

func _new_sample(colonist: Dictionary) -> Dictionary:
	var position: Vector2 = colonist.pos
	var sample: Dictionary = {
		"previous": position, "current": position, "rendered": position,
		"walk": 0.0, "work": 0.0, "climb": 0.0,
		"phase": float(colonist.id) * 0.37, "clock": 0.0, "facing": 1.0,
		"alive": true, "resting": false, "wants_work": false
	}
	_read_activity(sample, colonist)
	return sample

func _read_activity(sample: Dictionary, colonist: Dictionary) -> void:
	var path: Array = colonist.get("path", [])
	var task: String = str(colonist.get("task", ""))
	sample.alive = bool(colonist.get("alive", true))
	# The simulation reserves a bed and sets resting before the walk to it.
	sample.resting = task.begins_with("Resting") or (bool(colonist.get("resting", false)) and path.is_empty())
	sample.wants_work = sample.alive and not sample.resting and path.is_empty() and int(colonist.get("job", -1)) >= 0 and (task.begins_with("Digging") or task.begins_with("Building"))

func begin_step(colonists: Array) -> void:
	for colonist in colonists:
		if not _samples.has(colonist.id):
			_samples[colonist.id] = _new_sample(colonist)
		var sample: Dictionary = _samples[colonist.id]
		sample.previous = Vector2(colonist.pos)
		sample.current = Vector2(colonist.pos)

func end_step(colonists: Array) -> void:
	var present_ids: Dictionary = {}
	for colonist in colonists:
		present_ids[colonist.id] = true
		if not _samples.has(colonist.id):
			_samples[colonist.id] = _new_sample(colonist)
		var sample: Dictionary = _samples[colonist.id]
		sample.current = Vector2(colonist.pos)
		_read_activity(sample, colonist)
	for id in _samples.keys():
		if not present_ids.has(id):
			_samples.erase(id)

func _blend(current: float, target: float, amount: float) -> float:
	var result: float = lerpf(current, target, amount)
	return target if absf(result - target) < 0.0001 else result

func present(alpha: float, delta: float, speed: float, running: bool, reduced_motion: bool = false) -> void:
	# The caller retains its fractional accumulator while paused. No new time
	# enters that accumulator until resume, so the same sampled segment continues
	# at ordinary frame cadence without rebasing, catching up or extrapolation.
	if not running:
		return
	var fraction: float = clampf(alpha, 0.0, 1.0) if is_finite(alpha) else 0.0
	var frame_delta: float = clampf(delta, 0.0, 0.25) if is_finite(delta) else 0.0
	var rate: float = clampf(speed, 0.0, 3.0) if is_finite(speed) else 0.0
	var blend: float = 1.0 - exp(-BLEND_RATE * frame_delta)
	for sample in _samples.values():
		var before: Vector2 = sample.rendered
		var position: Vector2 = Vector2(sample.previous).lerp(Vector2(sample.current), fraction)
		var travel: Vector2 = position - before
		var distance: float = travel.length()
		sample.rendered = position
		var moving: bool = distance > MOTION_EPSILON
		# Authoritative arrival may precede visible arrival by one sample. Keep
		# functional gait until interpolation finishes, then settle into rest.
		var can_animate: bool = sample.alive and (not sample.resting or moving) and not reduced_motion
		var walking_target: float = 1.0 if moving and can_animate else 0.0
		var working_target: float = 1.0 if sample.wants_work and not moving and can_animate else 0.0
		var climbing_target: float = absf(travel.y) / distance if moving and can_animate else 0.0
		sample.walk = _blend(sample.walk, walking_target, blend)
		sample.work = _blend(sample.work, working_target, blend)
		sample.climb = _blend(sample.climb, climbing_target, blend)
		if moving and can_animate:
			sample.phase += distance * TAU / STRIDE_TILES
		if can_animate:
			sample.clock += frame_delta * rate
		if sample.alive and absf(travel.x) > MOTION_EPSILON:
			sample.facing = 1.0 if travel.x > 0.0 else -1.0

func pose(colonist: Dictionary) -> Dictionary:
	# Return independent data so even a renderer modifying its copy cannot alter
	# simulation paths, positions, health, job reservations or other authority.
	var result: Dictionary = colonist.duplicate(true)
	if not _samples.has(colonist.id):
		_samples[colonist.id] = _new_sample(colonist)
	var sample: Dictionary = _samples[colonist.id]
	result.pos = sample.rendered
	result.visual_walk_weight = sample.walk
	result.visual_work_weight = sample.work
	result.visual_climb_weight = sample.climb
	result.visual_phase = sample.phase
	result.visual_clock = sample.clock
	result.visual_facing = sample.facing
	# Reduced motion hides gait weights, so endpoint arrival is an independent
	# requirement. A bed reservation alone must never make a moving body lie down.
	result.visual_resting = sample.alive and sample.resting and Vector2(sample.rendered).distance_to(Vector2(sample.current)) <= MOTION_EPSILON and sample.walk < 0.05
	return result
