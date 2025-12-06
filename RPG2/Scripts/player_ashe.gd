extends "res://Scripts/player.gd"
# ↑ Ashe dědí kompletní logiku defaultního Playera
# (movement, autoattack, Q/E/R cooldown systém, směrové textury atd.)

#
# PlayerAshe.gd
#
# Ashe = frost archer varianta:
# - přepisuje Q na Frost Volley (kužel střel)
# - přepisuje E na Focused Fire (dočasný attack speed buff)
# - R zatím používá původní tower z player.gd (super._cast_skill_r())
#

# --- ASHE PARAMS ---

# Q – Frost Volley
@export var ashe_volley_projectiles: int = 7          # kolik šípů v kuželu
@export var ashe_volley_spread_deg: float = 40.0      # šířka kuželu ve stupních
@export var ashe_volley_damage_mult: float = 0.7      # dmg každého šípu vs. autoattack

# E – Focused Fire (dočasný attack speed buff)
@export var ashe_focus_duration: float = 3.0          # jak dlouho buff trvá (v sekundách)
@export var ashe_focus_attack_speed_mult: float = 0.5 # fire_cooldown * 0.5 = 2× rychlejší střelba

# Interní proměnné pro E buff
var _ashe_focus_active: bool = false
var _ashe_focus_time_left: float = 0.0
var _ashe_base_fire_cooldown: float = 0.0


func _ready() -> void:
	# zavoláme původní _ready() z player.gd
	super._ready()
	# uložíme si původní fire_cooldown pro E buff
	_ashe_base_fire_cooldown = fire_cooldown


func _physics_process(delta: float) -> void:
	# základní logika (movement, auto-střelba, skilly z player.gd)
	super._physics_process(delta)
	# navíc řešíme doběh Ashe E buffu
	_update_ashe_focus(delta)


# -------------------------------
#  Q – FROST VOLLEY (KUŽEL ŠÍPŮ)
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

	# Střed kuželu je base_dir, šířka spread_rad
	# i jde od 0 do count-1, t od -0.5 do +0.5, podle toho rotujeme
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

		# pokud má bullet nějaké extra metody (speed, pierce, split),
		# můžeme je sem časem přidat – zatím necháme default.

	# pro efekt můžeme pustit glow (pokud ho player.gd používá)
	_play_shoot_glow()


# ----------------------------------------
#  E – FOCUSED FIRE (ATTACK SPEED BUFF)
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
#  R – zatím používá původní R
# -------------------------------
func _cast_skill_r() -> void:
	# Prozatím jen použijeme původní implementaci R z player.gd (tower).
	# Později sem dáme Glacial Zone.
	super._cast_skill_r()

func _update_direction_visual(_dir: Vector2) -> void:
	# Tady můžeš řešit čistě vizuál – např. flip sprite doleva/doprava.
	if not has_node("Sprite2D"):
		return

	var spr := get_node("Sprite2D") as Sprite2D

	match facing_direction:
		CharacterBase.MoveDir.RIGHT:
			spr.flip_h = false
		CharacterBase.MoveDir.LEFT:
			spr.flip_h = true
		CharacterBase.MoveDir.UP, CharacterBase.MoveDir.DOWN:
			# Zatím nic speciálního, jen držíme poslední horizontální flip
			pass
