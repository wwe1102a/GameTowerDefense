extends TileMap


onready var walkable_tile_id = 0

onready var path2d_astar = $Path2DAstar
onready var line2d_astar = $PathLineAstar
onready var path2d_dijkstra = $Path2DDijk
onready var line2d_dijkstra = $PathLineDijkstra
onready var marker_astar = $MarkerAstar
onready var marker_dijk = $MarkerDijk

var inf = 1000000

var point_ids = {} 
var g_score = {}
var f_score = {}

var astar_explored_points = []
var dijkstra_explored_points = []

var path_astar = []
var path_dijkstra = []


onready var timer = Timer.new()
var change_interval = 6.0
var alternate_tile_id = 3
var changing_cells = []

var blocked_points = []   # ของ A*
var blocked_cells = []    # ของ Dijkstra



func _ready():
	build_point_map()
	start_astar_visual(Vector2(-1, 9), Vector2(21, 1)) 
	start_dijkstra_step_search(Vector2(-1, 9), Vector2(21, 1))
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
		start_astar_visual(Vector2(-1, 9), Vector2(21, 1))  
		initialize_dijkstra()
		start_dijkstra_step_search(Vector2(-1, 9), Vector2(21, 1))  
	else:
		timer.stop()
		print("All tiles have been changed - stopping automatic changes")



func build_point_map():
	point_ids.clear()
	for cell in get_used_cells():
		if get_cellv(cell) == walkable_tile_id:
			point_ids[cell] = true

#huristic function
func heuristic(a, b):
	return abs(a.x - b.x) + abs(a.y - b.y)


func compare_f_score(a, b):
	var fa = f_score.get(a, inf)
	var fb = f_score.get(b, inf)
	return fa < fb

# --- A* ---

func initialize_astar(): #ใช้สำหรับอัพเดทเส้นทางเมื่อมีการเกิดสิ่งกีดขวาง
	build_point_map() # สร้าง map ใหม่
	# บล็อค cell ทั้งหมดที่เก็บไว้ใน blocked_points
	for cell in blocked_points:
		if point_ids.has(cell):
			point_ids.erase(cell)
	# ล้างข้อมูล path และ explored points
	astar_explored_points.clear()
	path_astar.clear()
	line2d_astar.clear_points()
	update()

func start_astar_visual(start_cell, end_cell):
	var open_set = []
	var came_from = {}
	g_score.clear()
	f_score.clear()
	open_set.append(start_cell)
	g_score[start_cell] = 0
	f_score[start_cell] = heuristic(start_cell, end_cell)



	call_deferred("_astar_step", open_set, came_from, start_cell, end_cell)

func _astar_step(open_set, came_from, start_cell, end_cell):
	while open_set.size() > 0:
		open_set.sort_custom(self, "compare_f_score")
		var current = open_set[0]

		if current == end_cell:
			break

		open_set.erase(current)

		if current != start_cell and current != end_cell:
			astar_explored_points.append(current)

			# ย้าย marker ตามจุดที่สำรวจ
			marker_astar.position = map_to_world(current) + cell_size / 2
			marker_astar.visible = true

			update()  
			yield(get_tree().create_timer(0.1), "timeout")

		for offset in [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]:
			var neighbor = current + offset
			if not point_ids.has(neighbor):
				continue

			var tentative_g = inf
			if g_score.has(current):
				tentative_g = g_score[current] + 1

			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + heuristic(neighbor, end_cell)
				if not open_set.has(neighbor):
					open_set.append(neighbor)

	# สร้าง path
	var cell_path = []
	var cur = end_cell
	while came_from.has(cur):
		cell_path.insert(0, cur)
		cur = came_from[cur]
	
	draw_astar_path(cell_path)

