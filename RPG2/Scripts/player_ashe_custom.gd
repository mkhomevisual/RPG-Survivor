extends "res://Scripts/player.gd"

# ↑ Ashe dědí kompletní logiku defaultního Playera (movement, auto-attack, Q/E/R cooldown systém, …)
# Tento skript:
# - umožňuje override projektilu v inspektoru (bullet_scene_override)
# - přepisuje Q na Frost Volley
# - přepisuje E na attack-speed buff
# - přepisuje R na Glacial Zone kolem Ashe

@export var bullet_scene_override: PackedScene

# --- SPRITES PRO SMĚRY ---
@export var sprite_down: Texture2D
@export var sprite_left: Texture2D
@export var sprite_right: Texture2D
@export var sprite_up: Texture2D

# --- ASHE PARAMS ---

# Q – Frost Volley
@export var ashe_volley_projectiles: int = 10 # kolik šípů v kuželu
@export var ashe_volley_spread_deg: float = 50.0 # šířka kuželu ve stupních
@export var ashe_volley_damage_mult: float = 0.7 # dmg každého šípu vs. autoattack

# E – Focused Fire (dočasný attack speed buff)
@export var ashe_focus_duration: float = 3.0 # jak dlouho buff trvá (v sekundách)
@export var ashe_focus_attack_speed_mult: float = 0.5 # fire_cooldown * 0.5 = 2× rychlejší střelba

# R – Glacial Zone
@export var ashe_glacial_zone_scene: PackedScene = preload("res://Scenes/ashe_r_zone.tscn")


# Interní proměnné pro E buff
var _ashe_focus_active: bool = false
var _ashe_focus_time_left: float = 0.0
var _ashe_base_fire_cooldown: float = 0.0


func _ready() -> void:
	# Pokud hráč nastavil override projektilu, použijeme jej na bullet_scene
	if bullet_scene_override != null:
		bullet_scene = bullet_scene_override

	# Zavoláme původní _ready() z player.gd
	super._ready()

	# Uložíme si původní fire_cooldown pro E buff
	_ashe_base_fire_cooldown = fire_cooldown

	# Hned na start nastavíme správný sprite podle facing_direction (z CharacterBase)
	_on_direction_changed(facing_direction)


func _physics_process(delta: float) -> void:
	# Základní logika (movement, auto-střelba, skilly z player.gd)
	super._physics_process(delta)

	# Navíc řešíme doběh Ashe E buffu
	_update_ashe_focus(delta)


# -------------------------------
# Q – FROST VOLLEY (KUŽEL ŠÍPŮ)
# -------------------------------

func _cast_skill_q() -> void:
	# Přepíšeme defaultní Q (frost field) na kuželový volley projektilů.
	if bullet_scene == null:
		return

	# Cooldown Q – používáme původní proměnnou ze scriptu player.gd
	_skill_q_cd_left = skill_q_cooldown

	var world := get_tree().current_scene
	if world == null:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	var base_dir: Vector2 = mouse_pos - global_position
	if base_dir.length() == 0.0:
		base_dir = Vector2.RIGHT
	base_dir = base_dir.normalized()

	var count: int = max(ashe_volley_projectiles, 1)
	var spread_rad: float = deg_to_rad(ashe_volley_spread_deg)

	for i in range(count):
		var t: float = 0.0
		if count > 1:
			t = float(i) / float(count - 1) - 0.5
		var angle: float = t * spread_rad
		var dir: Vector2 = base_dir.rotated(angle)

		var b := bullet_scene.instantiate()
		world.add_child(b)
		b.global_position = global_position

		# nasměrujeme střelu
		if b.has_method("set_direction"):
			b.set_direction(dir)

		# damage – o něco menší než autoattack
		if b.has_method("set_damage"):
			var volley_damage := int(float(attack_damage) * ashe_volley_damage_mult)
			if volley_damage < 1:
				volley_damage = 1
			b.set_damage(volley_damage)

	# pro efekt můžeme pustit glow (přebíráme z player.gd)
	_play_shoot_glow()


# ----------------------------------------
# E – FOCUSED FIRE (ATTACK SPEED BUFF)
# ----------------------------------------

func _cast_skill_e() -> void:
	# Přepíšeme původní E skill z player.gd na buff attack speedu.

	# Cooldown E – používáme původní proměnnou
	_skill_e_cd_left = skill_e_cooldown

	# nastavení buffu
	_ashe_focus_active = true
	_ashe_focus_time_left = ashe_focus_duration

	# zrychlíme střelbu (snížíme fire_cooldown)
	# (chráníme se, aby se nedostal pod min_fire_cooldown)
	var new_cd := _ashe_base_fire_cooldown * ashe_focus_attack_speed_mult
	if new_cd < min_fire_cooldown:
		new_cd = min_fire_cooldown
	fire_cooldown = new_cd


func _update_ashe_focus(delta: float) -> void:
	if not _ashe_focus_active:
		return

	_ashe_focus_time_left -= delta
	if _ashe_focus_time_left <= 0.0:
		_ashe_focus_active = false
		# vrátíme fire_cooldown na původní hodnotu
		fire_cooldown = _ashe_base_fire_cooldown


# -------------------------------
# R – GLACIAL ZONE KOLEM ASHE
# -------------------------------

func _cast_skill_r() -> void:
	if ashe_glacial_zone_scene == null:
		return

	# Cooldown R – používáme stejnou logiku jako base
	_skill_r_cd_left = skill_r_cooldown

	var world := get_tree().current_scene
	if world == null:
		return

	var zone := ashe_glacial_zone_scene.instantiate()
	world.add_child(zone)

	# spawn přímo na Ashe
	if zone is Node2D:
		zone.global_position = global_position

	# navážeme zónu na Ashe, aby se hýbala s ní
	if zone.has_method("init_from_player"):
		zone.init_from_player(self)


# -------------------------------
# VIZUÁL PODLE SMĚRU
# -------------------------------

func _on_direction_changed(new_dir: int) -> void:
	# Tahle funkce přepisuje hook z CharacterBase.
	# Volá se AUTOMATICKY pokaždé, když se změní facing_direction.
	if _sprite == null:
		return

	match new_dir:
		CharacterBase.MoveDir.RIGHT:
			_sprite.texture = sprite_right
		CharacterBase.MoveDir.LEFT:
			_sprite.texture = sprite_left
		CharacterBase.MoveDir.UP:
			_sprite.texture = sprite_up
		CharacterBase.MoveDir.DOWN:
			_sprite.texture = sprite_down
