extends Node3D

@onready var world: Node3D = $World
@onready var player: CharacterBody3D = $Player
var prompt_label: Label
var toast_label: Label
var debug_label: Label
var start_panel: Control
var pause_panel: Control
var multiplayer_panel:Control
var mp_user:LineEdit
var mp_password:LineEdit
var mp_address:LineEdit
var mp_port:LineEdit
var mp_invite:LineEdit
var mp_status:Label
var mp_room_list:ItemList
var round_result_overlay:ColorRect
var round_result_label:Label
var damage_flash:ColorRect
var network_state_accum:=0.0
var remote_avatars:Dictionary={}
var toast_timer: Timer
var debug_visible := false
var inventory_slots: Array[PanelContainer] = []
var capsule_result_overlay: Control
var capsule_result_texture: TextureRect
var capsule_result_name: Label
var capsule_result_rarity: Label
var capsule_reveal_serial:=0
var world_environment: Environment
var sky_material: PanoramaSkyMaterial
var sun_light: DirectionalLight3D
var moon_light: DirectionalLight3D
var clock_label: Label
var performance_label: Label
var performance_hud_accum:=0.0
var game_hour := 18.5
var time_scale := 60.0
var time_speed_index := 1
var time_speeds := [0.0, 60.0, 300.0, 1200.0]
var interior_lights: Array[OmniLight3D] = []
var ambient_audio: AudioStreamPlayer
var stage_music: AudioStreamPlayer3D
var ui_audio: AudioStreamPlayer
var footstep_streams: Array[AudioStream] = []
var ball_impact_streams: Array[AudioStream] = []
var stage_music_target_db:=-5.0
var cloud_material:ShaderMaterial
var weapon_label:Label
var health_label:Label
var duel_label:Label
var duel_scores:=[0,0]
var round_number:=1
var round_time_left:=90.0
var round_freeze_left:=3.0
var round_active:=false

const INDIGO = Color("17152f")
const PURPLE = Color("512b68")
const PINK = Color("ee5f9f")
const CYAN = Color("39cad4")
const CORAL = Color("ff896f")
const MINT = Color("83d8c6")
const CREAM = Color("f3d9cf")

func _ready() -> void:
	if NetworkSession.dedicated_server:
		set_process(false)
		print("Main scene skipped visual setup in dedicated-server mode")
		return
	_build_environment()
	_build_audio()
	_build_hall()
	_build_stage()
	_build_arcade()
	_build_capsule_machine()
	_build_crt()
	_build_duel_layout()
	_build_lounges()
	_build_bar()
	_build_coast()
	_build_architectural_details()
	_build_render_details()
	_build_collectibles()
	_build_dance_balls()
	_build_ui()
	player.interaction_changed.connect(_on_interaction_changed)
	player.pause_requested.connect(_open_pause)
	player.inventory_changed.connect(_on_inventory_changed)
	player.health_changed.connect(_on_player_health_changed)
	_on_player_health_changed(player.health,player.max_health)
	_on_inventory_changed(player.inventory, player.selected_slot)
	if OS.has_environment("NCC_INVENTORY_TEST"):
		player.add_inventory_item({"id":"test_disc","name":"Orbit MiniDisc","shape":"disc","color":Color("aee8f0")})
		player.add_inventory_item({"id":"test_orb","name":"Aero 果冻光球","shape":"orb","color":Color("86e2cf")})
	player.set_controls_enabled(false)
	player.position=Vector3(16.6,0.05,0.5); player.rotation.y=deg_to_rad(-90.0); player.spawn_transform=player.global_transform
	if "--autostart" in OS.get_cmdline_user_args() or OS.has_environment("NCC_AUTOSTART"):
		_start_game.call_deferred()
	if "--rhythm-test" in OS.get_cmdline_user_args():
		var rhythm_ui := get_node_or_null("RhythmLayer/RhythmUI")
		if rhythm_ui: rhythm_ui.open_song_select.call_deferred()
	if "--rhythm-game-test" in OS.get_cmdline_user_args():
		var rhythm_game_ui := get_node_or_null("RhythmLayer/RhythmUI")
		if rhythm_game_ui: rhythm_game_ui.open_game.call_deferred()
	if OS.has_environment("NCC_BALCONY_PREVIEW"):
		player.rotation.y = 0.0
		player.get_node("Head").rotation.x = deg_to_rad(-7.0)
	if OS.has_environment("NCC_MODEL_PREVIEW"):
		player.position = Vector3(0,0.05,-7.0)
		player.rotation.y = deg_to_rad(-90.0)
	if OS.has_environment("NCC_COAST_PREVIEW"):
		player.position = Vector3(0,0.05,-23.0)
		player.rotation.y = 0.0
		player.get_node("Head").rotation.x = deg_to_rad(-15.0)
	if OS.has_environment("NCC_BEACH_PREVIEW"):
		player.position = Vector3(0,0.05,-25.25)
		player.rotation.y = 0.0
		player.get_node("Head").rotation.x = deg_to_rad(-35.0)
	if OS.has_environment("NCC_CAPSULE_PREVIEW"):
		player.position=Vector3(-10.5,0.05,-6.0)
		player.rotation.y=deg_to_rad(90.0)
	if OS.has_environment("NCC_CAPSULE_TEST"):
		_start_game.call_deferred()
		world.get_node("SealLandXCapsuleMachine").call_deferred("interact",player)

func _process(delta: float) -> void:
	_update_day_night(delta)
	_update_rhythm_music_ducking(delta)
	_update_duel_round(delta)
	_update_network_state(delta)
	_update_performance_hud(delta)
	if Input.is_action_just_pressed("cycle_time_speed"):
		time_speed_index=(time_speed_index+1)%time_speeds.size()
		time_scale=float(time_speeds[time_speed_index])
		show_toast("时间速度："+("暂停" if time_scale==0.0 else "×%d"%int(time_scale)))
	if Input.is_action_just_pressed("toggle_fullscreen"):
		_toggle_fullscreen()
	if Input.is_action_just_pressed("toggle_debug"):
		debug_visible = not debug_visible
		debug_label.visible = debug_visible
	if debug_visible:
		var target := "无"
		if player.last_target: target = str(player.last_target.interaction_name)
		debug_label.text = "FPS %d\n位置 %.1f, %.1f, %.1f\n互动 %s" % [Engine.get_frames_per_second(), player.global_position.x, player.global_position.y, player.global_position.z, target]

func _update_rhythm_music_ducking(delta:float) -> void:
	if not stage_music: return
	var rhythm_ui:=get_node_or_null("RhythmLayer/RhythmUI")
	var playing_chart:=false
	if rhythm_ui and "screen" in rhythm_ui: playing_chart=int(rhythm_ui.get("screen"))==3
	stage_music_target_db=-80.0 if playing_chart else -16.0
	stage_music.volume_db=move_toward(stage_music.volume_db,stage_music_target_db,delta*(75.0 if playing_chart else 24.0))

func _build_environment() -> void:
	var env := Environment.new()
	sky_material = PanoramaSkyMaterial.new()
	sky_material.panorama = load("res://assets/textures/miami_dusk_panorama.png")
	sky_material.filter = true
	sky_material.energy_multiplier = 0.72
	var sunset_sky := Sky.new()
	sunset_sky.sky_material = sky_material
	sunset_sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.background_mode = Environment.BG_SKY
	env.sky = sunset_sky
	env.sky_rotation = Vector3(0,deg_to_rad(90.0),0)
	env.background_energy_multiplier = 0.75
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8d7db8")
	env.ambient_light_energy = 0.72
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.ssr_enabled = true
	env.ssr_max_steps = 96
	env.ssr_fade_in = 0.12
	env.ssr_fade_out = 2.8
	env.ssao_enabled = true
	env.ssao_radius = 1.35
	env.ssao_intensity = 2.0
	env.ssil_enabled = true
	env.ssil_radius = 3.5
	env.ssil_intensity = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.82
	env.glow_strength = 1.08
	env.glow_bloom = 0.16
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.07
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("aa7590")
	env.fog_light_energy = 0.35
	env.fog_density = 0.0026
	env.fog_sky_affect = 0.16
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.018
	env.volumetric_fog_albedo = Color("b9a6cf")
	env.volumetric_fog_emission = Color("291c42")
	env.volumetric_fog_emission_energy = 0.12
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world.add_child(world_env)
	world_environment=env
	sun_light = DirectionalLight3D.new()
	sun_light.name="SunLight"
	sun_light.rotation_degrees = Vector3(-28, -22, 0)
	sun_light.light_color = Color("ffc0a0")
	sun_light.light_energy = 1.05
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_max_distance=120.0
	sun_light.shadow_blur=1.35
	world.add_child(sun_light)
	moon_light=DirectionalLight3D.new()
	moon_light.name="MoonLight"
	moon_light.light_color=Color("91a8ff")
	moon_light.light_energy=0.0
	moon_light.shadow_enabled=true
	moon_light.directional_shadow_max_distance=90.0
	moon_light.shadow_blur=1.8
	world.add_child(moon_light)
	_add_light(Vector3(-12, 4.5, 0), PINK, 2.2, 13.0)
	_add_light(Vector3(12, 4.5, 0), CYAN, 2.2, 13.0)
	_add_light(Vector3(0, 5.5, 9), PURPLE.lightened(0.3), 3.0, 12.0)
	_add_light(Vector3(0, 4, -10), CORAL, 1.7, 10.0)
	_build_dynamic_clouds()

func _build_dynamic_clouds() -> void:
	var dome:=MeshInstance3D.new(); dome.name="DynamicCloudDome"; var sphere:=SphereMesh.new(); sphere.radius=280.0; sphere.height=560.0; sphere.radial_segments=48; sphere.rings=24; dome.mesh=sphere; dome.position=Vector3(0,-38,0); dome.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud_material=ShaderMaterial.new(); cloud_material.shader=load("res://shaders/moving_clouds.gdshader"); dome.material_override=cloud_material; world.add_child(dome)

func _build_audio() -> void:
	_setup_audio_buses()
	ambient_audio=AudioStreamPlayer.new(); ambient_audio.name="CoastalClubAmbience"; ambient_audio.stream=load("res://assets/audio/ambient/coastal_rumble_cc0.ogg"); ambient_audio.volume_db=-23.5; add_child(ambient_audio)
	if ambient_audio.stream is AudioStreamOggVorbis: (ambient_audio.stream as AudioStreamOggVorbis).loop=true
	ambient_audio.play()
	stage_music=AudioStreamPlayer3D.new(); stage_music.name="MainStageMusic"; stage_music.position=Vector3(0,3.2,11.3); stage_music.stream=load("res://assets/audio/music/televisor_pinup.mp3"); stage_music.volume_db=-5.0; stage_music.unit_size=6.0; stage_music.max_distance=34.0; stage_music.attenuation_filter_cutoff_hz=10500.0; stage_music.attenuation_filter_db=-18.0; stage_music.bus="ClubReverb"; world.add_child(stage_music)
	if stage_music.stream is AudioStreamMP3: (stage_music.stream as AudioStreamMP3).loop=true
	stage_music.play()
	ui_audio=AudioStreamPlayer.new(); ui_audio.name="UISound"; ui_audio.volume_db=-8.0; add_child(ui_audio)
	for path in ["res://assets/audio/impact/footstep_1.ogg","res://assets/audio/impact/footstep_2.ogg","res://assets/audio/impact/footstep_3.ogg"]: footstep_streams.append(load(path))
	for path in ["res://assets/audio/impact/ball_soft.ogg","res://assets/audio/impact/ball_light.ogg"]: ball_impact_streams.append(load(path))

func _setup_audio_buses() -> void:
	if AudioServer.get_bus_index("ClubReverb")<0:
		AudioServer.add_bus(); var index:=AudioServer.bus_count-1; AudioServer.set_bus_name(index,"ClubReverb"); AudioServer.set_bus_send(index,"Master")
		var reverb:=AudioEffectReverb.new(); reverb.room_size=0.72; reverb.damping=0.58; reverb.spread=0.82; reverb.hipass=0.18; reverb.dry=0.86; reverb.wet=0.24; AudioServer.add_bus_effect(index,reverb)

