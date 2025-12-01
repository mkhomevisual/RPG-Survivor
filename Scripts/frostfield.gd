extends Area2D  # Frost pole pro skill Q

@export var lifetime: float = 2.0          # jak dlouho pole existuje
@export var pull_strength: float = 400.0   # síla přitažení do středu
@export var frost_duration: float = 4.0    # jak dlouho trvá zpomalení
@export var effect_radius: float = 220.0   # logický dosah efektu (nastavuješ v inspektoru)

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D

var _time_alive: float = 0.0


func _ready() -> void:
	# Kruh v editoru teď slouží jen jako vizuální pomoc,
	# logiku radiusu řídí čistě effect_radius.
	if _sprite:
		_sprite.play()  # default animace


func _physics_process(delta: float) -> void:
	# životnost
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()
		return

	var world := get_tree().current_scene
	if world == null or not world.has_node("Enemies"):
		return

	var enemies_root := world.get_node("Enemies")

	for child in enemies_root.get_children():
		if not child.is_in_group("enemy"):
			continue
		if child.has_method("is_dead") and child.is_dead():
			continue

		var enemy_pos: Vector2 = child.global_position
		var dist: float = global_position.distance_to(enemy_pos)
		if dist > effect_radius:
			continue

		# ---- přitažení do středu (vortex) ----
		if child.has_method("apply_vortex_pull"):
			child.apply_vortex_pull(global_position, pull_strength, delta)

		# ---- frost – jen zpomalení + zmodrání ----
		if child.has_method("apply_frost"):
			child.apply_frost(frost_duration)
