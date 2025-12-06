extends CharacterBase  # Default character inherits common behaviour

# Player.gd
#
# This script implements the default playable character.  It inherits
# movement, auto‑firing and health management from CharacterBase and
# adds cooldown‑based skills (Q/E/R), a muzzle flash effect and game
# over handling on death.  Derived characters can override or extend
# these behaviours as needed.

# -- Skill and effect parameters --
@export var shoot_glow_duration: float = 0.12

# Skill Q (Frost Field)
@export var skill_q_cooldown: float = 2.0
@export var frost_field_scene: PackedScene = preload("res://Scenes/frost_field.tscn")

# Skill E (Ezreal‑style projectile)
@export var skill_e_cooldown: float = 3.0
@export var skill_e_damage: int = 8
@export var skill_e_range: float = 2000.0
@export var skill_e_scene: PackedScene = preload("res://Scenes/skill_e_projectile.tscn")

# Skill R (Summon Tower)
@export var skill_r_cooldown: float = 10.0
@export var tower_scene: PackedScene = preload("res://Scenes/tower.tscn")
@export var tower_max_cast_range: float = 500.0

# Internal cooldown timers for skills
var _skill_q_cd_left: float = 0.0
var _skill_e_cd_left: float = 0.0
var _skill_r_cd_left: float = 0.0

# Muzzle flash components
@onready var _shoot_glow: Sprite2D = $ShootGlow
@onready var _sprite: Sprite2D = $Sprite2D
var _shoot_glow_time: float = 0.0

func _ready() -> void:
	# Call the base class to initialise HP and update HUD.
	super._ready()
	# Register this node in the "player" group for enemy detection.
	add_to_group("player")
	# Prepare the muzzle glow: hide and set alpha to zero.
	if _shoot_glow:
		_shoot_glow.visible = false
		var c: Color = _shoot_glow.modulate
		c.a = 0.0
		_shoot_glow.modulate = c
	# Ensure the HUD is updated with the starting HP (redundant if base did it).
	var world := get_tree().current_scene
	if world and world.has_method("update_player_health"):
		world.call_deferred("update_player_health", hp, max_hp)

func _handle_skills(delta: float) -> void:
	# Tick down skill cooldowns
	if _skill_q_cd_left > 0.0:
		_skill_q_cd_left -= delta
	if _skill_e_cd_left > 0.0:
		_skill_e_cd_left -= delta
	if _skill_r_cd_left > 0.0:
		_skill_r_cd_left -= delta
	# Handle input for each skill
	if Input.is_action_just_pressed("skill_q") and _skill_q_cd_left <= 0.0:
		_cast_skill_q()
	if Input.is_action_just_pressed("skill_e") and _skill_e_cd_left <= 0.0:
		_cast_skill_e()
	if Input.is_action_just_pressed("skill_r") and _skill_r_cd_left <= 0.0:
		_cast_skill_r()

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
	# Debug print
	print("Skill Q cast at: ", spawn_pos)

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

func _cast_skill_r() -> void:
	if tower_scene == null:
		return
	_skill_r_cd_left = skill_r_cooldown
	var world := get_tree().current_scene
	if world == null:
		return
	var mouse_pos: Vector2 = get_global_mouse_position()
	var dir: Vector2 = mouse_pos - global_position
	var dist: float = dir.length()
	if dist > tower_max_cast_range and dist > 0.0:
		dir = dir.normalized() * tower_max_cast_range
		mouse_pos = global_position + dir
	var tower: Node2D = tower_scene.instantiate()
	world.add_child(tower)
	tower.global_position = mouse_pos
	print("Tower R cast at: ", mouse_pos)

func _update_shoot_glow(delta: float) -> void:
	# Update the muzzle flash alpha over time.
	if _shoot_glow == null:
		return
	if _shoot_glow_time <= 0.0:
		return
	_shoot_glow_time -= delta
	var t: float = clampf(_shoot_glow_time / shoot_glow_duration, 0.0, 1.0)
	var c: Color = _shoot_glow.modulate
	c.a = t
	_shoot_glow.modulate = c
	if _shoot_glow_time <= 0.0:
		_shoot_glow.visible = false

func _play_shoot_glow() -> void:
	# Show the muzzle flash at full alpha for the duration.
	if _shoot_glow == null:
		return
	_shoot_glow_time = shoot_glow_duration
	_shoot_glow.visible = true
	var c: Color = _shoot_glow.modulate
	c.a = 1.0
	_shoot_glow.modulate = c

func _die() -> void:
	# Override death: show the game over panel and disable the player.
	var world := get_tree().current_scene
	if world != null and world.has_method("show_game_over"):
		world.show_game_over()
	# Stop processing so no further actions occur
	set_process(false)
	set_physics_process(false)
	# Disable collisions if present
	if has_node("CollisionShape2D"):
		var shape := get_node("CollisionShape2D")
		shape.set_deferred("disabled", true)
	if has_node("CollisionPolygon2D"):
		var poly := get_node("CollisionPolygon2D")
		poly.set_deferred("disabled", true)
	# Hide the player sprite and any children
	hide()
