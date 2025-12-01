extends CharacterBody2D  # Player

# -------- EXPORT ZÁKLAD --------
@export var speed: float = 50.0
@export var fire_cooldown: float = 0.2
@export var min_fire_cooldown: float = 0.05
@export var max_hp: int = 5
@export var shoot_glow_duration: float = 0.12
@export var auto_target_radius: float = 250.0

# -------- SKILL Q (FROST FIELD) --------
@export var skill_q_cooldown: float = 2.0
@export var frost_field_scene: PackedScene = preload("res://Scenes/frost_field.tscn")

# -------- SKILL E (EZREAL R STYLE) --------
@export var skill_e_cooldown: float = 3.0
@export var skill_e_damage: int = 8
@export var skill_e_range: float = 2000.0
@export var skill_e_scene: PackedScene = preload("res://Scenes/skill_e_projectile.tscn")

# -------- SKILL R (TOWER) --------
@export var skill_r_cooldown: float = 10.0
@export var tower_scene: PackedScene = preload("res://Scenes/tower.tscn")
@export var tower_max_cast_range: float = 500.0

# -------- STAV --------
var attack_damage: int = 1
var _time_since_shot: float = 0.0
var hp: int = 0

# Bullet speed (stat) – multiplikátor
var bullet_speed_multiplier: float = 1.0

# Augment flagy
var has_pierce: bool = false
var has_split: bool = false

# Cooldowny skillů
var _skill_q_cd_left: float = 0.0
var _skill_e_cd_left: float = 0.0
var _skill_r_cd_left: float = 0.0

# -------- ONREADY --------
@onready var _bullet_scene: PackedScene = preload("res://Scenes/bullet.tscn")
@onready var _shoot_glow: Sprite2D = $ShootGlow
@onready var _sprite: Sprite2D = $Sprite2D

var _shoot_glow_time: float = 0.0


func _ready() -> void:
	add_to_group("player")

	hp = max_hp

	# připravíme glow
	if _shoot_glow:
		_shoot_glow.visible = false
		var c := _shoot_glow.modulate
		c.a = 0.0
		_shoot_glow.modulate = c

	var world := get_tree().current_scene
	if world.has_method("update_player_health"):
		world.call_deferred("update_player_health", hp, max_hp)


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_auto_shoot(delta)
	_handle_skills(delta)
	_update_shoot_glow(delta)


# -------- POHYB --------
func _handle_movement(_delta: float) -> void:
	var dir := Vector2.ZERO

	dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if dir.length() > 0.0:
		dir = dir.normalized()

		# flip sprity podle směru na X ose
		if _sprite and dir.x != 0.0:
			_sprite.flip_h = dir.x < 0.0

	velocity = dir * speed
	move_and_slide()


# -------- AUTOSHOOT (ZÁKLADNÍ STŘELBA) --------
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
	if _bullet_scene == null:
		return

	var bullet := _bullet_scene.instantiate()
	var world := get_tree().current_scene
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

	if has_pierce or has_split:
		print("Bullet fired with augments -> pierce:", has_pierce, " split:", has_split)

	_play_shoot_glow()


# -------- SKILLY (Q / E / R) --------
func _handle_skills(delta: float) -> void:
	# cooldown tick
	if _skill_q_cd_left > 0.0:
		_skill_q_cd_left -= delta
	if _skill_e_cd_left > 0.0:
		_skill_e_cd_left -= delta
	if _skill_r_cd_left > 0.0:
		_skill_r_cd_left -= delta

	# Q – frost field na pozici myši
	if Input.is_action_just_pressed("skill_q") and _skill_q_cd_left <= 0.0:
		_cast_skill_q()

	# E – „Ezreal R“ projectile směrem k myši
	if Input.is_action_just_pressed("skill_e") and _skill_e_cd_left <= 0.0:
		_cast_skill_e()

	# R – tower na pozici myši (s max range)
	if Input.is_action_just_pressed("skill_r") and _skill_r_cd_left <= 0.0:
		_cast_skill_r()


