class_name MosslightSimulation
extends RefCounted

## The colony is plain data. Rendering and input never advance or own simulation state.
const CATALOG: Dictionary = {
	"ladder": {"name": "Root ladder", "description": "Reach other levels. Extend from an accessible floor or ladder.", "cost": {"biomass": 2}},
	"bed": {"name": "Leaf bed", "description": "A place for one tired colonist to recover energy.", "cost": {"biomass": 8}},
	"farm": {"name": "Mushroom bed", "description": "Produces 1 food every 90 seconds. Needs light and water.", "cost": {"ore": 8, "biomass": 8}},
	"airfern": {"name": "Breathing fern", "description": "Refreshes this cave's air. Needs light and water.", "cost": {"ore": 8, "biomass": 12}},
	"lamp": {"name": "Glow lamp", "description": "Lights plants within 5 tiles. Uses 0.6 power per second.", "cost": {"ore": 10}},
	"generator": {"name": "Bio generator", "description": "Turns biomass into 4 power per second.", "cost": {"ore": 20}},
	"cistern": {"name": "Dew collector", "description": "Collects 0.18 water per second from cave moisture.", "cost": {"ore": 12}},
	"beacon": {"name": "Hearth beacon", "description": "Uses 1.8 power per second. Keep the colony healthy through day five.", "cost": {"ore": 60, "biomass": 24}}
}
const DAY_SECONDS: float = 240.0
const SURVIVAL_SECONDS: float = 1200.0
const STABLE_SECONDS: float = 120.0
const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const NAMES: Array[String] = ["Pip", "Mara", "Tavi", "Ivo"]
var width: int = 48
var height: int = 26
var tiles: Array = []
var colonists: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var jobs: Array[Dictionary] = []
var resources: Dictionary = {}
var rooms: Array[Dictionary] = []
var landmarks: Array[Dictionary] = []
var elapsed: float = 0.0
var day: int = 1
var status: String = "playing"
var message: String = "Welcome home. Grow food and breathing ferns near the glow lamp, then follow the root ladder into the quarry."
var events: Array[String] = []
var seed_value: int = 42
var objective_progress: float = 0.0
var objective_reason: String = "Build a hearth beacon."
var stable_seconds: float = 0.0
var food_rate: float = 0.0
var power_rate: float = 0.0
var _next_id: int = 1
var _room_ids: Dictionary = {}
var _decision_timer: float = 0.0

func _init() -> void:
	reset()