func _build_hall() -> void:
	# Main floor and restrained animated dance grid.
	var hall_floor:=_box(world, "HallFloor", Vector3(0, -0.2, 0), Vector3(40, 0.4, 28), INDIGO.lightened(0.08), true); hall_floor.material_override=_architectural_pbr("res://assets/textures/club_floor_terrazzo.png",Vector2(10.0,7.0),0.38,0.16,0.72,0.42)
	var dance := _box(world, "DanceFloor", Vector3(0, 0.025, 1), Vector3(16, 0.08, 14), INDIGO, true)
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = load("res://shaders/dance_floor.gdshader")
	dance.material_override = shader_mat
	# Side and rear architecture; the seaward front has a wide walk-through opening.
	var left_wall:=_box(world, "LeftWall", Vector3(-20, 4.5, 0), Vector3(0.5, 9, 28), PURPLE.darkened(0.48), true); left_wall.material_override=_architectural_pbr("res://assets/textures/club_wall_panels.png",Vector2(7.0,2.4),0.34,0.28,0.82,0.48)
	var right_wall:=_box(world, "RightWall", Vector3(20, 4.5, 0), Vector3(0.5, 9, 28), PURPLE.darkened(0.48), true); right_wall.material_override=_architectural_pbr("res://assets/textures/club_wall_panels.png",Vector2(7.0,2.4),0.34,0.28,0.82,0.48)
	var stage_wall:=_box(world, "StageWall", Vector3(0, 4.5, 14), Vector3(40, 9, 0.5), INDIGO.lightened(0.04), true); stage_wall.material_override=_architectural_pbr("res://assets/textures/club_wall_panels.png",Vector2(9.0,2.2),0.36,0.24,0.76,0.46)
	var glass_l:=_box(world, "FrontGlassL", Vector3(-12, 4, -14), Vector3(16, 8, 0.16), Color("3bb4c4"), true, Color.BLACK, 0.20); glass_l.material_override=_club_glass_material(Color("45c5d0"),0.19)
	var glass_r:=_box(world, "FrontGlassR", Vector3(12, 4, -14), Vector3(16, 8, 0.16), Color("3bb4c4"), true, Color.BLACK, 0.20); glass_r.material_override=_club_glass_material(Color("45c5d0"),0.19)
	_box(world, "FrontBeam", Vector3(0, 8.1, -14), Vector3(40, 0.4, 0.4), MINT.darkened(0.35), true)
	# Ceiling accents and readable perimeter strips.
	var ceiling:=_box(world, "Ceiling", Vector3(0, 9, 0), Vector3(40, 0.25, 28), INDIGO.darkened(0.25), false); ceiling.material_override=_architectural_pbr("res://assets/textures/club_ceiling_acoustic.png",Vector2(10.0,7.0),0.84,0.03,0.52,0.62)
	for z in [-10.0, -5.0, 0.0, 5.0, 10.0]:
		_box(world, "CeilingStrip", Vector3(0, 8.78, z), Vector3(30, 0.05, 0.09), CYAN, false, CYAN, 1.2)
	# Textured acoustic feature walls add material depth around the stage.
	for x in [-14.0, 14.0]:
		var panel := _box(world, "AcousticFeaturePanel", Vector3(x, 4.5, 13.68), Vector3(9.0, 6.6, 0.08), Color.WHITE, false)
		panel.material_override = _textured_material("res://assets/textures/y2k_wall_panel.png", Vector3(1.4, 1.0, 1.0), 0.78)
		for edge_x in [-4.65, 4.65]:
			_box(world, "PanelTrim", Vector3(x + edge_x, 4.5, 13.58), Vector3(0.06, 6.9, 0.12), Color("8ea9b7"), false, CYAN, 0.18)
	# Disco ball and concentric Y2K rings.
	var disco := Node3D.new()
	disco.name = "DiscoBall"
	disco.position = Vector3(0, 7.0, 1)
	disco.set_script(load("res://scripts/environment/spin.gd"))
	world.add_child(disco)
	_sphere(disco, "MirrorBall", Vector3.ZERO, 0.7, Color("b9c8d8"), false, Color("7edbe3"), 0.45)
	for radius in [1.25, 1.75]:
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.035
		torus.outer_radius = radius + 0.035
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		ring.rotation_degrees.x = 90
		ring.material_override = _material(PINK if radius > 1.5 else CYAN, PINK if radius > 1.5 else CYAN, 1.0)
		disco.add_child(ring)
	# A separate rotating rig throws narrow colored shafts across floor and walls.
	var light_rig:=Node3D.new(); light_rig.name="DiscoLightRig"; light_rig.set_script(load("res://scripts/environment/disco_ball.gd")); disco.add_child(light_rig)
	for i in range(14):
		var beam:=SpotLight3D.new(); beam.name="MirrorBeam%02d"%i; beam.position=Vector3.ZERO
		beam.light_color=Color.from_hsv(0.53+i*0.073,0.62,1.0); beam.light_energy=8.5; beam.spot_range=27.0; beam.spot_angle=18.0+(i%3)*3.0; beam.spot_angle_attenuation=0.48; beam.shadow_enabled=false
		beam.rotation_degrees=Vector3(-48.0-(i%3)*12.0,i*25.714,0.0); light_rig.add_child(beam)
	var core:=OmniLight3D.new(); core.name="MirrorBallGlow"; core.light_color=Color("c7faff"); core.light_energy=2.6; core.omni_range=4.0; disco.add_child(core)

