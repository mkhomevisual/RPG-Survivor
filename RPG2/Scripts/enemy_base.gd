extends CharacterBody2D
# EnemyBase.gd
#
# Base class for all enemy types in the project.  It implements core behaviour such as
# moving toward the player, taking damage, knockback, frost/vortex effects and dying.
# Specific enemy types (melee, shooter, tank, etc.) should inherit from this class
# and override the `_update_enemy(delta)` method to provide custom behaviours.

class_name EnemyBase



##
## Exported stats
##

@export var speed: float = 20.0
# Base movement speed when moving toward the player.

@export var max_hp: int = 2
# Maximum health points.

@export var knockback_force: float = 50.0
# Force applied when the enemy is hit (knockback strength).

@export var knockback_friction: float = 50
# How quickly knockback velocity decays (higher = quicker slowdown).

@export var contact_damage: int = 1
# Damage dealt to the player when colliding with them.

@export var attack_cooldown: float = 0.5
# Minimum time between contact damage hits (seconds).

@export var xp_crystal_scene: PackedScene = preload("res://Scenes/xpcrystal.tscn")
# Scene used to spawn an XP crystal upon death.

@export var frost_slow_factor: float = 0.6
# Speed multiplier under frost effect (0.0 = completely frozen, 1.0 = no slow).

@export var damage_number_scene: PackedScene = preload("res://Scenes/damage_numbers.tscn")
# Scene for displaying damage numbers above the enemy when hit.

@export var damage_number_offset: Vector2 = Vector2(0, -10)
# Offset applied to damage numbers (so they appear above the enemy).



##
## Internal state
##

var hp: int = 0
# Current health points.

var target: Node2D = null
# Reference to the player node (the target to chase).

var knockback_velocity: Vector2 = Vector2.ZERO
# Knockback velocity applied on top of movement.

var _attack_cooldown_timer: float = 0.0
# Internal timer for contact damage cooldown.

var is_dying: bool = false
# Flag indicating that death animation is in progress (prevents multiple deaths).

var frost_time_left: float = 0.0
# Remaining time of the frost effect.

var _base_modulate: Color = Color(1, 1, 1, 1)
# Base colour of the sprite (for restoring after hits/frost).

const FROST_COLOR: Color = Color(0.6, 0.8, 1.0, 1.0)
# Colour used while under frost effect.

# References to child nodes (assigned in _ready).
var _damage_area: Area2D = null
var _sprite: Node2D = null        # <- teď obecně Node2D (může být Sprite2D nebo AnimatedSprite2D)
var _body_collision: CollisionShape2D = null



##
## Helper functions
##

func _spawn_damage_number(amount: int) -> void:
	# Spawn a floating damage number above the enemy.
	if damage_number_scene == null:
		return

	var dn := damage_number_scene.instantiate() as Node2D
	var world := get_tree().current_scene
	if world == null:
		return

	world.add_child(dn)
	dn.global_position = global_position + damage_number_offset

	if dn.has_method("show_number"):
		dn.show_number(amount)


func _fade_out_canvas_items(node: Node, t: Tween, duration: float) -> void:
	# Recursively fade out any CanvasItem (Sprite2D, AnimatedSprite2D, etc.) under this enemy.
	if node is CanvasItem:
		t.tween_property(node, "modulate:a", 0.0, duration)

	for child in node.get_children():
		_fade_out_canvas_items(child, t, duration)



##
## Built-in callbacks
##

func _ready() -> void:
	# Locate key child nodes.  Use find_child with recursion to allow custom scene structures.
	_damage_area = find_child("DamageArea", true, false) as Area2D

	# Najdeme buď uzel pojmenovaný "Sprite2D" (původní statický sprite),
	# nebo "AnimatedSprite2D" – podle toho, co máš ve scéně.
	var sprite_node: Node = find_child("Sprite2D", true, false)
	if sprite_node == null:
		sprite_node = find_child("AnimatedSprite2D", true, false)

	_sprite = sprite_node as Node2D
	_body_collision = find_child("CollisionShape2D", true, false) as CollisionShape2D

	# Store initial health and assign to enemy group.
	hp = max_hp
	add_to_group("enemy")

	# Record base colour for hit/frost effects and duplicate ShaderMaterial per instance.
	if _sprite != null and _sprite is CanvasItem:
		var ci := _sprite as CanvasItem
		_base_modulate = ci.modulate

		if ci.material is ShaderMaterial:
			ci.material = (ci.material as ShaderMaterial).duplicate()

	# Find the player if not already assigned.
	var world := get_tree().current_scene
	if world != null and target == null:
		if world.has_node("Player"):
			target = world.get_node("Player") as Node2D

	# Connect contact damage signal from DamageArea.
	if _damage_area != null and not _damage_area.body_entered.is_connected(_on_damage_area_body_entered):
		_damage_area.body_entered.connect(_on_damage_area_body_entered)


