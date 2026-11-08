extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const PLUG := Vector2i(18, 20)
const EXTRA_FARM := Vector2i(21, 16)
const EXTRA_FERN := Vector2i(22, 16)
const BEACON := Vector2i(11, 6)
const FOUNDATION := Vector2i(11, 7)
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func advance(sim: RefCounted, seconds: float) -> void:
	for i in range(int(ceil(seconds * 10.0))):
		sim.step(0.1)

func advance_until(sim: RefCounted, predicate: Callable, maximum_seconds: float = 120.0) -> bool:
	for i in range(int(maximum_seconds * 10.0)):
		if predicate.call():
			return true
		sim.step(0.1)
	return predicate.call()

func _init() -> void:
	if "--foundations-only" in OS.get_cmdline_user_args():
		_test_foundation_races()
		print("Mosslight foundations: %d checks, %d failures" % [checks, failures.size()])
		quit(0 if failures.is_empty() else 1)
		return
	if "--terrain-only" in OS.get_cmdline_user_args():
		_test_multilevel_terrain()
		print("Mosslight terrain: %d checks, %d failures" % [checks, failures.size()])
		quit(0 if failures.is_empty() else 1)
		return
	_test_initial_state()
	_test_multilevel_terrain()
	_test_accounting()
	_test_building_footprints()
	_test_ladder_occupancy()
	_test_footprint_races()
	_test_large_building_access()
	_test_foundation_races()
	_test_work_and_reachability()
	_test_rooms()
	_test_production()
	_test_rest_and_terminal_states()
	_test_local_sustainability()
	_test_playable_win()
	print("Mosslight simulation: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_initial_state() -> void:
	var a = Simulation.new()
	var b = Simulation.new()
	check(a.tiles == b.tiles, "same seed gives same terrain")
	check(a.colonists.size() == 4 and a.buildings.size() == 19, "four settlers, nine buildings and ten starter ladder sections")
	check(a.rooms.size() == 3, "three separated cave rooms")
	for colonist in a.colonists:
		check(a.is_walkable(Vector2i(colonist.pos)), "each settler starts on reachable ground")
	a.reset(543)
	check(a.tiles != b.tiles, "different seeds vary resource deposits")
	check(a.tiles[20][18] == 2 and a.tiles[23][25] == 2 and a.tiles[23][26] == 2, "lower exploration route always supplies useful ore")
	a.step(-1.0)
	a.step(NAN)
	check(a.elapsed == 0.0, "negative and nonfinite deltas cannot corrupt state")
	a.step(100.0)
	check(absf(a.elapsed - 1.0) < 0.0001, "slow calls are capped at one second")

func _test_multilevel_terrain() -> void:
	var sim = Simulation.new()
	var elevations: Dictionary = {}
	for building in sim.buildings:
		if building.kind != "ladder":
			elevations[building.cell.y] = true
	check(elevations.size() >= 3, "starter buildings occupy at least three real terrain elevations")
	var landmark_values: Variant = sim.get("landmarks")
	check(landmark_values is Array and landmark_values.size() == 4, "four authored cave landmarks identify distinct spaces")
	check(sim.is_open(Vector2i(8, 6)) and not sim.is_open(Vector2i(8, 7)), "upper roost has a real supporting ledge")
	check(sim.is_open(Vector2i(29, 18)) and not sim.is_open(Vector2i(29, 19)), "dew basin sits on a lower terrain shelf")
	var terrace_path: Array = sim._path_to(Vector2i(12, 13), [Vector2i(29, 18)])
	check(not terrace_path.is_empty(), "colonists can walk the actual stepped main floor")
	var terrace_heights: Dictionary = {}
	for cell in terrace_path:
		terrace_heights[cell.y] = true
	check(terrace_heights.size() >= 5, "main route physically traverses five height levels")
	var roost_path: Array = sim._path_to(Vector2i(8, 6), [Vector2i(22, 16)])
	check(roost_path.has(Vector2i(14, 7)) and roost_path.has(Vector2i(14, 12)), "upper roost route actually uses the starter ladder shaft")
	check(sim._path_to(Vector2i(22, 16), [Vector2i(24, 23)]).is_empty(), "lower quarry is inaccessible before excavating and extending the shaft")
	for colonist in sim.colonists:
		check(float(sim.room_at(Vector2i(colonist.pos)).get("air", 0.0)) == 85.0, "every actual starting colonist room has safe air")
	check(float(sim.room_at(Vector2i(24, 23)).get("air", 0.0)) == 18.0, "sealed quarry has independently stale air")

func _test_accounting() -> void:
	var sim = Simulation.new()
	var ore: float = sim.resources.ore
	var biomass: float = sim.resources.biomass
	check(sim.queue_build("farm", EXTRA_FARM), "valid construction queues")
	check(sim.resources.ore == ore - 8.0 and sim.resources.biomass == biomass - 8.0, "materials reserved once")
	check(not sim.queue_build("farm", EXTRA_FARM), "duplicate construction rejected")
	check(sim.resources.ore == ore - 8.0, "duplicate cannot charge twice")
	check(sim.cancel_job(EXTRA_FARM), "queued construction cancels")
	check(sim.resources.ore == ore and sim.resources.biomass == biomass, "cancel refunds all reserved materials")
	check(not sim.cancel_job(EXTRA_FARM) and sim.resources.ore == ore, "double cancel cannot mint resources")
	check(not sim.queue_build("beacon", BEACON), "insufficient materials rejected")
	check(sim.resources.ore == ore, "failed construction is free")
	check(not sim.queue_build("farm", Vector2i(21, 15)), "floating farm rejected")
	check(not sim.queue_build("farm", Vector2i(23, 17)), "solid tile building rejected")
	check(not sim.queue_build("farm", Vector2i(24, 16)), "occupied tile building rejected")
	check(not sim.queue_dig(Vector2i(0, 3)), "boundary rock protected")
	check(not sim.queue_dig(Vector2i(-1, 3)), "out-of-bounds dig rejected")
	check(not sim.queue_dig(Vector2i(24, 17)), "building foundations protected")

func _flat_footprint_colony() -> RefCounted:
	# A plain test floor isolates footprint geometry from the authored cave route.
	var sim = Simulation.new()
	sim.buildings.clear()
	sim.jobs.clear()
	for y in range(sim.height):
		for x in range(sim.width):
			sim.tiles[y][x] = 1 if y >= 12 or y == 0 or x == 0 or x == sim.width - 1 else 0
	sim._rebuild_rooms()
	for room in sim.rooms:
		room.air = 85.0
	sim.resources.ore = 1000.0
	sim.resources.biomass = 1000.0
	sim.colonists.resize(1)
	sim.colonists[0].pos = Vector2(8, 11)
	return sim

func _test_building_footprints() -> void:
	var starter = Simulation.new()
	var occupied: Dictionary = {}
	for building in starter.buildings:
		var area: Rect2i = starter.building_rect(building.kind, building.cell)
		check(starter._building_site_reason(building.kind, building.cell, building.id).is_empty(), "%s starter has full clearance and support" % building.kind)
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				var cell := Vector2i(x, y)
				check(not occupied.has(cell) and starter.building_at(cell).get("id", -1) == building.id, "%s starter occupies distinct cell %s" % [building.kind, cell])
				occupied[cell] = building.id
	var sizes: Dictionary = {"ladder": Vector2i(1, 1), "bed": Vector2i(2, 1), "farm": Vector2i(1, 1), "airfern": Vector2i(1, 2), "lamp": Vector2i(1, 2), "generator": Vector2i(2, 2), "cistern": Vector2i(2, 2), "beacon": Vector2i(2, 3)}
	var anchor := Vector2i(12, 11)
	for kind in sizes:
		var sim: RefCounted = _flat_footprint_colony()
		var size: Vector2i = sizes[kind]
		var area: Rect2i = sim.building_rect(kind, anchor)
		check(sim.building_size(kind) == size and area == Rect2i(anchor - Vector2i(0, size.y - 1), size), "%s uses its specified bottom-left footprint" % kind)
		check(sim.can_build(kind, anchor).is_empty(), "%s fits clear supported footprint" % kind)
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				sim.tiles[y][x] = 1
				check(not sim.can_build(kind, anchor).is_empty(), "%s needs clearance at %s" % [kind, Vector2i(x, y)])
				sim.tiles[y][x] = 0
		if kind != "ladder":
			for x in range(anchor.x, anchor.x + size.x):
				var support := Vector2i(x, anchor.y + 1)
				sim.tiles[support.y][support.x] = 0
				check(sim.can_build(kind, anchor).contains("floor"), "%s needs support under column %d" % [kind, x])
				sim.tiles[support.y][support.x] = 1
				check(sim.queue_dig(support), "%s can plan excavation before reserving column %d" % [kind, x])
				check(sim.can_build(kind, anchor).contains("digging"), "%s rejects excavation under column %d" % [kind, x])
				sim.cancel_job(support)
		var original: Dictionary = sim.resources.duplicate()
		check(sim.queue_build(kind, anchor), "%s reserves its full footprint" % kind)
		var job: Dictionary = sim.job_at(anchor)
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				var cell := Vector2i(x, y)
				check(sim.job_at(cell).get("id", -1) == job.id and not sim.can_build("ladder", cell).is_empty(), "%s reserved cell %s is queryable and blocks overlap" % [kind, cell])
		if kind != "ladder":
			for x in range(anchor.x, anchor.x + size.x):
				check(not sim.queue_dig(Vector2i(x, anchor.y + 1)), "%s blueprint protects column %d" % [kind, x])
		var corner := Vector2i(area.end.x - 1, area.position.y)
		check(sim.cancel_job(corner) and sim.resources == original and sim.jobs.is_empty(), "%s cancels through its far corner and refunds once" % kind)
		check(not sim.cancel_job(anchor) and sim.resources == original, "%s cannot refund again through its anchor" % kind)
		sim._add_building(kind, anchor)
		var built: Dictionary = sim.building_at(anchor)
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				var cell := Vector2i(x, y)
				check(sim.building_at(cell).get("id", -1) == built.id and not sim.can_build("ladder", cell).is_empty(), "%s built cell %s is queryable and blocks overlap" % [kind, cell])
		if kind != "ladder":
			for x in range(anchor.x, anchor.x + size.x):
				check(not sim.queue_dig(Vector2i(x, anchor.y + 1)), "%s completed foundation protects column %d" % [kind, x])
	var bounds: RefCounted = _flat_footprint_colony()
	for edge in [Vector2i(-1, 11), Vector2i(bounds.width - 1, 11), Vector2i(12, 1)]:
		check(bounds.can_build("beacon", edge).contains("cavern"), "whole beacon must fit inside boundary at %s" % edge)
	bounds._carve(Rect2i(12, bounds.height - 3, 2, 3))
	check(bounds.can_build("beacon", Vector2i(12, bounds.height - 1)).contains("floor"), "world edge cannot substitute for a solid foundation")
	var overlap: RefCounted = _flat_footprint_colony()
	overlap._add_building("bed", Vector2i(13, 11))
	check(overlap.can_build("bed", anchor).contains("occupied"), "candidate's far column cannot overlap an existing anchor")
	check(overlap.can_build("bed", Vector2i(14, 11)).contains("occupied"), "candidate anchor cannot overlap an existing far column")

func _test_footprint_races() -> void:
	var anchor := Vector2i(12, 11)
	for defect in ["upper terrain", "second foundation", "building overlap", "blueprint overlap", "foundation excavation"]:
		var sim: RefCounted = _flat_footprint_colony()
		var original: Dictionary = sim.resources.duplicate()
		check(sim.queue_build("generator", anchor), "%s race: wide building queues" % defect)
		var job: Dictionary = sim.job_at(anchor)
		job.progress = 0.75
		var worker: Dictionary = sim.colonists[0]
		worker.pos = Vector2(anchor)
		sim._find_work(worker)
		check(worker.job == job.id, "%s race: valid site gets a worker" % defect)
		match defect:
			"upper terrain":
				sim.tiles[10][13] = 1
			"second foundation":
				sim.tiles[12][13] = 0
			"building overlap":
				sim._add_building("ladder", Vector2i(13, 10))
			"blueprint overlap":
				var conflict: Dictionary = job.duplicate(true)
				conflict.id = sim._take_id()
				conflict.building_kind = "ladder"
				conflict.cell = Vector2i(13, 10)
				conflict.assigned = -1
				conflict.cost = {}
				sim.jobs.append(conflict)
			"foundation excavation":
				sim.jobs.append({"id": sim._take_id(), "kind": "dig", "cell": Vector2i(13, 12), "building_kind": "", "progress": 0.0, "assigned": -1, "cost": {}, "reason": "Stale excavation"})
		sim._update_colonist(worker, 0.1, false)
		check(job.progress == 0.75 and job.assigned == -1 and worker.job == -1, "%s race: execution stops and releases the worker" % defect)
		# Assignment examines this job alone so a separately injected conflict cannot be chosen instead.
		check(sim._job_goals(job).is_empty(), "%s race: invalid footprint supplies no remote work positions" % defect)
		sim._find_work(worker)
		check(worker.job != job.id and job.assigned == -1, "%s race: invalid footprint cannot be reassigned" % defect)
		sim._release_job(worker)
		job.progress = 1.0
		sim._finish_job(job)
		check(sim.building_at(anchor).is_empty() and sim.jobs.has(job) and job.progress < 1.0, "%s race: completion revalidates the entire footprint" % defect)
		check(sim.resources.ore == original.ore - 20.0, "%s race: failed completion retains exactly one reservation" % defect)
		check(sim.cancel_job(anchor) and sim.resources.ore == original.ore, "%s race: blocked construction remains fully refundable" % defect)
	var active: RefCounted = _flat_footprint_colony()
	active._add_building("generator", anchor)
	var building: Dictionary = active.building_at(anchor)
	for defect in [Vector2i(13, 10), Vector2i(13, 12)]:
		var original_tile: int = active.tiles[defect.y][defect.x]
		active.tiles[defect.y][defect.x] = 1 if original_tile == 0 else 0
		var before: float = active.resources.biomass
		active._update_buildings(1.0)
		check(not building.active and active.resources.biomass == before, "production stops when non-anchor footprint or support fails at %s" % defect)
		active.tiles[defect.y][defect.x] = original_tile
		active._update_buildings(1.0)
		check(building.active and active.resources.biomass < before, "valid full footprint resumes production after %s is repaired" % defect)

func _test_large_building_access() -> void:
	var anchor := Vector2i(12, 11)
	for start in [Vector2i(11, 11), Vector2i(12, 11), Vector2i(13, 11), Vector2i(14, 11)]:
		var sim: RefCounted = _flat_footprint_colony()
		var worker: Dictionary = sim.colonists[0]
		worker.pos = Vector2(start)
		check(sim.queue_build("beacon", anchor), "largest building queues beside worker at %s" % start)
		var job: Dictionary = sim.job_at(anchor)
		var goals: Array = sim._job_goals(job)
		check(goals.has(start), "largest building can be worked from floor or perimeter cell %s" % start)
		check(not goals.has(Vector2i(15, 11)) and not goals.has(Vector2i(10, 11)), "largest building never exposes remote floor cells as work goals")
		check(advance_until(sim, func() -> bool: return sim.jobs.is_empty(), 8.0), "worker at %s completes largest building without reaching the anchor" % start)
		check(sim.building_at(Vector2i(13, 9)).get("kind", "") == "beacon" and worker.pos == Vector2(start), "largest building completes at full height with worker staying at %s" % start)
	var isolated = Simulation.new()
	isolated.resources.ore = 100.0
	check(isolated.queue_build("beacon", Vector2i(40, 14)), "largest building can be planned in sealed cave")
	advance(isolated, 15.0)
	check(isolated.jobs[0].progress == 0.0 and isolated.jobs[0].reason.contains("Unreachable"), "workers never remotely construct a large building in another cave")

func _test_work_and_reachability() -> void:
	var sim = Simulation.new()
	check(sim.queue_dig(PLUG), "reachable dig accepted")
	var start: Vector2 = sim.colonists[0].pos
	sim.step(0.1)
	check(sim.tiles[20][18] == 2 and sim.jobs[0].progress == 0.0, "workers must travel before digging")
	advance(sim, 1.0)
	check(sim.colonists[0].pos != start, "assigned colonist visibly travels")
	advance_until(sim, func() -> bool: return sim.jobs.is_empty())
	check(sim.tiles[20][18] == 0 and sim.jobs.is_empty(), "worker completes reachable dig")
	check(sim.resources.ore == 52.0, "ore deposit harvested exactly once")
	check(not sim.queue_dig(PLUG), "excavated tile cannot be harvested twice")
	check(sim.queue_dig(Vector2i(40, 3)), "inaccessible dig can be planned")
	advance(sim, 15.0)
	check(sim.tiles[3][40] != 0 and sim.jobs[0].progress == 0.0, "workers never remotely mine inaccessible terrain")
	check(sim.jobs[0].reason.contains("Unreachable"), "inaccessible job explains the missing route")
	sim.cancel_job(Vector2i(40, 3))
	check(sim.queue_build("ladder", Vector2i(18, 20)), "ladder can extend through mined shaft plug")
	advance_until(sim, func() -> bool: return sim.jobs.is_empty())
	check(sim.is_walkable(Vector2i(18, 20)), "completed ladder creates vertical route")
	check(sim.queue_build("ladder", Vector2i(18, 21)), "ladder can extend downward again")
	advance_until(sim, func() -> bool: return sim.jobs.is_empty())
	check(not sim.building_at(Vector2i(18, 21)).is_empty(), "worker reaches and builds lower ladder")
	check(sim.queue_build("farm", EXTRA_FARM), "farm still queues after exploration")
	advance(sim, 0.8)
	var before: float = sim.resources.ore
	check(sim.cancel_job(EXTRA_FARM), "in-progress construction cancels")
	check(sim.resources.ore == before + 8.0, "in-progress cancel refunds materials")
	advance(sim, 10.0)
	check(sim.building_at(EXTRA_FARM).is_empty(), "canceled worker cannot finish ghost building")

func _foundation_colony() -> RefCounted:
	var sim = Simulation.new()
	# Earn beacon materials and give every case the same realistic worker positions.
	sim.queue_dig(PLUG)
	advance_until(sim, func() -> bool: return sim.jobs.is_empty())
	for y in range(20, 23):
		sim.queue_build("ladder", Vector2i(18, y))
	advance_until(sim, func() -> bool: return sim.jobs.is_empty())
	for x in range(25, 27):
		sim.queue_dig(Vector2i(x, 23))
	advance_until(sim, func() -> bool: return sim.jobs.is_empty())
	return sim

func _test_foundation_races() -> void:
	for kind in Simulation.CATALOG:
		if kind == "ladder":
			continue
		var sim: RefCounted = _foundation_colony()
		check(sim.queue_build(kind, BEACON), "%s race: construction queues with earned materials" % kind)
		var ore_after_reservation: float = sim.resources.ore
		check(not sim.queue_dig(FOUNDATION), "%s race: blueprint immediately protects its foundation" % kind)
		check(sim.jobs.size() == 1 and sim.resources.ore == ore_after_reservation, "%s race: refused dig changes no jobs or material reservations" % kind)
		advance_until(sim, func() -> bool: return float(sim.job_at(BEACON).get("progress", 0.0)) >= 0.8)
		check(sim.building_at(BEACON).is_empty(), "%s race: building is still under construction" % kind)
		check(not sim.queue_dig(FOUNDATION), "%s race: nearly completed blueprint still protects its foundation" % kind)
		var foundation_feedback: String = sim.message
		advance_until(sim, func() -> bool: return sim.jobs.is_empty())
		check(sim.tiles[FOUNDATION.y][FOUNDATION.x] != 0, "%s race: completed building retains its foundation" % kind)
		check(not sim.building_at(BEACON).is_empty(), "%s race: construction completes normally" % kind)
		check(sim.jobs.is_empty(), "%s race: invalidated excavation is removed" % kind)
		check(sim.resources.ore == ore_after_reservation, "%s race: canceled foundation dig yields no materials" % kind)
		var all_released: bool = true
		for colonist in sim.colonists:
			if colonist.job != -1:
				all_released = false
		check(all_released, "%s race: workers release canceled foundation job" % kind)
		check(foundation_feedback.contains("supports") and foundation_feedback.contains("planned"), "%s race: rejection explains planned foundation protection" % kind)
		var reverse: RefCounted = _foundation_colony()
		check(reverse.queue_dig(FOUNDATION), "%s reverse race: excavation can be planned first" % kind)
		var resources_before: Dictionary = reverse.resources.duplicate()
		check(not reverse.queue_build(kind, BEACON), "%s reverse race: cannot build on marked excavation" % kind)
		check(reverse.resources == resources_before, "%s reverse race: refused building reserves no materials" % kind)
		check(reverse.cancel_job(FOUNDATION), "%s reverse race: foundation excavation can be canceled" % kind)
		check(reverse.queue_build(kind, BEACON), "%s reverse race: building succeeds after canceling excavation" % kind)
		check(reverse.cancel_job(BEACON) and reverse.resources == resources_before, "%s reverse race: construction still refunds in full" % kind)
		# An interleaving fixture also checks execution and completion independently
		# of command validation: reintroduce a formerly valid, now obsolete dig.
		check(reverse.queue_dig(FOUNDATION), "%s stale race: floor becomes diggable after blueprint cancellation" % kind)
		var stale_dig: Dictionary = reverse.job_at(FOUNDATION).duplicate(true)
		reverse.cancel_job(FOUNDATION)
		check(reverse.queue_build(kind, BEACON), "%s stale race: construction reserves its foundation again" % kind)
		var reserved_ore: float = reverse.resources.ore
		reverse.jobs.append(stale_dig)
		reverse.step(0.1)
		check(reverse.job_at(FOUNDATION).is_empty() and reverse.tiles[FOUNDATION.y][FOUNDATION.x] != 0, "%s stale race: execution cancels obsolete excavation without digging" % kind)
		check(not reverse.job_at(BEACON).is_empty() and reverse.resources.ore == reserved_ore, "%s stale race: execution preserves construction and its reservation" % kind)
		var stale_completion: Dictionary = stale_dig.duplicate(true)
		reverse.jobs.append(stale_completion)
		reverse._finish_job(stale_completion)
		check(reverse.job_at(FOUNDATION).is_empty() and reverse.tiles[FOUNDATION.y][FOUNDATION.x] != 0, "%s stale race: completion also revalidates the planned foundation" % kind)
		check(not reverse.job_at(BEACON).is_empty() and reverse.resources.ore == reserved_ore, "%s stale race: refused completion preserves construction and its reservation" % kind)
		check(reverse.cancel_job(BEACON) and reverse.resources.ore == resources_before.ore, "%s stale race: construction still refunds after obsolete excavation is canceled" % kind)

func _test_rooms() -> void:
	var sim = Simulation.new()
	var mass: float = 0.0
	for room in sim.rooms:
		mass += room.air * room.cells.size()
	var before_air: float = sim.room_at(Vector2i(22, 16)).air
	sim.tiles[PLUG.y][PLUG.x] = 0
	sim._rebuild_rooms()
	var after: float = 0.0
	for room in sim.rooms:
		after += room.air * room.cells.size()
	check(sim.rooms.size() == 2, "breaching adjacent cave joins the room")
	check(absf(mass - after) < 0.001, "room joining conserves breathable air mass")
	check(sim.room_at(Vector2i(22, 16)).air < before_air - 5.0, "stale chamber materially lowers colony air")
	check(sim.room_at(Vector2i(22, 16)).id == sim.room_at(Vector2i(24, 23)).id, "new shaft joins the correct rooms")
	var vault_air: float = sim.room_at(Vector2i(40, 13)).air
	advance(sim, 20.0)
	check(sim.room_at(Vector2i(40, 13)).air == vault_air, "sealed unoccupied room does not consume colony air")

func _test_production() -> void:
	var sim = Simulation.new()
	var food: float = sim.resources.food
	advance(sim, 91.0)
	check(sim.resources.food == food + 1.0, "lit watered mushrooms produce food")
	sim.resources.biomass = 0.0
	sim.resources.power = 0.0
	advance(sim, 1.0)
	check(not sim.building_at(Vector2i(23, 16)).active, "empty generator supply disables lamp")
	check(not sim.building_at(Vector2i(24, 16)).active, "dark crops stop growing")
	check(sim.building_at(Vector2i(24, 16)).reason.contains("dark"), "dark crop reason is actionable")
	sim.resources.water = 0.0
	sim.resources.power = 20.0
	for building in sim.buildings:
		if building.kind == "cistern":
			sim.buildings.erase(building)
			break
	advance(sim, 1.0)
	check(not sim.building_at(Vector2i(27, 18)).active, "water shortage stops airfern")
	for resource in sim.resources:
		check(is_finite(sim.resources[resource]) and sim.resources[resource] >= 0.0, "resource %s stays finite and nonnegative" % resource)
	var new_sim = Simulation.new()
	check(new_sim.queue_build("farm", Vector2i(11, 13)), "unlit farm can be built deliberately")
	advance_until(new_sim, func() -> bool: return new_sim.jobs.is_empty())
	new_sim.step(0.1)
	check(not new_sim.building_at(Vector2i(11, 13)).active, "distant farm requires its own nearby lamp")

func _test_rest_and_terminal_states() -> void:
	var sim = Simulation.new()
	sim.colonists[0].energy = 10.0
	advance(sim, 20.0)
	check(sim.colonists[0].energy > 50.0, "tired colonist travels to bed and recovers")
	var doomed = Simulation.new()
	doomed.buildings.clear()
	doomed.resources.food = 0.0
	for room in doomed.rooms:
		room.air = 0.0
	for colonist in doomed.colonists:
		colonist.health = 1.0
	advance(doomed, 10.0)
	check(doomed.status == "lost", "all colonists dying ends the expedition")
	var elapsed: float = doomed.elapsed
	doomed.step(1.0)
	check(doomed.elapsed == elapsed, "terminal expedition stops simulation")
	check(not doomed.queue_dig(PLUG), "terminal expedition rejects commands")
	doomed.reset()
	check(doomed.status == "playing" and doomed.elapsed == 0.0 and doomed.colonists[0].health == 100.0, "retry fully resets colony state")

func _test_playable_win() -> void:
	# An ordinary command-only expedition. No resources, timers or outcomes are injected.
	var sim = Simulation.new()
	check(sim.queue_build("farm", EXTRA_FARM), "survival route queues second farm")
	check(sim.queue_build("airfern", EXTRA_FERN), "survival route queues second fern")
	check(sim.queue_dig(PLUG), "survival route excavates the lower shaft plug")
	check(advance_until(sim, func() -> bool: return sim.jobs.is_empty()), "colony completes initial planting and shaft excavation")
	for y in range(20, 23):
		check(sim.queue_build("ladder", Vector2i(18, y)), "survival route extends real ladder section %d" % y)
	check(advance_until(sim, func() -> bool: return sim.jobs.is_empty()), "colony completes lower shaft ladder")
	for x in range(25, 27):
		check(sim.queue_dig(Vector2i(x, 23)), "survival route queues deep ore %d" % x)
	check(sim.queue_dig(Vector2i(9, 23)), "survival route gathers quarry roots to replenish generator fuel")
	var visited_lower_ladder: bool = false
	var visited_quarry_floor: bool = false
	for i in range(1200):
		sim.step(0.1)
		for colonist in sim.colonists:
			if absf(colonist.pos.x - 18.0) < 0.1 and colonist.pos.y >= 20.0 and colonist.pos.y <= 22.1:
				visited_lower_ladder = true
			if colonist.pos.x >= 23.0 and colonist.pos.y >= 22.9:
				visited_quarry_floor = true
		if sim.jobs.is_empty():
			break
	check(visited_lower_ladder, "ordinary expedition physically climbs the new lower ladder")
	check(visited_quarry_floor, "ordinary expedition walks the lower quarry floor to reach ore")
	check(sim.jobs.is_empty(), "colony completes all ordered construction and deep mining jobs")
	check(sim.tiles[23][9] == 0 and sim.resources.biomass > 50.0, "ordinary root gathering replenishes biomass after ladder and plant costs")
	check(sim.resources.ore >= 60.0, "ordinary exploration supplies beacon materials")
	check(sim.queue_build("beacon", BEACON), "ordinary exploration affords hearth beacon")
	check(not sim.queue_dig(FOUNDATION) and not sim.queue_dig(FOUNDATION + Vector2i.RIGHT), "ordinary beacon blueprint protects both upper roost support columns")
	advance(sim, 150.0)
	check(sim.building_at(BEACON).get("active", false) and not sim.queue_dig(FOUNDATION) and not sim.queue_dig(FOUNDATION + Vector2i.RIGHT), "ordinary completed beacon keeps both upper roost support columns")
	check(sim.status == "playing", "beacon does not skip the survival duration")
	check(sim.stable_seconds > 0.0, "balanced colony earns stability progress")
	advance(sim, 1201.0 - sim.elapsed)
	check(sim.status == "won", "ordinary command-only colony wins after twenty minutes")
	check(sim.elapsed >= 1200.0 and sim.elapsed < 1201.0, "survival win timing is exact")
	check(sim.objective_progress == 1.0, "won colony has full objective progress")
	for colonist in sim.colonists:
		check(colonist.alive and colonist.health >= 75.0, "every original colonist survives the ordinary route")
	var broken = Simulation.new()
	advance(broken, 1201.0)
	check(broken.status != "won", "doing nothing cannot automatically win")

func _test_local_sustainability() -> void:
	# Focused state fixture: remote ferns must not certify the colony's sealed room.
	var sim = Simulation.new()
	sim._add_building("farm", EXTRA_FARM)
	sim._add_building("airfern", Vector2i(39, 14))
	sim._add_building("lamp", Vector2i(41, 14))
	sim._add_building("beacon", BEACON)
	sim.elapsed = 1200.0
	advance(sim, 130.0)
	check(sim.status == "playing" and sim.stable_seconds == 0.0, "remote sealed-room fern cannot satisfy occupied-room respiration")
	check(sim.objective_reason.contains("occupied rooms"), "air sustainability explains which rooms need ferns")
	var water = Simulation.new()
	water._add_building("farm", EXTRA_FARM)
	water._add_building("airfern", EXTRA_FERN)
	water._add_building("beacon", BEACON)
	for building in water.buildings:
		if building.kind == "cistern":
			water.buildings.erase(building)
			break
	water.elapsed = 1200.0
	advance(water, 130.0)
	check(water.status == "playing" and water.stable_seconds == 0.0, "stored water without renewable supply is not self-sustaining")
	check(water.objective_reason.contains("dew collectors"), "water sustainability explains the missing collector")

func _test_ladder_occupancy() -> void:
	var sim = Simulation.new()
	var matches := true
	for y in range(sim.height):
		for x in range(sim.width):
			var cell := Vector2i(x, y)
			var occupant: Dictionary = sim.building_at(cell)
			matches = matches and sim._has_ladder(cell) == (occupant.get("kind", "") == "ladder")
	check(matches, "Only actual ladder segments confer climbing across every occupied and empty cell")
	check(sim.queue_dig(PLUG), "New ladder route excavates a real extension site")
	sim._finish_job(sim.job_at(PLUG))
	check(sim.queue_build("ladder", PLUG) and not sim._has_ladder(PLUG), "A planned ladder does not grant climbing before completion")
	check(sim.cancel_job(PLUG) and not sim._has_ladder(PLUG), "Canceled ladder plans never leave climbing access")
	check(sim.queue_build("ladder", PLUG), "A canceled ladder can be planned again")
	sim._finish_job(sim.job_at(PLUG))
	check(sim._has_ladder(PLUG) and sim.is_walkable(PLUG), "Newly completed ladder immediately extends the walkable route")
	sim.buildings.erase(sim.building_at(PLUG))
	check(not sim._has_ladder(PLUG), "Removed ladder leaves no stale climbing access")