func reset(new_seed: int = 42) -> void:
	seed_value = new_seed
	elapsed = 0.0
	day = 1
	status = "playing"
	objective_progress = 0.0
	objective_reason = "Build a hearth beacon."
	stable_seconds = 0.0
	food_rate = 0.0
	power_rate = 0.0
	_next_id = 1
	_decision_timer = 0.0
	message = "Welcome home. Grow food and breathing ferns near the glow lamp, then follow the root ladder into the quarry."
	events.clear()
	tiles.clear()
	colonists.clear()
	buildings.clear()
	jobs.clear()
	rooms.clear()
	landmarks.clear()
	_room_ids.clear()
	resources = {"food": 24.0, "water": 90.0, "ore": 36.0, "biomass": 80.0, "power": 60.0}
	var rng := RandomNumberGenerator.new()
	rng.seed = new_seed
	for y in range(height):
		var row: Array = []
		for x in range(width):
			var material: int = 1
			if x > 1 and y > 1 and x < width - 2 and y < height - 2:
				var roll: int = rng.randi_range(0, 99)
				if roll < 12:
					material = 2
				elif roll < 21:
					material = 3
				elif roll < 25:
					material = 4
			row.append(material)
		tiles.append(row)
	# Authored terraces are real terrain: settlers walk the steps and climb the
	# roost and quarry shafts. Only the resource speckling changes with the seed.
	for x in range(4, 33):
		var floor_y: int = 11
		var ceiling_y: int = 8
		if x == 10:
			floor_y = 12
		elif x >= 11 and x <= 16:
			floor_y = 13
		elif x == 17:
			floor_y = 14
		elif x == 18:
			floor_y = 15
		elif x >= 19 and x <= 25:
			floor_y = 16
		elif x == 26:
			floor_y = 17
		elif x >= 27:
			floor_y = 18
		if x >= 10 and x <= 16:
			ceiling_y = 9
		elif x >= 21 and x <= 25:
			ceiling_y = 7
		elif x >= 26:
			ceiling_y = 11
		_carve(Rect2i(x, ceiling_y, 1, floor_y - ceiling_y + 1))
	_carve(Rect2i(6, 3, 9, 4))
	_carve(Rect2i(14, 7, 1, 6))
	_carve(Rect2i(18, 16, 1, 4))
	_carve(Rect2i(10, 21, 15, 3))
	_carve(Rect2i(12, 20, 4, 1))
	_carve(Rect2i(36, 9, 9, 5))
	_carve(Rect2i(38, 8, 5, 1))
	_carve(Rect2i(37, 14, 7, 1))
	# The lower route supplies beacon ore without asking the player to gamble
	# on a random deposit. The plug must be mined and its ladder extended.
	for cell in [Vector2i(18, 20), Vector2i(25, 23), Vector2i(26, 23)]:
		tiles[cell.y][cell.x] = 2
	tiles[23][9] = 3
	tiles[14][35] = 3
	landmarks.assign([
		{"name": "The Roost", "cell": Vector2i(9, 5), "kind": "roost"},
		{"name": "Lantern Hollow", "cell": Vector2i(22, 12), "kind": "hollow"},
		{"name": "Dew Basin", "cell": Vector2i(29, 16), "kind": "dew_basin"},
		{"name": "Root Quarry", "cell": Vector2i(18, 22), "kind": "quarry"}
	])
	_rebuild_rooms()
	for room in rooms:
		room.air = 18.0
	for cell in [Vector2i(7, 6), Vector2i(9, 6), Vector2i(12, 13), Vector2i(15, 13)]:
		_add_building("bed", cell)
	for entry in [["generator", Vector2i(20, 16)], ["lamp", Vector2i(23, 16)], ["farm", Vector2i(25, 16)], ["airfern", Vector2i(27, 18)], ["cistern", Vector2i(30, 18)]]:
		_add_building(entry[0], entry[1])
	for y in range(7, 13):
		_add_building("ladder", Vector2i(14, y))
	for y in range(16, 20):
		_add_building("ladder", Vector2i(18, y))
	var positions: Array[Vector2i] = [Vector2i(8, 6), Vector2i(13, 13), Vector2i(22, 16), Vector2i(29, 18)]
	for i in range(4):
		colonists.append({"id": i, "name": NAMES[i], "pos": Vector2(positions[i]), "health": 100.0, "hunger": float(i * 4), "energy": 90.0, "task": "Settling in", "alive": true, "job": -1, "path": [], "resting": false, "bed": -1})
		var occupied_room: Dictionary = room_at(positions[i])
		if not occupied_room.is_empty():
			occupied_room.air = 85.0
	_update_buildings(0.0)

func _carve(area: Rect2i) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			tiles[y][x] = 0

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height

func is_open(cell: Vector2i) -> bool:
	return in_bounds(cell) and tiles[cell.y][cell.x] == 0

func building_at(cell: Vector2i) -> Dictionary:
	for building in buildings:
		if building.cell == cell:
			return building
	return {}

func job_at(cell: Vector2i) -> Dictionary:
	for job in jobs:
		if job.cell == cell:
			return job
	return {}

func room_at(cell: Vector2i) -> Dictionary:
	var index: int = int(_room_ids.get(cell, -1))
	return rooms[index] if index >= 0 and index < rooms.size() else {}

func _has_ladder(cell: Vector2i) -> bool:
	var building: Dictionary = building_at(cell)
	return not building.is_empty() and building.kind == "ladder"

func is_walkable(cell: Vector2i) -> bool:
	return is_open(cell) and (not is_open(cell + Vector2i.DOWN) or _has_ladder(cell) or _has_ladder(cell + Vector2i.DOWN))

func _neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in [Vector2i.LEFT, Vector2i.RIGHT]:
		var next: Vector2i = cell + direction
		if is_walkable(next):
			result.append(next)
		# Colonists can step over a single block, or down one step.
		var up: Vector2i = next + Vector2i.UP
		if is_open(cell + Vector2i.UP) and is_walkable(up) and not is_open(next):
			result.append(up)
		var down: Vector2i = next + Vector2i.DOWN
		if is_open(next) and is_walkable(down):
			result.append(down)
	for direction in [Vector2i.UP, Vector2i.DOWN]:
		var next: Vector2i = cell + direction
		if is_walkable(next) and (_has_ladder(cell) or _has_ladder(next)):
			result.append(next)
	return result