func _build_stage() -> void:
	var stage := StaticBody3D.new()
	stage.name = "Stage"
	stage.position = Vector3(0, 0, 10.7)
	stage.set_script(load("res://scripts/props/stage_controller.gd"))
	world.add_child(stage)
	_body_box(stage, "Platform", Vector3(0, 0.55, 0), Vector3(15, 1.1, 5), PURPLE.darkened(0.22))
	_box(stage,"StageChromeFront",Vector3(0,1.08,-2.47),Vector3(14.8,0.075,0.075),Color("9baebb"),false,CYAN,0.24)
	_box(stage,"StageChromeBack",Vector3(0,1.08,2.47),Vector3(14.8,0.075,0.075),Color("9baebb"),false,PINK,0.18)
	for x in [-7.46,7.46]: _box(stage,"StageChromeSide",Vector3(x,1.08,0),Vector3(0.075,0.075,4.9),Color("9baebb"),false,CYAN if x<0 else PINK,0.20)
	for i in range(3):
		_body_box(stage, "Step%d" % i, Vector3(0, 0.12 + i * 0.2, -3.2 + i * 0.45), Vector3(8 - i * 0.6, 0.24 + i * 0.02, 0.9), INDIGO.lightened(0.16))
	var stage_screen:=_body_box(stage, "Screen", Vector3(0, 4.15, 2.25), Vector3(10.5, 4.2, 0.25), Color("120f2d"), CYAN, 0.75); var stage_show:=ShaderMaterial.new(); stage_show.shader=load("res://shaders/stage_vapor_show.gdshader"); stage_show.set_shader_parameter("poster_texture",load("res://assets/textures/stage_vaporwave_poster.png")); stage_screen.material_override=stage_show
	var label := _label3d(stage, "StageLabel", "NEON COAST // VAPOR LIVE", Vector3(0, 6.0, 2.08), 34, CYAN)
	label.rotation_degrees.y = 180; label.visible=false
	for x in [-6.2, 6.2]:
		_body_box(stage, "Speaker", Vector3(x, 2.0, 1.7), Vector3(2.0, 4.0, 1.5), INDIGO.darkened(0.35))
		for y in [1.2, 2.7]: _cylinder(stage, "SpeakerCone", Vector3(x, y, 0.91), 0.55, 0.12, Color("242438"), false, Vector3(90,0,0))
	_body_box(stage, "Truss", Vector3(0, 7.25, 1.8), Vector3(16, 0.18, 0.18), Color("8190a3"))
	for x in [-5.0, 5.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(x, 6.5, 0.3)
		light.light_color = PINK if x < 0 else CYAN
		light.light_energy = 2.5
		light.omni_range = 7.0
		stage.add_child(light)

func _build_arcade() -> void:
	var arcade := StaticBody3D.new()
	arcade.name = "ArcadeMachine"
	arcade.position = Vector3(-15.2, 0, 1.5)
	arcade.rotation_degrees.y = -90
	arcade.set_script(load("res://scripts/props/arcade_machine.gd"))
	world.add_child(arcade)
	_body_box(arcade, "Cabinet", Vector3(0, 1.45, 0), Vector3(2.0, 2.9, 1.45), PURPLE.lightened(0.16))
	_body_box(arcade, "Marquee", Vector3(0, 2.9, -0.05), Vector3(2.15, 0.55, 1.3), PINK, PINK, 0.8)
	_body_box(arcade, "Screen", Vector3(0, 2.05, -0.755), Vector3(1.52, 0.95, 0.08), Color("061b2a"), CYAN, 2.2)
	var label := _label3d(arcade, "ScreenLabel", "4K ORBIT\nPRESS START", Vector3(0, 2.05, -0.81), 52, CYAN)
	label.rotation_degrees.y = 180
	for x in [-0.45, -0.12, 0.21, 0.54]: _sphere(arcade, "Button", Vector3(x, 1.3, -0.78), 0.10, PINK if x < 0 else CYAN, false, PINK if x < 0 else CYAN, 1.0)
	_cylinder(arcade, "Joystick", Vector3(-0.55, 1.55, -0.78), 0.07, 0.35, Color("27334c"), false)
	_sphere(arcade, "JoystickTop", Vector3(-0.55, 1.78, -0.78), 0.14, CORAL, false, CORAL, 0.6)

func _build_capsule_machine() -> void:
	var machine:=StaticBody3D.new(); machine.name="SealLandXCapsuleMachine"; machine.position=Vector3(-16.2,0,-6.0); machine.rotation_degrees.y=-90; machine.set_script(load("res://scripts/props/capsule_machine.gd"))
	_body_box(machine,"MachineBody",Vector3(0,1.55,0),Vector3(2.55,3.10,1.65),Color("35204f"))
	_body_box(machine,"MachineBase",Vector3(0,0.24,0.08),Vector3(2.90,0.48,2.05),Color("15152c"),CYAN,0.18)
	_body_box(machine,"Header",Vector3(0,3.35,0.02),Vector3(2.85,0.72,1.78),PURPLE.lightened(0.08),PINK,0.32)
	var label:=_label3d(machine,"ResultLabel","SEALANDX\nPRESS E",Vector3(0,3.35,-0.91),54,CYAN); label.rotation_degrees.y=180
	# Transparent rounded capsule chamber.
	var chamber:=_sphere(machine,"ChamberGlass",Vector3(0,2.25,-0.88),1.12,Color("94e8ea"),false,Color.BLACK,0.0,0.20); chamber.scale=Vector3(1.0,0.82,0.43)
	var chamber_ring:=TorusMesh.new(); chamber_ring.inner_radius=1.04; chamber_ring.outer_radius=1.14
	var ring:=MeshInstance3D.new(); ring.name="ChamberRing"; ring.mesh=chamber_ring; ring.position=Vector3(0,2.25,-1.03); ring.rotation_degrees.x=90; ring.material_override=_material(Color("a9b8c8"),CYAN,0.34); machine.add_child(ring)
	var rotor:=Node3D.new(); rotor.name="Rotor"; rotor.position=Vector3(0,2.25,-1.02); machine.add_child(rotor)
	for i in range(10):
		var angle:=TAU*float(i)/10.0
		var capsule:=Node3D.new(); capsule.position=Vector3(cos(angle)*0.72,sin(angle)*0.56,0); capsule.rotation_degrees.z=rad_to_deg(angle); rotor.add_child(capsule)
		var capsule_color:Color=[CYAN,PINK,MINT,CORAL,Color("c59bdd")][i%5]
		_sphere(capsule,"MiniCapsule",Vector3.ZERO,0.18,capsule_color,false,capsule_color,0.22,0.88).scale=Vector3(1.0,0.72,0.72)
	var knob:=Node3D.new(); knob.name="KnobPivot"; knob.position=Vector3(0,1.06,-1.02); machine.add_child(knob)
	_cylinder(knob,"KnobDisc",Vector3.ZERO,0.46,0.22,Color("b8c6d0"),false,Vector3(90,0,0))
	_box(knob,"KnobGrip",Vector3(0,0,-0.17),Vector3(0.18,0.72,0.18),PINK,false,PINK,0.36)
	var output:=Node3D.new(); output.name="OutputCapsule"; output.visible=false; machine.add_child(output)
	var top:=Node3D.new(); top.name="Top"; output.add_child(top); var top_mesh:=_sphere(top,"Shell",Vector3.ZERO,0.34,Color("8de6ef"),false,CYAN,0.30,0.86); top_mesh.scale=Vector3(1.0,0.62,0.78)
	var bottom:=Node3D.new(); bottom.name="Bottom"; output.add_child(bottom); var bottom_mesh:=_sphere(bottom,"Shell",Vector3.ZERO,0.34,Color("ee77ae"),false,PINK,0.30,0.86); bottom_mesh.scale=Vector3(1.0,0.62,0.78)
	_body_box(machine,"PrizeTray",Vector3(0,0.48,-0.94),Vector3(1.45,0.52,0.46),Color("181a32"),CYAN,0.16)
	for x in [-1.22,1.22]:
		_cylinder(machine,"SideTube",Vector3(x,1.65,-0.88),0.10,2.55,Color("9eb4c0"),false)
		_sphere(machine,"SideLight",Vector3(x,2.90,-0.91),0.15,PINK if x<0 else CYAN,false,PINK if x<0 else CYAN,0.9)
	var rarity_light:=OmniLight3D.new(); rarity_light.name="RarityLight"; rarity_light.position=Vector3(0,1.25,-1.45); rarity_light.light_color=CYAN; rarity_light.light_energy=1.2; rarity_light.omni_range=4.0; machine.add_child(rarity_light)
	world.add_child(machine)

func _build_crt() -> void:
	var tv := StaticBody3D.new()
	tv.name = "CRTTV"
	tv.position = Vector3(14.5, 0, 0.5)
	tv.rotation_degrees.y = 90
	tv.set_script(load("res://scripts/props/crt_tv.gd"))
	world.add_child(tv)
	_body_box(tv, "Cabinet", Vector3(0, 0.65, 0), Vector3(3.6, 1.3, 1.7), Color("40395a"))
	_body_box(tv, "TVCase", Vector3(0, 2.05, 0), Vector3(3.0, 1.8, 1.65), Color("725978"))
	var screen := _body_box(tv, "Screen", Vector3(0, 2.12, -0.86), Vector3(2.25, 1.22, 0.08), Color("05252d"))
	var crtmat := ShaderMaterial.new(); crtmat.shader = load("res://shaders/crt_screen.gdshader"); screen.material_override = crtmat
	var tv_label := _label3d(tv, "ScreenLabel", "CHANNEL 88", Vector3(0, 2.12, -0.93), 54, Color.WHITE)
	tv_label.rotation_degrees.y = 180
	for x in [-0.7, 0.7]:
		_cylinder(tv, "Antenna", Vector3(x, 3.32, 0), 0.025, 1.5, Color("abb4c7"), false, Vector3(0,0,25 if x < 0 else -25))

func _build_duel_layout() -> void:
	var spawn_a:=Marker3D.new(); spawn_a.name="Spawn_TV_Left"; spawn_a.position=Vector3(16.6,0.05,0.5); world.add_child(spawn_a)
	var spawn_b:=Marker3D.new(); spawn_b.name="Spawn_4K_Right"; spawn_b.position=Vector3(-17.0,0.05,1.5); world.add_child(spawn_b)

func _spawn_training_bot() -> void:
	if world.get_node_or_null("DuelOpponent"): return
	var spawn_b:=world.get_node_or_null("Spawn_4K_Right") as Marker3D
	if not spawn_b: return
	var opponent:=CharacterBody3D.new(); opponent.name="DuelOpponent"; opponent.position=spawn_b.position; opponent.rotation_degrees.y=90; opponent.set_script(load("res://scripts/combat/duel_target.gd")); world.add_child(opponent)
	_body_box(opponent,"Torso",Vector3(0,1.25,0),Vector3(0.72,1.10,0.38),Color("26344d"),CYAN,0.12)
	_body_box(opponent,"Legs",Vector3(0,0.50,0),Vector3(0.58,0.95,0.32),Color("151b2b"))
	_sphere(opponent,"Head",Vector3(0,2.05,0),0.32,Color("d7a88d"),false)
	var head_hitbox:=Area3D.new(); head_hitbox.name="HeadHitbox"; head_hitbox.position=Vector3(0,2.05,0); head_hitbox.collision_layer=1; head_hitbox.collision_mask=0; head_hitbox.set_script(load("res://scripts/combat/damage_hitbox.gd")); head_hitbox.set("damage_multiplier",4.0); opponent.add_child(head_hitbox)
	var head_shape:=CollisionShape3D.new(); var head_sphere:=SphereShape3D.new(); head_sphere.radius=0.34; head_shape.shape=head_sphere; head_hitbox.add_child(head_shape)
	for x in [-0.48,0.48]: _body_box(opponent,"Arm",Vector3(x,1.30,0),Vector3(0.22,1.05,0.24),Color("344b66"))
	var bot_gun:=load("res://assets/models/weapons/quaternius/FBX/AssaultRifle_1.fbx") as PackedScene
	if bot_gun:
		var gun:=bot_gun.instantiate() as Node3D; gun.name="BotRifle"; gun.scale=Vector3.ONE*0.22; gun.rotation=Vector3(0,deg_to_rad(90),0); gun.position=Vector3(-0.25,1.28,-0.38); opponent.add_child(gun)
	var tag:=_label3d(opponent,"NameTag","训练 BOT · 100 HP",Vector3(0,2.72,0),34,Color("ffb3d2")); tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED

func _build_lounges() -> void:
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 11.0
		var lounge := Node3D.new(); lounge.name = "Y2KLounge"; world.add_child(lounge)
		var sofa_color:=Color("e3a0c3") if side<0 else Color("b9a1dd")
		_place_model(lounge,"KenneyDesignSofa","res://assets/models/kenney/loungeDesignSofa.glb",Vector3(x,0.02,-7.0),Vector3(1.22,1.22,1.22),Vector3(0,90,0),sofa_color,Vector3(1.25,1.0,2.9))
		_place_model(lounge,"KenneyGlassTable","res://assets/models/kenney/tableCoffeeGlass.glb",Vector3(x-side*2.15,0.02,-5.4),Vector3(1.05,1.05,1.05),Vector3.ZERO,Color("8edee1"),Vector3(1.25,0.55,0.9),0.55)
		_place_model(lounge,"KenneyLoungeChair","res://assets/models/kenney/loungeDesignChair.glb",Vector3(x-side*2.5,0.02,-8.2),Vector3(1.08,1.08,1.08),Vector3(0,-35*side,0),CORAL if side<0 else MINT,Vector3(1.0,1.0,1.0))
		_place_model(lounge,"KenneyFloorLamp","res://assets/models/kenney/lampRoundFloor.glb",Vector3(x+side*2.3,0.02,-8.3),Vector3(1.05,1.05,1.05),Vector3.ZERO,Color("b8c8d8"),Vector3(0.52,1.85,0.52))
		_sphere(lounge, "BubbleLamp", Vector3(x + side * 1.8, 1.15, -6.2), 0.55, Color("f8b4cd"), false, PINK, 0.7, 0.35)
		var torus := TorusMesh.new(); torus.inner_radius = 0.68; torus.outer_radius = 0.75
		var ring := MeshInstance3D.new(); ring.mesh = torus; ring.position = Vector3(x, 1.3, -8.0); ring.rotation_degrees.x = 90
		ring.material_override = _material(Color("aab8c8"), CYAN, 0.25); lounge.add_child(ring)

func _build_bar() -> void:
	var bar := Node3D.new(); bar.name = "MintBar"; world.add_child(bar)
	_box(bar, "BarBody", Vector3(13.0, 1.0, 8.0), Vector3(10, 2, 2.2), MINT.darkened(0.25), true, CYAN, 0.20, 0.78)
	_box(bar, "Counter", Vector3(13.0, 2.12, 8.0), Vector3(10.4, 0.22, 2.5), Color("b8c3cc"), true)
	_box(bar,"CounterFrontBevel",Vector3(13.0,2.23,6.77),Vector3(10.2,0.09,0.10),Color("d2e2e4"),false,MINT,0.22)
	_box(bar,"CounterBackBevel",Vector3(13.0,2.23,9.23),Vector3(10.2,0.09,0.10),Color("c7d4dd"),false,CYAN,0.12)
	_box(bar, "LightStrip", Vector3(13.0, 0.35, 6.86), Vector3(9.2, 0.12, 0.08), MINT, false, MINT, 1.5)
	for i in range(5):
		var x := 9.0 + i * 2.0
		_place_model(bar,"KenneyBarStool","res://assets/models/kenney/stoolBar.glb",Vector3(x,0.02,5.45),Vector3(0.96,0.96,0.96),Vector3.ZERO,CORAL if i%2==0 else PINK,Vector3(0.68,1.18,0.68))
	for i in range(4): _cylinder(bar, "Glass", Vector3(10.0 + i * 1.7, 2.45, 7.6), 0.13, 0.5, Color("a6ebec"), false, Vector3.ZERO, 0.34)

func _build_coast() -> void:
	# The club occupies an upper floor. The balcony remains at club level while the
	# street, beach and ocean sit eighteen metres below and are scenery only.
	var terrace := _box(world, "ElevatedBalcony", Vector3(0, -0.32, -20), Vector3(40, 0.64, 12), Color.WHITE, true)
	terrace.material_override = _textured_material("res://assets/textures/terrazzo_pink.png", Vector3(4.0, 4.0, 4.0), 0.62)
	_box(world, "BalconyUnderside", Vector3(0, -0.78, -20), Vector3(40.5, 0.28, 12.5), Color("4a3b58"), false)
	# Continuous glass and metal guardrail: there is no route to the street layer.
	for x in [-13.0, 0.0, 13.0]:
		_box(world, "GlassGuard", Vector3(x, 0.72, -25.78), Vector3(12.6, 1.25, 0.10), Color("78d6dd"), true, Color.BLACK, 0.0, 0.30)
		_box(world, "GuardTop", Vector3(x, 1.42, -25.78), Vector3(12.8, 0.10, 0.14), Color("9eb4bd"), false)
	for x in [-19.5, 19.5]:
		_box(world, "BalconySideGuard", Vector3(x, 0.72, -20), Vector3(0.12, 1.35, 12), Color("90cbd0"), true, Color.BLACK, 0.0, 0.34)
	# Tall invisible blockers preserve the open view while making the balcony jump-safe.
	_box(world,"BalconyJumpBlocker",Vector3(0,2.5,-25.95),Vector3(40.0,5.0,0.20),Color(0,0,0,0),true,Color.BLACK,0.0,0.0)
	for x in [-19.72,19.72]: _box(world,"BalconySideJumpBlocker",Vector3(x,2.5,-20),Vector3(0.18,5.0,12.0),Color(0,0,0,0),true,Color.BLACK,0.0,0.0)
	for x in [-19.2,-13.0,-6.5,0.0,6.5,13.0,19.2]:
		_cylinder(world, "GuardPost", Vector3(x, 0.62, -25.78), 0.055, 1.35, Color("aab9c2"), false)
	# Slim canopy and dedicated balcony furniture.
	for x in [-18.5, 18.5]:
		_cylinder(world, "CanopyPost", Vector3(x, 2.3, -19.0), 0.11, 4.6, Color("657989"), true)
	_box(world, "CanopyBeam", Vector3(0, 4.55, -19.0), Vector3(37.2, 0.16, 0.18), Color("8198a5"), false)
	for x in [-14.0, -7.0, 7.0, 14.0]:
		_build_balcony_chair(Vector3(x, 0.0, -22.0), 0.0 if x < 0 else 180.0)
	for x in [-10.5, 10.5]:
		_cylinder(world, "BalconyTable", Vector3(x, 0.63, -21.8), 0.72, 0.10, Color("b8e0df"), true, Vector3.ZERO, 0.32)
		_cylinder(world, "BalconyTableStem", Vector3(x, 0.32, -21.8), 0.08, 0.64, Color("879ca8"), true)
	# Club tower and facade visibly continue down to the street.
	_box(world, "ClubTower", Vector3(0, -9.1, 0), Vector3(40, 17.8, 28), Color("383147"), false)
	for floor_y in [-3.0, -6.5, -10.0, -13.5]:
		for x in range(-17, 18, 4):
			_box(world, "FacadeWindow", Vector3(float(x), floor_y, -14.05), Vector3(2.4, 1.7, 0.06), Color("243a55"), false, CYAN if int(x / 4) % 2 == 0 else PINK, 0.12)
	# Correct land order: road and city promenade, then beach, then the tide line.
	_box(world, "CoastRoad", Vector3(0, -17.98, -28.5), Vector3(90, 0.18, 6.0), Color("393947"), false)
	for x in range(-42, 43, 7):
		_box(world, "RoadMark", Vector3(float(x), -17.86, -28.5), Vector3(3.5, 0.025, 0.12), Color("e5d6b3"), false)
	_box(world,"CityPromenade",Vector3(0,-18.12,-33.1),Vector3(90,0.24,7.5),Color("827584"),false)
	var beach:=_box(world, "Beach", Vector3(0, -18.25, -44.0), Vector3(90, 0.30, 13.0), Color.WHITE, false)
	beach.material_override=_textured_material("res://assets/textures/beach_sand_v2.png",Vector3(11.0,4.5,11.0),0.88)
	# Ocean begins after the sand at z=-50.75 and continues beyond the visual horizon.
	var ocean_mesh := PlaneMesh.new(); ocean_mesh.size = Vector2(180, 180); ocean_mesh.subdivide_width = 96; ocean_mesh.subdivide_depth = 72
	var ocean := MeshInstance3D.new(); ocean.name = "OceanScenery"; ocean.mesh = ocean_mesh; ocean.position = Vector3(0, -18.25, -140.75)
	var ocean_mat := ShaderMaterial.new(); ocean_mat.shader = load("res://shaders/ocean.gdshader"); ocean.material_override = ocean_mat; world.add_child(ocean)
	_build_sea_spray()
	_sphere(world, "Sunset", Vector3(-28, 1.5, -216), 4.8, CORAL.lightened(0.18), false, CORAL, 2.0)
	_build_distant_skyline()
	_build_night_city_backdrop()
	# Street palms start at the true ground level and frame the downward view.
	for item in [[-17.0,-29.5,0.1],[-9.0,-34.0,1.4],[13.0,-29.5,2.3],[22.0,-34.0,3.0]]:
		_build_palm(Vector3(item[0], -18.0, item[1]), item[2])
	for x in [-35.0,-21.0,-7.0,7.0,21.0,35.0]: _build_street_lamp(Vector3(x,-17.9,-30.5))
	for item in [[-28.0,-40.0,0],[-14.0,-44.0,1],[2.0,-39.0,2],[18.0,-45.0,3],[31.0,-41.5,4]]:
		_build_beach_parasol(Vector3(item[0],-18.06,item[1]),item[2])
	_box(world,"BeachBoardwalk",Vector3(0,-18.02,-44.0),Vector3(4.0,0.10,12.5),Color("d9c2a4"),false)
	# A small distant lifeguard pavilion adds readable scale to the drop from the balcony.
	_box(world,"LifeguardHut",Vector3(-23.0,-16.55,-46.0),Vector3(4.2,2.6,3.2),Color("e99ab2"),false)
	_box(world,"LifeguardRoof",Vector3(-23.0,-15.12,-46.0),Vector3(5.0,0.22,3.8),Color("87d2cf"),false)
	for x in [-24.5,-21.5]: _cylinder(world,"HutLeg",Vector3(x,-17.28,-46.0),0.10,1.45,Color("a99a89"),false)
	# Irregular towers now stand entirely on the land promenade behind the beach.
	var towers=[[Vector3(-43,-18,-33),11.0,8.5,0],[Vector3(-33,-18,-32),17.0,7.0,1],[Vector3(-21,-18,-33),13.0,7.5,2],[Vector3(-9,-18,-34),21.0,6.5,3],[Vector3(9,-18,-34),15.0,7.0,4],[Vector3(21,-18,-33),22.0,6.5,5],[Vector3(33,-18,-32),13.0,8.0,6],[Vector3(43,-18,-33),18.0,7.0,7]]
	for i in range(towers.size()):
		var data=towers[i]; var color:Color=[MINT,CORAL,Color("9cc9de"),CREAM][i%4]
		_build_irregular_tower(data[0] as Vector3,float(data[1]),float(data[2]),color,int(data[3]))

func _build_balcony_chair(pos: Vector3, yaw: float) -> void:
	var chair := Node3D.new(); chair.name = "BalconyChair"; chair.position = pos; chair.rotation_degrees.y = yaw; world.add_child(chair)
	_place_model(chair,"KenneyRelaxChair","res://assets/models/kenney/loungeChairRelax.glb",Vector3.ZERO,Vector3(1.10,1.10,1.10),Vector3.ZERO,Color("e6a4c5"),Vector3(1.0,1.1,1.28))

func _build_night_city_backdrop() -> void:
	var city:=Node3D.new(); city.name="RearNightCityScenery"; world.add_child(city)
	# A deep foundation below every exterior layer guarantees no camera angle reveals the void.
	var foundation:=_box(city,"WorldFoundation",Vector3(0,-18.62,30),Vector3(620,0.55,560),Color("0b0e1b"),false)
	var foundation_mat:=StandardMaterial3D.new(); foundation_mat.albedo_color=Color("0b0f1d"); foundation_mat.roughness=0.92; foundation.material_override=foundation_mat
	# Continuous lower-level terrain closes the void behind and beside the club.
	var ground:=_box(city,"NightCityGround",Vector3(0,-18.28,48),Vector3(190,0.34,138),Color("111427"),false)
	var ground_mat:=StandardMaterial3D.new(); ground_mat.albedo_color=Color("101326"); ground_mat.roughness=0.72; ground_mat.metallic=0.18; ground.material_override=ground_mat
	# Main avenues and a luminous secondary grid establish city scale from the balcony.
	for x in [-72.0,-48.0,-24.0,0.0,24.0,48.0,72.0]:
		_box(city,"NightAvenue",Vector3(x,-18.08,48),Vector3(5.2,0.05,136),Color("20243a"),false)
		_box(city,"AvenueNeon",Vector3(x,-18.02,48),Vector3(0.10,0.025,134),CYAN if int(abs(x)/24.0)%2==0 else PINK,false,CYAN if int(abs(x)/24.0)%2==0 else PINK,0.42)
	for z in [-12.0,12.0,36.0,60.0,84.0,108.0]:
		_box(city,"NightCrossStreet",Vector3(0,-18.06,z),Vector3(188,0.06,4.5),Color("24263d"),false)
		for lane in [-1.25,1.25]: _box(city,"RoadLightTrail",Vector3(0,-18.0,z+lane),Vector3(184,0.024,0.055),CORAL if lane<0 else CYAN,false,CORAL if lane<0 else CYAN,0.26)
	var tower_positions=[
		Vector3(-84,-18,-4),Vector3(-66,-18,18),Vector3(-86,-18,48),Vector3(-62,-18,72),Vector3(-82,-18,104),
		Vector3(84,-18,-2),Vector3(64,-18,24),Vector3(86,-18,54),Vector3(62,-18,82),Vector3(84,-18,110),
		Vector3(-38,-18,42),Vector3(-40,-18,92),Vector3(38,-18,46),Vector3(42,-18,96),Vector3(-13,-18,75),Vector3(14,-18,112)
	]
	for i in range(tower_positions.size()):
		var height:=18.0+float((i*13)%24); var width:=7.0+float((i*7)%5); var palette=[Color("446484"),Color("70466f"),Color("315f68"),Color("615276")]
		_build_irregular_tower(tower_positions[i],height,width,palette[i%palette.size()],20+i)
	# Low distant silhouettes extend beyond the detailed blocks and fade into fog.
	for i in range(22):
		var x:=-105.0+float(i)*10.0; var h:=10.0+float((i*11)%25)
		var block:=_box(city,"NightCityDistant",Vector3(x,-18.0+h*0.5,124.0+float(i%3)*5.0),Vector3(7.5,h,8.0),Color("161a32"),false,Color("293b66"),0.08)
		block.visibility_range_begin=42.0; block.visibility_range_begin_margin=12.0; block.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

func _build_sea_spray() -> void:
	var spray:=GPUParticles3D.new(); spray.name="ShorelineSeaSpray"; spray.position=Vector3(0,-17.72,-50.5); spray.amount=340; spray.lifetime=3.8; spray.randomness=0.68; spray.visibility_aabb=AABB(Vector3(-48,-2,-4),Vector3(96,9,8))
	var process:=ParticleProcessMaterial.new(); process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX; process.emission_box_extents=Vector3(45,0.15,1.0); process.direction=Vector3(0,1,0.15); process.spread=38.0; process.gravity=Vector3(0,-0.24,0); process.initial_velocity_min=0.35; process.initial_velocity_max=1.45; process.scale_min=0.18; process.scale_max=0.72; process.color=Color(0.72,0.94,1.0,0.26); spray.process_material=process
	var quad:=QuadMesh.new(); quad.size=Vector2(0.24,0.13); var mat:=StandardMaterial3D.new(); mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED; mat.albedo_color=Color(0.78,0.95,1.0,0.38); mat.emission_enabled=true; mat.emission=Color("b8f2ff"); mat.emission_energy_multiplier=0.28; quad.material=mat; spray.draw_pass_1=quad; world.add_child(spray)

func _build_street_lamp(pos: Vector3) -> void:
	var lamp := Node3D.new(); lamp.name = "StreetLampScenery"; lamp.position = pos; world.add_child(lamp)
	_cylinder(lamp,"Pole",Vector3(0,2.1,0),0.055,4.2,Color("66717c"),false)
	_sphere(lamp,"Globe",Vector3(0,4.25,0),0.24,Color("ffd6b5"),false,CORAL,0.8)

func _build_beach_parasol(pos: Vector3, variant: int) -> void:
	var root:=Node3D.new(); root.name="BeachParasolScenery"; root.position=pos; world.add_child(root)
	_cylinder(root,"Pole",Vector3(0,1.15,0),0.045,2.3,Color("9b8f8b"),false)
	var canopy_mesh:=CylinderMesh.new(); canopy_mesh.top_radius=0.10; canopy_mesh.bottom_radius=1.25; canopy_mesh.height=0.48; canopy_mesh.radial_segments=18
	var canopy:=MeshInstance3D.new(); canopy.mesh=canopy_mesh; canopy.position=Vector3(0,2.25,0); var palette=[CORAL,PINK,MINT,Color("9ec7df"),CREAM]; var color:Color=palette[variant%palette.size()]; canopy.material_override=_material(color,color,0.12); root.add_child(canopy)
	_box(root,"BeachTowel",Vector3(1.35,0.05,0.35),Vector3(1.45,0.04,0.72),color.lightened(0.18),false)

func _build_irregular_tower(pos: Vector3, height: float, width: float, color: Color, variant: int) -> void:
	var root:=Node3D.new(); root.name="IrregularLandTower"; root.position=pos; root.rotation_degrees.y=float((variant%3)-1)*2.2; world.add_child(root)
	var lower_h:=height*0.46; var middle_h:=height*0.32; var upper_h:=height-lower_h-middle_h
	_tower_segment(root,Vector3(0,lower_h*0.5,0),Vector3(width,lower_h,5.4),color,1.0)
	var middle_shift:=(-0.55 if variant%2==0 else 0.62)
	_tower_segment(root,Vector3(middle_shift,lower_h+middle_h*0.5,-0.28),Vector3(width*0.76,middle_h,4.6),color.lightened(0.05),0.85)
	var upper_shift:=middle_shift+(-0.42 if variant%3==0 else 0.34)
	_tower_segment(root,Vector3(upper_shift,lower_h+middle_h+upper_h*0.5,-0.52),Vector3(width*0.54,upper_h,3.7),color.darkened(0.04),0.72)
	_box(root,"RoofCap",Vector3(upper_shift,height+0.18,-0.52),Vector3(width*0.62,0.32,4.0),Color("b7b1b7"),false)
	if variant%2==1:
		_cylinder(root,"RoofAntenna",Vector3(upper_shift,height+1.15,-0.52),0.045,1.9,Color("9aa9b4"),false)
	else:
		_box(root,"RoofCrown",Vector3(upper_shift,height+0.72,-0.52),Vector3(width*0.20,1.1,1.1),color.lightened(0.12),false,color,0.18)

func _tower_segment(root: Node, pos: Vector3, size: Vector3, color: Color, uv_scale: float) -> void:
	_box(root,"TowerMass",pos,size,color.darkened(0.20),false)
	var facade:=_box(root,"TowerFacade",Vector3(pos.x,pos.y,pos.z+size.z*0.5+0.035),Vector3(size.x*0.92,size.y*0.94,0.055),Color.WHITE,false)
	var mat:=_textured_material("res://assets/textures/art_deco_facade.png",Vector3(uv_scale,maxf(1.0,size.y/6.5),1.0),0.74); mat.albedo_color=color.lightened(0.16); facade.material_override=mat
	var back:=_box(root,"TowerFacadeBack",Vector3(pos.x,pos.y,pos.z-size.z*0.5-0.035),Vector3(size.x*0.92,size.y*0.94,0.055),Color.WHITE,false); back.material_override=mat
	var side_l:=_box(root,"TowerFacadeSideL",Vector3(pos.x-size.x*0.5-0.035,pos.y,pos.z),Vector3(0.055,size.y*0.94,size.z*0.90),Color.WHITE,false); side_l.material_override=mat
	var side_r:=_box(root,"TowerFacadeSideR",Vector3(pos.x+size.x*0.5+0.035,pos.y,pos.z),Vector3(0.055,size.y*0.94,size.z*0.90),Color.WHITE,false); side_r.material_override=mat
	_box(root,"FacadeGlowBand",Vector3(pos.x,pos.y-size.y*0.22,pos.z+size.z*0.5+0.075),Vector3(size.x*0.74,0.075,0.07),color,false,color,0.34)

func _build_distant_skyline() -> void:
	var quad:=QuadMesh.new(); quad.size=Vector2(480,100)
	var skyline:=MeshInstance3D.new(); skyline.name="DistantSkylineBillboard"; skyline.mesh=quad; skyline.position=Vector3(0,1.0,-222); skyline.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat:=StandardMaterial3D.new(); mat.albedo_texture=load("res://assets/textures/distant_skyline_alpha.png"); mat.albedo_color=Color(0.74,0.76,0.92,0.70); mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.cull_mode=BaseMaterial3D.CULL_DISABLED; mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC; skyline.material_override=mat; world.add_child(skyline)

func _build_architectural_details() -> void:
	# Framed portal clearly marks the transition from club to elevated balcony.
	for x in [-4.15, 4.15]:
		_box(world, "BalconyDoorFrame", Vector3(x, 4.0, -14.08), Vector3(0.22, 8.0, 0.28), Color("8299a8"), true)
	_box(world, "BalconyDoorHeader", Vector3(0, 7.85, -14.08), Vector3(8.5, 0.22, 0.28), Color("8299a8"), false)
	# Sculptural fluted pilasters soften the long side walls.
	for side in [-1.0, 1.0]:
		for z in [-10.0,-4.0,3.0,9.0]:
			for offset in [-0.34,0.0,0.34]:
				_capsule(world,"WallFlute",Vector3(side * 19.68,3.1,z + offset),0.16,4.8,PURPLE.lightened(0.08),false,Vector3(0,0,0))
	# Balcony planters are real modeled props with collision; foliage remains light.
	for x in [-17.0,17.0]:
		_place_model(world,"KenneyBalconyPlant","res://assets/models/kenney/plantSmall2.glb",Vector3(x,0.02,-23.8),Vector3(1.28,1.28,1.28),Vector3.ZERO,MINT,Vector3(0.82,1.18,0.82))
	# Layered ceiling pendants and subtle wayfinding strip.
	for x in [-9.0, 9.0]:
		var torus := TorusMesh.new(); torus.inner_radius = 0.78; torus.outer_radius = 0.84
		var ring := MeshInstance3D.new(); ring.name = "PendantRing"; ring.mesh = torus; ring.position = Vector3(x,7.15,-7.8); ring.rotation_degrees.x = 90; ring.material_override = _material(Color("879ba9"), MINT, 0.45); world.add_child(ring)
		_cylinder(world,"PendantStem",Vector3(x,8.0,-7.8),0.025,1.7,Color("7f8d99"),false)
	_box(world,"BalconyThresholdLight",Vector3(0,0.08,-13.9),Vector3(7.6,0.04,0.10),MINT,false,MINT,0.8)

func _build_render_details() -> void:
	# Local cubemap stabilizes chrome, glass and wet-looking PBR reflections indoors.
	var probe:=ReflectionProbe.new(); probe.name="ClubReflectionProbe"; probe.position=Vector3(0,4.2,0); probe.size=Vector3(39,8.2,27); probe.origin_offset=Vector3(0,0.8,0); probe.intensity=0.82; probe.box_projection=true; probe.update_mode=ReflectionProbe.UPDATE_ONCE; world.add_child(probe)
	# Floating dust catches the disco shafts and provides scale in volumetric fog.
	var dust:=GPUParticles3D.new(); dust.name="AtmosphericDustGPU"; dust.position=Vector3(0,4.2,0); dust.amount=260; dust.lifetime=9.0; dust.randomness=0.72; dust.visibility_aabb=AABB(Vector3(-20,-5,-14),Vector3(40,10,28))
	var particle_mat:=ParticleProcessMaterial.new(); particle_mat.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX; particle_mat.emission_box_extents=Vector3(19,4,13); particle_mat.direction=Vector3(0,1,0); particle_mat.spread=180.0; particle_mat.gravity=Vector3(0,0.012,0); particle_mat.initial_velocity_min=0.006; particle_mat.initial_velocity_max=0.035; particle_mat.scale_min=0.35; particle_mat.scale_max=1.0; particle_mat.color=Color(0.72,0.92,1.0,0.22); dust.process_material=particle_mat
	var dust_quad:=QuadMesh.new(); dust_quad.size=Vector2(0.022,0.022); dust_quad.orientation=PlaneMesh.FACE_Z; var dust_mat:=StandardMaterial3D.new(); dust_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; dust_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; dust_mat.albedo_color=Color(0.8,0.95,1.0,0.48); dust_mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED; dust_mat.emission_enabled=true; dust_mat.emission=Color("bdefff"); dust_mat.emission_energy_multiplier=0.55; dust_quad.material=dust_mat; dust.draw_pass_1=dust_quad; world.add_child(dust)
	# Repeated ceiling fasteners use one draw call instead of hundreds of nodes.
	var mm:=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D; mm.instance_count=128; var bolt_mesh:=BoxMesh.new(); bolt_mesh.size=Vector3(0.045,0.025,0.16); bolt_mesh.material=_material(Color("8799aa"),CYAN,0.16); mm.mesh=bolt_mesh
	for i in range(mm.instance_count):
		var row:=i/16; var col:=i%16; var x:=-17.0+float(col)*2.27; var z:=-11.5+float(row)*3.25; mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(x,8.84,z)))
	var mm_node:=MultiMeshInstance3D.new(); mm_node.name="CeilingFastenersMultiMesh"; mm_node.multimesh=mm; mm_node.visibility_range_end=65.0; mm_node.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF; world.add_child(mm_node)
	# Large opaque architecture acts as explicit occluders for furniture and props.
	for data in [[Vector3(-20,4.5,0),Vector3(0.6,9,28)],[Vector3(20,4.5,0),Vector3(0.6,9,28)],[Vector3(0,4.5,14),Vector3(40,9,0.6)]]:
		var occ:=OccluderInstance3D.new(); var box_occ:=BoxOccluder3D.new(); box_occ.size=data[1]; occ.occluder=box_occ; occ.position=data[0]; world.add_child(occ)

