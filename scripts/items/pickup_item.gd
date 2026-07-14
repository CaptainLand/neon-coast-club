class_name PickupItem
extends Interactable

@export var item_id := "aero_orb"
@export var item_display_name := "Aero 光球"
@export var item_shape := "orb"
@export var item_color := Color("9ee7e2")
var bob_time := 0.0
var base_y := 0.0

func _ready() -> void:
	interaction_name = item_display_name
	result_message = "已拾取 · " + item_display_name
	base_y = position.y

func _process(delta: float) -> void:
	bob_time += delta
	rotation.y += delta * 0.55
	position.y = base_y + sin(bob_time * 1.8) * 0.055

func interact(player: Node) -> void:
	var data := {"id":item_id, "name":item_display_name, "shape":item_shape, "color":item_color}
	if player.has_method("add_inventory_item") and player.add_inventory_item(data):
		super.interact(player)
		queue_free()

func hit(_player: Node) -> void:
	var tween := create_tween()
	tween.tween_property(self,"rotation:z",rotation.z + 0.28,0.07)
	tween.tween_property(self,"rotation:z",rotation.z,0.12)

