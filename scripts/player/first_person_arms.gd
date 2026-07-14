extends Node3D

var motion:Node3D
var animation_tree:AnimationTree
var playback:AnimationNodeStateMachinePlayback

func _ready() -> void:
	motion=Node3D.new(); motion.name="ArmMotion"; add_child(motion)
	_build_skeleton()
	_build_animation_graph()

func _build_skeleton() -> void:
	var skeleton:=Skeleton3D.new(); skeleton.name="FirstPersonSkeleton"; motion.add_child(skeleton)
	var root:=skeleton.add_bone("root")
	var upper_r:=skeleton.add_bone("upper_arm_r"); skeleton.set_bone_parent(upper_r,root); skeleton.set_bone_rest(upper_r,Transform3D(Basis(Vector3.FORWARD,deg_to_rad(-18.0)),Vector3(0.26,-0.05,0.0)))
	var fore_r:=skeleton.add_bone("forearm_r"); skeleton.set_bone_parent(fore_r,upper_r); skeleton.set_bone_rest(fore_r,Transform3D(Basis.IDENTITY,Vector3(0.0,-0.31,-0.03)))
	var hand_r:=skeleton.add_bone("hand_r"); skeleton.set_bone_parent(hand_r,fore_r); skeleton.set_bone_rest(hand_r,Transform3D(Basis.IDENTITY,Vector3(0.0,-0.28,-0.02)))
	var upper_l:=skeleton.add_bone("upper_arm_l"); skeleton.set_bone_parent(upper_l,root); skeleton.set_bone_rest(upper_l,Transform3D(Basis(Vector3.FORWARD,deg_to_rad(18.0)),Vector3(-0.26,-0.05,0.0)))
	var fore_l:=skeleton.add_bone("forearm_l"); skeleton.set_bone_parent(fore_l,upper_l); skeleton.set_bone_rest(fore_l,Transform3D(Basis.IDENTITY,Vector3(0.0,-0.31,-0.03)))
	var hand_l:=skeleton.add_bone("hand_l"); skeleton.set_bone_parent(hand_l,fore_l); skeleton.set_bone_rest(hand_l,Transform3D(Basis.IDENTITY,Vector3(0.0,-0.28,-0.02)))
	_add_limb(skeleton,"forearm_r",Color("b98ed0"),0.085,0.34)
	_add_limb(skeleton,"hand_r",Color("d6abd9"),0.105,0.20)
	_add_limb(skeleton,"forearm_l",Color("8ecbd2"),0.085,0.34)
	_add_limb(skeleton,"hand_l",Color("b0dce0"),0.105,0.20)
	var target:=Node3D.new(); target.name="RightHandIKTarget"; target.position=Vector3(0.31,-0.62,-0.10); add_child(target)
	var ik:=SkeletonIK3D.new(); ik.name="RightHandIK"; ik.root_bone="upper_arm_r"; ik.tip_bone="hand_r"; ik.target_node=NodePath("../../../RightHandIKTarget"); ik.interpolation=0.72; skeleton.add_child(ik); ik.start()

func _add_limb(skeleton:Skeleton3D,bone:String,color:Color,radius:float,height:float) -> void:
	var attachment:=BoneAttachment3D.new(); attachment.bone_name=bone; skeleton.add_child(attachment)
	var mesh:=CapsuleMesh.new(); mesh.radius=radius; mesh.height=height; mesh.radial_segments=20; mesh.rings=8
	var visual:=MeshInstance3D.new(); visual.mesh=mesh; visual.position.y=-height*0.42; visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat:=StandardMaterial3D.new(); mat.albedo_color=color; mat.roughness=0.32; mat.metallic=0.18; mat.emission_enabled=true; mat.emission=color.darkened(0.72); mat.emission_energy_multiplier=0.22; visual.material_override=mat; attachment.add_child(visual)

func _build_animation_graph() -> void:
	var player:=AnimationPlayer.new(); player.name="ArmAnimationPlayer"; add_child(player)
	var library:=AnimationLibrary.new(); player.add_animation_library("",library)
	library.add_animation("idle",_motion_animation([Vector3.ZERO,Vector3(0,0.008,0)],[0.0,1.1]))
	library.add_animation("walk",_motion_animation([Vector3.ZERO,Vector3(0.008,0.018,0),Vector3(-0.008,0.0,0)],[0.0,0.24,0.48]))
	library.add_animation("punch",_motion_animation([Vector3.ZERO,Vector3(0.02,0.08,-0.38),Vector3.ZERO],[0.0,0.10,0.28]))
	var state_machine:=AnimationNodeStateMachine.new()
	for state in ["idle","walk","punch"]:
		var node:=AnimationNodeAnimation.new(); node.animation=state; state_machine.add_node(state,node)
	state_machine.add_transition("idle","walk",AnimationNodeStateMachineTransition.new()); state_machine.add_transition("walk","idle",AnimationNodeStateMachineTransition.new()); state_machine.add_transition("idle","punch",AnimationNodeStateMachineTransition.new()); state_machine.add_transition("walk","punch",AnimationNodeStateMachineTransition.new()); state_machine.add_transition("punch","idle",AnimationNodeStateMachineTransition.new())
	animation_tree=AnimationTree.new(); animation_tree.name="ArmAnimationTree"; animation_tree.tree_root=state_machine; animation_tree.anim_player=player.get_path(); add_child(animation_tree); animation_tree.active=true
	playback=animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback; playback.start("idle")

func _motion_animation(values:Array[Vector3],times:Array[float]) -> Animation:
	var animation:=Animation.new(); animation.length=times[-1]; animation.loop_mode=Animation.LOOP_LINEAR if times[-1]>0.4 else Animation.LOOP_NONE
	var track:=animation.add_track(Animation.TYPE_VALUE); animation.track_set_path(track,NodePath("ArmMotion:position")); animation.value_track_set_update_mode(track,Animation.UPDATE_CONTINUOUS)
	for i in range(values.size()): animation.track_insert_key(track,times[i],values[i])
	return animation

func set_moving(value:bool) -> void:
	if playback: playback.travel("walk" if value else "idle")

func play_punch() -> void:
	if playback: playback.travel("punch")
