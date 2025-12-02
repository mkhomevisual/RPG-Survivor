extends SkillBase

@export var frost_field_scene: PackedScene = preload("res://Scenes/frost_field.tscn")

func _cast(target_position: Vector2) -> bool:
        if frost_field_scene == null:
                return false

        var world := get_tree().current_scene
        if world == null:
                return false

        var field: Area2D = frost_field_scene.instantiate()
        world.add_child(field)
        field.global_position = target_position
        return true
