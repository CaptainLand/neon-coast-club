extends CharacterBody3D

signal interaction_changed(text: String)
signal pause_requested
signal inventory_changed(items: Array, selected_slot: int)
signal health_changed(current: int, maximum: int)

@export var walk_speed := 4.5
@export var run_speed := 7.5
@export var mouse_sensitivity := 0.0022
@export var gravity := 18.0
@export var acceleration := 12.0
@export var deceleration := 16.0
@export var head_bob_strength := 0.025
@export var head_bob_frequency := 7.0
@export var jump_velocity := 6.4
@export var max_inventory_slots := 5
@export var fly_speed := 10.5

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/Camera3D/InteractionRayCast3D
@onready var hand_pivot: Node3D = $Head/Camera3D/HandPivot
@onready var held_item_root: Node3D = $Head/Camera3D/HandPivot/HeldItemRoot
@onready var first_person_arms: Node3D = $Head/Camera3D/HandPivot/FirstPersonArms
@onready var weapon_root: Node3D = $Head/Camera3D/WeaponRoot
@onready var weapon_model: Node3D = $Head/Camera3D/WeaponRoot/WeaponModel
@onready var muzzle_flash: OmniLight3D = $Head/Camera3D/WeaponRoot/MuzzleFlash
@onready var weapon_audio: AudioStreamPlayer3D = $Head/Camera3D/WeaponRoot/WeaponAudio
var controls_enabled := false
var spawn_transform: Transform3D
var bob_time := 0.0
var last_target: Object
var inventory: Array[Dictionary] = []
var selected_slot := 0
var punch_busy := false
var hand_rest_position: Vector3
var hand_rest_rotation: Vector3
var footstep_distance := 0.0
var fly_mode:=false
var speed_blend:=0.0
var landing_impulse:=0.0
var was_on_floor:=false
var weapon_index:=-1
var weapon_ammo:=0
var weapon_reserve:=0
var weapon_cooldown:=0.0
var weapon_reloading:=false
var weapon_rest_position:=Vector3.ZERO
var weapon_aiming:=false
var weapon_switching:=false
var weapon_sway:=Vector2.ZERO
var health:=100
var max_health:=100
var weapon_owned:=[true,true,true,true,true]
const ACTIVE_WEAPON_COUNT:=5
var weapon_ammo_slots:Array[int]=[]
var weapon_reserve_slots:Array[int]=[]
var spray_heat:=0.0
var freeze_movement:=false
var armor:=100
var competitive_mode:=true
var crouching:=false
var auto_fire_audio_active:=false
var fire_audio_pool:Array[AudioStreamPlayer3D]=[]
var fire_audio_cursor:=0

const WEAPONS=[
	{"name":"AR-1 步枪","scene":"res://assets/models/weapons/quaternius/FBX/AssaultRifle_1.fbx","sound":"res://assets/audio/weapons/rifle_fire_single.wav","mag":30,"reserve":90,"rate":0.10,"damage":34.0,"automatic":true,"scale":0.25,"rotation":Vector3(0,deg_to_rad(90),0),"model_position":Vector3(-0.22,0.18,0.18),"muzzle_z":-0.78,"style":"rifle","recoil":0.018,"reload_time":2.65,"falloff_start":24.0,"falloff_end":85.0,"min_damage":0.72},
	{"name":"SMG-2 冲锋枪","scene":"res://assets/models/weapons/quaternius/FBX/SubmachineGun_2.fbx","sound":"res://assets/audio/weapons/rifle_fire_single.wav","mag":32,"reserve":96,"rate":0.075,"damage":24.0,"automatic":true,"scale":0.20,"rotation":Vector3(0,deg_to_rad(90),0),"model_position":Vector3(-0.18,0.18,0.15),"muzzle_z":-0.68,"style":"rifle","recoil":0.012,"reload_time":2.35,"falloff_start":14.0,"falloff_end":58.0,"min_damage":0.55},
	{"name":"SG-1 霰弹枪","scene":"res://assets/models/weapons/quaternius/FBX/Shotgun_1.fbx","sound":"res://assets/audio/weapons/rifle_fire_single.wav","mag":8,"reserve":40,"rate":0.78,"damage":82.0,"automatic":false,"scale":0.16,"rotation":Vector3(0,deg_to_rad(90),0),"model_position":Vector3(-0.20,0.15,0.18),"muzzle_z":-0.76,"style":"shotgun","recoil":0.052,"reload_time":3.4,"falloff_start":5.0,"falloff_end":24.0,"min_damage":0.22},
	{"name":"R-2 手枪","scene":"res://assets/models/weapons/quaternius/FBX/Revolver_2.fbx","sound":"res://assets/audio/weapons/pistol_fire_single.wav","mag":12,"reserve":48,"rate":0.24,"damage":38.0,"automatic":false,"scale":0.40,"rotation":Vector3(0,deg_to_rad(90),0),"model_position":Vector3(-0.17,0.12,0.13),"muzzle_z":-0.50,"style":"pistol","recoil":0.030,"reload_time":2.15,"falloff_start":18.0,"falloff_end":70.0,"min_damage":0.62},
	{"name":"战术刀","scene":"res://assets/models/weapons/quaternius/FBX/Accessories/Bayonet.fbx","sound":"res://assets/audio/impact/punch.ogg","mag":-1,"reserve":-1,"rate":0.48,"damage":55.0,"automatic":false,"scale":0.42,"rotation":Vector3(0,deg_to_rad(90),deg_to_rad(-18)),"model_position":Vector3(-0.10,0.02,0.08),"muzzle_z":-0.45,"style":"knife","recoil":0.0,"reload_time":0.0},
	{"name":"CC0 FPS 步枪","scene":"res://assets/models/weapons/cc0_fps_rifle.glb","sound":"res://assets/audio/weapons/rifle_fire_single.wav","mag":30,"reserve":90,"rate":0.095,"damage":34.0,"automatic":true,"scale":0.11,"rotation":Vector3.ZERO,"model_position":Vector3(-0.03,0.13,0.12),"muzzle_z":-0.72},
	{"name":"PPQ 手枪","scene":"res://assets/models/weapons/cc0_pistol.fbx","sound":"res://assets/audio/weapons/pistol_fire_single.wav","mag":15,"reserve":45,"rate":0.22,"damage":42.0,"automatic":false,"scale":2.45,"rotation":Vector3(0,deg_to_rad(180),0),"model_position":Vector3(-0.02,-0.04,0.08),"muzzle_z":-0.38}
]

