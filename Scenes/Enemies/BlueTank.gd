extends Node2D

var speed = 130
var maxhp = 50
var hp = 50
var is_dead = false

var path = []
var path_index = 0

onready var health_bar = $HealthBar
onready var impact_area = get_node("Impact")
var projectile_impact = preload("res://Scenes/SupportScenes/ProjectileImpact.tscn")


func _ready():
	health_bar.max_value = maxhp
	health_bar.value = hp


func _physics_process(delta):
	move(delta)


func set_path(p):
	path = p
	path_index = 0
	print("Path set:", path)


func move(delta):
	if path_index >= path.size():
		return
	
	var target = path[path_index]
	var direction = (target - global_position).normalized()
	global_position += direction * speed * delta
	
	if global_position.distance_to(target) < 4:
		path_index += 1
	
	print("Moving toward:", target, "Current:", global_position)


func on_hit(damage):
	if is_dead:
		return

	impact()
	hp -= damage
	health_bar.value = hp
	
	if hp <= 0:
		is_dead = true
		on_destroy()


func impact():
	randomize()
	var x_pos = randi() % 31
	randomize()
	var y_pos = randi() % 31
	var impact_location = Vector2(x_pos, y_pos)
	var new_impact = projectile_impact.instance()
	new_impact.position = impact_location
	impact_area.add_child(new_impact)


func on_destroy():
	GameData.add_money(10)
	GameData.enemy_changed(1)

	var explosion = load("res://Scenes/Enemies/explode.tscn").instance()
	explosion.global_position = global_position
	get_tree().get_root().add_child(explosion)
	
	yield(get_tree().create_timer(0.2), "timeout")
	explosion.queue_free()
	queue_free()
