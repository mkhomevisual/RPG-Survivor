extends Node
class_name SkillBase

@export var cooldown: float = 1.0

var _cooldown_left: float = 0.0
var player: CharacterBody2D = null


func initialize(owner: CharacterBody2D) -> void:
        player = owner
        set_process(true)
        set_physics_process(true)


func can_cast() -> bool:
        return _cooldown_left <= 0.0


func trigger(target_position: Vector2) -> bool:
        if not can_cast():
                return false

        if _cast(target_position):
                _cooldown_left = cooldown
                return true

        return false


func _cast(_target_position: Vector2) -> bool:
        return false


func _process(delta: float) -> void:
        if _cooldown_left > 0.0:
                _cooldown_left -= delta
                if _cooldown_left < 0.0:
                        _cooldown_left = 0.0