func _build_collectibles() -> void:
	_build_pickup(Vector3(-8.4,1.05,-5.55),"orbit_disc","Orbit MiniDisc","disc",Color("aee8f0"))
	_build_pickup(Vector3(8.4,1.18,-5.55),"aero_orb","Aero 果冻光球","orb",Color("86e2cf"))
	_build_pickup(Vector3(-16.8,1.05,5.2),"keyframe_crystal","关键帧水晶","diamond",Color("dc8fd5"))
	_build_pickup(Vector3(13.0,2.65,7.55),"chrome_phone","透明翻盖终端","phone",Color("9bcfe6"))
	_build_pickup(Vector3(0.0,1.48,8.15),"memory_capsule","Memory 胶囊","capsule",Color("f3a6c0"))
	_build_breakable(Vector3(-17.3,1.0,-1.8),"左侧 AE 记忆泡泡",CYAN)
	_build_breakable(Vector3(17.3,1.0,-1.8),"右侧 AE 记忆泡泡",PINK)

func _build_dance_balls() -> void:
	var ball_data=[
		[Vector3(-5.0,0.62,2.2),0.58,PINK],
		[Vector3(4.2,0.48,-1.5),0.44,CYAN],
		[Vector3(-2.0,0.39,-4.2),0.35,MINT],
		[Vector3(7.0,0.72,4.5),0.68,CORAL],
		[Vector3(1.4,0.52,6.0),0.48,Color("b99be5")]
	]
	for i in range(ball_data.size()):
		var data=ball_data[i]
		var ball:=RigidBody3D.new(); ball.set_script(load("res://scripts/items/throwable_item.gd")); ball.name="DanceBall%02d"%i; ball.position=data[0]; ball.mass=0.55+float(data[1]); ball.continuous_cd=true
		ball.set("item_data",{"id":"dance_ball_%02d"%i,"name":"霓虹舞池球 %02d"%(i+1),"shape":"throw_ball","color":data[2],"radius":float(data[1])})
		ball.linear_damp=0.16; ball.angular_damp=0.08; ball.contact_monitor=true; ball.max_contacts_reported=4
		var physics:=PhysicsMaterial.new(); physics.friction=0.72; physics.bounce=0.46; ball.physics_material_override=physics
		var mesh:=SphereMesh.new(); mesh.radius=float(data[1]); mesh.height=float(data[1])*2.0; mesh.radial_segments=24; mesh.rings=12
		var visual:=MeshInstance3D.new(); visual.mesh=mesh; visual.material_override=_material(data[2],data[2],0.18); ball.add_child(visual)
		var collision:=CollisionShape3D.new(); var shape:=SphereShape3D.new(); shape.radius=float(data[1]); collision.shape=shape; ball.add_child(collision)
		world.add_child(ball)
		ball.body_entered.connect(func(_body:Node): _on_ball_collision(ball))
	# Floating keyframe diamonds echo early motion-graphics interfaces.
	for side in [-1.0,1.0]:
		for i in range(3):
			var cube:=BoxMesh.new(); cube.size=Vector3(0.34,0.34,0.08)
			var key:=MeshInstance3D.new(); key.name="KeyframeMotif"; key.mesh=cube; key.position=Vector3(side*(17.7-i*0.45),4.8+i*0.7,5.4+i*1.5); key.rotation_degrees=Vector3(0,0,45); key.material_override=_material(Color("9dbdce"),CYAN if side<0 else PINK,0.5); world.add_child(key)