func _path_to(start: Vector2i, goals: Array) -> Array:
	if goals.has(start):
		return [start]
	var frontier: Array[Vector2i] = [start]
	var previous: Dictionary = {start: start}
	var head: int = 0
	while head < frontier.size():
		var cell: Vector2i = frontier[head]
		head += 1
		for next in _neighbors(cell):
			if previous.has(next):
				continue
			previous[next] = cell
			if goals.has(next):
				var path: Array = [next]
				var cursor: Vector2i = next
				while cursor != start:
					cursor = previous[cursor]
					path.push_front(cursor)
				return path
			frontier.append(next)
	return []

func _job_goals(job: Dictionary) -> Array:
	var result: Array = []
	var cell: Vector2i = job.cell
	if job.kind == "build" and job.building_kind != "ladder" and is_open(cell + Vector2i.DOWN):
		return result
	if job.kind == "build" and is_walkable(cell):
		result.append(cell)
	for direction in DIRECTIONS:
		var next: Vector2i = cell + direction
		if is_walkable(next):
			result.append(next)
	return result

func _reject(reason: String) -> bool:
	message = reason
	return false

func _foundation_owner_name(cell: Vector2i) -> String:
	var above: Dictionary = building_at(cell + Vector2i.UP)
	if not above.is_empty() and above.kind != "ladder":
		return CATALOG[above.kind].name
	var blueprint: Dictionary = job_at(cell + Vector2i.UP)
	if not blueprint.is_empty() and blueprint.kind == "build" and blueprint.building_kind != "ladder":
		return "planned %s" % CATALOG[blueprint.building_kind].name
	return ""

func queue_dig(cell: Vector2i) -> bool:
	if status != "playing":
		return _reject("This expedition has ended. Start a new colony to build again.")
	if not in_bounds(cell) or cell.x == 0 or cell.y == 0 or cell.x == width - 1 or cell.y == height - 1:
		return _reject("The outer bedrock cannot be excavated.")
	if is_open(cell):
		return _reject("Choose a solid rock or resource tile to dig.")
	var foundation_owner: String = _foundation_owner_name(cell)
	if not foundation_owner.is_empty():
		return _reject("This rock supports %s. Choose another tile." % foundation_owner)
	if not job_at(cell).is_empty():
		return _reject("That tile already has a job. Select Cancel and click the tile to remove it.")
	jobs.append({"id": _take_id(), "kind": "dig", "cell": cell, "building_kind": "", "progress": 0.0, "assigned": -1, "cost": {}, "reason": "Waiting for a reachable worker"})
	message = "Dig marked. Workers need a floor or ladder beside the tile."
	_decision_timer = 0.0
	return true

func can_build(kind: String, cell: Vector2i) -> String:
	if status != "playing":
		return "This expedition has ended. Start a new colony."
	if not CATALOG.has(kind):
		return "Choose a building from the toolbar."
	if not is_open(cell):
		return "Excavate this tile before placing a building."
	if not building_at(cell).is_empty() or not job_at(cell).is_empty():
		return "This tile is already occupied or reserved."
	if kind != "ladder" and is_open(cell + Vector2i.DOWN):
		return "Place this building on a solid floor."
	if kind != "ladder":
		var foundation_job: Dictionary = job_at(cell + Vector2i.DOWN)
		if not foundation_job.is_empty() and foundation_job.kind == "dig":
			return "This floor is marked for digging. Cancel that excavation before building here."
	if kind == "beacon":
		for building in buildings:
			if building.kind == "beacon":
				return "One hearth beacon is enough for this colony."
		for job in jobs:
			if job.building_kind == "beacon":
				return "A hearth beacon is already queued."
	var cost: Dictionary = CATALOG[kind].cost
	for resource in cost:
		if float(resources.get(resource, 0.0)) < float(cost[resource]):
			return "Need %d %s for %s." % [cost[resource], resource, CATALOG[kind].name]
	return ""