func _ready() -> void:
	if NetworkSession.dedicated_server:
		set_process(false)
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	spawn_transform = global_transform
	hand_rest_position = hand_pivot.position
	hand_rest_rotation = hand_pivot.rotation
	weapon_rest_position=weapon_root.position; weapon_root.visible=false
	weapon_audio.max_polyphony=5; weapon_audio.volume_db=-6.0
	for i in range(6):
		var shot_audio:=AudioStreamPlayer3D.new(); shot_audio.name="GunshotVoice%d"%i; shot_audio.bus="ClubReverb"; shot_audio.max_distance=52.0; shot_audio.volume_db=-6.0; weapon_root.add_child(shot_audio); fire_audio_pool.append(shot_audio)
	for i in range(ACTIVE_WEAPON_COUNT): weapon_ammo_slots.append(int(WEAPONS[i].mag)); weapon_reserve_slots.append(int(WEAPONS[i].reserve))
	health_changed.emit(health,max_health)
	_equip_weapon.call_deferred(0)
	if OS.has_environment("NCC_WEAPON_TEST") or "--weapon-test" in OS.get_cmdline_user_args(): _run_weapon_test.call_deferred()

func _run_weapon_test() -> void:
	for i in range(WEAPONS.size()):
		await _cycle_weapon(); _try_fire_weapon(); await get_tree().create_timer(0.16).timeout

func set_controls_enabled(value: bool) -> void:
	controls_enabled = value
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE

func reset_to_spawn() -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	head.rotation = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and controls_enabled:
		pause_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and controls_enabled and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed and controls_enabled and inventory.size()>0:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:
			select_inventory_slot(wrapi(selected_slot-1,0,inventory.size()))
			_play_inventory_scroll_sound()
			get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			select_inventory_slot(wrapi(selected_slot+1,0,inventory.size()))
			_play_inventory_scroll_sound()
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var aim_multiplier:=1.0
		rotate_y(-event.relative.x * mouse_sensitivity*aim_multiplier)
		head.rotate_x(-event.relative.y * mouse_sensitivity*aim_multiplier)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-82.0), deg_to_rad(82.0))
		if weapon_index>=0: weapon_sway+=Vector2(event.relative.x,event.relative.y)*0.00042
	if event.is_action_pressed("interact") and controls_enabled:
		var target := _get_interactable()
		if target and target.has_method("interact"):
			target.interact(self)
	if event.is_action_pressed("attack") and controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if weapon_index>=0:
			if not bool(WEAPONS[weapon_index].automatic): _try_fire_weapon()
		else: _punch()
	if event.is_action_pressed("acquire_weapon") and controls_enabled:
		_cycle_weapon()
	if event.is_action_pressed("reload_weapon") and controls_enabled and weapon_index>=0:
		_reload_weapon()
	if event.is_action_pressed("place_sticker") and controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if weapon_index<0: _use_selected_item()
	if event.is_action_pressed("drop_weapon") and controls_enabled: _drop_current_weapon()
	for i in range(max_inventory_slots):
		if event.is_action_pressed("slot_%d" % (i + 1)):
			_equip_weapon(i)

