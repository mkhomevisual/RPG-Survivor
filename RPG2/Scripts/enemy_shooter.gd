extends "res://Scripts/enemy_base.gd"

# EnemyShooter.gd
#
# Ranged nepřítel:
# - jde k playerovi, dokud nedojde do shoot_range
# - v radiusu se zastaví, vystřelí, čeká shoot_interval a opakuje
# - když je player mimo range, zase jde směrem k němu (movement řeší EnemyBase)

@export var shoot_interval: float = 1.0                  # pauza mezi výstřely
@export var shoot_range: float = 100.0                   # radius, ve kterém se zastaví a střílí
@export var projectile_scene: PackedScene = preload("res://Scenes/enemy_projectile.tscn")
@export var projectile_speed: float = 50.0
@export var projectile_damage: int = 1

var _shoot_timer: float = 0.0
var _base_speed: float = 0.0


func _ready() -> void:
	# Base inicializace z EnemyBase (hp, target, group "enemy", atd.)
	super._ready()
	# náhodný offset, ať nestřílí všichni stejně
	_shoot_timer = randf() * shoot_interval
	# _base_speed necháme na 0, nastavíme ho lazy v _update_enemy,
	# až proběhne případný scaling ze spawneru


func _update_enemy(delta: float) -> void:
	# Když nemáme target, nic neřešíme.
	if target == null:
		return

	# Lazy inicializace base speed – v téhle chvíli už mohl spawner upravit enemy.speed
	if _base_speed == 0.0:
		_base_speed = speed

	# Odpočítáme cooldown střelby.
	if _shoot_timer > 0.0:
		_shoot_timer -= delta

	# Vektor a vzdálenost k playerovi.
	var dir: Vector2 = target.global_position - global_position
	var distance: float = dir.length()

	if distance <= shoot_range:
		# Jsme v radiusu => zastavíme se.
		speed = 0.0

		# Pokud máme po cooldownu a existuje projectile_scene, vystřelíme.
		if _shoot_timer <= 0.0 and projectile_scene != null:
			_shoot_timer = shoot_interval
			_spawn_projectile(dir)
	else:
		# Mimo radius => běž normální rychlostí (EnemyBase tě žene k playerovi).
		speed = _base_speed


func _spawn_projectile(dir: Vector2) -> void:
	var world := get_tree().current_scene
	if world == null:
		return

	var proj := projectile_scene.instantiate()
	world.add_child(proj)
	proj.global_position = global_position

	# Set direction and damage if methods exist on projectile.
	if proj.has_method("set_direction"):
		proj.set_direction(dir)
	if proj.has_method("set_damage"):
		proj.set_damage(projectile_damage)
	if proj.has_method("set_speed"):
		proj.set_speed(projectile_speed)
