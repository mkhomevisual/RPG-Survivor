extends Node  # EnemySpawner

# --- Obecné nastavení ---
@export var spawn_enabled: bool = true

# kde kolem hráče se spawnuje
@export var spawn_radius_min: float = 450.0
@export var spawn_radius_max: float = 650.0

@export var enemy_scene: PackedScene = preload("res://Scenes/enemy.tscn")

# režim spawneru (sandbox)
@export_enum("Constant", "Accelerating", "Waves")
var spawn_mode: int = 2  # 0 = Constant, 1 = Accelerating, 2 = Waves

# CONSTANT / ACCELERATING
@export var spawn_interval: float = 0.2            # start interval
@export var min_spawn_interval: float = 0.05       # spodní limit
@export var accel_factor: float = 0.97             # násobek po každém spawnu (pro Accelerating)

# WAVES
@export var wave_size: int = 20                     # kolik enemáků ve wave
@export var wave_interval: float = 2.0             # pauza mezi wave

# limit počtu nepřátel
@export var max_enemies: int = 800                 # 0 = bez limitu

@onready var _timer: Timer = $SpawnTimer

var _enemies_root: Node2D
var _player: Node2D


func _ready() -> void:
	randomize()

	var world: Node = get_tree().current_scene
	if world == null:
		return

	if world.has_node("Enemies"):
		_enemies_root = world.get_node("Enemies") as Node2D
	if world.has_node("Player"):
		_player = world.get_node("Player") as Node2D

	if _enemies_root == null or _player == null:
		push_error("Spawner: nenašel jsem nody 'Enemies' nebo 'Player' v Main.tscn")
		return

	if not _timer.timeout.is_connected(_on_spawn_timer_timeout):
		_timer.timeout.connect(_on_spawn_timer_timeout)

	_reset_timer()


func _reset_timer() -> void:
	if not spawn_enabled:
		_timer.stop()
		return

	match spawn_mode:
		0: # Constant
			_timer.wait_time = spawn_interval
		1: # Accelerating
			_timer.wait_time = spawn_interval
		2: # Waves
			_timer.wait_time = wave_interval

	_timer.start()


func _on_spawn_timer_timeout() -> void:
	if not spawn_enabled:
		return

	match spawn_mode:
		0: # Constant
			_spawn_enemy()
		1: # Accelerating
			_spawn_enemy()
			# vždycky po spawnu trochu zrychlíme
			spawn_interval = max(min_spawn_interval, spawn_interval * accel_factor)
		2: # Waves
			for i in range(wave_size):
				_spawn_enemy()

	# nastav další interval (kvůli Accelerating / Waves)
	_reset_timer()


func _spawn_enemy() -> void:
	if _enemies_root == null or _player == null:
		return

	# limit nepřátel na mapě
	if max_enemies > 0 and _count_enemies() >= max_enemies:
		return

	var enemy := enemy_scene.instantiate()
	_enemies_root.add_child(enemy)

	# náhodný úhel + náhodný radius v intervalu <min,max>
	var angle: float = randf() * TAU
	var radius: float = randf_range(spawn_radius_min, spawn_radius_max)
	var offset: Vector2 = Vector2.RIGHT.rotated(angle) * radius

	enemy.global_position = _player.global_position + offset


func _count_enemies() -> int:
	var count := 0
	for child in _enemies_root.get_children():
		if child.is_in_group("enemy"):
			count += 1
	return count
