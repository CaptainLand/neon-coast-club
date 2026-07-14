extends Node3D
@export var speed := 0.18
func _process(delta: float) -> void: rotate_y(speed * delta)

