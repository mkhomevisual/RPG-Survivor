extends CharacterBody2D

class_name CharacterBase

# -------- SMĚR POHYBU (4-DIRECTION) --------
enum MoveDir { RIGHT, LEFT, UP, DOWN }

# Aktuální směrový stav – bude se přepisovat podle vstupu
@export var facing_direction: MoveDir = MoveDir.DOWN
# Jen textový helper, abys v Inspectoru viděl hezky "Right/Left/Up/Down"
@export var facing_debug: String = "Down"



# -------- EXPORTOVANÉ ZÁKLADNÍ STATY --------
@export var speed: float = 50.0
@export var fire_cooldown: float = 0.2
@export var min_fire_cooldown: float = 0.05
@export var max_hp: int = 5000
@export var auto_target_radius: float = 250.0
# Nové – pro plynulejší movement
@export var acceleration: float = 2000.0
@export var friction: float = 1200.0

# Defaultní projektil – konkrétní postavy si mohou v inspektoru přepsat na jinou scénu
@export var bullet_scene: PackedScene = preload("res://Scenes/bullet.tscn")

# -------- VNITŘNÍ STATY --------
var attack_damage: int = 1
var hp: int = 0
var bullet_speed_multiplier: float = 1.0

var has_pierce: bool = false
var has_split: bool = false

var _time_since_shot: float = 0.0


# -------- READY --------
func _ready() -> void:
	# Inicializace HP
	hp = max_hp

	# Sync HP do HUDu (Main má update_player_health)
	var world := get_tree().current_scene
	if world and world.has_method("update_player_health"):
		world.call_deferred("update_player_health", hp, max_hp)


# -------- HLAVNÍ LOOP --------
func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_auto_shoot(delta)

	# Hooky pro potomky – prázdné implementace níže
	_handle_skills(delta)
	_update_shoot_glow(delta)


# -------- POHYB --------
func _handle_movement(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	# Máme nějaký input
	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()

		# update směru a vizuálu (směr si dál řešíš přes facing_direction)
		_update_movement_direction(input_dir)
		_update_direction_visual(input_dir)

		# cílová rychlost = směr * speed
		var target_velocity := input_dir * speed
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		# žádný input → zpomalujeme pomocí friction
		if velocity.length() > 0.0:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		_update_direction_visual(Vector2.ZERO)

	# drobný “snap” na nulu, ať to nedriluje kvůli malým hodnotám
	if velocity.length() < 1.0 and input_dir == Vector2.ZERO:
		velocity = Vector2.ZERO

	move_and_slide()



# Určí aktuální facing_direction z vektoru dir (4 směry)
func _update_movement_direction(dir: Vector2) -> void:
	var new_dir: int

	# Rozhodneme podle toho, která složka je větší – horizontální vs vertikální
	if abs(dir.x) > abs(dir.y):
		new_dir = MoveDir.RIGHT if dir.x > 0.0 else MoveDir.LEFT
	else:
		new_dir = MoveDir.DOWN if dir.y > 0.0 else MoveDir.UP

	if new_dir != facing_direction:
		facing_direction = new_dir
		_update_facing_debug()
		_on_direction_changed(new_dir)


# Helper čistě pro Inspector – aktualizuje text
func _update_facing_debug() -> void:
	match facing_direction:
		MoveDir.RIGHT:
			facing_debug = "Right"
		MoveDir.LEFT:
			facing_debug = "Left"
		MoveDir.UP:
			facing_debug = "Up"
		MoveDir.DOWN:
			facing_debug = "Down"


# -------- AUTO STŘELBA --------
func _handle_auto_shoot(delta: float) -> void:
	_time_since_shot += delta
	if _time_since_shot < fire_cooldown:
		return

	var target := _get_closest_enemy(auto_target_radius)
	if target == null:
		return

	_time_since_shot = 0.0
	_shoot_bullet(target.global_position)


func _get_closest_enemy(max_distance: float) -> Node2D:
	var world := get_tree().current_scene
	if world == null or not world.has_node("Enemies"):
		return null

	var enemies_root := world.get_node("Enemies")
	var closest: Node2D = null
	var best_dist2: float = max_distance * max_distance

	for child in enemies_root.get_children():
		if not child.is_in_group("enemy"):
			continue
		if child.has_method("is_dead") and child.is_dead():
			continue

		var d2: float = global_position.distance_squared_to(child.global_position)
		if d2 < best_dist2:
			best_dist2 = d2
			closest = child

	return closest


func _shoot_bullet(target_pos: Vector2) -> void:
	if bullet_scene == null:
		return

	var world := get_tree().current_scene
	if world == null:
		return

	var bullet := bullet_scene.instantiate()
	world.add_child(bullet)

	bullet.global_position = global_position
	var dir: Vector2 = target_pos - global_position

	if bullet.has_method("set_direction"):
		bullet.set_direction(dir)
	if bullet.has_method("set_damage"):
		bullet.set_damage(attack_damage)
	if bullet.has_method("set_speed_multiplier"):
		bullet.set_speed_multiplier(bullet_speed_multiplier)

	if has_pierce and bullet.has_method("set_pierce"):
		bullet.set_pierce(1)
	if has_split and bullet.has_method("set_split"):
		bullet.set_split(true, 1)

	# Hook pro potomka (třeba přidání slow efektu)
	_on_bullet_spawned(bullet)

	# Hook pro muzzle flash / efekt střelby
	_play_shoot_glow()


# -------- ZDRAVÍ / DAMAGE --------
func take_damage(amount: int) -> void:
	hp -= amount

	var world := get_tree().current_scene
	if world and world.has_method("update_player_health"):
		world.update_player_health(hp, max_hp)

	if hp <= 0:
		_die()


func _die() -> void:
	# Defaultně prostě restart scény – později to můžeme přepojit na Game Over panel
	get_tree().reload_current_scene()


# -------- UPGRADY STATŮ --------
func upgrade_attack_speed() -> void:
	fire_cooldown *= 0.7
	if fire_cooldown < min_fire_cooldown:
		fire_cooldown = min_fire_cooldown


func upgrade_attack_damage() -> void:
	attack_damage += 0.5


func upgrade_max_health() -> void:
	max_hp += 1
	hp += 1
	var world := get_tree().current_scene
	if world and world.has_method("update_player_health"):
		world.update_player_health(hp, max_hp)


func upgrade_bullet_speed() -> void:
	bullet_speed_multiplier *= 1.5


func upgrade_movement_speed() -> void:
	speed *= 1.13


func upgrade_pickup_radius() -> void:
	auto_target_radius *= 1.2


# -------- AUGMENTY --------
func add_augment_pierce() -> void:
	if has_pierce:
		return
	has_pierce = true


func add_augment_split() -> void:
	if has_split:
		return
	has_split = true


# -------- HOOKY PRO POTOMKY --------
func _handle_skills(_delta: float) -> void:
	pass


func _update_shoot_glow(_delta: float) -> void:
	pass


func _on_bullet_spawned(_bullet: Node2D) -> void:
	pass


func _play_shoot_glow() -> void:
	pass


func _update_direction_visual(_dir: Vector2) -> void:
	# Potomci (Player, Ashe…) si můžou přepsat a použít facing_direction.
	# Tady defaultně nic neděláme.
	pass


func _on_direction_changed(_new_dir: int) -> void:
	# Hook pro potomky – když se změní směr (RIGHT/LEFT/UP/DOWN),
	# můžeš sem v Ashe dát třeba přepnutí animace.
	pass