func _build_pickup(pos: Vector3, id_: String, display_name: String, shape_type: String, color: Color) -> void:
	var pickup:=StaticBody3D.new(); pickup.name="Pickup_"+id_; pickup.position=pos; pickup.set_script(load("res://scripts/items/pickup_item.gd")); pickup.set("item_id",id_); pickup.set("item_display_name",display_name); pickup.set("item_shape",shape_type); pickup.set("item_color",color)
	var mesh_instance:=MeshInstance3D.new(); mesh_instance.name="CollectibleMesh"
	if shape_type=="disc":
		var mesh:=CylinderMesh.new(); mesh.top_radius=0.38; mesh.bottom_radius=0.38; mesh.height=0.10; mesh.radial_segments=24; mesh_instance.mesh=mesh; mesh_instance.rotation_degrees.x=90
	elif shape_type=="capsule":
		var mesh:=CapsuleMesh.new(); mesh.radius=0.20; mesh.height=0.72; mesh.radial_segments=20; mesh.rings=8; mesh_instance.mesh=mesh; mesh_instance.rotation_degrees.z=35
	elif shape_type=="phone":
		var mesh:=BoxMesh.new(); mesh.size=Vector3(0.48,0.72,0.12); mesh_instance.mesh=mesh; mesh_instance.rotation_degrees.z=-12
	elif shape_type=="diamond":
		var mesh:=BoxMesh.new(); mesh.size=Vector3(0.48,0.48,0.48); mesh_instance.mesh=mesh; mesh_instance.rotation_degrees=Vector3(22,30,45)
	else:
		var mesh:=SphereMesh.new(); mesh.radius=0.32; mesh.height=0.64; mesh.radial_segments=20; mesh.rings=10; mesh_instance.mesh=mesh
	var holo:=_textured_material("res://assets/textures/holographic_foil.png",Vector3(1.4,1.4,1.4),0.18); holo.albedo_color=color; holo.metallic=0.42; holo.emission_enabled=true; holo.emission=color; holo.emission_energy_multiplier=0.28; mesh_instance.material_override=holo; pickup.add_child(mesh_instance)
	var collision:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=Vector3(0.72,0.82,0.72); collision.shape=shape; pickup.add_child(collision)
	var label:=_label3d(pickup,"ItemLabel",display_name,Vector3(0,0.68,0),34,color); label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.pixel_size=0.004
	world.add_child(pickup)

func _build_breakable(pos: Vector3, display_name: String, color: Color) -> void:
	var body:=StaticBody3D.new(); body.name="BreakableSculpture"; body.position=pos; body.set_script(load("res://scripts/items/breakable_sculpture.gd")); body.set("sculpture_name",display_name)
	var orb:=SphereMesh.new(); orb.radius=0.52; orb.height=1.04; orb.radial_segments=20; orb.rings=10
	var mesh:=MeshInstance3D.new(); mesh.mesh=orb; mesh.position=Vector3(0,0.55,0); var holo:=_textured_material("res://assets/textures/holographic_foil.png",Vector3(1,1,1),0.12); holo.albedo_color=Color(color.r,color.g,color.b,0.72); holo.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; holo.emission_enabled=true; holo.emission=color; holo.emission_energy_multiplier=0.45; mesh.material_override=holo; body.add_child(mesh)
	var ring_mesh:=TorusMesh.new(); ring_mesh.inner_radius=0.68; ring_mesh.outer_radius=0.74
	var ring:=MeshInstance3D.new(); ring.mesh=ring_mesh; ring.position=Vector3(0,0.55,0); ring.rotation_degrees.x=90; ring.material_override=_material(color,color,0.65); body.add_child(ring)
	var collision:=CollisionShape3D.new(); collision.position=Vector3(0,0.55,0); var sphere_shape:=SphereShape3D.new(); sphere_shape.radius=0.58; collision.shape=sphere_shape; body.add_child(collision)
	world.add_child(body)

func _build_palm(pos: Vector3, phase: float) -> void:
	var palm := Node3D.new(); palm.name = "PalmTree"; palm.position = pos; palm.set_script(load("res://scripts/environment/palm_wind.gd")); palm.set("phase", phase); world.add_child(palm)
	_cylinder(palm, "Trunk", Vector3(0, 2.7, 0), 0.28, 5.4, Color("8d664f"), true)
	for i in range(7):
		var leaf := CapsuleMesh.new(); leaf.radius = 0.18; leaf.height = 3.3
		var mesh := MeshInstance3D.new(); mesh.mesh = leaf; mesh.position = Vector3(0, 5.45, 0); mesh.rotation_degrees = Vector3(62, i * 51.4, 0); mesh.material_override = _material(Color("3d8e72")); palm.add_child(mesh)

func _build_ui() -> void:
	var layer := CanvasLayer.new(); layer.layer = 10; add_child(layer)
	# HUD
	var hud := Control.new(); hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(hud)
	var cross := Label.new(); cross.text = "+"; cross.add_theme_font_size_override("font_size", 23); cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_set_rect(cross, 0.5, 0.5, 0.5, 0.5, -18, -18, 18, 18); hud.add_child(cross)
	prompt_label = Label.new(); prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; prompt_label.add_theme_font_size_override("font_size", 19); prompt_label.add_theme_color_override("font_color", Color.WHITE)
	_set_rect(prompt_label, 0.25, 0.78, 0.75, 0.85, 0, 0, 0, 0); hud.add_child(prompt_label)
	toast_label = Label.new(); toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; toast_label.add_theme_font_size_override("font_size", 20); toast_label.add_theme_color_override("font_color", MINT); toast_label.visible = false
	_set_rect(toast_label, 0.22, 0.12, 0.78, 0.19, 0, 0, 0, 0); hud.add_child(toast_label)
	debug_label = Label.new(); debug_label.position = Vector2(18,18); debug_label.visible = false; debug_label.add_theme_font_size_override("font_size", 14); hud.add_child(debug_label)
	clock_label=Label.new(); clock_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; clock_label.add_theme_font_size_override("font_size",18); clock_label.add_theme_color_override("font_color",Color("bffaff")); clock_label.text="18:30  黄昏"; _set_rect(clock_label,1.0,0.0,1.0,0.0,-260,18,-22,52); hud.add_child(clock_label)
	performance_label=Label.new(); performance_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; performance_label.add_theme_font_size_override("font_size",14); performance_label.add_theme_color_override("font_color",Color("d7f6ff")); performance_label.text="FPS --   PING --"; _set_rect(performance_label,1.0,0.0,1.0,0.0,-300,50,-22,78); hud.add_child(performance_label)
	weapon_label=Label.new(); weapon_label.visible=false; weapon_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; weapon_label.add_theme_font_size_override("font_size",20); weapon_label.add_theme_color_override("font_color",Color("f5d7a8")); _set_rect(weapon_label,1.0,1.0,1.0,1.0,-350,-142,-24,-102); hud.add_child(weapon_label)
	health_label=Label.new(); health_label.add_theme_font_size_override("font_size",24); health_label.add_theme_color_override("font_color",Color("ff789f")); _set_rect(health_label,0.0,1.0,0.0,1.0,24,-92,260,-46); hud.add_child(health_label)
	duel_label=Label.new(); duel_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; duel_label.add_theme_font_size_override("font_size",22); duel_label.add_theme_color_override("font_color",Color("ffffff")); _set_rect(duel_label,0.5,0.0,0.5,0.0,-240,18,240,62); hud.add_child(duel_label)
	damage_flash=ColorRect.new(); damage_flash.color=Color(0.75,0.01,0.03,0.0); damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); damage_flash.mouse_filter=Control.MOUSE_FILTER_IGNORE; hud.add_child(damage_flash)
	round_result_overlay=ColorRect.new(); round_result_overlay.color=Color(0.02,0.01,0.06,0.0); round_result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); round_result_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE; round_result_overlay.visible=false; hud.add_child(round_result_overlay)
	round_result_label=Label.new(); round_result_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; round_result_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; round_result_label.add_theme_font_size_override("font_size",58); round_result_label.add_theme_color_override("font_color",Color("fff0a6")); _set_rect(round_result_label,0.15,0.36,0.85,0.64,0,0,0,0); round_result_overlay.add_child(round_result_label)
	var inventory_bar:=HBoxContainer.new(); inventory_bar.name="InventoryBar"; inventory_bar.alignment=BoxContainer.ALIGNMENT_CENTER; inventory_bar.add_theme_constant_override("separation",8); _set_rect(inventory_bar,0.5,1.0,0.5,1.0,-294,-88,294,-20); hud.add_child(inventory_bar)
	for i in range(5):
		var slot:=PanelContainer.new(); slot.custom_minimum_size=Vector2(110,62); slot.add_theme_stylebox_override("panel",_inventory_style(false)); inventory_bar.add_child(slot); inventory_slots.append(slot)
		var vb:=VBoxContainer.new(); vb.alignment=BoxContainer.ALIGNMENT_CENTER; vb.add_theme_constant_override("separation",0); slot.add_child(vb)
		var number:=Label.new(); number.text=str(i+1); number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; number.add_theme_font_size_override("font_size",13); number.add_theme_color_override("font_color",Color("8fdde0")); vb.add_child(number)
		var item_name:=Label.new(); item_name.name="ItemName"; item_name.text="—"; item_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; item_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; item_name.add_theme_font_size_override("font_size",14); vb.add_child(item_name)
	# Capsule reveal overlay; it never blocks mouse control and fades automatically.
	capsule_result_overlay=ColorRect.new(); capsule_result_overlay.color=Color(0.025,0.02,0.08,0.72); capsule_result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); capsule_result_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE; capsule_result_overlay.visible=false; layer.add_child(capsule_result_overlay)
	var reveal_panel:=PanelContainer.new(); reveal_panel.custom_minimum_size=Vector2(400,500); _set_rect(reveal_panel,0.5,0.5,0.5,0.5,-200,-250,200,250); capsule_result_overlay.add_child(reveal_panel)
	var reveal_style:=StyleBoxFlat.new(); reveal_style.bg_color=Color("14132d"); reveal_style.border_color=CYAN; reveal_style.set_border_width_all(3); reveal_style.corner_radius_top_left=26; reveal_style.corner_radius_top_right=26; reveal_style.corner_radius_bottom_left=26; reveal_style.corner_radius_bottom_right=26; reveal_style.content_margin_left=28; reveal_style.content_margin_right=28; reveal_style.content_margin_top=22; reveal_style.content_margin_bottom=22; reveal_panel.add_theme_stylebox_override("panel",reveal_style)
	var reveal_vb:=VBoxContainer.new(); reveal_vb.alignment=BoxContainer.ALIGNMENT_CENTER; reveal_vb.add_theme_constant_override("separation",10); reveal_panel.add_child(reveal_vb)
	var acquired:=Label.new(); acquired.text="CAPSULE OPEN · 获得贴纸"; acquired.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; acquired.add_theme_font_size_override("font_size",19); acquired.add_theme_color_override("font_color",MINT); reveal_vb.add_child(acquired)
	capsule_result_texture=TextureRect.new(); capsule_result_texture.custom_minimum_size=Vector2(330,330); capsule_result_texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; capsule_result_texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; reveal_vb.add_child(capsule_result_texture)
	capsule_result_name=Label.new(); capsule_result_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; capsule_result_name.add_theme_font_size_override("font_size",22); reveal_vb.add_child(capsule_result_name)
	capsule_result_rarity=Label.new(); capsule_result_rarity.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; capsule_result_rarity.add_theme_font_size_override("font_size",18); reveal_vb.add_child(capsule_result_rarity)
	toast_timer = Timer.new(); toast_timer.one_shot = true; toast_timer.wait_time = 2.8; toast_timer.timeout.connect(func(): toast_label.visible = false); add_child(toast_timer)
	# Start overlay
	start_panel = _overlay(layer, "NEON COAST CLUB", "高层海岸边的 Y2K / Aero 蒸汽波舞厅。\n\nWASD 移动　Space 跳跃　Shift 奔跑\nB 获取/切换武器　左键 开火/挥击　R 换弹\nE 互动/拿取　右键 使用/投掷　F 飞行\n滚轮 / 1–5 物品栏　T 时间　F11 全屏　Esc 暂停", "进入舞厅", _start_game)
	var start_column:=start_panel.get_node("Panel/VBox") as VBoxContainer
	var online_button:=Button.new(); online_button.text="登录并进入在线大厅"; online_button.custom_minimum_size.y=46; online_button.pressed.connect(func(): start_panel.visible=false; _open_multiplayer()); start_column.add_child(online_button)
	# Pause overlay
	pause_panel = _overlay(layer, "夜色暂停", "海风仍在玻璃幕墙之外流动。", "继续", _resume_game)
	pause_panel.visible = false
	var column := pause_panel.get_node("Panel/VBox") as VBoxContainer
	var reset := Button.new(); reset.text = "重置位置"; reset.custom_minimum_size.y = 42; reset.pressed.connect(func(): player.reset_to_spawn(); _resume_game()); column.add_child(reset)
	var multiplayer_button:=Button.new(); multiplayer_button.text="多人游戏"; multiplayer_button.custom_minimum_size.y=42; multiplayer_button.pressed.connect(_open_multiplayer); column.add_child(multiplayer_button)
	var quit := Button.new(); quit.text = "退出游戏"; quit.custom_minimum_size.y = 42; quit.pressed.connect(func(): get_tree().quit()); column.add_child(quit)
	_build_multiplayer_panel(layer)
	_wire_ui_audio(layer)

