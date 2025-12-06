# Ashe R – Glacial Zone
# Kruhová aura kolem Ashe:
# - nepřátelé uvnitř se hýbou jen na 10 % speedu a mají frost vizuál
# - Ashe projektily uvnitř zóny jsou 2× rychlejší u Ashe
#   a plynule klesají na 1× rychlost na hraně kruhu

extends Node2D

@export var radius: float = 150.0
@export var duration: float = 5.0
@export var enemy_speed_mult: float = 0.9    # 10 % rychlosti
@export var bullet_center_mult: float = 10.0  # 200 % rychlosti střel uprostřed
@export var frost_tick_duration: float = 0.25

var _time_alive: float = 0.0
var _player: Node2D = null
var _affected_enemies: Dictionary = {} # enemy -> původní speed


func init_from_player(player: Node2D) -> void:
	# Zavolá se při vytvoření zóny – dostane referenci na Ashe
	_player = player
	global_position = player.global_position


func _ready() -> void:
	# Kdyby náhodou init_from_player nebyl zavolán, zkusíme najít Player ve scéně
	if _player == null:
		var world := get_tree().current_scene
		if world and world.has_node("Player"):
			_player = world.get_node("Player") as Node2D


func _physics_process(delta: float) -> void:
	# Když player zmizí, zónu uklidíme a smažeme
	if _player == null or not is_instance_valid(_player):
		_cleanup()
		queue_free()
		return

	# zóna se drží na Ashe
	#global_position = _player.global_position

	# čas života zóny
	_time_alive += delta
	if _time_alive >= duration:
		_cleanup()
		queue_free()
		return

	_update_enemies()
	_update_bullets()


func _update_enemies() -> void:
	var world := get_tree().current_scene
	if world == null or not world.has_node("Enemies"):
		return

	var enemies_root: Node = world.get_node("Enemies")

	# odmažeme mrtvé / neplatné reference z dictionary
	for enemy in _affected_enemies.keys():
		if not is_instance_valid(enemy):
			_affected_enemies.erase(enemy)

	for child in enemies_root.get_children():
		# pracujeme jen s node, které jsou v group "enemy"
		if not child.is_in_group("enemy"):
			continue

		# BEZPEČNOST:
		# zóna R pracuje jen s EnemyBase (protože používá .speed, apply_frost, is_dead ...)
		if not (child is EnemyBase):
			continue
		var enemy := child as EnemyBase

		# pokud je mrtvý, vrátíme mu původní speed a už ho neřešíme
		if enemy.has_method("is_dead") and enemy.is_dead():
			if _affected_enemies.has(enemy):
				enemy.speed = _affected_enemies[enemy]
				_affected_enemies.erase(enemy)
			continue

		# vzdálenost od středu zóny
		var dist: float = global_position.distance_to(enemy.global_position)
		var inside: bool = dist <= radius

		if inside:
			if not _affected_enemies.has(enemy):
				# poprvé v zóně – uložíme původní speed a zpomalíme na enemy_speed_mult
				_affected_enemies[enemy] = enemy.speed
				enemy.speed = enemy.speed * enemy_speed_mult

			# frost vizuál – obnovujeme efekt, aby nevypršel během trvání zóny
			if enemy.has_method("apply_frost"):
				enemy.apply_frost(frost_tick_duration)
		else:
			# opustil zónu – vrátíme původní speed a odebereme z dictionary
			if _affected_enemies.has(enemy):
				enemy.speed = _affected_enemies[enemy]
				_affected_enemies.erase(enemy)


func _update_bullets() -> void:
	# najdeme všechny hráčovy střely (musí být v group "player_bullet")
	var bullets := get_tree().get_nodes_in_group("player_bullet")
	if bullets.is_empty():
		return

	for b in bullets:
		if not is_instance_valid(b):
			continue
		if not b.has_method("set_speed_multiplier"):
			continue

		# vzdálenost střely od středu zóny
		var dist: float = global_position.distance_to(b.global_position)
		var inside: bool = dist <= radius

		# vypočítáme multiplikátor rychlosti podle vzdálenosti
		var mult: float = 1.0
		if radius > 0.0:
			var t: float = clamp(dist / radius, 0.0, 1.0)
			# t = 0 => bullet_center_mult, t = 1 => 1×
			mult = lerpf(bullet_center_mult, 1.0, t)

		b.set_speed_multiplier(mult)

		# ---- PIERCE MÓD UVNITŘ ZÓNY ----
		if b.has_method("set_pierce_in_zone"):
			b.set_pierce_in_zone(inside)

func _cleanup() -> void:
	# vrátíme speed všem ovlivněným nepřátelům (to už tam máš)
	for enemy in _affected_enemies.keys():
		if is_instance_valid(enemy) and (enemy is EnemyBase):
			var e := enemy as EnemyBase
			e.speed = _affected_enemies[enemy]
	_affected_enemies.clear()

	# a resetujeme rychlost střel na 100 % + vypneme piercing mód
	var bullets := get_tree().get_nodes_in_group("player_bullet")
	for b in bullets:
		if not is_instance_valid(b):
			continue
		if b.has_method("set_speed_multiplier"):
			b.set_speed_multiplier(1.0)
		if b.has_method("set_pierce_in_zone"):
			b.set_pierce_in_zone(false)
