extends Node
signal interaction_performed(target: Node)
func perform(target: Node, player: Node) -> void:
	if target and target.has_method("interact"):
		target.interact(player)
		interaction_performed.emit(target)