func _build_multiplayer_panel(layer:CanvasLayer) -> void:
	multiplayer_panel=_overlay(layer,"NEON COAST ONLINE","统一大厅 · 登录后创建或加入 1v1 房间","返回",_close_multiplayer); multiplayer_panel.visible=false
	var panel:=multiplayer_panel.get_node("Panel") as PanelContainer; panel.custom_minimum_size=Vector2(680,0); _set_rect(panel,0.5,0.04,0.5,0.96,-340,0,340,0)
	var column:=panel.get_node("VBox") as VBoxContainer
	panel.remove_child(column)
	var scroll:=ScrollContainer.new(); scroll.name="MultiplayerScroll"; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO; scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; panel.add_child(scroll)
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; column.add_theme_constant_override("separation",12); scroll.add_child(column)
	mp_user=LineEdit.new(); mp_user.placeholder_text="用户名（至少 3 位）"; column.add_child(mp_user)
	mp_password=LineEdit.new(); mp_password.placeholder_text="密码（至少 6 位）"; mp_password.secret=true; column.add_child(mp_password)
	var auth_row:=HBoxContainer.new(); column.add_child(auth_row)
	var login_button:=Button.new(); login_button.text="登录"; login_button.pressed.connect(_mp_login); auth_row.add_child(login_button)
	var register_button:=Button.new(); register_button.text="注册"; register_button.pressed.connect(_mp_register); auth_row.add_child(register_button)
	var server_label:=Label.new(); server_label.text="大厅服务器：%s:%d（自动连接）"%[NetworkSession.PUBLIC_HOST,NetworkSession.PUBLIC_PORT]; server_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; column.add_child(server_label)
	mp_room_list=ItemList.new(); mp_room_list.custom_minimum_size=Vector2(0,190); mp_room_list.item_selected.connect(_mp_select_room); column.add_child(mp_room_list)
	mp_invite=LineEdit.new(); mp_invite.placeholder_text="创建时输入房间名；加入时选择上方房间"; column.add_child(mp_invite)
	var room_row:=HBoxContainer.new(); column.add_child(room_row)
	var host_button:=Button.new(); host_button.text="创建房间"; host_button.pressed.connect(_mp_host); room_row.add_child(host_button)
	var join_button:=Button.new(); join_button.text="加入房间"; join_button.pressed.connect(_mp_join); room_row.add_child(join_button)
	var ready_button:=Button.new(); ready_button.text="准备 / 取消准备"; ready_button.pressed.connect(_mp_toggle_ready); column.add_child(ready_button)
	var leave_button:=Button.new(); leave_button.text="离开当前房间"; leave_button.pressed.connect(func(): NetworkSession.leave_room()); column.add_child(leave_button)
	mp_status=Label.new(); mp_status.text="正在连接统一大厅…"; mp_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; mp_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; column.add_child(mp_status)
	NetworkSession.auth_changed.connect(func(ok:bool,name:String,message:String): mp_status.text=("已登录："+name+"\n" if ok else "")+message; show_toast(message))
	NetworkSession.session_state_changed.connect(func(state:String): _refresh_room_status(state,NetworkSession.players))
	NetworkSession.room_updated.connect(func(players:Dictionary): _refresh_room_status(NetworkSession.state,players))
	NetworkSession.lobby_rooms_updated.connect(_refresh_lobby_rooms)
	NetworkSession.match_ready.connect(_on_network_match_ready)
	NetworkSession.remote_state_received.connect(_on_remote_state)
	NetworkSession.remote_shot_received.connect(_on_remote_shot)
	NetworkSession.authoritative_damage.connect(_on_network_damage)

func _open_multiplayer() -> void:
	pause_panel.visible=false; multiplayer_panel.visible=true; Input.mouse_mode=Input.MOUSE_MODE_VISIBLE; _set_offline_bot_enabled(false)
	var error:=NetworkSession.connect_lobby()
	if error!=OK: mp_status.text="大厅连接启动失败：%s"%error_string(error)

func _close_multiplayer() -> void:
	multiplayer_panel.visible=false; pause_panel.visible=true; _set_offline_bot_enabled(NetworkSession.state=="offline")

func _mp_register() -> void: NetworkSession.register_account(mp_user.text,mp_password.text)
func _mp_login() -> void: NetworkSession.login(mp_user.text,mp_password.text)
func _mp_host() -> void:
	NetworkSession.create_room(mp_invite.text); mp_status.text="正在创建房间…"
func _mp_join() -> void:
	var selected:=mp_room_list.get_selected_items()
	if selected.is_empty(): mp_status.text="请先选择一个房间"; return
	var room_id:=int(mp_room_list.get_item_metadata(selected[0])); NetworkSession.join_room(room_id); mp_status.text="正在加入房间 %d…"%room_id
func _mp_select_room(index:int) -> void:
	var room_id:=int(mp_room_list.get_item_metadata(index)); mp_invite.text="房间 #%d"%room_id
func _mp_toggle_ready() -> void:
	var id:=multiplayer.get_unique_id(); var current:=bool(NetworkSession.players.get(id,{}).get("ready",false)); NetworkSession.set_local_ready(not current)
func _refresh_lobby_rooms(rooms:Dictionary) -> void:
	mp_room_list.clear()
	var ids:=rooms.keys(); ids.sort()
	for room_id in ids:
		var room:Dictionary=rooms[room_id]
		var index:=mp_room_list.item_count
		mp_room_list.add_item("#%d  %s   %d/%d   %s"%[int(room_id),str(room.name),int(room.count),int(room.capacity),str(room.status)])
		mp_room_list.set_item_metadata(index,int(room_id))
	if rooms.is_empty(): mp_room_list.add_item("当前没有房间，登录后创建一个吧")
func _refresh_room_status(state:String,players:Dictionary) -> void:
	var lines:=["状态："+state]
	for id in players: lines.append("%s  %s"%[str(players[id].get("name","Player")),"已准备" if bool(players[id].get("ready",false)) else "未准备"])
	mp_status.text="\n".join(lines)
func _on_network_match_ready() -> void:
	_assign_network_spawn()
	player.reset_for_round()
	mp_status.text="双方已准备，比赛开始"; multiplayer_panel.visible=false; pause_panel.visible=false; player.set_controls_enabled(true); round_time_left=90.0; round_freeze_left=3.0; round_active=false
	_set_offline_bot_enabled(false)

func _set_offline_bot_enabled(enabled:bool) -> void:
	var bot:=world.get_node_or_null("DuelOpponent")
	if not bot: return
	bot.visible=enabled
	bot.process_mode=Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	bot.collision_layer=1 if enabled else 0
	bot.collision_mask=1 if enabled else 0

func _update_performance_hud(delta:float) -> void:
	if not performance_label: return
	performance_hud_accum+=delta
	if performance_hud_accum<0.25: return
	performance_hud_accum=0.0
	var ping:=NetworkSession.get_ping_ms()
	performance_label.text="FPS %d   PING %s"%[Engine.get_frames_per_second(),("%d ms"%ping if ping>=0 else "--")]

func _assign_network_spawn() -> void:
	var is_left_slot:=NetworkSession.local_room_slot()==0
	player.global_position=Vector3(16.6,0.05,0.5) if is_left_slot else Vector3(-17.0,0.05,1.5)
	player.rotation.y=deg_to_rad(-90.0 if is_left_slot else 90.0)
	player.head.rotation=Vector3.ZERO; player.spawn_transform=player.global_transform

func _update_network_state(delta:float) -> void:
	if NetworkSession.state=="offline": return
	network_state_accum+=delta
	if network_state_accum<0.05: return
	network_state_accum=0.0
	NetworkSession.send_player_state({"position":player.global_position,"yaw":player.rotation.y,"pitch":player.head.rotation.x,"weapon":player.weapon_index,"crouch":player.crouching,"health":player.health})

func _on_remote_state(peer_id:int,state:Dictionary) -> void:
	var avatar:Node3D=remote_avatars.get(peer_id)
	if not avatar: avatar=_create_remote_avatar(peer_id); remote_avatars[peer_id]=avatar
	avatar.global_position=avatar.global_position.lerp(state.get("position",avatar.global_position),0.42); avatar.rotation.y=lerp_angle(avatar.rotation.y,float(state.get("yaw",0.0)),0.45)
	avatar.scale.y=0.72 if bool(state.get("crouch",false)) else 1.0

func _create_remote_avatar(peer_id:int) -> Node3D:
	var root:=Node3D.new(); root.name="RemotePlayer_%d"%peer_id; world.add_child(root)
	var material:=_material(Color("406080"),CYAN,0.08)
	var torso:=MeshInstance3D.new(); var capsule:=CapsuleMesh.new(); capsule.radius=0.34; capsule.height=1.18; torso.mesh=capsule; torso.material_override=material; torso.position=Vector3(0,1.05,0); root.add_child(torso)
	var head_mesh:=MeshInstance3D.new(); var sphere:=SphereMesh.new(); sphere.radius=0.29; sphere.height=0.58; head_mesh.mesh=sphere; head_mesh.material_override=_material(Color("d5aa91")); head_mesh.position=Vector3(0,1.88,0); root.add_child(head_mesh)
	var tag:=_label3d(root,"RemoteName",str(NetworkSession.players.get(peer_id,{}).get("name","PLAYER")),Vector3(0,2.45,0),28,Color.WHITE); tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	return root

func send_network_shot(origin:Vector3,direction:Vector3,weapon:int,damage:float) -> void:
	if NetworkSession.state!="offline": NetworkSession.send_shot(origin,direction,weapon,damage)

func _on_remote_shot(_peer_id:int,origin:Vector3,direction:Vector3,_weapon:int) -> void:
	spawn_muzzle_effect(origin+direction*0.65); _play_positional(load("res://assets/audio/weapons/rifle_fire_single.wav"),origin,-6.0,52.0,randf_range(0.97,1.03))

func _on_network_damage(target_peer:int,current_health:int,_amount:float,hit_point:Vector3) -> void:
	spawn_blood_splatter(hit_point,Vector3.UP)
	if target_peer==multiplayer.get_unique_id(): player.apply_network_health(current_health)
	elif current_health<=0 and round_active: _finish_round(0)

func _overlay(parent: Node, title: String, body: String, button_text: String, callback: Callable) -> Control:
	var root := ColorRect.new(); root.color = Color(0.035,0.025,0.10,0.92); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); parent.add_child(root)
	var panel := PanelContainer.new(); panel.name = "Panel"; panel.custom_minimum_size = Vector2(520, 360); _set_rect(panel,0.5,0.5,0.5,0.5,-260,-180,260,180); root.add_child(panel)
	var style := StyleBoxFlat.new(); style.bg_color = Color("191630"); style.border_color = Color("4fc9d2"); style.set_border_width_all(2); style.corner_radius_top_left = 22; style.corner_radius_top_right = 22; style.corner_radius_bottom_left = 22; style.corner_radius_bottom_right = 22; style.content_margin_left = 42; style.content_margin_right = 42; style.content_margin_top = 34; style.content_margin_bottom = 34; panel.add_theme_stylebox_override("panel", style)
	var vb := VBoxContainer.new(); vb.name = "VBox"; vb.alignment = BoxContainer.ALIGNMENT_CENTER; vb.add_theme_constant_override("separation", 18); panel.add_child(vb)
	var heading := Label.new(); heading.text = title; heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; heading.add_theme_font_size_override("font_size", 36); heading.add_theme_color_override("font_color", PINK); vb.add_child(heading)
	var desc := Label.new(); desc.text = body; desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; desc.add_theme_font_size_override("font_size", 18); vb.add_child(desc)
	var button := Button.new(); button.text = button_text; button.custom_minimum_size.y = 50; button.add_theme_font_size_override("font_size", 19); button.pressed.connect(callback); vb.add_child(button)
	return root

