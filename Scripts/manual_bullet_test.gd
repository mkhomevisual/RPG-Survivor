extends Node

@export var bullet_scene: PackedScene = preload("res://Scenes/bullet.tscn")
@export var modifiers: Dictionary = {
        "pierce_count": 2,
        "split_generations": 1,
        "chain_jumps": 1,
        "chain_range": 150.0,
}

func _ready() -> void:
        print("[ManualTest] Spawning debug bullet with modifiers:", modifiers)
        var world := get_tree().current_scene
        if world == null:
                return
        var bullet := bullet_scene.instantiate()
        world.add_child(bullet)
        if bullet is Node2D:
                bullet.global_position = Vector2.ZERO
        _apply_modifiers(bullet)
        if bullet.has_method("set_direction"):
                bullet.set_direction(Vector2.RIGHT)


func _apply_modifiers(bullet: Node) -> void:
        if bullet == null:
                return
        for child in bullet.get_children():
                if child is PierceEffect:
                        child.pierce_count = int(modifiers.get("pierce_count", 0))
                if child is SplitEffect:
                        child.generations = int(modifiers.get("split_generations", 0))
                        child.bullet_scene = bullet_scene
                if child is ChainEffect:
                        child.chain_jumps = int(modifiers.get("chain_jumps", 0))
                        child.chain_range = float(modifiers.get("chain_range", 200.0))
                        child.bullet_scene = bullet_scene
        print("[ManualTest] Bullet effects configured for editor test")
