extends TileMap

onready var astar = AStar2D.new()
onready var walkable_tile_id = 0
onready var used_cells = get_used_cells()

# สำหรับวาดเส้นทาง A*
onready var line2d_astar = $PathLineAstar
onready var path2d_astar = $Path2DAstar

# สำหรับวาดเส้นทาง Dijkstra
onready var line2d_dijkstra = $PathLineDijkstra
onready var path2d_dijkstra = $Path2DDijk

onready var timer = Timer.new()
var change_interval = 5.0
var alternate_tile_id = 3
var changing_cells = []

var path_astar = []
var path_dijkstra = []

var blocked_points = []   # point IDs ของ A*
var blocked_cells = []    #  ของ Dijkstra

var point_ids = {}
var world_to_cell_map = {}

func _ready():
	initialize_astar()
	calculate_astar_path()
	start_dijkstra()
	setup_automatic_changes()

func setup_automatic_changes():
	var fixed_cells = [Vector2(9, 4), Vector2(8, 2)]
	for cell in fixed_cells:
		if get_cellv(cell) == walkable_tile_id:
			changing_cells.append(cell)
		else:
			print("Cell ", cell, " is not walkable (tile ID: ", get_cellv(cell), ")")
	
	if changing_cells.size() > 0:
		add_child(timer)
		timer.wait_time = change_interval
		timer.connect("timeout", self, "_on_tile_change_timeout")
		timer.start()
	else:
		print("No valid cells found for automatic changes")

func _on_tile_change_timeout():
	if changing_cells.size() > 0:
		var cell = changing_cells.pop_front()
		set_cellv(cell, alternate_tile_id)
		block_cell(cell)
		initialize_astar()
		calculate_astar_path()
		start_dijkstra()
	else:
		timer.stop()
		print("All tiles have been changed - stopping automatic changes")


# --- A* Setup ---

func initialize_astar():
	var id = 0
	point_ids.clear()
	world_to_cell_map.clear()
	astar.clear()

	for cell in used_cells:
		if get_cellv(cell) == walkable_tile_id and not blocked_cells.has(cell):
			var center_pos = map_to_world(cell) + cell_size / 2
			var world_pos = center_pos + Vector2(-cell_size.x * 0.2, -cell_size.y * 0.2)
			astar.add_point(id, world_pos)
			point_ids[cell] = id
			world_to_cell_map[world_pos] = cell
			id += 1

	for cell in point_ids.keys():
		var from_id = point_ids[cell]
		for offset in [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]:
			var neighbor = cell + offset
			if point_ids.has(neighbor):
				var to_id = point_ids[neighbor]
				if not astar.are_points_connected(from_id, to_id):
					astar.connect_points(from_id, to_id)

func calculate_astar_path():
	var start_cell = Vector2(-1, 9)
	var end_cell = Vector2(21, 1)
	if point_ids.has(start_cell) and point_ids.has(end_cell):
		update_astar_visuals(point_ids[start_cell], point_ids[end_cell])
	else:
		line2d_astar.clear_points()
		path2d_astar.curve = null
		print("A*: Start or end cell not in point_ids")

func update_astar_visuals(start_id, end_id):
	path_astar = astar.get_point_path(start_id, end_id)
	
	
	line2d_astar.clear_points()
	for point in path_astar:
		line2d_astar.add_point(to_local(point))
	line2d_astar.width = 2
	line2d_astar.default_color = Color.red

	var curve = Curve2D.new()
	for point in path_astar:
		curve.add_point(to_local(point))
	path2d_astar.curve = curve


#  Dijkstra Setup 

func is_walkable(cell: Vector2) -> bool:
	if not used_cells.has(cell):
		return false
	if get_cellv(cell) != walkable_tile_id:
		return false
	if blocked_cells.has(cell):
		return false
	return true

func start_dijkstra():
	var start_cell = Vector2(-1, 9)
	var end_cell = Vector2(21, 1)

	if not is_walkable(start_cell) or not is_walkable(end_cell):
		print("Dijkstra: Start or end cell not walkable")
		return

	var came_from = {}
	var cost_so_far = {}
	var frontier = PriorityQueue.new()

	frontier.push(start_cell, 0)
	came_from[start_cell] = null
	cost_so_far[start_cell] = 0

	call_deferred("_dijkstra_step", start_cell, end_cell, came_from, cost_so_far, frontier)

func _dijkstra_step(start_cell, end_cell, came_from, cost_so_far, frontier):
	while not frontier.empty():
		var current = frontier.pop()
		if current == end_cell:
			break

		for offset in [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]:
			var neighbor = current + offset
			if not is_walkable(neighbor):
				continue

			var new_cost = cost_so_far[current] + 1
			if not cost_so_far.has(neighbor) or new_cost < cost_so_far[neighbor]:
				cost_so_far[neighbor] = new_cost
				frontier.push(neighbor, new_cost)
				came_from[neighbor] = current

	draw_dijkstra_path(came_from, end_cell)

func draw_dijkstra_path(came_from, end_cell):
	path_dijkstra.clear()
	var current = end_cell
	while current != null:
		var center_pos = map_to_world(current) + cell_size / 2
		var world_pos = center_pos + Vector2(0, 0)
		path_dijkstra.insert(0, world_pos)
		current = came_from.get(current, null)
	
	
	
	line2d_dijkstra.clear_points()
	for point in path_dijkstra:
		line2d_dijkstra.add_point(to_local(point))
	line2d_dijkstra.width = 2
	line2d_dijkstra.default_color = Color.blue

	var curve = Curve2D.new()
	for point in path_dijkstra:
		curve.add_point(to_local(point))
	path2d_dijkstra.curve = curve


# --- Block / Unblock Cells ---

func block_cell(cell: Vector2) -> void:
	if point_ids.has(cell):
		var point_id = point_ids[cell]
		if not blocked_points.has(point_id):
			blocked_points.append(point_id)
			astar.set_point_disabled(point_id, true)
	if not blocked_cells.has(cell):
		blocked_cells.append(cell)
	recalculate_paths()

func unblock_cell(cell: Vector2) -> void:
	if point_ids.has(cell):
		var point_id = point_ids[cell]
		if blocked_points.has(point_id):
			blocked_points.erase(point_id)
			astar.set_point_disabled(point_id, false)
	if blocked_cells.has(cell):
		blocked_cells.erase(cell)
	recalculate_paths()

func recalculate_paths():
	calculate_astar_path()
	start_dijkstra()
	# Notify enemies to update paths if needed
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("update_path"):
			enemy.update_path()


#  PriorityQueue class for Dijkstra 

class PrioritySorter:
	extends Reference
	func _sort(a, b):
		return a["priority"] < b["priority"]

class PriorityQueue:
	var elements = []
	var sorter = PrioritySorter.new()

	func push(item, priority):
		elements.append({"item": item, "priority": priority})
		elements.sort_custom(sorter, "_sort")

	func pop():
		return elements.pop_front()["item"]

	func empty():
		return elements.empty()
