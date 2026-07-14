extends Interactable

const STICKERS=[
	{"id":"sticker_common","name":"SealLandX 普通贴纸","label":"普通 · 高级","texture":"res://assets/stickers/sealandx_common.png","color":Color("4b69ff"),"weight":0.80128,"foil":0.02},
	{"id":"sticker_sparkle","name":"SealLandX 闪亮贴纸","label":"闪亮 · 卓越","texture":"res://assets/stickers/sealandx_sparkle.png","color":Color("8847ff"),"weight":0.16026,"foil":0.18},
	{"id":"sticker_holographic","name":"SealLandX 全息贴纸","label":"全息 · 奇异","texture":"res://assets/stickers/sealandx_holographic.png","color":Color("d32ce6"),"weight":0.03205,"foil":0.48},
	{"id":"sticker_gold","name":"SealLandX 金色贴纸","label":"金贴 · 非凡","texture":"res://assets/stickers/sealandx_gold.png","color":Color("ffd700"),"weight":0.00641,"foil":0.62}
]

var busy:=false
var rng:=RandomNumberGenerator.new()

func _ready() -> void:
	interaction_name="SealLandX 贴纸胶囊机"
	result_message=""
	rng.randomize()

func interact(player: Node) -> void:
	if busy:
		var main:=get_tree().current_scene
		if main and main.has_method("show_toast"): main.show_toast("胶囊机正在运转…")
		return
	_open_capsule(player)

func _open_capsule(player: Node) -> void:
	busy=true
	var main:=get_tree().current_scene
	var knob:Node3D=$KnobPivot
	var rotor:Node3D=$Rotor
	var output:Node3D=$OutputCapsule
	var top:Node3D=$OutputCapsule/Top
	var bottom:Node3D=$OutputCapsule/Bottom
	var label:Label3D=$ResultLabel
	var light:OmniLight3D=$RarityLight
	label.text="CAPSULE LINK\nROLLING..."
	if main and main.has_method("show_capsule_stage"): main.show_capsule_stage("胶囊仓加速中…")
	var spin:=create_tween().set_parallel(true)
	spin.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	spin.tween_property(knob,"rotation_degrees:z",knob.rotation_degrees.z+720.0,1.25)
	spin.tween_property(rotor,"rotation_degrees:z",rotor.rotation_degrees.z+1080.0,1.55)
	spin.tween_property(self,"scale",Vector3(1.025,0.985,1.025),0.18)
	await spin.finished
	var settle:=create_tween()
	settle.tween_property(self,"scale",Vector3.ONE,0.18).set_trans(Tween.TRANS_ELASTIC)
	await settle.finished
	var item:Dictionary=_roll_sticker()
	var rarity_color:Color=item["color"]
	light.light_color=rarity_color; light.light_energy=5.5
	label.modulate=rarity_color; label.text="CAPSULE READY\n"+str(item["label"])
	output.visible=true; output.scale=Vector3.ZERO; output.position=Vector3(0,1.25,-1.10)
	top.position=Vector3(0,0.12,0); bottom.position=Vector3(0,-0.12,0)
	if main and main.has_method("show_capsule_stage"): main.show_capsule_stage("胶囊掉落…")
	var drop:=create_tween().set_parallel(true)
	drop.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	drop.tween_property(output,"scale",Vector3.ONE,0.42)
	drop.tween_property(output,"position:y",0.48,0.62)
	await drop.finished
	var open:=create_tween().set_parallel(true)
	open.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open.tween_property(top,"position",Vector3(-0.18,0.48,0),0.42)
	open.tween_property(top,"rotation_degrees:z",-32.0,0.42)
	open.tween_property(bottom,"position",Vector3(0.18,-0.34,0),0.42)
	open.tween_property(bottom,"rotation_degrees:z",28.0,0.42)
	await open.finished
	var inventory_item={"id":item["id"],"name":item["name"],"shape":"sticker","texture":item["texture"],"rarity":item["label"],"color":rarity_color,"foil":item["foil"],"stackable":true,"count":1}
	var stored:bool=false
	if player.has_method("add_inventory_item"): stored=bool(player.add_inventory_item(inventory_item))
	if stored and main and main.has_method("show_capsule_result"): main.show_capsule_result(inventory_item)
	await get_tree().create_timer(1.35).timeout
	output.visible=false; top.rotation_degrees=Vector3.ZERO; bottom.rotation_degrees=Vector3.ZERO
	light.light_energy=1.2; label.modulate=Color("70dbe3"); label.text="SEALANDX\nPRESS E"
	busy=false

func _roll_sticker() -> Dictionary:
	var roll:=rng.randf()
	var cumulative:=0.0
	for item in STICKERS:
		cumulative+=float(item["weight"])
		if roll<=cumulative: return item.duplicate(true)
	return STICKERS[0].duplicate(true)
