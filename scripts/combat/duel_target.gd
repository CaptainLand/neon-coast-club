extends CharacterBody3D

@export var max_health:=100
@export var move_speed:=3.8
var health:=100
var armor:=100
var spawn_transform:Transform3D
var target:CharacterBody3D
var fire_cooldown:=0.8
var strafe_sign:=1.0
var strafe_timer:=1.3
var burst_left:=0
var dying:=false

func _ready() -> void:
	health=max_health; armor=100; spawn_transform=global_transform
	var main:=get_tree().current_scene
	if main: target=main.get_node_or_null("Player") as CharacterBody3D

func _physics_process(delta:float) -> void:
	var main:=get_tree().current_scene
	if not target or not main or not bool(main.get("round_active")):
		velocity=velocity.move_toward(Vector3.ZERO,delta*10.0); move_and_slide(); return
	var flat_delta:=target.global_position-global_position; flat_delta.y=0.0
	var distance:=flat_delta.length()
	if distance<0.1: return
	look_at(Vector3(target.global_position.x,global_position.y,target.global_position.z),Vector3.UP)
	strafe_timer-=delta
	if strafe_timer<=0.0: strafe_sign*=-1.0; strafe_timer=randf_range(0.8,1.8)
	var forward:=flat_delta.normalized(); var right:=Vector3(-forward.z,0,forward.x)
	var desired:=right*strafe_sign*0.72
	if distance>13.0: desired+=forward
	elif distance<7.0: desired-=forward
	desired=desired.normalized()*move_speed
	velocity.x=move_toward(velocity.x,desired.x,delta*9.0); velocity.z=move_toward(velocity.z,desired.z,delta*9.0)
	if not is_on_floor(): velocity.y-=18.0*delta
	else: velocity.y=-0.2
	move_and_slide()
	fire_cooldown-=delta
	if fire_cooldown<=0.0 and _has_line_of_sight(): _fire(distance)

func _has_line_of_sight() -> bool:
	var from:=global_position+Vector3.UP*1.55; var to:=target.global_position+Vector3.UP*1.35
	var query:=PhysicsRayQueryParameters3D.create(from,to,1,[get_rid()]); query.collide_with_areas=true
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider")==target

func _fire(distance:float) -> void:
	burst_left=burst_left-1 if burst_left>0 else randi_range(3,6)
	fire_cooldown=0.115 if burst_left>0 else randf_range(0.55,1.0)
	var from:=global_position+Vector3.UP*1.55
	var accuracy:=0.055+clampf(distance/32.0,0.0,1.0)*0.035
	var to:=target.global_position+Vector3.UP*1.28+Vector3(randf_range(-accuracy,accuracy)*distance,randf_range(-accuracy,accuracy)*distance,randf_range(-accuracy,accuracy)*distance)
	var query:=PhysicsRayQueryParameters3D.create(from,to,1,[get_rid()]); query.collide_with_areas=true
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	var main:=get_tree().current_scene
	if main and main.has_method("spawn_muzzle_effect"): main.spawn_muzzle_effect(from+(to-from).normalized()*0.65)
	if hit.get("collider")==target:
		var falloff:=lerpf(1.0,0.62,clampf((distance-14.0)/45.0,0.0,1.0))
		target.take_damage(22.0*falloff,self)
		if main and main.has_method("spawn_blood_splatter"): main.spawn_blood_splatter(hit.get("position",target.global_position+Vector3.UP),hit.get("normal",Vector3.UP))

func take_damage(amount:float,attacker:Node=null) -> void:
	_apply_damage(amount,attacker)

func take_damage_at(amount:float,hit_point:Vector3,attacker:Node=null) -> void:
	var local_y:=to_local(hit_point).y
	var multiplier:=4.0 if local_y>1.72 else (0.75 if local_y<0.92 else 1.0)
	_apply_damage(amount*multiplier,attacker)

func _apply_damage(amount:float,_attacker:Node=null) -> void:
	var absorbed:=minf(float(armor),amount*0.45); armor=maxi(0,armor-int(round(absorbed*0.55))); health=clampi(health-int(round(amount-absorbed)),0,max_health)
	var main:=get_tree().current_scene
	if main and main.has_method("show_toast"): main.show_toast("BOT HP %d · 护甲 %d"%[health,armor])
	if health<=0 and not dying:
		dying=true; collision_layer=0; velocity=Vector3.ZERO
		var fall:=create_tween(); fall.set_parallel(true); fall.tween_property(self,"rotation:z",deg_to_rad(-88.0),0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN); fall.tween_property(self,"position:y",global_position.y-0.28,0.58)
		if main and main.has_method("on_combatant_defeated"): main.on_combatant_defeated("opponent")

func reset_for_round() -> void:
	health=max_health; armor=100; global_transform=spawn_transform; velocity=Vector3.ZERO; visible=true; collision_layer=1; fire_cooldown=0.8; dying=false
