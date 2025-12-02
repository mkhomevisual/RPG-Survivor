# Resource pro loadout hráče – drží základní i upravené statistiky
extends Resource
class_name PlayerLoadout

@export var move_speed: float = 50.0
@export var fire_cooldown: float = 0.2
@export var min_fire_cooldown: float = 0.05
@export var attack_damage: int = 1
@export var bullet_speed_multiplier: float = 1.0
@export var pickup_radius_multiplier: float = 1.0

@export var has_pierce: bool = false
@export var has_split: bool = false


func duplicate_loadout() -> PlayerLoadout:
        # explicitní wrapper, ať máme jasný typ při kopírování
        return duplicate(true)
