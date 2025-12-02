extends Resource
class_name PlayerLoadout

@export var projectile_scene: PackedScene
@export var attack_damage: int = 1
@export var fire_cooldown: float = 0.2
@export var min_fire_cooldown: float = 0.05
@export var shoot_glow_duration: float = 0.12
@export var auto_target_radius: float = 250.0
@export var max_hp: int = 5
@export var skill_scene_paths: Array[String] = []
