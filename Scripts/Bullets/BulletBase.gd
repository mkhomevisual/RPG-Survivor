extends Area2D

@export var speed: float = 400.0
@export var lifetime: float = 1.5
@export var damage: int = 1
@export var direction: Vector2 = Vector2.ZERO

var base_speed: float = 0.0
var _time_alive: float = 0.0
var _effect_nodes: Array = []


func _ready() -> void:
        base_speed = speed
        if direction == Vector2.ZERO:
                direction = Vector2.RIGHT
        if has_signal("body_entered"):
                body_entered.connect(_on_body_entered)
        _effect_nodes = _gather_effect_nodes()


func _physics_process(delta: float) -> void:
        position += direction.normalized() * speed * delta
        _time_alive += delta
        if _time_alive >= lifetime:
                queue_free()


func set_direction(dir: Vector2) -> void:
        if dir == Vector2.ZERO:
                direction = Vector2.RIGHT
        else:
                direction = dir.normalized()


func set_damage(amount: int) -> void:
        damage = amount


func set_speed_multiplier(mult: float) -> void:
        if base_speed == 0.0:
                base_speed = speed
        speed = base_speed * mult


func set_speed(value: float) -> void:
        speed = value
        if base_speed == 0.0:
                base_speed = speed


func _on_body_entered(body: Node) -> void:
        if not body.is_in_group("enemy"):
                return
        if body.has_method("is_dead") and body.is_dead():
                return

        var bullet_state: Dictionary = {
                "bullet": self,
                "direction": direction,
                "damage": damage,
                "speed": speed,
                "should_destroy": true,
                "effect_snapshots": {}
        }

        for node in _effect_nodes:
                if node.has_method("get_state_snapshot"):
                        bullet_state["effect_snapshots"][node.get_class()] = node.get_state_snapshot()

        var did_hit := false
        if body.has_method("take_damage"):
                body.take_damage(damage)
                did_hit = true

        if body.has_method("apply_knockback") and direction != Vector2.ZERO:
                body.apply_knockback(direction)

        if not did_hit:
                return

        for node in _effect_nodes:
                if node.has_method("apply_on_hit"):
                        node.apply_on_hit(body, bullet_state)

        if bullet_state.get("should_destroy", true):
                queue_free()


func _gather_effect_nodes() -> Array:
        var nodes: Array = []
        for child in get_children():
                if child.has_method("apply_on_hit"):
                        nodes.append(child)
        return nodes