func _physics_process(delta: float) -> void:
	# Skip behaviour while dying.
	if is_dying:
		return

	# Handle frost effect timer and apply slow.
	var speed_mult: float = 1.0
	if frost_time_left > 0.0:
		frost_time_left -= delta
		if frost_time_left <= 0.0:
			frost_time_left = 0.0
			_set_frost_visual(false)
		else:
			speed_mult = frost_slow_factor

	# Determine movement direction toward the player.
	var move_dir: Vector2 = Vector2.ZERO
	if target != null:
		var dir: Vector2 = target.global_position - global_position
		if dir.length() > 5.0:
			move_dir = dir.normalized()

	# Combine base movement and knockback.
	var base_velocity: Vector2 = move_dir * speed * speed_mult
	velocity = base_velocity + knockback_velocity
	move_and_slide()

	# Dampen knockback over time.
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)

	# Update attack cooldown timer.
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	# Allow subclasses to implement custom behaviour.
	_update_enemy(delta)


func _update_enemy(_delta: float) -> void:
	# Placeholder for subclasses.  Override this to add specific behaviours.
	pass


func take_damage(amount: int) -> void:
	if is_dying:
		return

	hp -= amount

	# Damage numbers + hit flash
	_spawn_damage_number(amount)
	_play_hit_flash()

	if hp <= 0:
		_die()


func apply_knockback(dir: Vector2) -> void:
	# Apply knockback velocity in the given direction.
	knockback_velocity += dir.normalized() * knockback_force


func _on_damage_area_body_entered(body: Node) -> void:
	# Apply contact damage to the player when colliding.
	if not body.is_in_group("player"):
		return
	if _attack_cooldown_timer > 0.0:
		return

	if body.has_method("take_damage"):
		body.take_damage(contact_damage)

	_attack_cooldown_timer = attack_cooldown



##
## Status effects
##

func apply_frost(duration: float) -> void:
	frost_time_left = duration
	_set_frost_visual(true)


func _set_frost_visual(enabled: bool) -> void:
	if _sprite == null or not (_sprite is CanvasItem):
		return

	var ci := _sprite as CanvasItem

	if enabled:
		ci.modulate = FROST_COLOR
	else:
		ci.modulate = _base_modulate


func apply_vortex_pull(center: Vector2, strength: float, delta: float) -> void:
	# Pull the enemy toward a point (used by vortex effects).
	var dir: Vector2 = center - global_position
	if dir == Vector2.ZERO:
		return

	var desired := dir.normalized() * strength
	knockback_velocity = knockback_velocity.move_toward(desired, strength * delta)

	var max_vortex_speed := strength
	if knockback_velocity.length() > max_vortex_speed:
		knockback_velocity = knockback_velocity.normalized() * max_vortex_speed



##
## Visual effects
##

func _play_hit_flash() -> void:
	# Use a shader uniform to flash the sprite white when hit.
	if _sprite == null or not (_sprite is CanvasItem):
		return

	var ci := _sprite as CanvasItem
	var shader_mat := ci.material as ShaderMaterial
	if shader_mat == null:
		return

	var t := create_tween()

	# Start with full flash.
	shader_mat.set_shader_parameter("flash_amount", 1.0)

	# Tween back to zero over 0.1 seconds.
	t.tween_property(
		shader_mat,
		"shader_parameter/flash_amount",
		0.0,
		0.1
	)


func is_dead() -> bool:
	return is_dying or hp <= 0



func _die() -> void:
	# Guard against multiple death triggers.
	if is_dying:
		return
	is_dying = true

	# Disable collisions to avoid further interactions while dying.
	if _body_collision != null:
		_body_collision.set_deferred("disabled", true)
	if _damage_area != null:
		_damage_area.set_deferred("monitoring", false)
		_damage_area.set_deferred("monitorable", false)

	# Award score to the player if the world supports it.
	var world := get_tree().current_scene
	if world != null and world.has_method("add_score"):
		world.add_score(1)

	# Spawn an XP crystal on death.
	if xp_crystal_scene != null and world != null:
		var crystal := xp_crystal_scene.instantiate()
		crystal.global_position = global_position
		world.call_deferred("add_child", crystal)

	# Play death animation: scale up slightly and fade out all visuals.
	if _sprite != null:
		var t := create_tween()
		t.set_parallel(true)

		# Lehce ho nafoukneme.
		t.tween_property(_sprite, "scale", _sprite.scale * 1.2, 0.08)

		# Globální fade všech CanvasItemů (včetně rootu).
		_fade_out_canvas_items(self, t, 0.18)

		t.finished.connect(func(): queue_free())
	else:
		queue_free()
