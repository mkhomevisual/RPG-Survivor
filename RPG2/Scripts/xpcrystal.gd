extends Area2D  # XP krystal

@export var xp_amount: int = 1

@export var base_trigger_radius: float = 150.0   # základní radius, kdy začne magnet
@export var min_magnet_speed: float = 100.0      # min rychlost přitahování
@export var max_magnet_speed: float = 400.0      # max rychlost přitahování

var _player: Node2D = null
var _is_magnetized: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
var _base_modulate: Color = Color(1, 1, 1, 1)


func _ready() -> void:
	if _sprite != null:
		_base_modulate = _sprite.modulate

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	# najdeme playera, pokud ještě není uložený
	if _player == null:
		var world := get_tree().current_scene
		if world != null and world.has_node("Player"):
			_player = world.get_node("Player") as Node2D

	if _player == null:
		return

	var to_player: Vector2 = _player.global_position - global_position
	var distance: float = to_player.length()

	# pickup radius multiplikátor z playera
	var radius_mult: float = 1.0
	if _player.has_method("get_pickup_radius_multiplier"):
		radius_mult = float(_player.get_pickup_radius_multiplier())

	var effective_trigger: float = base_trigger_radius * radius_mult

	# když jsme dost blízko, začneme se přitahovat
	if not _is_magnetized and distance <= effective_trigger:
		_is_magnetized = true

	if not _is_magnetized:
		# mimo magnet – držíme původní barvu
		if _sprite != null:
			_sprite.modulate = _base_modulate
		return

	# když jsme už skoro u hráče -> sebereme se
	if distance < 8.0:
		_collect()
		return

	var dir: Vector2 = to_player.normalized()

	# čím blíže, tím rychleji – mapujeme [effective_trigger -> 0] na [0 -> 1]
	var t: float = clampf(1.0 - (distance / effective_trigger), 0.0, 1.0)
	var speed: float = lerpf(min_magnet_speed, max_magnet_speed, t)

	global_position += dir * speed * delta

	_update_color(distance, effective_trigger)


func _update_color(distance: float, effective_trigger: float) -> void:
	if _sprite == null:
		return

	# od poloviny effective_trigger začneme bělet
	var inner_radius: float = effective_trigger * 0.5

	if distance >= inner_radius:
		_sprite.modulate = _base_modulate
		return

	# distance: inner_radius -> 0  => t: 0 -> 1
	var t: float = clampf(1.0 - (distance / inner_radius), 0.0, 1.0)
	var white_factor: float = t * 0.9  # max ~90 % bílého přebarvení

	var target_color: Color = Color(1, 1, 1, 1)
	var c: Color = _base_modulate.lerp(target_color, white_factor)
	_sprite.modulate = c


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	_collect()


func _collect() -> void:
	var world := get_tree().current_scene
	if world != null and world.has_method("add_xp"):
		var amount := xp_amount

		# Volitelně: XP multiplier z Mainu (pokud má funkci get_xp_multiplier).
		if world.has_method("get_xp_multiplier"):
			var mult := float(world.get_xp_multiplier())
			amount = int(round(float(xp_amount) * mult))

		world.add_xp(amount)

	queue_free()