func _physics_process(delta: float) -> void:
	weapon_cooldown=maxf(0.0,weapon_cooldown-delta)
	spray_heat=maxf(0.0,spray_heat-delta*2.8)
	_update_weapon_pose(delta)
	if controls_enabled and weapon_index>=0 and bool(WEAPONS[weapon_index].automatic) and Input.is_action_pressed("attack") and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED: _try_fire_weapon()
	if controls_enabled and Input.is_action_just_pressed("toggle_fly") and not freeze_movement and not competitive_mode:
		fly_mode=not fly_mode; velocity=Vector3.ZERO
		var main:=get_tree().current_scene
		if main and main.has_method("show_toast"): main.show_toast("自由飞行："+("开启 · Space 上升 / Ctrl 下降" if fly_mode else "关闭"))
	if fly_mode:
		_fly_process(delta)
		move_and_slide(); _update_interaction(); return
	var grounded_before:=is_on_floor()
	if not grounded_before: velocity.y -= gravity * delta
	else: velocity.y = -0.2
	if controls_enabled and not freeze_movement:
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var direction := (global_transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
		crouching=Input.is_action_pressed("crouch")
		var silent_walking:=Input.is_action_pressed("walk_silent") or crouching
		var requested_speed:=2.0 if crouching else (2.35 if silent_walking else (run_speed if Input.is_action_pressed("sprint") else walk_speed))
		head.position.y=lerpf(head.position.y,1.14 if crouching else 1.62,1.0-exp(-delta*12.0))
		$CollisionShape3D.scale.y=lerpf($CollisionShape3D.scale.y,0.66 if crouching else 1.0,1.0-exp(-delta*14.0))
		$CollisionShape3D.position.y=lerpf($CollisionShape3D.position.y,0.58 if crouching else 0.875,1.0-exp(-delta*14.0))
		var target_speed:=requested_speed if direction.length_squared()>0.0 else 0.0
		var speed_response:=4.2 if target_speed>speed_blend else 7.5
		speed_blend=lerpf(speed_blend,target_speed,1.0-exp(-speed_response*delta))
		var target_velocity := direction * speed_blend
		var current_horizontal:=Vector2(velocity.x,velocity.z); var desired_horizontal:=Vector2(target_velocity.x,target_velocity.z)
		var turning:=current_horizontal.length()>0.4 and desired_horizontal.length()>0.4 and current_horizontal.normalized().dot(desired_horizontal.normalized())<0.45
		var rate := (acceleration*1.45 if turning else acceleration) if direction.length_squared() > 0.0 else deceleration
		velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)
		if weapon_index<0: camera.fov=lerpf(camera.fov,82.5 if Input.is_action_pressed("sprint") and direction.length_squared()>0.0 else 78.0,1.0-exp(-delta*5.0))
		head.rotation.z=lerpf(head.rotation.z,-input.x*0.026*(speed_blend/run_speed),1.0-exp(-delta*7.0))
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity
		if direction.length_squared() > 0.0 and is_on_floor():
			if first_person_arms and first_person_arms.has_method("set_moving"): first_person_arms.set_moving(true)
			bob_time += delta * head_bob_frequency * maxf(speed_blend,0.1) / walk_speed
			footstep_distance += Vector2(velocity.x,velocity.z).length()*delta
			if footstep_distance>=1.65:
				footstep_distance=0.0
				var main:=get_tree().current_scene
				if not silent_walking and main and main.has_method("play_footstep"): main.play_footstep(global_position)
			camera.position = Vector3(cos(bob_time * 0.5) * head_bob_strength * 0.5, sin(bob_time) * head_bob_strength, 0)
		else:
			camera.position = camera.position.lerp(Vector3.ZERO, delta * 8.0)
			if first_person_arms and first_person_arms.has_method("set_moving"): first_person_arms.set_moving(false)
		if (Input.is_action_just_pressed("reset_player") and weapon_index<0) or global_position.y < -5.0: reset_to_spawn()
	else:
		speed_blend=move_toward(speed_blend,0.0,delta*10.0)
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	move_and_slide()
	if not was_on_floor and is_on_floor():
		landing_impulse=clampf(absf(velocity.y)*0.012,0.025,0.11)
	was_on_floor=is_on_floor()
	if landing_impulse>0.001:
		camera.position.y-=landing_impulse; landing_impulse=move_toward(landing_impulse,0.0,delta*0.55)
	_update_interaction()

func _fly_process(delta:float) -> void:
	if not controls_enabled:
		velocity=velocity.lerp(Vector3.ZERO,1.0-exp(-delta*8.0)); return
	var input:=Input.get_vector("move_left","move_right","move_forward","move_backward")
	var vertical:=Input.get_action_strength("jump")-Input.get_action_strength("fly_down")
	var direction:=(global_transform.basis*Vector3(input.x,0,input.y))+Vector3.UP*vertical
	if direction.length_squared()>1.0: direction=direction.normalized()
	var target:=direction*fly_speed*(1.65 if Input.is_action_pressed("sprint") else 1.0)
	velocity=velocity.lerp(target,1.0-exp(-delta*5.5))
	if weapon_index<0 or not weapon_aiming: camera.fov=lerpf(camera.fov,84.0 if target.length()>fly_speed else 78.0,1.0-exp(-delta*4.0))
	head.rotation.z=lerpf(head.rotation.z,-input.x*0.035,1.0-exp(-delta*6.0))

