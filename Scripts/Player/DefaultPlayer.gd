extends PlayerBase

@export var loadout_resource: PlayerLoadout = preload("res://Resources/PlayerLoadout/Default.tres")

var _skill_map := {
        "skill_q": 0,
        "skill_e": 1,
        "skill_r": 2
}


func _ready() -> void:
        if loadout == null:
                loadout = loadout_resource
        super._ready()


func _physics_process(delta: float) -> void:
        super._physics_process(delta)
        _handle_skill_inputs()


func _handle_skill_inputs() -> void:
        for action in _skill_map.keys():
                if Input.is_action_just_pressed(action):
                        trigger_skill(_skill_map[action], get_global_mouse_position())