func draw_astar_path(cell_path):
	path_astar.clear()
	line2d_astar.clear_points()
	path2d_astar.curve.clear_points()
	
	
	
	# แปลงทุกเซลล์ใน path เป็น world position
	for cell in cell_path:
		var world_pos = map_to_world(cell) + cell_size / 2
		
		
		path_astar.append(world_pos)
		line2d_astar.add_point(world_pos)  # ใช้ world_pos โดยตรง
		path2d_astar.curve.add_point(world_pos)  # ใช้ world_pos โดยตรง
	
	line2d_astar.width = 2  # ทำให้เส้นหนาขึ้นเพื่อสังเกตง่าย
	line2d_astar.default_color = Color(1, 0, 0, 0.8)  # สีแดงเข้ม
	




# --- Dijkstra ---
func initialize_dijkstra():   #ใช้สำหรับอัพเดทเส้นทางเมื่อมีการเกิดสิ่งกีดขวาง
	build_point_map()
	# ลบ point ที่บล็อคออกจาก point_ids
	for cell in blocked_points:
		if point_ids.has(cell):
			point_ids.erase(cell)
	dijkstra_explored_points.clear()
	path_dijkstra.clear()
	line2d_dijkstra.clear_points()
	update()

class PriorityQueue:
	var elements = []

	func empty():
		return elements.empty()

	func push(item, priority):
		elements.append({'item': item, 'priority': priority})
		elements.sort_custom(self, "_compare_priority")

	func pop():
		return elements.pop_front()['item']

	func _compare_priority(a, b):
		 return a['priority'] < b['priority']

func start_dijkstra_step_search(start_cell, end_cell):
	dijkstra_explored_points.clear()
	path_dijkstra.clear()

	var came_from = {}
	var cost_so_far = {}
	var frontier = PriorityQueue.new()

	frontier.push(start_cell, 0)
	came_from[start_cell] = null
	cost_so_far[start_cell] = 0

	call_deferred("_dijkstra_step_search", start_cell, end_cell, came_from, cost_so_far, frontier)

func _dijkstra_step_search(start_cell, end_cell, came_from, cost_so_far, frontier):
	while not frontier.empty():
		var current = frontier.pop()

		if current != start_cell and current != end_cell:
			dijkstra_explored_points.append(current)
			update()  # รีเฟรช _draw เพื่อวาดวงกลม
			yield(get_tree().create_timer(0.1), "timeout")
			
			# ย้าย MarkerDijk ตามจุดที่สำรวจ
			marker_dijk.position = map_to_world(current) + cell_size / 2
			marker_dijk.visible = true
			

		if current == end_cell:
			break

		for offset in [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]:
			var neighbor = current + offset
			if not point_ids.has(neighbor):
				continue

			var new_cost = cost_so_far[current] + 1
			if not cost_so_far.has(neighbor) or new_cost < cost_so_far[neighbor]:
				cost_so_far[neighbor] = new_cost
				frontier.push(neighbor, new_cost)
				came_from[neighbor] = current

	# สร้าง path
	draw_dijkstra_path(came_from, end_cell)

func draw_dijkstra_path(came_from, end_cell):
	path_dijkstra.clear()
	line2d_dijkstra.clear_points()  # ต้องเรียก clear_points() ที่ Line2D

	var current = end_cell
	while current != null:
		var pos = map_to_world(current) + cell_size / 2
		var world_pos = pos + Vector2(2, 2)
		path_dijkstra.insert(0, world_pos)
		line2d_dijkstra.add_point(to_local(world_pos))
		current = came_from.get(current, null)

	line2d_dijkstra.width = 1
	line2d_dijkstra.default_color = Color.blue


# --- _draw() วาดวงกลมจุดที่สำรวจ ---

func _draw():
	var radius = cell_size.x * 0.1
	for cell in astar_explored_points:
		var pos = map_to_world(cell) + cell_size / 2
		draw_circle(to_local(pos), radius, Color(1, 0, 0, 0.7))  

	for cell in dijkstra_explored_points:
		var pos = map_to_world(cell) + cell_size / 2
		draw_circle(to_local(pos), radius, Color(0, 0, 1, 0.7))  

func block_cell(cell):
	
	if point_ids.has(cell):
		point_ids.erase(cell)
		blocked_points.append(cell)