func _get_interactable() -> Object:
	if not ray.is_colliding(): return null
	var hit := ray.get_collider()
	return hit if hit and hit.has_method("interact") else null

func _update_interaction() -> void:
	var target := _get_interactable()
	if target == last_target: return
	last_target = target
	interaction_changed.emit("按 E 互动 · " + str(target.interaction_name) if target else "")

func add_inventory_item(item: Dictionary) -> bool:
	if bool(item.get("stackable",false)):
		for i in range(inventory.size()):
			if inventory[i].get("id","")==item.get("id",""):
				inventory[i]["count"]=int(inventory[i].get("count",1))+int(item.get("count",1))
				selected_slot=i
				_refresh_held_item(); inventory_changed.emit(inventory,selected_slot)
				return true
	if inventory.size() >= max_inventory_slots:
		var main := get_tree().current_scene
		if main and main.has_method("show_toast"): main.show_toast("物品栏已满")
		return false
	var stored:=item.duplicate(true); stored["count"]=int(stored.get("count",1)); inventory.append(stored)
	if inventory.size() == 1: selected_slot = 0
	_refresh_held_item()
	inventory_changed.emit(inventory, selected_slot)
	return true

func select_inventory_slot(index: int) -> void:
	selected_slot = clampi(index, 0, max_inventory_slots - 1)
	_refresh_held_item()
	inventory_changed.emit(inventory, selected_slot)

func _play_inventory_scroll_sound() -> void:
	var main:=get_tree().current_scene
	if main and main.has_method("play_inventory_scroll"): main.play_inventory_scroll()

func _cycle_weapon() -> void:
	var next:=(weapon_index+1)%ACTIVE_WEAPON_COUNT
	for i in range(ACTIVE_WEAPON_COUNT):
		var candidate:=(next+i)%ACTIVE_WEAPON_COUNT
		if weapon_owned[candidate]: await _equip_weapon(candidate); return

func _equip_weapon(requested_index:int) -> void:
	if weapon_switching: return
	var previous:=weapon_index
	if previous>=0 and previous<ACTIVE_WEAPON_COUNT:
		weapon_ammo_slots[previous]=weapon_ammo; weapon_reserve_slots[previous]=weapon_reserve
	weapon_reloading=false
	weapon_audio.stop(); auto_fire_audio_active=false
	for voice in fire_audio_pool: voice.stop()
	weapon_switching=true; weapon_aiming=false
	weapon_index=clampi(requested_index,0,ACTIVE_WEAPON_COUNT-1)
	if not weapon_owned[weapon_index]: weapon_switching=false; return
	for child in weapon_model.get_children(): child.queue_free()
	if weapon_index<0:
		var lower:=create_tween(); lower.tween_property(weapon_root,"position",weapon_rest_position+Vector3(0,-0.42,0.20),0.18); await lower.finished; weapon_root.visible=false; weapon_root.position=weapon_rest_position; weapon_switching=false
		_update_weapon_hud("",0,0)
		var main:=get_tree().current_scene
		if main and main.has_method("show_toast"): main.show_toast("已收起武器 · 左键恢复挥击")
		return
	var data:Dictionary=WEAPONS[weapon_index]
	var main:=get_tree().current_scene
	if main and main.has_method("play_weapon_switch"): main.play_weapon_switch()
	weapon_audio.bus="ClubReverb"
	var packed:=load(str(data.scene)) as PackedScene
	if packed:
		var model:=packed.instantiate() as Node3D; model.name="EquippedWeapon"; model.scale=Vector3.ONE*float(data.scale); model.rotation=data.rotation; model.position=data.model_position; weapon_model.add_child(model)
		_hide_embedded_hands(model)
	muzzle_flash.position.z=float(data.muzzle_z)
	weapon_ammo=weapon_ammo_slots[weapon_index]; weapon_reserve=weapon_reserve_slots[weapon_index]; weapon_root.position=weapon_rest_position+Vector3(0,-0.42,0.18); weapon_root.rotation=Vector3(0.10,0,-0.12); weapon_root.visible=true; weapon_reloading=false
	var raise:=create_tween(); raise.set_parallel(true); raise.tween_property(weapon_root,"position",weapon_rest_position,0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT); raise.tween_property(weapon_root,"rotation",Vector3.ZERO,0.26); await raise.finished; weapon_switching=false
	_update_weapon_hud(str(data.name),weapon_ammo,weapon_reserve)
	main=get_tree().current_scene
	if main and main.has_method("update_weapon_slots"): main.update_weapon_slots(weapon_index,weapon_owned)
	if main and main.has_method("show_toast"): main.show_toast("已获取 · "+str(data.name)+"　R 换弹")