func queue_build(kind: String, cell: Vector2i) -> bool:
	var reason: String = can_build(kind, cell)
	if not reason.is_empty():
		return _reject(reason)
	var cost: Dictionary = CATALOG[kind].cost.duplicate()
	for resource in cost:
		resources[resource] -= float(cost[resource])
	jobs.append({"id": _take_id(), "kind": "build", "cell": cell, "building_kind": kind, "progress": 0.0, "assigned": -1, "cost": cost, "reason": "Waiting for a reachable worker"})
	message = "%s queued. Materials reserved; canceling returns them." % CATALOG[kind].name
	_decision_timer = 0.0
	return true

func cancel_job(cell: Vector2i) -> bool:
	var job: Dictionary = job_at(cell)
	if job.is_empty():
		return _reject("There is no queued job on this tile.")
	for resource in job.cost:
		resources[resource] += float(job.cost[resource])
	for colonist in colonists:
		if colonist.job == job.id:
			colonist.job = -1
			colonist.path = []
			colonist.task = "Ready to help"
	jobs.erase(job)
	message = "Job canceled. Reserved materials returned."
	return true

func _take_id() -> int:
	var result: int = _next_id
	_next_id += 1
	return result

func _add_building(kind: String, cell: Vector2i) -> void:
	buildings.append({"id": _take_id(), "kind": kind, "cell": cell, "active": true, "progress": 0.0, "reason": "Ready", "production": 0.0})

func _rebuild_rooms() -> void:
	var old_air: Dictionary = {}
	for room in rooms:
		for cell in room.cells:
			old_air[cell] = room.air
	rooms.clear()
	_room_ids.clear()
	for y in range(height):
		for x in range(width):
			var start := Vector2i(x, y)
			if not is_open(start) or _room_ids.has(start):
				continue
			var id: int = rooms.size()
			var cells: Array[Vector2i] = [start]
			_room_ids[start] = id
			var head: int = 0
			var air_mass: float = 0.0
			while head < cells.size():
				var cell: Vector2i = cells[head]
				head += 1
				# Freshly excavated rock contains no breathable air.
				air_mass += float(old_air.get(cell, 0.0))
				for direction in DIRECTIONS:
					var next: Vector2i = cell + direction
					if is_open(next) and not _room_ids.has(next):
						_room_ids[next] = id
						cells.append(next)
			rooms.append({"id": id, "cells": cells, "air": air_mass / float(cells.size())})

func _lit(cell: Vector2i) -> bool:
	var room: Dictionary = room_at(cell)
	if room.is_empty():
		return false
	for building in buildings:
		if building.kind != "lamp" or not building.active:
			continue
		var other: Dictionary = room_at(building.cell)
		if not other.is_empty() and other.id == room.id and Vector2(cell).distance_to(Vector2(building.cell)) <= 5.0:
			return true
	return false

func _update_buildings(dt: float) -> void:
	food_rate = 0.0
	power_rate = 0.0
	# Supply first, then consumers, then plants. Order never depends on construction order.
	for building in buildings:
		building.active = true
		building.reason = "Ready"
		if not is_open(building.cell):
			building.active = false
			building.reason = "Blocked by terrain"
		elif building.kind != "ladder" and is_open(building.cell + Vector2i.DOWN):
			building.active = false
			building.reason = "Needs a solid floor beneath it"
		if not building.active:
			continue
		if building.kind == "generator":
			if resources.biomass >= 0.025 * dt and resources.biomass > 0.0:
				resources.biomass = maxf(0.0, resources.biomass - 0.025 * dt)
				resources.power = minf(200.0, resources.power + 4.0 * dt)
				power_rate += 4.0
				building.reason = "Generating 4 power/s"
			else:
				building.active = false
				building.reason = "Needs biomass — dig green deposits"
		elif building.kind == "cistern":
			resources.water = minf(500.0, resources.water + 0.18 * dt)
			building.reason = "Collecting 0.18 water/s"
	for building in buildings:
		if not building.active or building.kind not in ["lamp", "beacon"]:
			continue
		var demand: float = 0.6 if building.kind == "lamp" else 1.8
		if resources.power >= demand * dt and resources.power > 0.0:
			resources.power = maxf(0.0, resources.power - demand * dt)
			power_rate -= demand
			building.reason = "Lighting nearby plants" if building.kind == "lamp" else "Signal active — keep the colony healthy"
		else:
			building.active = false
			building.reason = "Needs power — build or fuel a bio generator"
	for building in buildings:
		if not building.active or building.kind not in ["farm", "airfern"]:
			continue
		if not _lit(building.cell):
			building.active = false
			building.reason = "Too dark — place a powered lamp within 5 tiles"
		elif resources.water < 0.04 * dt or resources.water <= 0.0:
			building.active = false
			building.reason = "Needs water — build a dew collector or dig blue deposits"
		else:
			resources.water = maxf(0.0, resources.water - 0.04 * dt)
			if building.kind == "farm":
				building.production += dt
				while building.production >= 90.0:
					building.production -= 90.0
					resources.food = minf(500.0, resources.food + 1.0)
				building.progress = building.production / 90.0
				food_rate += 1.0 / 90.0
				building.reason = "Growing — next food in %ds" % ceili(90.0 - building.production)
			else:
				var room: Dictionary = room_at(building.cell)
				if not room.is_empty():
					room.air = minf(100.0, room.air + 20.0 * dt / float(room.cells.size()))
				building.reason = "Refreshing this room's air"

