class_name Interactable
extends StaticBody3D

@export var interaction_name := "互动对象"
@export_multiline var result_message := "已互动"

func interact(_player: Node) -> void:
	var main := get_tree().current_scene
	if main and main.has_method("show_toast"):
		main.show_toast(result_message)

