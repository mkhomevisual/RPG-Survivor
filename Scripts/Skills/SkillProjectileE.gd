extends SkillBase
class_name SkillProjectileE

@export var projectile_scene: PackedScene = preload("res://Scenes/skill_e_projectile.tscn")
@export var projectile_damage: int = 8


func cast(player_state: Dictionary) -> bool:
        var world: Node = player_state.get("world", null)
        var player_node: Node2D = player_state.get("player", null)
        if world == null or player_node == null:
                return false

        if projectile_scene == null:
                return false

        var aim_position: Vector2 = player_state.get("aim_position", player_node.global_position)
        if cast_range > 0.0:
                var dir := aim_position - player_node.global_position
                var dist := dir.length()
                if dist > cast_range and dist > 0.0:
                        dir = dir.normalized() * cast_range
                        aim_position = player_node.global_position + dir

        var direction: Vector2 = aim_position - player_node.global_position
        if direction == Vector2.ZERO:
                return false

        var projectile: Node2D = projectile_scene.instantiate()
        world.add_child(projectile)

        projectile.global_position = player_node.global_position

        if projectile.has_method("set_direction"):
                projectile.set_direction(direction)
        if projectile.has_method("set_damage"):
                projectile.set_damage(projectile_damage)

        return true
