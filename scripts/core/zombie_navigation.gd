extends RefCounted

const Registry = preload("res://scripts/core/registry.gd")
var reached: bool = false
var fence_seen: bool = false
var incomplete: bool = false
var max_drop: int = 1
var model: RefCounted
var visited_checks: Dictionary = {}

func clear_at(cell: Vector3i) -> bool:
	if model.kind_at(cell) in ["fence","gate"] or model.kind_at(cell+Vector3i.UP) in ["fence","gate"]:
		fence_seen = true
		return false
	if visited_checks.has(cell):
		return visited_checks[cell]
	var result: bool = Registry.cube(model.block(cell + Vector3i.DOWN)) and not Registry.cube(model.block(cell)) and not Registry.cube(model.block(cell + Vector3i.UP))
	visited_checks[cell] = result
	return result

func path(from: Vector3, target: Vector3) -> Array[Vector3]:
	visited_checks.clear()
	reached = false
	fence_seen = false
	incomplete = false
	var start := Vector3i(from.floor())
	var finish := Vector3i(target.floor())
	var open: Array[Vector3i] = [start]
	var costs: Dictionary = {start: 0.0}
	var previous: Dictionary = {}
	var closest: Vector3i = start
	var closed: Dictionary = {}
	for iteration in range(256):
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
				if step > 0 and model.kind_at(next+Vector3i.DOWN) in ["fence","gate"]:
					fence_seen = true
					continue
				if step > 0 and Registry.cube(model.block(current + Vector3i(0, 2, 0))):
					continue
				if step < 0 and Registry.cube(model.block(next + Vector3i(0, 2, 0))):
					continue
				if step < -1:
					var clear_drop: bool = true
					for y in range(next.y+1,current.y+2):
						if Registry.cube(model.block(Vector3i(next.x,y,next.z))):
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
	var result: Array[Vector3] = []
	var cell: Vector3i = closest
	while cell != start and previous.has(cell):
		result.push_front(Vector3(cell) + Vector3(0.5, 0, 0.5))
		cell = previous[cell]
	return result

func heuristic(a: Vector3i, b: Vector3i) -> float:
	return absf(a.x - b.x) + absf(a.z - b.z) + absf(a.y - b.y) * 0.3