func _job_by_id(id: int) -> Dictionary:
	for job in jobs:
		if job.id == id:
			return job
	return {}

func _release_job(colonist: Dictionary) -> void:
	var job: Dictionary = _job_by_id(colonist.job)
	if not job.is_empty():
		job.assigned = -1
	colonist.job = -1
	colonist.path = []

func _find_work(colonist: Dictionary) -> void:
	var start := Vector2i(Vector2(colonist.pos).round())
	for job in jobs:
		if job.assigned != -1:
			continue
		var path: Array = _path_to(start, _job_goals(job))
		if path.is_empty():
			job.reason = "Unreachable — dig a route or extend a ladder"
			continue
		job.assigned = colonist.id
		job.reason = "%s is on the way" % colonist.name
		colonist.job = job.id
		colonist.path = path
		colonist.task = "Digging" if job.kind == "dig" else "Building %s" % CATALOG[job.building_kind].name
		return
	colonist.task = "Ready to help" if jobs.is_empty() else "No reachable jobs"

func _find_bed(colonist: Dictionary) -> void:
	for building in buildings:
		if building.kind != "bed" or not building.active:
			continue
		var occupied: bool = false
		for other in colonists:
			if other.alive and other.id != colonist.id and other.bed == building.id:
				occupied = true
		if occupied:
			continue
		var path: Array = _path_to(Vector2i(Vector2(colonist.pos).round()), [building.cell])
		if not path.is_empty():
			_release_job(colonist)
			colonist.bed = building.id
			colonist.resting = true
			colonist.path = path
			colonist.task = "Going to bed"
			return

func _move(colonist: Dictionary, dt: float) -> bool:
	var remaining: float = 2.1 * dt
	while not colonist.path.is_empty():
		var destination: Vector2 = Vector2(colonist.path[0])
		if not is_walkable(Vector2i(destination)):
			colonist.path = []
			return false
		var distance: float = Vector2(colonist.pos).distance_to(destination)
		if distance <= remaining:
			colonist.pos = destination
			colonist.path.pop_front()
			remaining -= distance
		else:
			colonist.pos = Vector2(colonist.pos).move_toward(destination, remaining)
			return false
	return true

func _cancel_protected_dig(job: Dictionary) -> bool:
	if job.kind != "dig":
		return false
	var foundation_owner: String = _foundation_owner_name(job.cell)
	if foundation_owner.is_empty():
		return false
	# Planned and finished buildings both own their supporting floor. Revalidate
	# at execution and completion, then release the worker through normal cancel.
	cancel_job(job.cell)
	_notify("Dig canceled: this rock now supports %s." % foundation_owner)
	return true

func _finish_job(job: Dictionary) -> void:
	var cell: Vector2i = job.cell
	if job.kind == "dig":
		if _cancel_protected_dig(job):
			return
		var material: int = tiles[cell.y][cell.x]
		tiles[cell.y][cell.x] = 0
		resources.ore += 3.0 if material == 1 else (16.0 if material == 2 else 1.0)
		if material == 3:
			resources.biomass += 18.0
		elif material == 4:
			resources.water += 25.0
		_rebuild_rooms()
	else:
		# A floor may have been dug away after the job was queued.
		if job.building_kind != "ladder" and is_open(cell + Vector2i.DOWN):
			job.assigned = -1
			job.reason = "Construction needs a solid floor"
			job.progress = 0.99
			return
		_add_building(job.building_kind, cell)
		_notify("%s completed." % CATALOG[job.building_kind].name)
	jobs.erase(job)
	for colonist in colonists:
		if colonist.job == job.id:
			colonist.job = -1
			colonist.path = []
	_decision_timer = 0.0

