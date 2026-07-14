extends SceneTree

func _init() -> void:
	for path in ["res://assets/models/weapons/cc0_fps_rifle.glb","res://assets/models/weapons/cc0_pistol.fbx"]:
		var packed:=load(path) as PackedScene
		print("MODEL ",path)
		if packed:
			var root:=packed.instantiate()
			_scan(root,Transform3D.IDENTITY,"")
	quit()

func _scan(node:Node,parent_transform:Transform3D,prefix:String) -> void:
	var transform:=parent_transform
	if node is Node3D: transform=parent_transform*(node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_node:=node as MeshInstance3D
		print(prefix,node.name," global_origin=",transform.origin," aabb=",mesh_node.get_aabb()," scale=",transform.basis.get_scale())
	for child in node.get_children(): _scan(child,transform,prefix+"  ")
