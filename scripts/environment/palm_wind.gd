extends Node3D
@export var phase := 0.0
func _process(delta: float) -> void:
	phase += delta
	rotation.z = sin(phase * 0.75) * 0.018

