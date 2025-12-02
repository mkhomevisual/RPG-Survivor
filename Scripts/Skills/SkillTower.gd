extends SkillBase
class_name SkillTower

@export var tower_scene: PackedScene = preload("res://Scenes/tower.tscn")
@export var tower_damage: int = 3
@export var tower_fire_cooldown: float = 0.5
@export var tower_range: float = 400.0
@export var tower_lifetime: float = 10.0


func cast(player_state: Dictionary) -> bool:
        var world: Node = player_state.get("world", null)
        var player_node: Node2D = player_state.get("player", null)
        if world == null:
                return false

        if tower_scene == null:
                return false

        var target_position: Vector2 = player_state.get("aim_position", Vector2.ZERO)
        if cast_range > 0.0 and player_node != null:
                var dir: Vector2 = target_position - player_node.global_position
                var dist := dir.length()
                if dist > cast_range and dist > 0.0:
                        dir = dir.normalized() * cast_range
                        target_position = player_node.global_position + dir

        var tower: Node2D = tower_scene.instantiate()
        world.add_child(tower)
        tower.global_position = target_position

        if tower.has_method("set_damage"):
                tower.set_damage(tower_damage)
        else:
                tower.damage = tower_damage

        tower.fire_cooldown = tower_fire_cooldown
        tower.range = tower_range
        tower.lifetime = tower_lifetime

        return true
