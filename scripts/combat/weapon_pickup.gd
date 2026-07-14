extends RigidBody3D

var weapon_slot:=-1
var weapon_ammo:=0
var weapon_reserve:=0
var interaction_name:="地面武器"

func interact(player:Node) -> void:
	if player.has_method("pickup_weapon") and player.pickup_weapon(weapon_slot,weapon_ammo,weapon_reserve): queue_free()
