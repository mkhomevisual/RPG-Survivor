# res://Scenes/damage_number.gd
extends Node2D

@export var float_distance: float = 24.0      # Jak vysoko text vyletí
@export var duration: float = 0.8             # Jak dlouho animace trvá
@export var start_color: Color = Color(1, 1, 1, 1)  # Počáteční barva (bílá, plná alfa)
@export var end_color: Color = Color(1, 1, 1, 0)    # Konečná barva (průhledná)

@onready var _label: Label = $Label

func show_number(value: int) -> void:
	# Nastavíme text na hodnotu damage
	_label.text = str(value)
	# Nastavíme počáteční barvu (pro jistotu)
	_label.modulate = start_color

	# Vytvoříme tween pro plynulý pohyb a fade
	var t := create_tween()

	# Pohyb nahoru – z aktuální pozice o float_distance výš během 'duration'
	t.tween_property(self, "position:y", position.y - float_distance, duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)

	# Paralelně vyblednutí textu do end_color během stejného času
	t.parallel().tween_property(_label, "modulate", end_color, duration)

	# Po skončení animace node smažeme
	t.finished.connect(func(): queue_free())