func _hide_embedded_hands(node:Node) -> void:
	if node is MeshInstance3D and "hand" in node.name.to_lower(): (node as MeshInstance3D).visible=false
	for child in node.get_children(): _hide_embedded_hands(child)

func _try_fire_weapon() -> void:
	if weapon_index<0 or weapon_cooldown>0.0 or weapon_reloading or weapon_switching: return
	var data:Dictionary=WEAPONS[weapon_index]
	var style:=_weapon_style(data)
	if style!="knife" and weapon_ammo<=0:
		_reload_weapon(); return
	if style!="knife": weapon_ammo-=1
	if style!="knife": weapon_ammo_slots[weapon_index]=weapon_ammo
	spray_heat=minf(spray_heat+float(data.get("spread_gain",0.13)),1.5)
	weapon_cooldown=float(data.rate)
	if style=="knife": weapon_audio.stop(); weapon_audio.stream=load(str(data.sound)); weapon_audio.pitch_scale=randf_range(0.96,1.035); weapon_audio.play()
	else: _play_gunshot(data)
	muzzle_flash.light_energy=0.0 if style=="knife" else 7.5
	var flash_tween:=create_tween(); flash_tween.tween_property(muzzle_flash,"light_energy",0.0,0.055)
	var recoil:=float(data.get("recoil",0.018 if style=="rifle" else 0.032)); head.rotation.x=clampf(head.rotation.x-recoil,deg_to_rad(-82.0),deg_to_rad(82.0))
	weapon_root.position=weapon_rest_position+Vector3(0,0,0.10)
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(weapon_root,"position",weapon_rest_position,0.11)
	_play_weapon_animation()
	if style=="pistol": _animate_pistol_slide()
	var interaction_range:=ray.target_position
	var move_penalty:=clampf(Vector2(velocity.x,velocity.z).length()/run_speed,0.0,1.0)*0.018
	var spread:=(0.002+spray_heat*0.012+move_penalty) if style!="knife" else 0.0
	var shot_distance:=2.35 if style=="knife" else 120.0
	ray.target_position=Vector3(randf_range(-spread,spread)*shot_distance,randf_range(-spread,spread)*shot_distance,-shot_distance); ray.force_raycast_update()
	var main:=get_tree().current_scene
	if main and main.has_method("send_network_shot"): main.send_network_shot(camera.global_position,(ray.to_global(ray.target_position)-camera.global_position).normalized(),weapon_index,float(data.damage))
	if style!="knife" and main and main.has_method("spawn_muzzle_effect"): main.spawn_muzzle_effect(camera.global_position-camera.global_basis.z*0.9)
	if style!="knife" and main and main.has_method("spawn_shell_casing"): main.spawn_shell_casing(camera.global_position+camera.global_basis.x*0.25-camera.global_basis.y*0.16,camera.global_basis.x)
	var shot_collided:=ray.is_colliding(); var collider:=ray.get_collider() if shot_collided else null; var hit_point:=ray.get_collision_point() if shot_collided else Vector3.ZERO; var hit_normal:=ray.get_collision_normal() if shot_collided else Vector3.UP
	ray.target_position=interaction_range; ray.force_raycast_update()
	if shot_collided:
		var hit_distance:=camera.global_position.distance_to(hit_point)
		var falloff_t:=clampf((hit_distance-float(data.get("falloff_start",25.0)))/maxf(0.1,float(data.get("falloff_end",100.0))-float(data.get("falloff_start",25.0))),0.0,1.0)
		var final_damage:=float(data.damage)*lerpf(1.0,float(data.get("min_damage",0.7)),falloff_t)
		if collider is RigidBody3D: (collider as RigidBody3D).apply_impulse(-camera.global_basis.z*float(data.damage)*0.11,hit_point-(collider as RigidBody3D).global_position)
		if collider and collider.has_method("take_damage_at"): collider.take_damage_at(final_damage,hit_point,self)
		elif collider and collider.has_method("take_damage"): collider.take_damage(final_damage,self)
		if collider and (collider.has_method("take_damage_at") or collider.has_method("take_damage")) and main and main.has_method("spawn_blood_splatter"): main.spawn_blood_splatter(hit_point,hit_normal)
		elif collider and collider.has_method("hit"): collider.hit(self)
		if main and main.has_method("spawn_bullet_impact"): main.spawn_bullet_impact(hit_point,hit_normal)
	_update_weapon_hud(str(data.name),weapon_ammo,weapon_reserve)

func _play_weapon_animation() -> void:
	if weapon_model.get_child_count()==0: return
	var players:=weapon_model.get_child(0).find_children("*","AnimationPlayer",true,false)
	if not players.is_empty():
		var animation_player:=players[0] as AnimationPlayer; var names:=animation_player.get_animation_list()
		for candidate in names:
			if "shoot" in str(candidate).to_lower() or "fire" in str(candidate).to_lower(): animation_player.play(candidate); return

