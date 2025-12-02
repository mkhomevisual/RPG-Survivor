extends Node
class_name SkillBase

@export var cooldown: float = 1.0
@export var icon_path: String = ""
@export var cast_range: float = 0.0

signal cooldown_changed(slot_skill: SkillBase, cooldown_left: float, cooldown_total: float, icon: String)

var _cooldown_left: float = 0.0


func _ready() -> void:
        _emit_cooldown_changed()


func process_cooldown(delta: float) -> void:
        if _cooldown_left <= 0.0:
                return

        _cooldown_left = maxf(0.0, _cooldown_left - delta)
        _emit_cooldown_changed()


func can_cast(_player_state: Dictionary) -> bool:
        return _cooldown_left <= 0.0


func cast(_player_state: Dictionary) -> bool:
        return false


func try_cast(player_state: Dictionary) -> bool:
        if not can_cast(player_state):
                return false

        var success := cast(player_state)
        if success:
                _cooldown_left = cooldown
                _emit_cooldown_changed()
        return success


func _emit_cooldown_changed() -> void:
        cooldown_changed.emit(self, _cooldown_left, cooldown, icon_path)
