extends Area3D

@export var damage_multiplier:=1.0
@onready var combatant:=get_parent()

func take_damage_at(amount:float,_point:Vector3,attacker:Node=null) -> void:
	if combatant and combatant.has_method("take_damage"): combatant.take_damage(amount*damage_multiplier,attacker)

func take_damage(amount:float,attacker:Node=null) -> void:
	if combatant and combatant.has_method("take_damage"): combatant.take_damage(amount*damage_multiplier,attacker)