func _play_gunshot(data:Dictionary) -> void:
	if fire_audio_pool.is_empty(): return
	var voice:=fire_audio_pool[fire_audio_cursor]; fire_audio_cursor=(fire_audio_cursor+1)%fire_audio_pool.size()
	voice.stop(); voice.stream=load(str(data.sound)); voice.pitch_scale=randf_range(0.965,1.035); voice.volume_db=-6.0; voice.play()

func _reload_weapon() -> void:
	if weapon_index<0 or weapon_reloading: return
	if _weapon_style(WEAPONS[weapon_index])=="knife": return
	var capacity:=int(WEAPONS[weapon_index].mag)
	if weapon_ammo>=capacity or weapon_reserve<=0: return
	weapon_reloading=true; weapon_aiming=false
	var main:=get_tree().current_scene
	weapon_audio.stop(); auto_fire_audio_active=false
	if main and main.has_method("play_weapon_reload"): main.play_weapon_reload()
	if main and main.has_method("show_toast"): main.show_toast("换弹中…")
	var tween:=create_tween()
	var style:=_weapon_style(WEAPONS[weapon_index])
	if style=="shotgun":
		tween.set_parallel(true); tween.tween_property(weapon_root,"position",weapon_rest_position+Vector3(0.12,-0.28,0.16),0.22); tween.tween_property(weapon_root,"rotation",Vector3(deg_to_rad(24),deg_to_rad(10),deg_to_rad(28)),0.22); tween.set_parallel(false); tween.tween_interval(0.68); tween.tween_property(weapon_root,"position",weapon_rest_position,0.28); tween.parallel().tween_property(weapon_root,"rotation",Vector3.ZERO,0.28)
	elif style=="rifle" or style=="sniper":
		tween.set_parallel(true); tween.tween_property(weapon_root,"position",weapon_rest_position+Vector3(-0.22,-0.25,0.18),0.24); tween.tween_property(weapon_root,"rotation",Vector3(deg_to_rad(18),deg_to_rad(-15),deg_to_rad(-34)),0.24); tween.set_parallel(false); tween.tween_interval(0.58); tween.tween_property(weapon_root,"position",weapon_rest_position,0.25); tween.parallel().tween_property(weapon_root,"rotation",Vector3.ZERO,0.25)
	else:
		tween.set_parallel(true); tween.tween_property(weapon_root,"position",weapon_rest_position+Vector3(0.15,-0.32,0.16),0.20); tween.tween_property(weapon_root,"rotation",Vector3(deg_to_rad(12),deg_to_rad(22),deg_to_rad(42)),0.20); tween.set_parallel(false); tween.tween_interval(0.46); tween.tween_property(weapon_root,"position",weapon_rest_position,0.22); tween.parallel().tween_property(weapon_root,"rotation",Vector3.ZERO,0.22)
	var base_duration:=1.40 if style=="shotgun" else (1.07 if style=="rifle" or style=="sniper" else 0.88)
	tween.set_speed_scale(base_duration/float(WEAPONS[weapon_index].get("reload_time",base_duration)))
	await tween.finished
	if weapon_index<0: weapon_reloading=false; return
	var needed:=capacity-weapon_ammo; var loaded:=mini(needed,weapon_reserve); weapon_ammo+=loaded; weapon_reserve-=loaded; weapon_reloading=false
	weapon_ammo_slots[weapon_index]=weapon_ammo; weapon_reserve_slots[weapon_index]=weapon_reserve
	_update_weapon_hud(str(WEAPONS[weapon_index].name),weapon_ammo,weapon_reserve)

func _update_weapon_pose(delta:float) -> void:
	if weapon_index<0 or not weapon_root.visible: return
	var style:=_weapon_style(WEAPONS[weapon_index]); var aim_offset:=Vector3(-0.335,0.145,0.19) if style=="rifle" else (Vector3(-0.34,0.12,0.22) if style=="sniper" else Vector3(-0.33,0.105,0.20))
	var target_offset:=aim_offset if weapon_aiming else Vector3.ZERO
	weapon_sway=weapon_sway.lerp(Vector2.ZERO,1.0-exp(-delta*9.0))
	target_offset+=Vector3(-weapon_sway.x,-weapon_sway.y,0.0)
	weapon_model.position=weapon_model.position.lerp(target_offset,1.0-exp(-delta*(13.0 if weapon_aiming else 9.0)))
	var target_fov:=58.0 if weapon_aiming else (82.5 if Input.is_action_pressed("sprint") and Vector2(velocity.x,velocity.z).length()>2.0 else 78.0)
	camera.fov=lerpf(camera.fov,target_fov,1.0-exp(-delta*10.0))

func _animate_pistol_slide() -> void:
	if weapon_model.get_child_count()==0: return
	var slides:=weapon_model.get_child(0).find_children("*slide*","Node3D",true,false)
	if slides.is_empty(): return
	var slide:=slides[0] as Node3D; var rest:=slide.position
	var tween:=create_tween(); tween.tween_property(slide,"position",rest+Vector3(0,0,0.035),0.035); tween.tween_property(slide,"position",rest,0.065)

