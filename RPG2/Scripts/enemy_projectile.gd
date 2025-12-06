extends Area2D

# enemy_projectile.gd
#
# Simple projectile used by ranged enemies.  Moves in a set direction
# at a fixed speed, deals damage to the player on collision, and
# despawns after its lifetime.

@export var speed: float = 50.0
@export var lifetime: float = 3.0
@export var damage: int = 0.5

var _direction: Vector2 = Vector2.ZERO
var _time_alive: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += _direction * speed * delta
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()

func set_direction(dir: Vector2) -> void:
	# Accept either raw Vector2 or normalise a non-zero vector.
	if dir.length() > 0.0:
		_direction = dir.normalized()
	else:
		_direction = Vector2.ZERO

func set_damage(amount: int) -> void:
	damage = amount

func set_speed(value: float) -> void:
	speed = value

func _on_body_entered(body: Node) -> void:
	# Damage the player and despawn.
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
