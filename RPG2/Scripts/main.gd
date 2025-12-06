extends Node2D  # Root scény



# -------- SCORE --------
var score: int = 0  # Celkové skóre

# -------- XP / LEVEL --------
var xp: int = 0
var level: int = 1
@export var xp_to_next_level: int = 5
@export var xp_level_multiplier: float = 1.5  # kolik se násobí requirement

# XP multiplier (kolik XP reálně dostaneš z krystalu)
@export var base_xp_multiplier: float = 1.0        # základ
@export var xp_mult_per_level: float = 0.10        # +10 % XP za každý level nad 1

var _elapsed_time: float = 0.0                     # pokud ještě nemáš, přidej

# -------- STATY PRO LEVEL-UP --------
enum StatUpgrade {
	ATTACK_SPEED,
	ATTACK_DAMAGE,
	MAX_HEALTH,
	BULLET_SPEED,
	MOVEMENT_SPEED,
	PICKUP_RADIUS
}

var _stat_choice_btn1: int = StatUpgrade.ATTACK_SPEED
var _stat_choice_btn2: int = StatUpgrade.ATTACK_DAMAGE

# -------- UI NODES --------
@onready var _score_label: Label = $UI/ScoreLabel
@onready var _level_label: Label = $UI/LevelLabel
@onready var _health_label: Label = $UI/HealthLabel

@onready var _level_panel: Panel = $UI/LevelUpPanel
@onready var _btn_speed: Button = $UI/LevelUpPanel/Layout/ButtonSpeed
@onready var _btn_damage: Button = $UI/LevelUpPanel/Layout/ButtonDamage
@onready var _levelup_label: Label = $UI/LevelUpPanel/Layout/LevelUpLabel

# -------- GAME OVER UI --------
@onready var _game_over_panel: Control = $UI/GameOverPanel
@onready var _game_over_title: Label = $UI/GameOverPanel/TitleLabel
@onready var _game_over_repeat_btn: Button = $UI/GameOverPanel/RepeatButton


func _ready() -> void:
	add_to_group("main")  # pro případné budoucí použití

	# Level-up panel na začátku schovat
	_level_panel.visible = false

	# Game Over panel na začátku schovat
	_game_over_panel.visible = false

	# Signály z tlačítek level-up
	_btn_speed.pressed.connect(_on_button_speed_pressed)
	_btn_damage.pressed.connect(_on_button_damage_pressed)

	# Signál z tlačítka "Repeat?"
	_game_over_repeat_btn.pressed.connect(_on_game_over_repeat_pressed)

	_update_score_label()
	_update_level_label()
	# HealthLabel nastaví Player přes update_player_health()
	
	var ps := preload("res://Scenes/damage_numbers.tscn")
	var dn := ps.instantiate()
	add_child(dn)
	dn.global_position = Vector2(400, 300)  # někde doprostřed
	dn.show_number(99)

# ====================================================================
#   SCORE API (volá Enemy)
# ====================================================================

func add_score(amount: int) -> void:
	score += amount
	_update_score_label()


func _update_score_label() -> void:
	_score_label.text = "Score: %d" % score


# ====================================================================
#   XP / LEVEL API (volá XPCrystal)
# ====================================================================

func add_xp(amount: int) -> void:
	xp += amount

	while xp >= xp_to_next_level:
		xp -= xp_to_next_level
		level += 1
		xp_to_next_level = int(float(xp_to_next_level) * xp_level_multiplier)
		_show_stats_levelup()

	_update_level_label()


func _update_level_label() -> void:
	_level_label.text = "Level: %d  XP: %d/%d" % [level, xp, xp_to_next_level]


# ====================================================================
#   HEALTH API (volá Player)
# ====================================================================

func update_player_health(hp: int, max_hp: int) -> void:
	_health_label.text = "HP: %d / %d" % [hp, max_hp]


# ====================================================================
#   LEVEL-UP PANEL
# ====================================================================

func _open_levelup_panel() -> void:
	_level_panel.visible = true
	get_tree().paused = true   # pauza hry během výběru


func _close_levelup_panel() -> void:
	_level_panel.visible = false
	get_tree().paused = false  # odpauzujeme hru


func _show_stats_levelup() -> void:
	_levelup_label.text = "LEVEL UP! Vyber upgrade statů:"

	var all_stats := [
		StatUpgrade.ATTACK_SPEED,
		StatUpgrade.ATTACK_DAMAGE,
		StatUpgrade.MAX_HEALTH,
		StatUpgrade.BULLET_SPEED,
		StatUpgrade.MOVEMENT_SPEED,
		StatUpgrade.PICKUP_RADIUS
	]
	all_stats.shuffle()
	_stat_choice_btn1 = all_stats[0]
	_stat_choice_btn2 = all_stats[1]

	_btn_speed.text = _get_stat_label(_stat_choice_btn1)
	_btn_damage.text = _get_stat_label(_stat_choice_btn2)

	_open_levelup_panel()


func _get_stat_label(stat: int) -> String:
	match stat:
		StatUpgrade.ATTACK_SPEED:
			return "Rychlost střelby +"
		StatUpgrade.ATTACK_DAMAGE:
			return "Poškození střel +"
		StatUpgrade.MAX_HEALTH:
			return "Maximální zdraví +"
		StatUpgrade.BULLET_SPEED:
			return "Rychlost projektilů +"
		StatUpgrade.MOVEMENT_SPEED:
			return "Rychlost pohybu +"
		StatUpgrade.PICKUP_RADIUS:
			return "Dosah sbírání XP +"
		_:
			return "Upgrade"


func _apply_stat_upgrade(player: Node, stat: int) -> void:
	match stat:
		StatUpgrade.ATTACK_SPEED:
			if player.has_method("upgrade_attack_speed"):
				player.upgrade_attack_speed()
		StatUpgrade.ATTACK_DAMAGE:
			if player.has_method("upgrade_attack_damage"):
				player.upgrade_attack_damage()
		StatUpgrade.MAX_HEALTH:
			if player.has_method("upgrade_max_health"):
				player.upgrade_max_health()
		StatUpgrade.BULLET_SPEED:
			if player.has_method("upgrade_bullet_speed"):
				player.upgrade_bullet_speed()
		StatUpgrade.MOVEMENT_SPEED:
			if player.has_method("upgrade_movement_speed"):
				player.upgrade_movement_speed()
		StatUpgrade.PICKUP_RADIUS:
			if player.has_method("upgrade_pickup_radius"):
				player.upgrade_pickup_radius()


# -------- REAKCE NA BUTTONY LEVEL-UP --------

func _on_button_speed_pressed() -> void:
	var player := $Player
	_apply_stat_upgrade(player, _stat_choice_btn1)
	_close_levelup_panel()


func _on_button_damage_pressed() -> void:
	var player := $Player
	_apply_stat_upgrade(player, _stat_choice_btn2)
	_close_levelup_panel()


# ====================================================================
#   GAME OVER LOGIKA
# ====================================================================

func show_game_over() -> void:
	# Volá Player._die() -> world.show_game_over()
	_game_over_title.text = "You died"
	_game_over_panel.visible = true
	get_tree().paused = true


func _on_game_over_repeat_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func get_xp_multiplier() -> float:
	# Jednoduchý příklad: víc XP s levelem
	var mult := base_xp_multiplier + xp_mult_per_level * float(level - 1)
	return max(mult, 0.0)
