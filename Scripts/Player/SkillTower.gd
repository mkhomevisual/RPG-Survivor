extends SkillBase

@export var tower_scene: PackedScene = preload("res://Scenes/tower.tscn")
@export var max_cast_range: float = 500.0

func _cast(target_position: Vector2) -> bool:
        if player == null or tower_scene == null:
                return false

        var world := get_tree().current_scene
        if world == null:
                return false

        var cast_position := target_position

        if max_cast_range > 0.0:
                var dir := target_position - player.global_position
                var dist := dir.length()
                if dist > max_cast_range and dist > 0.0:
                        dir = dir.normalized() * max_cast_range
                        cast_position = player.global_position + dir

        var tower: Node2D = tower_scene.instantiate()
        world.add_child(tower)
        tower.global_position = cast_position
        return true
