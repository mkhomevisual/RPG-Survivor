extends SkillBase
class_name SkillFrostField

@export var frost_field_scene: PackedScene = preload("res://Scenes/frost_field.tscn")


func cast(player_state: Dictionary) -> bool:
        var world: Node = player_state.get("world", null)
        if world == null:
                return false

        if frost_field_scene == null:
                return false

        var target_position: Vector2 = player_state.get("aim_position", Vector2.ZERO)
        if cast_range > 0.0:
                var player_position: Vector2 = player_state.get("player_position", Vector2.ZERO)
                var dir: Vector2 = target_position - player_position
                var dist := dir.length()
                if dist > cast_range and dist > 0.0:
                        dir = dir.normalized() * cast_range
                        target_position = player_position + dir

        var field: Node2D = frost_field_scene.instantiate()
        world.add_child(field)
        field.global_position = target_position
        return true
