extends CharacterBody2D  # Player

# -------- EXPORT ZÁKLAD --------
@export var speed: float = 50.0
@export var fire_cooldown: float = 0.2
@export var min_fire_cooldown: float = 0.05
@export var max_hp: int = 5
@export var shoot_glow_duration: float = 0.12
@export var auto_target_radius: float = 250.0

# -------- SKILLS --------
@export var skill_q_icon: String = "res://Assets/Skills/q2/Comp 2/Comp 2_00000.png"
@export var skill_e_icon: String = "res://Assets/Skills/Bullet3.png"
@export var skill_r_icon: String = "res://Assets/Skills/Tower.png"

# -------- STAV --------
var attack_damage: int = 1
var _time_since_shot: float = 0.0
var hp: int = 0

# Bullet speed (stat) – multiplikátor
var bullet_speed_multiplier: float = 1.0

# Augment flagy
var has_pierce: bool = false
var has_split: bool = false

var skills: Array[SkillBase] = []
var _skill_slots: Dictionary = {}

# -------- ONREADY --------
@onready var _bullet_scene: PackedScene = preload("res://Scenes/bullet.tscn")
@onready var _shoot_glow: Sprite2D = $ShootGlow
@onready var _sprite: Sprite2D = $Sprite2D

var _shoot_glow_time: float = 0.0


func _ready() -> void:
        add_to_group("player")

        hp = max_hp

        _initialize_skills()

	# připravíme glow
	if _shoot_glow:
		_shoot_glow.visible = false
		var c := _shoot_glow.modulate
		c.a = 0.0
		_shoot_glow.modulate = c

	var world := get_tree().current_scene
        if world.has_method("update_player_health"):
                world.call_deferred("update_player_health", hp, max_hp)


func _initialize_skills() -> void:
        skills.clear()
        _skill_slots.clear()

        var frost_skill := SkillFrostField.new()
        frost_skill.cooldown = 2.0
        frost_skill.icon_path = skill_q_icon
        frost_skill.cast_range = 0.0
        _register_skill("Q", frost_skill)

        var projectile_skill := SkillProjectileE.new()
        projectile_skill.cooldown = 3.0
        projectile_skill.icon_path = skill_e_icon
        projectile_skill.projectile_damage = 8
        projectile_skill.cast_range = 0.0
        _register_skill("E", projectile_skill)

        var tower_skill := SkillTower.new()
        tower_skill.cooldown = 10.0
        tower_skill.icon_path = skill_r_icon
        tower_skill.cast_range = 500.0
        _register_skill("R", tower_skill)

        for skill in skills:
                skill._emit_cooldown_changed()


func _register_skill(slot: String, skill: SkillBase) -> void:
        if skill == null:
                return

        add_child(skill)
        skills.append(skill)
        _skill_slots[slot] = skill
        skill.cooldown_changed.connect(_on_skill_cooldown_changed.bind(slot))


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_auto_shoot(delta)
	_handle_skills(delta)
	_update_shoot_glow(delta)


# -------- POHYB --------
func _handle_movement(_delta: float) -> void:
	var dir := Vector2.ZERO

	dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if dir.length() > 0.0:
		dir = dir.normalized()

		# flip sprity podle směru na X ose
		if _sprite and dir.x != 0.0:
			_sprite.flip_h = dir.x < 0.0

	velocity = dir * speed
	move_and_slide()


# -------- AUTOSHOOT (ZÁKLADNÍ STŘELBA) --------
func _handle_auto_shoot(delta: float) -> void:
	_time_since_shot += delta
	if _time_since_shot < fire_cooldown:
		return

	var target := _get_closest_enemy(auto_target_radius)
	if target == null:
		return

	_time_since_shot = 0.0
	_shoot_bullet(target.global_position)


func _get_closest_enemy(max_distance: float) -> Node2D:
	var world := get_tree().current_scene
	if world == null or not world.has_node("Enemies"):
		return null

	var enemies_root := world.get_node("Enemies")
	var closest: Node2D = null
	var best_dist2: float = max_distance * max_distance

	for child in enemies_root.get_children():
		if not child.is_in_group("enemy"):
			continue
		if child.has_method("is_dead") and child.is_dead():
			continue

		var d2: float = global_position.distance_squared_to(child.global_position)
		if d2 < best_dist2:
			best_dist2 = d2
			closest = child

	return closest


