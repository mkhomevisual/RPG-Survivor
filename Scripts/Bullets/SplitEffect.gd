class_name SplitEffect
extends Node

@export var generations: int = 0
@export var split_angle_deg: float = 25.0
@export var bullet_scene: PackedScene

var _generations_left: int = 0


func _ready() -> void:
        _generations_left = generations


func apply_on_hit(_body: Node, bullet_state: Dictionary) -> void:
        if _generations_left <= 0:
                return
        if bullet_scene == null:
                return

        var world := get_tree().current_scene
        if world == null:
                return

        var parent_bullet := get_parent() as Node2D
        if parent_bullet == null:
                return

        var base_dir: Vector2 = bullet_state.get("direction", Vector2.RIGHT)
        var angle_rad := deg_to_rad(split_angle_deg)
        var dirs := [base_dir.rotated(angle_rad), base_dir.rotated(-angle_rad)]
        var snapshots := bullet_state.get("effect_snapshots", {})

        for d in dirs:
                var b := bullet_scene.instantiate()
                world.add_child(b)

                if b is Node2D:
                        b.global_position = parent_bullet.global_position
                if b.has_method("set_direction"):
                        b.set_direction(d)
                if b.has_method("set_damage"):
                        b.set_damage(bullet_state.get("damage", 1))
                if b.has_method("set_speed"):
                        b.set_speed(bullet_state.get("speed", 400.0))

                _apply_snapshots_to_bullet(b, snapshots)
                _propagate_split_generation(b)

        _generations_left -= 1
        print("[Bullet] Split generated, generations left:", _generations_left)


func get_state_snapshot() -> Dictionary:
        return {"generations_left": _generations_left}


func apply_snapshot(snapshot: Dictionary) -> void:
        _generations_left = snapshot.get("generations_left", generations)


func _apply_snapshots_to_bullet(bullet: Node, snapshots: Dictionary) -> void:
        for child in bullet.get_children():
                var key := child.get_class()
                if snapshots.has(key) and child.has_method("apply_snapshot"):
                        child.apply_snapshot(snapshots[key])


func _propagate_split_generation(bullet: Node) -> void:
        for child in bullet.get_children():
                if child is SplitEffect:
                        child.apply_snapshot({"generations_left": _generations_left - 1})