func _notify(text: String) -> void:
	message = text
	events.append(text)
	if events.size() > 12:
		events.pop_front()

func _update_colonist(colonist: Dictionary, dt: float, decide: bool) -> void:
	if not colonist.alive:
		return
	colonist.hunger = minf(100.0, colonist.hunger + 0.12 * dt)
	colonist.energy = maxf(0.0, colonist.energy - 0.055 * dt)
	if colonist.hunger >= 35.0 and resources.food >= 1.0:
		resources.food -= 1.0
		colonist.hunger = maxf(0.0, colonist.hunger - 35.0)
	var cell := Vector2i(Vector2(colonist.pos).round())
	var room: Dictionary = room_at(cell)
	var air: float = float(room.get("air", 0.0))
	if not room.is_empty():
		room.air = maxf(0.0, room.air - 6.0 * dt / float(room.cells.size()))
	if air < 15.0:
		colonist.health = maxf(0.0, colonist.health - (15.0 - air) * 0.035 * dt)
	if colonist.hunger >= 95.0:
		colonist.health = maxf(0.0, colonist.health - 0.3 * dt)
	if air > 40.0 and colonist.hunger < 70.0:
		colonist.health = minf(100.0, colonist.health + 0.04 * dt)
	if colonist.health <= 0.0:
		colonist.alive = false
		colonist.task = "Lost"
		colonist.bed = -1
		_release_job(colonist)
		_notify("%s was lost. Check food and room air before expanding." % colonist.name)
		return
	# An excavated floor causes a visible fall to the next supporting tile.
	if not is_walkable(cell):
		_release_job(colonist)
		colonist.resting = false
		colonist.bed = -1
		colonist.task = "Falling"
		var next: Vector2i = cell + Vector2i.DOWN
		if is_open(next):
			colonist.pos = Vector2(colonist.pos).move_toward(Vector2(next), 5.0 * dt)
		return
	if colonist.energy < 30.0 and not colonist.resting and decide:
		_find_bed(colonist)
	if colonist.resting:
		if _move(colonist, dt):
			var at_bed: bool = false
			for building in buildings:
				if building.id == colonist.bed and building.active and Vector2(colonist.pos).distance_to(Vector2(building.cell)) < 0.01:
					at_bed = true
			if not at_bed:
				colonist.resting = false
				colonist.bed = -1
				return
			colonist.task = "Resting"
			colonist.energy = minf(100.0, colonist.energy + 3.5 * dt)
			if colonist.energy >= 95.0:
				colonist.resting = false
				colonist.bed = -1
		return
	if colonist.energy < 5.0:
		colonist.task = "Resting on the ground — needs a reachable bed"
		colonist.energy = minf(30.0, colonist.energy + 0.35 * dt)
		return
	if colonist.job == -1 and decide:
		_find_work(colonist)
	var job: Dictionary = _job_by_id(colonist.job)
	if job.is_empty():
		return
	if _cancel_protected_dig(job):
		return
	if not _move(colonist, dt):
		if colonist.path.is_empty():
			_release_job(colonist)
		return
	var goals: Array = _job_goals(job)
	if not goals.has(Vector2i(Vector2(colonist.pos).round())):
		_release_job(colonist)
		return
	job.reason = "%s is working" % colonist.name
	job.progress = minf(1.0, job.progress + dt / (3.0 if job.kind == "dig" else 5.0))
	if job.progress >= 1.0:
		_finish_job(job)