func _weapon_style(data:Dictionary) -> String:
	if data.has("style"): return str(data.style)
	return "pistol" if "pistol" in str(data.scene).to_lower() else "rifle"

func _drop_current_weapon() -> void:
	if weapon_index<0 or weapon_index>=ACTIVE_WEAPON_COUNT or weapon_switching: return
	var dropped_index:=weapon_index; var data:Dictionary=WEAPONS[dropped_index]
	if _weapon_style(data)=="knife": return
	weapon_owned[dropped_index]=false; weapon_aiming=false
	var main:=get_tree().current_scene
	if main and main.has_method("spawn_dropped_weapon"): main.spawn_dropped_weapon(data,dropped_index,weapon_ammo,weapon_reserve,camera.global_position-camera.global_basis.z*0.8,-camera.global_basis.z)
	weapon_root.visible=false
	for child in weapon_model.get_children(): child.queue_free()
	weapon_index=-1; _update_weapon_hud("",0,0)
	if main and main.has_method("update_weapon_slots"): main.update_weapon_slots(-1,weapon_owned)
	if main and main.has_method("show_toast"): main.show_toast("已丢弃 "+str(data.name))

func pickup_weapon(slot:int,ammo:int,reserve:int) -> bool:
	if slot<0 or slot>=ACTIVE_WEAPON_COUNT or weapon_owned[slot]: return false
	weapon_owned[slot]=true; weapon_ammo_slots[slot]=ammo; weapon_reserve_slots[slot]=reserve; _equip_weapon(slot)
	return true

func take_damage(amount:float,_attacker:Node=null) -> void:
	var absorbed:=minf(float(armor),amount*0.45); armor=maxi(0,armor-int(round(absorbed*0.55))); health=clampi(health-int(round(amount-absorbed)),0,max_health); health_changed.emit(health,max_health)
	var hit_main:=get_tree().current_scene
	if hit_main and hit_main.has_method("show_player_hit_blood"): hit_main.show_player_hit_blood()
	if health<=0:
		freeze_movement=true; var fall:=create_tween(); fall.set_parallel(true); fall.tween_property(head,"rotation:z",deg_to_rad(72.0),0.52).set_trans(Tween.TRANS_QUAD); fall.tween_property(head,"position:y",0.55,0.52)
		var main:=get_tree().current_scene
		if weapon_index>=0 and _weapon_style(WEAPONS[weapon_index])!="knife": _drop_current_weapon()
		if main and main.has_method("on_combatant_defeated"): main.on_combatant_defeated("player")
		else: health=max_health; armor=100; reset_to_spawn(); health_changed.emit(health,max_health)

func reset_for_round() -> void:
	health=max_health; armor=100; velocity=Vector3.ZERO; weapon_owned=[true,true,true,true,true]; crouching=false; spray_heat=0.0; weapon_cooldown=0.0; weapon_reloading=false; weapon_switching=false; auto_fire_audio_active=false
	for i in range(ACTIVE_WEAPON_COUNT): weapon_ammo_slots[i]=int(WEAPONS[i].mag); weapon_reserve_slots[i]=int(WEAPONS[i].reserve)
	reset_to_spawn(); head.position.y=1.62; head.rotation=Vector3.ZERO; $CollisionShape3D.scale=Vector3.ONE; $CollisionShape3D.position.y=0.875; freeze_movement=false; health_changed.emit(health,max_health); _equip_weapon(0)

func apply_network_health(current:int) -> void:
	var previous:=health; health=clampi(current,0,max_health); health_changed.emit(health,max_health)
	if health<previous:
		var main:=get_tree().current_scene
		if main and main.has_method("show_player_hit_blood"): main.show_player_hit_blood()
	if health<=0:
		freeze_movement=true; var fall:=create_tween(); fall.tween_property(head,"rotation:z",deg_to_rad(72.0),0.52)
		var main:=get_tree().current_scene
		if main and main.has_method("on_combatant_defeated"): main.on_combatant_defeated("player")

func _update_weapon_hud(name_:String,ammo:int,reserve:int) -> void:
	var main:=get_tree().current_scene
	if main and main.has_method("update_weapon_hud"): main.update_weapon_hud(name_,ammo,reserve)

