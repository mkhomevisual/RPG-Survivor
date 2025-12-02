extends SkillBase

@export var projectile_scene: PackedScene = preload("res://Scenes/skill_e_projectile.tscn")
@export var damage: int = 8
@export var max_range: float = 2000.0

func _cast(target_position: Vector2) -> bool:
        if projectile_scene == null or player == null:
                return false

        var world := get_tree().current_scene
        if world == null:
                return false

        var proj := projectile_scene.instantiate()
        world.add_child(proj)

        if proj.has_method("set_direction"):
                proj.set_direction(target_position - player.global_position)
        if proj.has_method("set_damage"):
                proj.set_damage(damage)
        if proj.has_method("set_max_range"):
                proj.set_max_range(max_range)

        proj.global_position = player.global_position
        return true
