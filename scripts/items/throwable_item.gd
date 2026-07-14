extends RigidBody3D

var item_data:Dictionary={}
var interaction_name:="可投掷物"

func _ready() -> void:
	interaction_name=str(item_data.get("name","可投掷物"))

func interact(player:Node) -> void:
	if item_data.is_empty(): return
	if player.has_method("add_inventory_item") and player.add_inventory_item(item_data.duplicate(true)):
		var main:=get_tree().current_scene
		if main and main.has_method("show_toast"): main.show_toast("已拿起 · "+interaction_name+"（右键投掷）")
		queue_free()
