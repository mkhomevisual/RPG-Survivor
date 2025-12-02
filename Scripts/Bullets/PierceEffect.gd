class_name PierceEffect
extends Node

@export var pierce_count: int = 0

var _pierce_remaining: int = 0


func _ready() -> void:
        _pierce_remaining = pierce_count


func apply_on_hit(_body: Node, bullet_state: Dictionary) -> void:
        if _pierce_remaining > 0:
                        _pierce_remaining -= 1
                        bullet_state["should_destroy"] = false
                        print("[Bullet] Pierce remaining:", _pierce_remaining)
        else:
                        bullet_state["should_destroy"] = bullet_state.get("should_destroy", true)


func get_state_snapshot() -> Dictionary:
        return {"pierce_remaining": _pierce_remaining}


func apply_snapshot(snapshot: Dictionary) -> void:
        _pierce_remaining = snapshot.get("pierce_remaining", pierce_count)
