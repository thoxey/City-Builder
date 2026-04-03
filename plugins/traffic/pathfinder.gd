class_name Pathfinder

## A* pathfinder over the road graph.
##
## find_path(graph, start, goal, cost_fn, heuristic_fn) → Array[Vector3i]
##
## cost_fn:      Callable(from: Vector3i, to: Vector3i) -> float
##               Cost to traverse one edge. Use road metadata for weighted roads:
##               e.g. func(f, t): return 30.0 / road_meta_for(t).speed_limit
##
## heuristic_fn: Callable(node: Vector3i, goal: Vector3i) -> float
##               Admissible estimate of remaining cost. Default: Manhattan distance.
##               For weighted roads scale this to stay admissible.
##
## Returns an empty array if no path exists.

static func find_path(
		graph: Dictionary,
		start: Vector3i,
		goal: Vector3i,
		cost_fn: Callable,
		heuristic_fn: Callable) -> Array[Vector3i]:

	if start == goal:
		return [start]

	# open_set entries: [f_score, g_score, node]
	var open_set: Array = [[heuristic_fn.call(start, goal), 0.0, start]]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0.0}

	while not open_set.is_empty():
		open_set.sort_custom(func(a, b): return a[0] < b[0])
		var entry = open_set.pop_front()
		var current: Vector3i = entry[2]

		if current == goal:
			return _reconstruct(came_from, current)

		for neighbor in graph.get(current, []):
			var tentative_g: float = g_score[current] + cost_fn.call(current, neighbor)
			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				var f: float = tentative_g + heuristic_fn.call(neighbor, goal)
				open_set.append([f, tentative_g, neighbor])

	return []  # no path found

static func _reconstruct(came_from: Dictionary, current: Vector3i) -> Array[Vector3i]:
	var path: Array[Vector3i] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path

## Default heuristic: Manhattan distance on XZ plane (admissible for uniform-cost grids).
static func manhattan(a: Vector3i, b: Vector3i) -> float:
	return float(abs(a.x - b.x) + abs(a.z - b.z))
