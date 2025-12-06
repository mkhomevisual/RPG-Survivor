extends Area2D # Skill E - široký projektil (Ezreal R style)

@export var speed: float = 400.0
@export var lifetime: float = 2.5
@export var damage: int = 8

var _direction: Vector2 = Vector2.ZERO
var _time_alive: float = 0.0
var _hit_bodies: Dictionary = {} # instance_id -> bool, každý enemy jen jednou

var base_speed: float = 0.0


func _ready() -> void:
	base_speed = speed

	if has_node("CollisionShape2D"):
		var shape = $CollisionShape2D
		shape.disabled = false
	if has_signal("body_entered"):
		body_entered.connect(_on_body_entered)

	# i tenhle skill bereme jako Ashe projektil
	add_to_group("player_bullet")


func set_direction(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		_direction = Vector2.RIGHT
	else:
		_direction = dir.normalized()

	# otočení sprity podle směru
	if has_node("Sprite2D"):
		var sprite := $Sprite2D as Sprite2D
		if sprite != null:
			sprite.rotation = _direction.angle()


func set_damage(value: int) -> void:
	damage = value


func set_speed_multiplier(mult: float) -> void:
	if base_speed == 0.0:
		base_speed = speed
	speed = base_speed * mult


func _physics_process(delta: float) -> void:
	position += _direction * speed * delta
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemy"):
		return

	var id := body.get_instance_id()
	if _hit_bodies.has(id):
		return # už dostal dmg z tohoto skillu
	_hit_bodies[id] = true

	if body.has_method("take_damage"):
		body.take_damage(damage)
