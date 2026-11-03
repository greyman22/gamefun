extends RefCounted

const Registry = preload("res://scripts/core/registry.gd")
const Water=preload("res://scripts/core/water.gd")
var allow_swim: bool=false
var avoid_water: bool=false
var reached: bool = false
var fence_seen: bool = false
var incomplete: bool = false
var max_drop: int = 1
const Perf=preload("res://scripts/core/performance_log.gd")
var budget: RefCounted
var priority: float=0
var work_key: String=""
var deferred: bool=false
var search_count: int=0
var search_state: Dictionary={}
var completed_component: Dictionary={}
var model: RefCounted
var visited_checks: Dictionary = {}

func clear_at(cell: Vector3i) -> bool:
	if model.sample_kind(cell) in ["fence","gate"] or model.sample_kind(cell+Vector3i.UP) in ["fence","gate"]:
		fence_seen = true
		return false
	if visited_checks.has(cell):
		return visited_checks[cell]
	var water_here: bool=Water.wet(model.sample_kind(cell))
	var water_below: bool=Water.wet(model.sample_kind(cell+Vector3i.DOWN))
	if avoid_water and ((water_here or water_below) and not allow_swim or water_here):
		visited_checks[cell]=false
		return false
	var result: bool = (Registry.cube(model.sample_block(cell + Vector3i.DOWN)) or (allow_swim and water_below)) and not Registry.cube(model.sample_block(cell)) and not Registry.cube(model.sample_block(cell + Vector3i.UP))
	visited_checks[cell] = result
	return result

func search_path(from: Vector3, target: Vector3) -> Array[Vector3]:
	var start := Vector3i(from.floor())
	var finish := Vector3i(target.floor())
	var revision: int=budget.revision if budget!=null else 0
	var resume: bool=not search_state.is_empty() and search_state.start==start and search_state.finish==finish and search_state.revision==revision
	if not resume:
		visited_checks.clear()
		fence_seen=false
		search_state={"start":start,"finish":finish,"revision":revision,"open":Array([start],TYPE_VECTOR3I,"",null),"costs":{start:0.0},"previous":{},"closest":start,"closed":{}}
	reached=false
	incomplete=false
	var open: Array[Vector3i]=search_state.open
	var costs: Dictionary=search_state.costs
	var previous: Dictionary=search_state.previous
	var closest: Vector3i=search_state.closest
	var closed: Dictionary=search_state.closed
	var slice_start: int=Time.get_ticks_usec()
	var sliced: bool=false
	for iteration in range(256):
		if closed.size()>=256:
			break
		if budget!=null and budget.active and iteration>0 and Time.get_ticks_usec()-slice_start>=1000:
			sliced=true
			break
		if open.is_empty():
			break
		var best_index: int = 0
		for index in range(1, open.size()):
			if float(costs[open[index]]) + heuristic(open[index], finish) < float(costs[open[best_index]]) + heuristic(open[best_index], finish):
				best_index = index
		var current: Vector3i = open[best_index]
		open.remove_at(best_index)
		closed[current] = true
		if heuristic(current, finish) < heuristic(closest, finish):
			closest = current
		if current.x == finish.x and current.z == finish.z and absi(current.y - finish.y) <= 1:
			closest = current
			reached = true
			break
		var steps: Array[int] = [0,1]
		for drop in range(1,max_drop+1):
			steps.append(-drop)
		for direction in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			for step in steps:
				var next: Vector3i = current + direction + Vector3i(0, step, 0)
				if closed.has(next) or absi(next.x - start.x) > 24 or absi(next.z - start.z) > 24 or not clear_at(next):
					continue
				if step > 0 and model.sample_kind(next+Vector3i.DOWN) in ["fence","gate"]:
					fence_seen = true
					continue
				if step > 0 and Registry.cube(model.sample_block(current + Vector3i(0, 2, 0))):
					continue
				if step < 0 and Registry.cube(model.sample_block(next + Vector3i(0, 2, 0))):
					continue
				if step < -1:
					var clear_drop: bool = true
					for y in range(next.y+1,current.y+2):
						if Registry.cube(model.sample_block(Vector3i(next.x,y,next.z))):
							clear_drop=false
							break
					if not clear_drop:
						continue
				var cost: float = float(costs[current]) + 1 + absf(step) * 0.3
				if cost < float(costs.get(next, INF)):
					costs[next] = cost
					previous[next] = current
					if not open.has(next):
						open.append(next)
				break
	incomplete = not reached and not open.is_empty()
	completed_component=closed if not reached and not incomplete and not fence_seen else {}
	if sliced:
		search_state.closest=closest
	else:
		search_state.clear()
	var result: Array[Vector3] = []
	var cell: Vector3i = closest
	while cell != start and previous.has(cell):
		result.push_front(Vector3(cell) + Vector3(0.5, 0, 0.5))
		cell = previous[cell]
	return result

func heuristic(a: Vector3i, b: Vector3i) -> float:
	return absf(a.x - b.x) + absf(a.z - b.z) + absf(a.y - b.y) * 0.3

func path(from: Vector3, target: Vector3) -> Array[Vector3]:
	deferred=false
	if budget!=null:
		budget.ensure_frame(model.game_time)
	if budget!=null and budget.active and not budget.request(work_key if not work_key.is_empty() else str(get_instance_id()),priority):
		deferred=true
		return []
	var stamp: int=Time.get_ticks_usec()
	var measured: int=Perf.begin()
	var result: Array[Vector3]=search_path(from,target)
	search_count+=1
	Perf.finish("creature_navigation",measured)
	if budget!=null:
		budget.completed(Time.get_ticks_usec()-stamp)
	return result