func _start_game() -> void:
	start_panel.visible = false; player.set_controls_enabled(true)
	if NetworkSession.state=="offline": _spawn_training_bot()
func _toggle_fullscreen() -> void:
	var current:=DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if current==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _wire_ui_audio(node: Node) -> void:
	if node is Button:
		(node as Button).mouse_entered.connect(play_ui_hover)
		(node as Button).pressed.connect(play_ui_confirm)
	for child in node.get_children(): _wire_ui_audio(child)

func play_ui_hover() -> void:
	_play_ui_stream("res://assets/audio/ui/hover.ogg",-13.0)

func play_ui_confirm() -> void:
	_play_ui_stream("res://assets/audio/ui/confirm.ogg",-7.0)

func play_inventory_scroll() -> void:
	_play_ui_stream("res://assets/audio/ui/inventory_scroll.ogg",-10.0)

func play_weapon_switch() -> void:
	_play_ui_stream("res://assets/audio/ui/inventory_scroll.ogg",-7.0); ui_audio.pitch_scale=randf_range(0.82,0.92)

func play_weapon_reload() -> void:
	_play_ui_stream("res://assets/audio/ui/confirm.ogg",-5.0); ui_audio.pitch_scale=randf_range(0.72,0.82)

func update_weapon_hud(name_:String,ammo:int,reserve:int) -> void:
	if not weapon_label: return
	weapon_label.visible=not name_.is_empty(); weapon_label.text="%s　%02d / %03d"%[name_,ammo,reserve]

func _on_player_health_changed(current:int,maximum:int) -> void:
	if health_label: health_label.text="HP %03d / %03d   ARMOR %03d"%[current,maximum,player.armor]

func _update_duel_round(delta:float) -> void:
	if not player or not duel_label: return
	if round_freeze_left>0.0:
		round_freeze_left=maxf(0.0,round_freeze_left-delta); player.freeze_movement=true
		duel_label.text="%d  :  %d     回合 %d     准备 %.1f"%[duel_scores[0],duel_scores[1],round_number,round_freeze_left]
		if round_freeze_left<=0.0: round_active=true; player.freeze_movement=false
	elif round_active:
		round_time_left=maxf(0.0,round_time_left-delta); duel_label.text="%d  :  %d     回合 %d     %02d:%02d"%[duel_scores[0],duel_scores[1],round_number,int(round_time_left/60.0),int(round_time_left)%60]
		if round_time_left<=0.0: _finish_round(1)

func on_combatant_defeated(side:String) -> void:
	if not round_active: return
	_finish_round(0 if side=="opponent" else 1)

func _finish_round(winner:int) -> void:
	if not round_active: return
	round_active=false; duel_scores[winner]+=1; _show_round_result(winner)
	await get_tree().create_timer(2.0).timeout
	round_number+=1; round_time_left=90.0; round_freeze_left=3.0
	player.reset_for_round()
	if NetworkSession.state!="offline": NetworkSession.reset_round_health()
	var opponent:=world.get_node_or_null("DuelOpponent")
	if opponent and NetworkSession.state=="offline" and opponent.has_method("reset_for_round"): opponent.reset_for_round()
	elif opponent: _set_offline_bot_enabled(false)
	round_result_overlay.visible=false

func _show_round_result(winner:int) -> void:
	var local_win:=winner==0; round_result_overlay.visible=true; round_result_overlay.modulate=Color(1,1,1,0); round_result_label.scale=Vector2(0.55,0.55); round_result_label.pivot_offset=round_result_label.size*0.5
	round_result_label.text="胜 利" if local_win else "失 败"; round_result_label.add_theme_color_override("font_color",Color("ffe581") if local_win else Color("ff637f"))
	_play_ui_stream("res://assets/audio/ui/confirm.ogg",-2.0 if local_win else -7.0); ui_audio.pitch_scale=1.18 if local_win else 0.72
	var tween:=create_tween(); tween.set_parallel(true); tween.tween_property(round_result_overlay,"modulate",Color.WHITE,0.20); tween.tween_property(round_result_label,"scale",Vector2.ONE,0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT); tween.set_parallel(false); tween.tween_interval(1.15); tween.tween_property(round_result_overlay,"modulate",Color(1,1,1,0),0.48)

func show_player_hit_blood() -> void:
	damage_flash.color=Color(0.72,0.01,0.025,0.32); var tween:=create_tween(); tween.tween_property(damage_flash,"color",Color(0.72,0.01,0.025,0.0),0.36)

func spawn_blood_splatter(pos:Vector3,normal:Vector3) -> void:
	var blood:=GPUParticles3D.new(); blood.one_shot=true; blood.amount=18; blood.lifetime=0.55; blood.explosiveness=1.0; blood.position=pos
	var process:=ParticleProcessMaterial.new(); process.direction=normal; process.spread=62.0; process.initial_velocity_min=1.2; process.initial_velocity_max=4.2; process.gravity=Vector3(0,-8.0,0); process.scale_min=0.25; process.scale_max=0.75; process.color=Color("a70d27"); blood.process_material=process
	var mesh:=SphereMesh.new(); mesh.radius=0.025; mesh.height=0.05; mesh.material=_material(Color("7d0618")); blood.draw_pass_1=mesh; world.add_child(blood); blood.emitting=true; get_tree().create_timer(1.0).timeout.connect(blood.queue_free)

func update_weapon_slots(selected:int,owned:Array) -> void:
	var weapon_names:=["步枪","冲锋枪","霰弹枪","手枪","刀"]
	for i in range(inventory_slots.size()):
		inventory_slots[i].add_theme_stylebox_override("panel",_inventory_style(i==selected))
		var label:=inventory_slots[i].get_child(0).get_node("ItemName") as Label
		label.text=weapon_names[i] if bool(owned[i]) else "已丢弃"

func spawn_dropped_weapon(data:Dictionary,slot:int,ammo:int,reserve:int,pos:Vector3,direction:Vector3) -> void:
	var body:=RigidBody3D.new(); body.set_script(load("res://scripts/combat/weapon_pickup.gd")); body.name="Dropped_"+str(data.name); body.position=pos; body.mass=1.2; body.continuous_cd=true; body.set("weapon_slot",slot); body.set("weapon_ammo",ammo); body.set("weapon_reserve",reserve); body.set("interaction_name","拾取 "+str(data.name))
	var packed:=load(str(data.scene)) as PackedScene
	if packed:
		var model:=packed.instantiate() as Node3D; model.scale=Vector3.ONE*float(data.scale); model.rotation=data.rotation; body.add_child(model)
	var shape:=BoxShape3D.new(); shape.size=Vector3(0.75,0.20,0.18); var collision:=CollisionShape3D.new(); collision.shape=shape; body.add_child(collision); world.add_child(body)
	body.apply_central_impulse(direction.normalized()*4.5+Vector3.UP*1.4); body.apply_torque_impulse(Vector3(0.3,0.8,0.5))

func spawn_muzzle_effect(pos:Vector3) -> void:
	var flash:=MeshInstance3D.new(); var mesh:=SphereMesh.new(); mesh.radius=0.075; mesh.height=0.15; flash.mesh=mesh; flash.position=pos; flash.material_override=_material(Color("fff0b0"),Color("ff8a35"),5.0); flash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; world.add_child(flash)
	var tween:=create_tween(); tween.tween_property(flash,"scale",Vector3(2.4,2.4,0.3),0.035); tween.tween_property(flash,"scale",Vector3.ZERO,0.045); tween.finished.connect(flash.queue_free)

func spawn_bullet_impact(pos:Vector3,normal:Vector3) -> void:
	var sparks:=GPUParticles3D.new(); sparks.one_shot=true; sparks.amount=9; sparks.lifetime=0.38; sparks.explosiveness=1.0; sparks.position=pos
	var process:=ParticleProcessMaterial.new(); process.direction=normal; process.spread=48.0; process.initial_velocity_min=1.8; process.initial_velocity_max=4.5; process.gravity=Vector3(0,-5.0,0); process.scale_min=0.35; process.scale_max=0.85; process.color=Color("ffc36d"); sparks.process_material=process
	var mesh:=BoxMesh.new(); mesh.size=Vector3(0.012,0.012,0.11); mesh.material=_material(Color("fff0a8"),Color("ff7c32"),3.0); sparks.draw_pass_1=mesh; world.add_child(sparks); sparks.emitting=true
	get_tree().create_timer(0.8).timeout.connect(sparks.queue_free)

func spawn_shell_casing(pos:Vector3,right:Vector3) -> void:
	var shell:=RigidBody3D.new(); shell.name="SpentCasing"; shell.position=pos; shell.mass=0.025; shell.collision_layer=0; shell.collision_mask=1
	var mesh:=CylinderMesh.new(); mesh.top_radius=0.012; mesh.bottom_radius=0.012; mesh.height=0.055; mesh.radial_segments=10; mesh.material=_material(Color("c99b46"),Color.BLACK,0.0); var visual:=MeshInstance3D.new(); visual.mesh=mesh; visual.rotation_degrees.z=90; shell.add_child(visual)
	var shape:=CylinderShape3D.new(); shape.radius=0.012; shape.height=0.055; var collision:=CollisionShape3D.new(); collision.shape=shape; collision.rotation_degrees.z=90; shell.add_child(collision); world.add_child(shell)
	shell.apply_central_impulse(right.normalized()*randf_range(1.0,1.8)+Vector3.UP*randf_range(0.7,1.2)); shell.apply_torque_impulse(Vector3(randf(),randf(),randf())*0.08)
	get_tree().create_timer(5.0).timeout.connect(shell.queue_free)

func _play_ui_stream(path:String, volume:float) -> void:
	if not ui_audio: return
	ui_audio.stream=load(path); ui_audio.volume_db=volume; ui_audio.pitch_scale=randf_range(0.96,1.04); ui_audio.play()

func play_footstep(pos:Vector3) -> void:
	if footstep_streams.is_empty(): return
	_play_positional(footstep_streams.pick_random(),pos,-9.0,9.0,randf_range(0.94,1.06))

func play_punch_sound(pos:Vector3) -> void:
	_play_positional(load("res://assets/audio/impact/punch.ogg"),pos,-8.0,8.0,randf_range(0.96,1.05))

func _on_ball_collision(ball:RigidBody3D) -> void:
	var strength:=ball.linear_velocity.length()
	if strength<0.8: return
	var now:=Time.get_ticks_msec(); var last:=int(ball.get_meta("last_sound",0))
	if now-last<130: return
	ball.set_meta("last_sound",now)
	_play_positional(ball_impact_streams.pick_random(),ball.global_position,clampf(-17.0+strength*1.7,-16.0,-4.0),13.0,randf_range(0.88,1.12))

func _play_positional(stream:AudioStream,pos:Vector3,volume:float,max_range:float,pitch:float=1.0) -> void:
	if not stream: return
	var audio:=AudioStreamPlayer3D.new(); audio.stream=stream; audio.position=pos; audio.volume_db=volume; audio.max_distance=max_range; audio.pitch_scale=pitch; audio.bus="ClubReverb"; world.add_child(audio); audio.finished.connect(audio.queue_free); audio.play()

func throw_inventory_item(item:Dictionary,origin:Vector3,direction:Vector3) -> void:
	var body:=RigidBody3D.new(); body.set_script(load("res://scripts/items/throwable_item.gd")); body.name="Thrown_"+str(item.get("id","item")); body.position=origin; body.mass=0.7; body.continuous_cd=true; body.contact_monitor=true; body.max_contacts_reported=4; body.set("item_data",item.duplicate(true))
	var visual:=MeshInstance3D.new(); var collision:=CollisionShape3D.new(); var shape_type:=str(item.get("shape","orb")); var radius:=clampf(float(item.get("radius",0.18)),0.10,0.70)
	match shape_type:
		"disc":
			var mesh:=CylinderMesh.new(); mesh.top_radius=0.24; mesh.bottom_radius=0.24; mesh.height=0.065; mesh.radial_segments=24; visual.mesh=mesh; var shape:=CylinderShape3D.new(); shape.radius=0.24; shape.height=0.065; collision.shape=shape
		"capsule":
			var mesh:=CapsuleMesh.new(); mesh.radius=0.11; mesh.height=0.36; visual.mesh=mesh; var shape:=CapsuleShape3D.new(); shape.radius=0.11; shape.height=0.36; collision.shape=shape
		"phone":
			var mesh:=BoxMesh.new(); mesh.size=Vector3(0.22,0.34,0.07); visual.mesh=mesh; var shape:=BoxShape3D.new(); shape.size=mesh.size; collision.shape=shape
		"diamond":
			var mesh:=BoxMesh.new(); mesh.size=Vector3(0.24,0.24,0.24); visual.mesh=mesh; visual.rotation_degrees=Vector3(25,35,45); var shape:=SphereShape3D.new(); shape.radius=0.18; collision.shape=shape
		_:
			var mesh:=SphereMesh.new(); mesh.radius=radius; mesh.height=radius*2.0; mesh.radial_segments=20; mesh.rings=10; visual.mesh=mesh; var shape:=SphereShape3D.new(); shape.radius=radius; collision.shape=shape
	var color:Color=item.get("color",CYAN); visual.material_override=_material(color,color,0.18); body.add_child(visual); body.add_child(collision)
	var physics:=PhysicsMaterial.new(); physics.friction=0.62; physics.bounce=0.38; body.physics_material_override=physics; world.add_child(body)
	body.body_entered.connect(func(_other:Node): _on_ball_collision(body)); body.apply_central_impulse(direction.normalized()*8.8+Vector3.UP*1.4); body.apply_torque_impulse(Vector3(randf_range(-1.8,1.8),randf_range(-1.8,1.8),randf_range(-1.8,1.8)))
