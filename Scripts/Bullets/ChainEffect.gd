class_name ChainEffect
extends Node

@export var chain_jumps: int = 0
@export var chain_range: float = 200.0
@export var bullet_scene: PackedScene

var _hit_enemies: Array = []


func apply_on_hit(body: Node, bullet_state: Dictionary) -> void:
        if chain_jumps <= 0:
                return
        _hit_enemies.append(body)

        var next_enemy := _find_next_enemy(body)
        if next_enemy == null:
                return

        if bullet_scene == null:
                return

        var b := bullet_scene.instantiate()
        var world := get_tree().current_scene
        if world != null:
                world.add_child(b)
        if b is Node2D:
                b.global_position = (body as Node2D).global_position

        var dir := next_enemy.global_position - (body as Node2D).global_position

        if b.has_method("set_direction"):
                b.set_direction(dir)
        if b.has_method("set_damage"):
                b.set_damage(bullet_state.get("damage", 1))
        if b.has_method("set_speed"):
                b.set_speed(bullet_state.get("speed", 400.0))

        _apply_snapshots(bullet_state.get("effect_snapshots", {}), b)
        _propagate_chain(b)

        bullet_state["should_destroy"] = true
        chain_jumps -= 1
        print("[Bullet] Chain jump spawned, remaining:", chain_jumps)


func get_state_snapshot() -> Dictionary:
        return {"chain_jumps": chain_jumps, "chain_range": chain_range, "hit_enemies": _hit_enemies.duplicate()}


func apply_snapshot(snapshot: Dictionary) -> void:
        chain_jumps = snapshot.get("chain_jumps", chain_jumps)
        chain_range = snapshot.get("chain_range", chain_range)
        _hit_enemies = snapshot.get("hit_enemies", []).duplicate()


func _find_next_enemy(from_enemy: Node2D) -> Node2D:
        var world := get_tree().current_scene
        if world == null or not world.has_node("Enemies"):
                return null

        var enemies_root := world.get_node("Enemies")
        var best: Node2D = null
        var best_dist2: float = chain_range * chain_range

        for child in enemies_root.get_children():
                if not child.is_in_group("enemy"):
                        continue
                if child == from_enemy:
                        continue
                if child in _hit_enemies:
                        continue
                if child.has_method("is_dead") and child.is_dead():
                        continue

                var d2 := from_enemy.global_position.distance_squared_to(child.global_position)
                if d2 < best_dist2:
                        best_dist2 = d2
                        best = child

        return best


func _apply_snapshots(snapshots: Dictionary, bullet: Node) -> void:
        for child in bullet.get_children():
                var key := child.get_class()
                if snapshots.has(key) and child.has_method("apply_snapshot"):
                        child.apply_snapshot(snapshots[key])


func _propagate_chain(bullet: Node) -> void:
        for child in bullet.get_children():
                if child is ChainEffect:
                        child.chain_jumps = chain_jumps
                        child._hit_enemies = _hit_enemies.duplicate()
