extends Node  # EnemySpawner

# --- Obecné nastavení ---
@export var spawn_enabled: bool = true

# kde kolem hráče se spawnuje
@export var spawn_radius_min: float = 500.0
@export var spawn_radius_max: float = 600.0

# List of enemy scenes to spawn.  If multiple entries are provided, a random
# one will be chosen for each spawn.  Populate this array in the inspector
# with scenes such as `enemy.tscn` (ghost), `enemy_shooter.tscn`, etc.
@export var enemy_scenes: Array[PackedScene] = [preload("res://Scenes/enemy.tscn")]

# režim spawneru (sandbox)
@export_enum("Constant", "Accelerating", "Waves")
var spawn_mode: int = 1  # 0 = Constant, 1 = Accelerating, 2 = Waves

# CONSTANT / ACCELERATING
@export var spawn_interval: float = 0.2            # start interval
@export var min_spawn_interval: float = 0.02       # spodní limit
@export var accel_factor: float = 0.95             # <1.0 = zrychluje, >1.0 = zpomaluje

# WAVES
@export var wave_size: int = 20                    # kolik enemáků ve wave
@export var wave_interval: float = 2.0             # pauza mezi wave

# limit počtu nepřátel
@export var max_enemies: int = 1600                # 0 = bez limitu

# --- PROGRESE A DIFFICULTY SCALING ---
@export var phase_length: float = 30.0             # délka jedné fáze (A → A+B → B) v sekundách
@export var hp_growth_per_minute: float = 0.25     # +25 % HP za minutu
@export var speed_growth_per_minute: float = 0.10  # +10 % rychlosti za minutu

@onready var _timer: Timer = $SpawnTimer

var _enemies_root: Node2D
var _player: Node2D

var _elapsed_time: float = 0.0                     # kolik sekund uběhlo od startu


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


func _physics_process(delta: float) -> void:
	# Sledujeme celkový čas – podle něj řídíme fáze a scaling.
	_elapsed_time += delta


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
			# vždycky po spawnu trochu zrychlíme (nikdy ne pod min_spawn_interval)
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

	# Pokud není nic v seznamu, neděláme nic.
	if enemy_scenes.size() == 0:
		return

	# Vybereme scénu podle aktuální fáze / času.
	var scene: PackedScene = _choose_enemy_scene()
	if scene == null:
		return

	var enemy := scene.instantiate()
	_enemies_root.add_child(enemy)

	# náhodný úhel + náhodný radius v intervalu <min,max>
	var angle: float = randf() * TAU
	var radius: float = randf_range(spawn_radius_min, spawn_radius_max)
	var offset: Vector2 = Vector2.RIGHT.rotated(angle) * radius

	enemy.global_position = _player.global_position + offset

	# Aplikujeme scaling HP/speed podle času.
	if enemy is EnemyBase:
		_apply_difficulty_scaling(enemy as EnemyBase)


func _count_enemies() -> int:
	var count := 0
	for child in _enemies_root.get_children():
		if child.is_in_group("enemy"):
			count += 1
	return count


# ------------------------------------------------------------
#  Výběr typu enemy podle pořadí v enemy_scenes a času
#  Pro N typů:
#    pair (0,1): A → A+B → B
#    pak pair (1,2): B → B+C → C
#    atd...
# ------------------------------------------------------------
func _choose_enemy_scene() -> PackedScene:
	var count: int = enemy_scenes.size()
	if count == 0:
		return null
	if count == 1:
		# jen jeden typ => furt ten samý
		return enemy_scenes[0]

	# kolikátá fáze (0,1,2,...) podle času
	var phase_index: int = int(floor(_elapsed_time / phase_length))

	# máme páry (0,1), (1,2), ..., (count-2, count-1)
	var pair_count: int = count - 1
	# na každý pár jsou 3 fáze: A, mix A+B, B
	# tj. 0..(3*pair_count-1)
	var max_phase: int = 3 * pair_count - 1

	# po poslední fázi už zůstáváme na posledním typu enemáka
	if phase_index > max_phase:
		phase_index = max_phase

	var pair_index: int = phase_index / 3          # který pár (0..pair_count-1)
	var stage: int = phase_index % 3               # 0=A, 1=mix, 2=B

	var idx_a: int = pair_index                    # starší typ
	var idx_b: int = min(pair_index + 1, count - 1) # novější typ (TADY BYLA CHYBA – teď je explicitně int)

	match stage:
		0:
			# první třetina: jen starší typ
			return enemy_scenes[idx_a]
		1:
			# druhá třetina: mix půl na půl
			return enemy_scenes[idx_a] if randf() < 0.5 else enemy_scenes[idx_b]
		2:
			# třetí třetina: jen novější typ
			return enemy_scenes[idx_b]

	# fallback, kdyby se něco rozbilo
	return enemy_scenes[0]


# ------------------------------------------------------------
#  Difficulty scaling pro jednoho EnemyBase
# ------------------------------------------------------------
func _apply_difficulty_scaling(enemy: EnemyBase) -> void:
	# minutes = kolik minut uplynulo od startu
	var minutes: float = _elapsed_time / 60.0
	if minutes <= 0.0:
		return

	# multiplikátory: 1.0 = bez změny
	var hp_mult: float = 1.0 + hp_growth_per_minute * minutes
	var speed_mult: float = 1.0 + speed_growth_per_minute * minutes

	# HP scaling
	enemy.max_hp = max(1, int(round(enemy.max_hp * hp_mult)))
	enemy.hp = enemy.max_hp  # nově spawnutý enemy má plné HP

	# Speed scaling
	enemy.speed *= speed_mult
