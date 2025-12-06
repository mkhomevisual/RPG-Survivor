extends "res://Scripts/enemy_base.gd"

# EnemyTank.gd
#
# A heavily armoured melee enemy.  This variant has high health and
# slower movement but otherwise behaves like a basic ghost.  It can be
# further customised in the inspector.

# This Tank variant inherits all of its base stats from EnemyBase.
# To customise its behaviour (e.g. higher health or slower speed),
# adjust the exported variables in the Inspector when editing the
# Tank scene rather than redeclaring them here.  Redeclaring
# exported variables that already exist in the parent class will
# cause parse errors in Godot.

func _update_enemy(_delta: float) -> void:
	# Tank has no ranged attacks; default behaviour is enough.
	pass
