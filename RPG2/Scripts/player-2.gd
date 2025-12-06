extends CharacterBase  # Default character inherits common behaviour

# -------- EXPORT ZÁKLAD --------
# Speed, fire_cooldown, max_hp and auto_target_radius are defined in CharacterBase.
@export var shoot_glow_duration: float = 0.12

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
# Stat and augment fields are inherited from CharacterBase.

# Cooldowny skillů
var _skill_q_cd_left: float = 0.0
var _skill_e_cd_left: float = 0.0
var _skill_r_cd_left: float = 0.0

# -------- ONREADY --------
# Bullet scene is provided by CharacterBase; load only the glow and sprite.
@onready var _shoot_glow: Sprite2D = $ShootGlow
@onready var _sprite: Sprite2D = $Sprite2D

var _shoot_glow_time: float = 0.0


func _ready() -> void:
    # Call base initialisation (sets HP, updates HUD)
    super._ready()

    # Ensure this node is in the "player" group so other code can find it
    add_to_group("player")

    # Prepare the muzzle glow: hide and set alpha to 0
    if _shoot_glow:
        _shoot_glow.visible = false
        var c := _shoot_glow.modulate
        c.a = 0.0
        _shoot_glow.modulate = c

    # Sync health display (already done in base, but ensure deferred call)
    var world := get_tree().current_scene
    if world and world.has_method("update_player_health"):
        world.call_deferred("update_player_health", hp, max_hp)


# Base class handles movement and auto shooting.  This override only needs
# to process skill cooldowns and skill inputs.  The shoot glow is updated
# by CharacterBase if defined.
# Movement and auto‑shooting are handled by CharacterBase.  This class
# implements its own skill logic in _handle_skills(), which will be called
# automatically from the base class.


# -------- POHYB --------

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

# Override the default death behaviour to show a game‑over panel without
# destroying the player node.  This keeps the camera in place and
# prevents scene reload when HP reaches zero.
func _die() -> void:
    # Find the world (Main scene) and call its show_game_over() if available.
    var world := get_tree().current_scene
    if world and world.has_method("show_game_over"):
        world.show_game_over()

    # Disable this character's processing so it no longer moves or shoots.
    set_process(false)
    set_physics_process(false)
    # Disable all collision shapes to prevent further hits.
    for child in get_children():
        if child is CollisionShape2D:
            child.disabled = true
        elif child is CollisionPolygon2D:
            child.disabled = true
    # Hide the player sprite and muzzle glow; camera stays active.
    hide()
