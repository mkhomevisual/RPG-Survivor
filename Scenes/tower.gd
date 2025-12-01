extends Node2D  # Tower R

@export var damage: int = 3                    # dmg jednoho zásahu
@export var fire_cooldown: float = 0.5        # jak rychle věž střílí
@export var range: float = 400.0               # dosah towerky
@export var lifetime: float = 10.0              # jak dlouho existuje

@export var chain_jumps: int = 3               # kolik „hopů“ chain udělá po prvním cíli
@export var chain_range: float = 220.0         # range mezi chain targety
@export var bullet_speed_mult: float = 1.3     # tower bullets jsou o něco rychlejší

@onready var _bullet_scene: PackedScene = preload("res://Scenes/bullet.tscn")

var _time_alive: float = 0.0
var _time_since_shot: float = 0.0
var _enemies_root: Node = null


func _ready() -> void:
	var world := get_tree().current_scene
	if world != null and world.has_node("Enemies"):
		_enemies_root = world.get_node("Enemies")


func _process(delta: float) -> void:
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()
		return

	_time_since_shot += delta
	if _time_since_shot >= fire_cooldown:
		_time_since_shot = 0.0
		_try_shoot()


func _try_shoot() -> void:
	if _bullet_scene == null or _enemies_root == null:
		return

	var target := _get_closest_enemy_in_range()
	if target == null:
		return

	var world := get_tree().current_scene
	if world == null:
		return

	var bullet := _bullet_scene.instantiate()
	world.add_child(bullet)

	bullet.global_position = global_position

	var dir: Vector2 = target.global_position - global_position
	if bullet.has_method("set_direction"):
		bullet.set_direction(dir)
	if bullet.has_method("set_damage"):
		bullet.set_damage(damage)
	if bullet.has_method("set_speed_multiplier"):
		bullet.set_speed_multiplier(bullet_speed_mult)
	if chain_jumps > 0 and bullet.has_method("set_chain"):
		bullet.set_chain(chain_jumps, chain_range)


func _get_closest_enemy_in_range() -> Node2D:
	if _enemies_root == null:
		return null

	var closest: Node2D = null
	var best_dist2: float = range * range

	for child in _enemies_root.get_children():
		if not child.is_in_group("enemy"):
			continue
		if child.has_method("is_dead") and child.is_dead():
			continue

		var d2 := global_position.distance_squared_to(child.global_position)
		if d2 < best_dist2:
			best_dist2 = d2
			closest = child

	return closest