# --- Q: FROST FIELD NA POZICI MYŠI ---
func _cast_skill_q() -> void:
	if frost_field_scene == null:
		return

	_skill_q_cd_left = skill_q_cooldown

	var world := get_tree().current_scene
	if world == null:
		return

	var spawn_pos: Vector2 = get_global_mouse_position()

	var field: Area2D = frost_field_scene.instantiate()
	world.add_child(field)
	field.global_position = spawn_pos

	print("Skill Q cast at: ", spawn_pos)


# --- E: EZREAL R PROJEKTIL ---
func _cast_skill_e() -> void:
	if skill_e_scene == null:
		return

	_skill_e_cd_left = skill_e_cooldown

	var world := get_tree().current_scene
	if world == null:
		return

	var proj := skill_e_scene.instantiate()
	world.add_child(proj)

	proj.global_position = global_position

	var mouse_pos: Vector2 = get_global_mouse_position()
	var dir: Vector2 = mouse_pos - global_position

	if proj.has_method("set_direction"):
		proj.set_direction(dir)
	if proj.has_method("set_damage"):
		proj.set_damage(skill_e_damage)
	if proj.has_method("set_max_range"):
		proj.set_max_range(skill_e_range)

	print("Skill E cast dir: ", dir)


# --- R: SUMMON TOWER ---
func _cast_skill_r() -> void:
	if tower_scene == null:
		return

	_skill_r_cd_left = skill_r_cooldown

	var world := get_tree().current_scene
	if world == null:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()

	# omezíme cast range od hráče
	var dir: Vector2 = mouse_pos - global_position
	var dist: float = dir.length()
	if dist > tower_max_cast_range and dist > 0.0:
		dir = dir.normalized() * tower_max_cast_range
		mouse_pos = global_position + dir

	var tower: Node2D = tower_scene.instantiate()
	world.add_child(tower)
	tower.global_position = mouse_pos

	print("Tower R cast at: ", mouse_pos)


# -------- SHOOT GLOW --------
func _update_shoot_glow(delta: float) -> void:
	if _shoot_glow == null:
		return
	if _shoot_glow_time <= 0.0:
		return

	_shoot_glow_time -= delta

	var t := clampf(_shoot_glow_time / shoot_glow_duration, 0.0, 1.0)
	var c := _shoot_glow.modulate
	c.a = t
	_shoot_glow.modulate = c

	if _shoot_glow_time <= 0.0:
		_shoot_glow.visible = false


func _play_shoot_glow() -> void:
	if _shoot_glow == null:
		return

	_shoot_glow_time = shoot_glow_duration
	_shoot_glow.visible = true

	var c := _shoot_glow.modulate
	c.a = 1.0
	_shoot_glow.modulate = c


# -------- HEALTH / DAMAGE --------
func take_damage(amount: int) -> void:
	hp -= amount

	var world := get_tree().current_scene
	if world.has_method("update_player_health"):
		world.update_player_health(hp, max_hp)

	if hp <= 0:
		_die()


func _die() -> void:
	get_tree().reload_current_scene()


# -------- STAT UPGRADES --------
func upgrade_attack_speed() -> void:
	fire_cooldown *= 0.85
	if fire_cooldown < min_fire_cooldown:
		fire_cooldown = min_fire_cooldown


func upgrade_attack_damage() -> void:
	attack_damage += 1


func upgrade_max_health() -> void:
	max_hp += 1
	hp += 1
	var world := get_tree().current_scene
	if world.has_method("update_player_health"):
		world.update_player_health(hp, max_hp)


func upgrade_bullet_speed() -> void:
	bullet_speed_multiplier *= 1.15


# -------- AUGMENTY --------
func add_augment_pierce() -> void:
	if has_pierce:
		return
	has_pierce = true
	print("AUGMENT ACQUIRED: PIERCE")


func add_augment_split() -> void:
	if has_split:
		return
	has_split = true
	print("AUGMENT ACQUIRED: SPLIT")