func _refresh_held_item() -> void:
	for child in held_item_root.get_children(): child.queue_free()
	if selected_slot >= inventory.size(): return
	var item := inventory[selected_slot]
	var mesh_instance := MeshInstance3D.new()
	var shape_type: String = item.get("shape", "orb")
	if shape_type == "sticker":
		var sticker_quad:=QuadMesh.new(); sticker_quad.size=Vector2(0.30,0.30); mesh_instance.mesh=sticker_quad
		var sticker_mat:=ShaderMaterial.new(); sticker_mat.shader=load("res://shaders/sticker.gdshader"); sticker_mat.set_shader_parameter("sticker_texture",load(str(item.get("texture","")))); sticker_mat.set_shader_parameter("rarity_color",item.get("color",Color("4b69ff"))); sticker_mat.set_shader_parameter("foil_strength",float(item.get("foil",0.0))); mesh_instance.material_override=sticker_mat; mesh_instance.position=Vector3(-0.02,0.08,-0.03)
	elif shape_type == "disc":
		var disc := CylinderMesh.new(); disc.top_radius = 0.15; disc.bottom_radius = 0.15; disc.height = 0.055; disc.radial_segments = 20; mesh_instance.mesh = disc; mesh_instance.rotation_degrees.x = 90
	elif shape_type == "capsule":
		var capsule := CapsuleMesh.new(); capsule.radius = 0.08; capsule.height = 0.30; mesh_instance.mesh = capsule; mesh_instance.rotation_degrees.z = 35
	elif shape_type == "phone":
		var phone := BoxMesh.new(); phone.size = Vector3(0.18,0.28,0.05); mesh_instance.mesh = phone; mesh_instance.rotation_degrees.z = -12
	elif shape_type == "diamond":
		var diamond := BoxMesh.new(); diamond.size = Vector3(0.18,0.18,0.18); mesh_instance.mesh = diamond; mesh_instance.rotation_degrees = Vector3(25,35,45)
	else:
		var orb := SphereMesh.new(); var held_radius:=0.17 if shape_type=="throw_ball" else 0.12; orb.radius=held_radius; orb.height=held_radius*2.0; orb.radial_segments = 16; orb.rings = 8; mesh_instance.mesh = orb
	if shape_type!="sticker":
		var mat := StandardMaterial3D.new()
		var color: Color = item.get("color", Color("9ee7e2"))
		mat.albedo_color = color; mat.metallic = 0.38; mat.roughness = 0.18; mat.emission_enabled = true; mat.emission = color; mat.emission_energy_multiplier = 0.35
		mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	held_item_root.add_child(mesh_instance)

func _try_place_sticker() -> void:
	var main:=get_tree().current_scene
	if selected_slot>=inventory.size() or inventory[selected_slot].get("shape","")!="sticker":
		if main and main.has_method("show_toast"): main.show_toast("请先选择一枚贴纸")
		return
	if not ray.is_colliding() or camera.global_position.distance_to(ray.get_collision_point())>3.35:
		if main and main.has_method("show_toast"): main.show_toast("请靠近墙面再贴")
		return
	var normal:=ray.get_collision_normal()
	if absf(normal.y)>0.68:
		if main and main.has_method("show_toast"): main.show_toast("贴纸只能贴在垂直表面")
		return
	var current:=inventory[selected_slot].duplicate(true)
	if main and main.has_method("place_sticker"):
		main.place_sticker(current,ray.get_collision_point(),normal)
		_consume_selected_item()

func _use_selected_item() -> void:
	var main:=get_tree().current_scene
	if selected_slot>=inventory.size():
		if main and main.has_method("show_toast"): main.show_toast("物品栏里没有可使用的物品")
		return
	var item:=inventory[selected_slot]
	if item.get("shape","")=="sticker":
		_try_place_sticker()
		return
	if main and main.has_method("throw_inventory_item"):
		var throw_origin:=camera.global_position-camera.global_basis.z*0.75+Vector3.DOWN*0.18
		var throw_direction:=-camera.global_basis.z+Vector3.UP*0.10
		main.throw_inventory_item(item.duplicate(true),throw_origin,throw_direction)
		_consume_selected_item()

func _consume_selected_item() -> void:
	if selected_slot>=inventory.size(): return
	var count:=int(inventory[selected_slot].get("count",1))-1
	if count>0: inventory[selected_slot]["count"]=count
	else:
		inventory.remove_at(selected_slot)
		selected_slot=clampi(selected_slot,0,maxi(0,inventory.size()-1))
	_refresh_held_item(); inventory_changed.emit(inventory,selected_slot)

func _punch() -> void:
	if punch_busy: return
	punch_busy = true
	if first_person_arms and first_person_arms.has_method("play_punch"): first_person_arms.play_punch()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(hand_pivot, "position", hand_rest_position + Vector3(-0.10,0.10,-0.36), 0.09)
	tween.parallel().tween_property(hand_pivot, "rotation", hand_rest_rotation + Vector3(-0.34,0.18,-0.22), 0.09)
	tween.tween_property(hand_pivot, "position", hand_rest_position, 0.16).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(hand_pivot, "rotation", hand_rest_rotation, 0.16)
	tween.finished.connect(func(): punch_busy = false)
	if ray.is_colliding() and camera.global_position.distance_to(ray.get_collision_point()) <= 2.35:
		var target := ray.get_collider()
		if target and target.has_method("hit"): target.hit(self)
	var main:=get_tree().current_scene
	if main and main.has_method("play_punch_sound"): main.play_punch_sound(global_position)
