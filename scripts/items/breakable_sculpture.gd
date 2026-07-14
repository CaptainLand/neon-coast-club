extends StaticBody3D

@export var sculpture_name := "Aero 记忆泡泡"
@export var health := 3
var hit_busy := false

func hit(_player: Node) -> void:
	if hit_busy: return
	hit_busy = true
	health -= 1
	var main := get_tree().current_scene
	if main and main.has_method("show_toast"):
		main.show_toast("%s · %s" % [sculpture_name, "碎裂" if health <= 0 else "受到冲击 %d/3" % (3-health)])
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"scale",Vector3(1.18,0.82,1.18),0.08)
	if health <= 0:
		tween.tween_property(self,"scale",Vector3.ZERO,0.18)
		tween.finished.connect(queue_free)
	else:
		tween.tween_property(self,"scale",Vector3.ONE,0.16)
		tween.finished.connect(func(): hit_busy = false)