func _shoot_bullet(target_pos: Vector2) -> void:
	if _bullet_scene == null:
		return

	var bullet := _bullet_scene.instantiate()
	var world := get_tree().current_scene
	world.add_child(bullet)

	bullet.global_position = global_position

	var dir: Vector2 = target_pos - global_position

	if bullet.has_method("set_direction"):
		bullet.set_direction(dir)
	if bullet.has_method("set_damage"):
		bullet.set_damage(attack_damage)
	if bullet.has_method("set_speed_multiplier"):
		bullet.set_speed_multiplier(bullet_speed_multiplier)

	if has_pierce and bullet.has_method("set_pierce"):
		bullet.set_pierce(1)
	if has_split and bullet.has_method("set_split"):
		bullet.set_split(true, 1)

	if has_pierce or has_split:
		print("Bullet fired with augments -> pierce:", has_pierce, " split:", has_split)

	_play_shoot_glow()


# -------- SKILLY (Q / E / R) --------
func _handle_skills(delta: float) -> void:
        _process_skill_cooldowns(delta)

        var state := _get_skill_state()

        if Input.is_action_just_pressed("skill_q"):
                _try_cast_skill("Q", state)

        if Input.is_action_just_pressed("skill_e"):
                _try_cast_skill("E", state)

        if Input.is_action_just_pressed("skill_r"):
                _try_cast_skill("R", state)


func _process_skill_cooldowns(delta: float) -> void:
        for skill in skills:
                if skill == null:
                        continue
                skill.process_cooldown(delta)


func _get_skill_state() -> Dictionary:
        return {
                "player": self,
                "player_position": global_position,
                "aim_position": get_global_mouse_position(),
                "world": get_tree().current_scene
        }


func _try_cast_skill(slot: String, state: Dictionary) -> void:
        if not _skill_slots.has(slot):
                return
        var skill: SkillBase = _skill_slots[slot]
        if skill == null:
                return
        skill.try_cast(state)


func _on_skill_cooldown_changed(skill: SkillBase, cooldown_left: float, cooldown_total: float, icon_path: String, slot: String) -> void:
        var world := get_tree().current_scene
        if world and world.has_method("update_skill_cooldown"):
                world.update_skill_cooldown(slot, cooldown_left, cooldown_total, icon_path)


# -------- SHOOT GLOW --------
func _update_shoot_glow(delta: float) -> void:
	if _shoot_glow == null:
		return
	if _shoot_glow_time <= 0.0:
		return

	_shoot_glow_time -= delta

	var t := clampf(_shoot_glow_time / shoot_glow_duration, 0.0, 1.0)
	var c := _shoot_glow.modulate
	c.a = t
	_shoot_glow.modulate = c

	if _shoot_glow_time <= 0.0:
		_shoot_glow.visible = false


func _play_shoot_glow() -> void:
	if _shoot_glow == null:
		return

	_shoot_glow_time = shoot_glow_duration
	_shoot_glow.visible = true

	var c := _shoot_glow.modulate
	c.a = 1.0
	_shoot_glow.modulate = c


# -------- HEALTH / DAMAGE --------
func take_damage(amount: int) -> void:
	hp -= amount

	var world := get_tree().current_scene
	if world.has_method("update_player_health"):
		world.update_player_health(hp, max_hp)

	if hp <= 0:
		_die()


func _die() -> void:
	get_tree().reload_current_scene()


# -------- STAT UPGRADES --------
func upgrade_attack_speed() -> void:
	fire_cooldown *= 0.85
	if fire_cooldown < min_fire_cooldown:
		fire_cooldown = min_fire_cooldown


func upgrade_attack_damage() -> void:
	attack_damage += 1


func upgrade_max_health() -> void:
	max_hp += 1
	hp += 1
	var world := get_tree().current_scene
	if world.has_method("update_player_health"):
		world.update_player_health(hp, max_hp)


func upgrade_bullet_speed() -> void:
	bullet_speed_multiplier *= 1.15


# -------- AUGMENTY --------
func add_augment_pierce() -> void:
	if has_pierce:
		return
	has_pierce = true
	print("AUGMENT ACQUIRED: PIERCE")


func add_augment_split() -> void:
	if has_split:
		return
	has_split = true
	print("AUGMENT ACQUIRED: SPLIT")