func _update_objective(dt: float) -> void:
	var living: int = 0
	var healthy: bool = true
	var room_demand: Dictionary = {}
	for colonist in colonists:
		if colonist.alive:
			living += 1
			var room: Dictionary = room_at(Vector2i(Vector2(colonist.pos).round()))
			var room_id: int = int(room.get("id", -1))
			room_demand[room_id] = float(room_demand.get(room_id, 0.0)) + 6.0
			if float(room.get("air", 0.0)) < 50.0 or colonist.health < 75.0 or colonist.hunger > 70.0:
				healthy = false
	if living == 0:
		status = "lost"
		_notify("The colony fell silent. Begin again with what you learned.")
		return
	var beacon_active: bool = false
	var room_supply: Dictionary = {}
	var water_supply: float = 0.0
	var water_demand: float = 0.0
	for building in buildings:
		if building.active and building.kind == "beacon":
			beacon_active = true
		if building.active and building.kind == "airfern":
			var room: Dictionary = room_at(building.cell)
			var room_id: int = int(room.get("id", -1))
			room_supply[room_id] = float(room_supply.get(room_id, 0.0)) + 20.0
		if building.active and building.kind == "cistern":
			water_supply += 0.18
		if building.active and building.kind in ["farm", "airfern"]:
			water_demand += 0.04
	var air_sustainable: bool = true
	for room_id in room_demand:
		if float(room_supply.get(room_id, 0.0)) < float(room_demand[room_id]):
			air_sustainable = false
	# Demand is the long-term food use, not the instant between meals.
	objective_reason = ""
	if not beacon_active:
		objective_reason = "Build and power a hearth beacon."
	elif not healthy:
		objective_reason = "Keep every survivor healthy, fed and in at least 50% air."
	elif food_rate < float(living) * 0.12 / 35.0:
		objective_reason = "Grow enough food: four colonists need two active mushroom beds."
	elif not air_sustainable:
		objective_reason = "Add breathing ferns in occupied rooms: four colonists need two."
	elif power_rate < 0.0:
		objective_reason = "Generate at least as much power as the colony uses."
	elif water_supply < water_demand:
		objective_reason = "Add dew collectors to replenish the water your plants use."
	elif resources.food < 8.0 or resources.water < 10.0:
		objective_reason = "Build a reserve of at least 8 food and 10 water."
	if objective_reason.is_empty():
		stable_seconds = minf(STABLE_SECONDS, stable_seconds + dt)
	else:
		stable_seconds = 0.0
	objective_progress = minf(minf(1.0, elapsed / SURVIVAL_SECONDS), stable_seconds / STABLE_SECONDS)
	if elapsed >= SURVIVAL_SECONDS and stable_seconds >= STABLE_SECONDS:
		status = "won"
		_notify("Mosslight thrives. Your living shelter has become a home.")

func objective_text() -> String:
	var progress: String = "Survive 20 minutes (%d:%02d / 20:00). Healthy, sustainable beacon: %d/120s." % [int(elapsed) / 60, int(elapsed) % 60, int(stable_seconds)]
	return progress + (" " + objective_reason if not objective_reason.is_empty() else " Your habitat is self-sustaining.")

func step(dt: float) -> void:
	if status != "playing" or not is_finite(dt) or dt <= 0.0:
		return
	# Bounded slices preserve transactions and path following for callers with a slow frame.
	var remaining: float = minf(dt, 1.0)
	while remaining > 0.00001 and status == "playing":
		var slice: float = minf(remaining, 0.1)
		remaining -= slice
		elapsed += slice
		day = int(elapsed / DAY_SECONDS) + 1
		_decision_timer -= slice
		var decide: bool = _decision_timer <= 0.0
		if decide:
			_decision_timer = 0.5
		_update_buildings(slice)
		for colonist in colonists:
			_update_colonist(colonist, slice, decide)
		_update_objective(slice)

func cell_info(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return "Beyond the cavern"
	var names: Array[String] = ["Open cavern", "Stone · yields 3 ore", "Ore vein · yields 16 ore", "Root deposit · yields 18 biomass", "Water pocket · yields 25 water"]
	var lines: Array[String] = [names[tiles[cell.y][cell.x]]]
	var building: Dictionary = building_at(cell)
	if not building.is_empty():
		lines.append(CATALOG[building.kind].name + " — " + str(building.reason))
	var job: Dictionary = job_at(cell)
	if not job.is_empty():
		lines.append("%s %d%% — %s" % ["Dig" if job.kind == "dig" else CATALOG[job.building_kind].name, int(job.progress * 100.0), job.reason])
	var room: Dictionary = room_at(cell)
	if not room.is_empty():
		lines.append("Room air: %d%% · %d tiles" % [int(room.air), room.cells.size()])
	for colonist in colonists:
		if Vector2i(Vector2(colonist.pos).round()) == cell:
			lines.append("%s · %s · health %d%%" % [colonist.name, colonist.task, int(colonist.health)])
	return "\n".join(lines)
