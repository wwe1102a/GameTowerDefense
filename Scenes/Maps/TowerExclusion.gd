extends TileMap

onready var astar = AStar2D.new()
onready var walkable_tile_id = 0
onready var used_cells = get_used_cells()


func _ready():
	var point_ids = {}
	var id = 0

	# 1. เพิ่มจุดทั้งหมดใน TileMap
	for cell in used_cells:
		if get_cellv(cell) == walkable_tile_id:
			var world_pos = map_to_world(cell) + cell_size / 2
			astar.add_point(id, world_pos)
			point_ids[cell] = id
			id += 1

	# 2. เชื่อมต่อจุดกับเพื่อนบ้าน (4 ทิศ)
	for cell in point_ids.keys():
		var from_id = point_ids[cell]
		for offset in [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]:
			var neighbor = cell + offset
			if point_ids.has(neighbor):
				var to_id = point_ids[neighbor]
				if not astar.are_points_connected(from_id, to_id):
					astar.connect_points(from_id, to_id)

	# 3. ตัวอย่างการหาเส้นทาง
	var start_cell = Vector2(0, 9)
	var end_cell = Vector2(19, 1)

	if point_ids.has(start_cell) and point_ids.has(end_cell):
		var path = astar.get_point_path(point_ids[start_cell], point_ids[end_cell])
		print("Path: ", path)

