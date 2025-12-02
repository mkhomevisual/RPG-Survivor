extends CharacterBody2D

@export var speed: float = 50.0
@export var loadout: PlayerLoadout

var fire_cooldown: float = 0.2
var min_fire_cooldown: float = 0.05
var max_hp: int = 5
var shoot_glow_duration: float = 0.12
var auto_target_radius: float = 250.0
var attack_damage: int = 1

var _time_since_shot: float = 0.0
var hp: int = 0

var bullet_speed_multiplier: float = 1.0
var has_pierce: bool = false
var has_split: bool = false

var _skills: Array = []

@onready var _bullet_scene: PackedScene = loadout != null ? loadout.projectile_scene : preload("res://Scenes/bullet.tscn")
@onready var _shoot_glow: Sprite2D = $ShootGlow
@onready var _sprite: Sprite2D = $Sprite2D

var _shoot_glow_time: float = 0.0


func _ready() -> void:
        add_to_group("player")

        _apply_loadout()
        hp = max_hp

        if _shoot_glow:
                _shoot_glow.visible = false
                var c := _shoot_glow.modulate
                c.a = 0.0
                _shoot_glow.modulate = c

        var world := get_tree().current_scene
        if world.has_method("update_player_health"):
                world.call_deferred("update_player_health", hp, max_hp)

        _initialize_skills()


func _physics_process(delta: float) -> void:
        _handle_movement()
        _handle_auto_shoot(delta)
        _update_shoot_glow(delta)


func _handle_movement() -> void:
        var dir := Vector2.ZERO

        dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
        dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

        if dir.length() > 0.0:
                dir = dir.normalized()

                if _sprite and dir.x != 0.0:
                        _sprite.flip_h = dir.x < 0.0

        velocity = dir * speed
        move_and_slide()


func _handle_auto_shoot(delta: float) -> void:
        _time_since_shot += delta
        if _time_since_shot < fire_cooldown:
                return

        var target := _get_closest_enemy(auto_target_radius)
        if target == null:
                return

        _time_since_shot = 0.0
        _shoot_bullet(target.global_position)


func _get_closest_enemy(max_distance: float) -> Node2D:
        var world := get_tree().current_scene
        if world == null or not world.has_node("Enemies"):
                return null

        var enemies_root := world.get_node("Enemies")
        var closest: Node2D = null
        var best_dist2: float = max_distance * max_distance

        for child in enemies_root.get_children():
                if not child.is_in_group("enemy"):
                        continue
                if child.has_method("is_dead") and child.is_dead():
                        continue

                var d2: float = global_position.distance_squared_to(child.global_position)
                if d2 < best_dist2:
                        best_dist2 = d2
                        closest = child

        return closest


func _shoot_bullet(target_pos: Vector2) -> void:
        if _bullet_scene == null:
                return

        var bullet := _bullet_scene.instantiate()
        var world := get_tree().current_scene
        world.add_child(bullet)

        bullet.global_position = global_position

        var dir: Vector2 = target_pos - global_position

        if bullet.has_method("set_direction"):
                bullet.set_direction(dir)
        if bullet.has_method("set_damage"):
                bullet.set_damage(attack_damage)
        if bullet.has_method("set_speed_multiplier"):
                bullet.set_speed_multiplier(bullet_speed_multiplier)

        if has_pierce and bullet.has_method("set_pierce"):
                bullet.set_pierce(1)
        if has_split and bullet.has_method("set_split"):
                bullet.set_split(true, 1)

        _play_shoot_glow()


func trigger_skill(index: int, target_position: Vector2) -> void:
        if index < 0 or index >= _skills.size():
                return

        var skill := _skills[index]
        if skill is SkillBase:
                skill.trigger(target_position)


func _initialize_skills() -> void:
        if loadout == null:
                return

        for path in loadout.skill_scene_paths:
                var scene: PackedScene = load(path)
                if scene == null:
                        continue

                var skill_instance := scene.instantiate()
                add_child(skill_instance)

                if skill_instance is SkillBase:
                        skill_instance.initialize(self)
                        _skills.append(skill_instance)


func _update_shoot_glow(delta: float) -> void:
        if _shoot_glow == null:
                return
        if _shoot_glow_time <= 0.0:
                return

        _shoot_glow_time -= delta

        var t := clampf(_shoot_glow_time / shoot_glow_duration, 0.0, 1.0)
        var c := _shoot_glow.modulate
        c.a = t
        _shoot_glow.modulate = c

        if _shoot_glow_time <= 0.0:
                _shoot_glow.visible = false


func _play_shoot_glow() -> void:
        if _shoot_glow == null:
                return

        _shoot_glow_time = shoot_glow_duration
        _shoot_glow.visible = true

        var c := _shoot_glow.modulate
        c.a = 1.0
        _shoot_glow.modulate = c


func take_damage(amount: int) -> void:
        hp -= amount

        var world := get_tree().current_scene
        if world.has_method("update_player_health"):
                world.update_player_health(hp, max_hp)

        if hp <= 0:
                _die()


func _die() -> void:
        get_tree().reload_current_scene()


func upgrade_attack_speed() -> void:
        fire_cooldown *= 0.85
        if fire_cooldown < min_fire_cooldown:
                fire_cooldown = min_fire_cooldown


func upgrade_attack_damage() -> void:
        attack_damage += 1


func upgrade_max_health() -> void:
        max_hp += 1
        hp += 1
        var world := get_tree().current_scene
        if world.has_method("update_player_health"):
                world.update_player_health(hp, max_hp)


func upgrade_bullet_speed() -> void:
        bullet_speed_multiplier *= 1.15


func _apply_loadout() -> void:
        if loadout == null:
                return

        if loadout.projectile_scene != null:
                _bullet_scene = loadout.projectile_scene

        attack_damage = loadout.attack_damage
        fire_cooldown = loadout.fire_cooldown
        min_fire_cooldown = loadout.min_fire_cooldown
        shoot_glow_duration = loadout.shoot_glow_duration
        auto_target_radius = loadout.auto_target_radius
        max_hp = loadout.max_hp