func _open_pause() -> void:
	pause_panel.visible = true; player.set_controls_enabled(false)
func _resume_game() -> void:
	pause_panel.visible = false; player.set_controls_enabled(true)
func _on_interaction_changed(text: String) -> void: prompt_label.text = text
func _on_inventory_changed(items: Array, selected: int) -> void:
	var weapon_names:=["步枪","冲锋枪","霰弹枪","手枪","刀"]
	for i in range(inventory_slots.size()):
		inventory_slots[i].add_theme_stylebox_override("panel",_inventory_style(i==player.weapon_index))
		(inventory_slots[i].get_child(0).get_node("ItemName") as Label).text=weapon_names[i]
	return
	for i in range(inventory_slots.size()):
		var slot:=inventory_slots[i]
		slot.add_theme_stylebox_override("panel",_inventory_style(i==selected))
		var label:=slot.get_child(0).get_node("ItemName") as Label
		if i<items.size():
			var count:=int(items[i].get("count",1)); label.text=str(items[i].get("name","—"))+(" ×%d"%count if count>1 else "")
		else: label.text="—"

func _inventory_style(selected: bool) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new(); style.bg_color=Color(0.055,0.045,0.12,0.84); style.border_color=PINK if selected else Color("496674"); style.set_border_width_all(2 if selected else 1); style.corner_radius_top_left=10; style.corner_radius_top_right=10; style.corner_radius_bottom_left=10; style.corner_radius_bottom_right=10; style.content_margin_left=8; style.content_margin_right=8; style.content_margin_top=5; style.content_margin_bottom=5; return style
func show_toast(text: String) -> void:
	toast_label.text = text; toast_label.visible = true; toast_timer.start()

func _update_day_night(delta: float) -> void:
	if not world_environment or not sun_light or not moon_light: return
	game_hour=fmod(game_hour+delta*time_scale/3600.0,24.0)
	var orbit:float=(game_hour-6.0)/24.0*TAU
	var sun_height:float=sin(orbit)
	var daylight:float=smoothstep(-0.12,0.22,sun_height)
	var dusk:float=1.0-smoothstep(0.05,0.55,abs(sun_height))
	sun_light.rotation_degrees=Vector3(-sun_height*78.0,game_hour*15.0-180.0,0.0)
	sun_light.light_energy=lerpf(0.0,1.18,daylight)
	sun_light.light_color=Color("ffd8b0").lerp(Color("fff5df"),clampf(sun_height,0.0,1.0))
	moon_light.rotation_degrees=Vector3(sun_height*72.0,game_hour*15.0,0.0)
	moon_light.light_energy=lerpf(0.48,0.0,daylight)
	var night_color:=Color("25264d")
	var day_color:=Color("9eb2c9")
	var sunset_color:=Color("b06f91")
	world_environment.ambient_light_color=night_color.lerp(day_color,daylight).lerp(sunset_color,dusk*0.38)
	world_environment.ambient_light_energy=lerpf(0.34,0.88,daylight)
	world_environment.background_energy_multiplier=lerpf(0.18,0.92,daylight)+dusk*0.12
	world_environment.fog_light_color=Color("34365c").lerp(Color("c7b5c9"),daylight).lerp(Color("d38491"),dusk*0.35)
	world_environment.fog_light_energy=lerpf(0.16,0.48,daylight)
	if cloud_material: cloud_material.set_shader_parameter("daylight",daylight)
	sky_material.energy_multiplier=world_environment.background_energy_multiplier
	for light in interior_lights:
		if is_instance_valid(light): light.light_energy=lerpf(float(light.get_meta("night_energy",2.0)),float(light.get_meta("day_energy",0.75)),daylight)
	if clock_label:
		var hour:=int(game_hour); var minute:=int((game_hour-hour)*60.0)
		var period:="深夜" if game_hour<5.0 else ("清晨" if game_hour<8.0 else ("白昼" if game_hour<17.0 else ("黄昏" if game_hour<20.0 else "夜晚")))
		clock_label.text="%02d:%02d  %s  ×%d"%[hour,minute,period,int(time_scale)] if time_scale>0.0 else "%02d:%02d  %s  暂停"%[hour,minute,period]

func show_capsule_stage(text: String) -> void:
	show_toast(text)

func show_capsule_result(item: Dictionary) -> void:
	capsule_reveal_serial+=1
	var serial:=capsule_reveal_serial
	var color:Color=item.get("color",CYAN)
	capsule_result_texture.texture=load(str(item.get("texture","")))
	capsule_result_name.text=str(item.get("name","SealLandX 贴纸"))
	capsule_result_rarity.text=str(item.get("rarity","未知品质"))
	capsule_result_name.add_theme_color_override("font_color",color)
	capsule_result_rarity.add_theme_color_override("font_color",color.lightened(0.20))
	capsule_result_overlay.visible=true; capsule_result_overlay.modulate.a=0.0
	var tween:=create_tween(); tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT); tween.tween_property(capsule_result_overlay,"modulate:a",1.0,0.32)
	await get_tree().create_timer(3.2).timeout
	if serial!=capsule_reveal_serial: return
	var fade:=create_tween(); fade.tween_property(capsule_result_overlay,"modulate:a",0.0,0.28); await fade.finished
	if serial==capsule_reveal_serial: capsule_result_overlay.visible=false

func place_sticker(item: Dictionary, point: Vector3, normal: Vector3) -> void:
	var sticker:=MeshInstance3D.new(); sticker.name="PlacedSticker_"+str(item.get("id","sticker"))
	var quad:=QuadMesh.new(); quad.size=Vector2(0.78,0.78); sticker.mesh=quad; sticker.material_override=_sticker_material(item); sticker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; world.add_child(sticker)
	sticker.global_position=point+normal*0.018
	sticker.look_at(point-normal,Vector3.UP)
	sticker.rotate_object_local(Vector3.FORWARD,deg_to_rad(randf_range(-7.0,7.0)))
	show_toast("已贴上 · "+str(item.get("name","贴纸")))

func _sticker_material(item: Dictionary) -> ShaderMaterial:
	var mat:=ShaderMaterial.new(); mat.shader=load("res://shaders/sticker.gdshader"); mat.set_shader_parameter("sticker_texture",load(str(item.get("texture","")))); mat.set_shader_parameter("rarity_color",item.get("color",CYAN)); mat.set_shader_parameter("foil_strength",float(item.get("foil",0.0))); return mat

func _set_rect(control: Control, l: float, t: float, r: float, b: float, ol: float, ot: float, ore: float, ob: float) -> void:
	control.anchor_left=l; control.anchor_top=t; control.anchor_right=r; control.anchor_bottom=b; control.offset_left=ol; control.offset_top=ot; control.offset_right=ore; control.offset_bottom=ob

func _material(color: Color, emission := Color.BLACK, energy := 0.0, transparency := 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(color.r,color.g,color.b,transparency); mat.roughness = 0.38; mat.metallic = 0.08
	if emission != Color.BLACK: mat.emission_enabled = true; mat.emission = emission; mat.emission_energy_multiplier = energy
	if transparency < 1.0: mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _textured_material(path: String, uv_scale: Vector3, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if path.get_extension().to_lower()=="svg":
		var image:=Image.new()
		image.load_svg_from_buffer(FileAccess.get_file_as_bytes(path),1.0)
		mat.albedo_texture=ImageTexture.create_from_image(image) if not image.is_empty() else null
	else:
		mat.albedo_texture = load(path)
	mat.uv1_scale = uv_scale
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = roughness
	mat.metallic = 0.02
	return mat

func _architectural_pbr(path:String,uv_scale:Vector2,roughness:float,metallic:float,normal_strength:float,ao_strength:float) -> ShaderMaterial:
	var mat:=ShaderMaterial.new(); mat.shader=load("res://shaders/architectural_pbr.gdshader")
	mat.set_shader_parameter("albedo_texture",load(path)); mat.set_shader_parameter("uv_scale",uv_scale); mat.set_shader_parameter("roughness_base",roughness); mat.set_shader_parameter("metallic_base",metallic); mat.set_shader_parameter("normal_strength",normal_strength); mat.set_shader_parameter("ao_strength",ao_strength)
	return mat

func _club_glass_material(color:Color,alpha:float) -> ShaderMaterial:
	var mat:=ShaderMaterial.new(); mat.shader=load("res://shaders/club_glass.gdshader"); mat.set_shader_parameter("glass_tint",Color(color.r,color.g,color.b,alpha)); return mat

func _place_model(parent: Node, name_: String, path: String, pos: Vector3, scale_: Vector3, rot: Vector3, color: Color, collision_size := Vector3.ZERO, transparency := 1.0) -> Node3D:
	var packed:=load(path) as PackedScene
	if packed==null:
		push_warning("无法载入模型: "+path)
		return Node3D.new()
	var instance:=packed.instantiate() as Node3D
	instance.name=name_; instance.position=pos; instance.scale=scale_; instance.rotation_degrees=rot; parent.add_child(instance)
	var material:=_material(color,color,0.10,transparency)
	_tint_model(instance,material)
	if collision_size!=Vector3.ZERO:
		var body:=StaticBody3D.new(); body.name=name_+"Collision"; body.position=pos; body.rotation_degrees=rot; parent.add_child(body)
		var collision:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=collision_size; collision.shape=shape; body.add_child(collision)
	return instance

func _tint_model(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh_node:=node as MeshInstance3D; mesh_node.material_override=material; mesh_node.visibility_range_end=72.0; mesh_node.visibility_range_end_margin=8.0; mesh_node.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for child in node.get_children(): _tint_model(child,material)

func _box(parent: Node, name_: String, pos: Vector3, size: Vector3, color: Color, collision := false, emission := Color.BLACK, energy := 0.0, transparency := 1.0) -> MeshInstance3D:
	var mesh := BoxMesh.new(); mesh.size = size
	var node := MeshInstance3D.new(); node.name=name_; node.mesh=mesh; node.position=pos; node.material_override=_material(color,emission,energy,transparency); parent.add_child(node)
	if collision:
		var body := StaticBody3D.new(); body.name=name_+"Collision"; body.position=pos; parent.add_child(body)
		var shape := CollisionShape3D.new(); var box_shape := BoxShape3D.new(); box_shape.size=size; shape.shape=box_shape; body.add_child(shape)
	return node

func _body_box(body: CollisionObject3D, name_: String, pos: Vector3, size: Vector3, color: Color, emission := Color.BLACK, energy := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new(); mesh.size=size
	var node := MeshInstance3D.new(); node.name=name_; node.mesh=mesh; node.position=pos; node.material_override=_material(color,emission,energy); body.add_child(node)
	var shape := CollisionShape3D.new(); shape.position=pos; var box_shape := BoxShape3D.new(); box_shape.size=size; shape.shape=box_shape; body.add_child(shape)
	return node

func _sphere(parent: Node, name_: String, pos: Vector3, radius: float, color: Color, collision := false, emission := Color.BLACK, energy := 0.0, transparency := 1.0) -> MeshInstance3D:
	var mesh := SphereMesh.new(); mesh.radius=radius; mesh.height=radius*2; mesh.radial_segments=16; mesh.rings=8
	var node := MeshInstance3D.new(); node.name=name_; node.mesh=mesh; node.position=pos; node.material_override=_material(color,emission,energy,transparency); parent.add_child(node)
	if collision:
		var body := StaticBody3D.new(); body.position=pos; parent.add_child(body); var shape:=CollisionShape3D.new(); var sphere_shape:=SphereShape3D.new(); sphere_shape.radius=radius; shape.shape=sphere_shape; body.add_child(shape)
	return node

func _cylinder(parent: Node, name_: String, pos: Vector3, radius: float, height: float, color: Color, collision := false, rot := Vector3.ZERO, transparency := 1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new(); mesh.top_radius=radius; mesh.bottom_radius=radius; mesh.height=height; mesh.radial_segments=16
	var node := MeshInstance3D.new(); node.name=name_; node.mesh=mesh; node.position=pos; node.rotation_degrees=rot; node.material_override=_material(color,Color.BLACK,0.0,transparency); parent.add_child(node)
	if collision:
		var body:=StaticBody3D.new(); body.position=pos; body.rotation_degrees=rot; parent.add_child(body); var shape:=CollisionShape3D.new(); var cyl:=CylinderShape3D.new(); cyl.radius=radius; cyl.height=height; shape.shape=cyl; body.add_child(shape)
	return node

func _capsule(parent: Node, name_: String, pos: Vector3, radius: float, height: float, color: Color, collision := false, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh:=CapsuleMesh.new(); mesh.radius=radius; mesh.height=height; mesh.radial_segments=16; mesh.rings=8
	var node:=MeshInstance3D.new(); node.name=name_; node.mesh=mesh; node.position=pos; node.rotation_degrees=rot; node.material_override=_material(color); parent.add_child(node)
	if collision:
		var body:=StaticBody3D.new(); body.position=pos; body.rotation_degrees=rot; parent.add_child(body); var shape:=CollisionShape3D.new(); var cap:=CapsuleShape3D.new(); cap.radius=radius; cap.height=height; shape.shape=cap; body.add_child(shape)
	return node

func _label3d(parent: Node, name_: String, text_: String, pos: Vector3, size: int, color: Color) -> Label3D:
	var label:=Label3D.new(); label.name=name_; label.text=text_; label.position=pos; label.font_size=size; label.modulate=color; label.outline_size=5; label.outline_modulate=Color("17152f"); label.pixel_size=0.006; label.no_depth_test=true; label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; parent.add_child(label); return label

func _add_light(pos: Vector3, color: Color, energy: float, range_: float) -> void:
	var light:=OmniLight3D.new(); light.position=pos; light.light_color=color; light.light_energy=energy; light.omni_range=range_; light.shadow_enabled=false; light.set_meta("night_energy",energy); light.set_meta("day_energy",energy*0.34); world.add_child(light); interior_lights.append(light)
