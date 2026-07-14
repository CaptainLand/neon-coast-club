extends Interactable
var powered:=false
var channel:=0

func _ready() -> void:
	interaction_name = "CRT 电视"
	result_message = "蒸汽波录像频道"
	_update_screen()

func interact(player: Node) -> void:
	if not powered:
		powered=true
	else:
		channel=(channel+1)%3
	_update_screen()
	var main:=get_tree().current_scene
	if main and main.has_method("show_toast"): main.show_toast("CRT 播放中 · VAPOR TAPE %02d"%(channel+1))

func _update_screen() -> void:
	var screen:=get_node_or_null("Screen") as MeshInstance3D
	var label := get_node_or_null("ScreenLabel") as Label3D
	if label:
		label.visible=not powered
		label.text="CHANNEL 88\nPRESS E TO PLAY"
	if screen and screen.material_override is ShaderMaterial:
		var mat:=screen.material_override as ShaderMaterial
		mat.set_shader_parameter("powered",1.0 if powered else 0.0)
		mat.set_shader_parameter("channel",float(channel))
