extends Node3D

@export var speed := 0.34
var phase := 0.0

func _process(delta: float) -> void:
	phase += delta
	rotate_y(speed * delta)
	for i in range(get_child_count()):
		var light := get_child(i) as SpotLight3D
		if light:
			light.light_energy = 8.5 + sin(phase * 2.1 + i * 0.73) * 2.0
			light.light_color = Color.from_hsv(fmod(0.53 + i * 0.073 + phase * 0.012, 1.0), 0.62, 1.0)
