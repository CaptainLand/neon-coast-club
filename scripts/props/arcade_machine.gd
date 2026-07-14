extends Interactable
const RHYTHM_UI_SCENE := preload("res://scenes/rhythm/rhythm_ui.tscn")
var active := false
func _ready() -> void:
	interaction_name = "4K 街机"
	result_message = "4K ORBIT · FREE PLAY"
func interact(player: Node) -> void:
	active = not active
	var label := get_node_or_null("ScreenLabel") as Label3D
	if label: label.text = "4K ORBIT\nFREE PLAY" if active else "4K ORBIT\nPRESS START"
	var screen := get_node_or_null("Screen") as MeshInstance3D
	if screen and screen.material_override: screen.material_override.emission_energy_multiplier = 4.5 if active else 2.2
	var main := get_tree().current_scene
	var rhythm_ui := main.get_node_or_null("RhythmLayer/RhythmUI")
	if rhythm_ui == null:
		var layer := main.get_node_or_null("RhythmLayer") as CanvasLayer
		if layer == null:
			layer = CanvasLayer.new()
			layer.name = "RhythmLayer"
			layer.layer = 50
			main.add_child(layer)
		rhythm_ui = RHYTHM_UI_SCENE.instantiate()
		rhythm_ui.name = "RhythmUI"
		layer.add_child(rhythm_ui)
	if rhythm_ui and rhythm_ui.has_method("open_song_select"):
		rhythm_ui.open_song_select()
	else:
		push_error("RhythmUI is unavailable at RhythmLayer/RhythmUI")
		if main and main.has_method("show_toast"):
			main.show_toast("RhythmUI 加载失败，请查看调试器错误")
	super.interact(player)
