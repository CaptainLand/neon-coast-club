extends Interactable
var show_mode := false
func _ready() -> void:
	interaction_name = "主舞台"
	result_message = "舞台已切换为联机演出模式"
func interact(player: Node) -> void:
	show_mode = not show_mode
	var label := get_node_or_null("StageLabel") as Label3D
	if label: label.text = "NEON COAST\nLIVE LINK MODE" if show_mode else "NEON COAST\nCOMMUNITY RHYTHM STAGE"
	for child in get_children():
		if child is OmniLight3D: child.light_energy = 5.0 if show_mode else 2.5
	super.interact(player)

