extends Area2D # Bullet

@export var speed: float = 100.0 # základní rychlost střely
@export var lifetime: float = 1.5 # životnost střely v sekundách
@export var split_angle_deg: float = 25.0 # rozestup split střel ve stupních
# default chain range, když nic nenastavíš
@export var default_chain_range: float = 200.0

var base_speed: float = 0.0 # původní rychlost pro multiplikátor
var _direction: Vector2 = Vector2.ZERO
var _time_alive: float = 0.0
var damage: int = 1

# ---- PRŮSTŘEL ----
var pierce_remaining: int = 0 # kolik ENEMY může střela ještě prostřelit (0 = default)

# ---- SPLIT ----
var split_on_hit: bool = false
var split_generations: int = 0 # kolikrát se může tahle střela ještě „dělit“

# ---- CHAIN ----
var chain_jumps_remaining: int = 0
var chain_range: float = 0.0
var _hit_enemies: Array[Node] = []

@onready var _bullet_scene: PackedScene = preload("res://Scenes/bullet.tscn")


func _ready() -> void:
	base_speed = speed
	chain_range = default_chain_range
	body_entered.connect(_on_body_entered)
	# hráčské projektily – kvůli Ashe R zóně
	add_to_group("player_bullet")


func _physics_process(delta: float) -> void:
	position += _direction * speed * delta
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()


func set_direction(dir: Vector2) -> void:
	_direction = dir.normalized()


func set_damage(amount: int) -> void:
	damage = amount


func set_pierce(count: int) -> void:
	pierce_remaining = count


func set_split(enabled: bool, generations: int = 1) -> void:
	split_on_hit = enabled
	split_generations = generations


func set_speed_multiplier(mult: float) -> void:
	if base_speed == 0.0:
		base_speed = speed
	speed = base_speed * mult


func set_chain(jumps: int, range: float) -> void:
	# kolik „přeskoků“ má střela udělat po prvním zásahu
	# jumps = 3 => trefí 1 cíl + max 3 další
	chain_jumps_remaining = jumps
	chain_range = range
	_hit_enemies.clear()


func _on_body_entered(body: Node) -> void:
	# střela řeší jen enemy
	if not body.is_in_group("enemy"):
		return
	if body.has_method("is_dead") and body.is_dead():
		return

	var did_hit := false
	if body.has_method("take_damage"):
		body.take_damage(damage)
		did_hit = true
	if body.has_method("apply_knockback"):
		body.apply_knockback(_direction)

	if not did_hit:
		return

	# ---- CHAIN BOUNCE ----
	if chain_jumps_remaining > 0:
		_hit_enemies.append(body)
		if _spawn_chain_bullet(body):
			# tenhle bullet končí, další „hop“ letí v novém bulletu
			queue_free()
			return

	# ---- SPLIT ----
	if split_on_hit and split_generations > 0:
		_spawn_split_bullets()

	# ---- PIERCE ----
	if pierce_remaining > 0:
		pierce_remaining -= 1
		if pierce_remaining > 0:
			return # letí dál

	# default: zmizí
	queue_free()


func _spawn_chain_bullet(from_enemy: Node2D) -> bool:
	if _bullet_scene == null:
		return false

	var world := get_tree().current_scene
	if world == null or not world.has_node("Enemies"):
		return false

	var enemies_root := world.get_node("Enemies")
	var best: Node2D = null
	var best_dist2: float = chain_range * chain_range

	for child in enemies_root.get_children():
		if not child.is_in_group("enemy"):
			continue
		if child == from_enemy:
			continue
		if child.has_method("is_dead") and child.is_dead():
			continue

		var d2 := from_enemy.global_position.distance_squared_to(child.global_position)
		if d2 < best_dist2:
			best_dist2 = d2
			best = child

	if best == null:
		return false

	var b := _bullet_scene.instantiate()
	world.add_child(b)
	b.global_position = from_enemy.global_position

	var dir := best.global_position - from_enemy.global_position
	if b.has_method("set_direction"):
		b.set_direction(dir)
	if b.has_method("set_damage"):
		b.set_damage(damage)

	# zachováme stejný speed multiplikátor jako měl původní bullet
	var mult := 1.0
	if base_speed != 0.0:
		mult = speed / base_speed
	if b.has_method("set_speed_multiplier"):
		b.set_speed_multiplier(mult)

	if chain_jumps_remaining - 1 > 0 and b.has_method("set_chain"):
		b.set_chain(chain_jumps_remaining - 1, chain_range)

	return true


func _spawn_split_bullets() -> void:
	if _bullet_scene == null:
		return

	var world := get_tree().current_scene
	if world == null:
		return

	var base_dir := _direction
	var angle_rad := deg_to_rad(split_angle_deg)
	var dir1 := base_dir.rotated(angle_rad)
	var dir2 := base_dir.rotated(-angle_rad)

	for d in [dir1, dir2]:
		var b := _bullet_scene.instantiate()
		world.add_child(b)
		b.global_position = global_position

		if b.has_method("set_direction"):
			b.set_direction(d)
		if b.has_method("set_damage"):
			b.set_damage(damage)

		# průstřel do dělených střel
		if pierce_remaining > 0 and b.has_method("set_pierce"):
			b.set_pierce(pierce_remaining)

		var next_gen := split_generations - 1
		if next_gen > 0 and b.has_method("set_split"):
			b.set_split(true, next_gen)
