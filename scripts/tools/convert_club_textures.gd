extends SceneTree

func _init() -> void:
	for name in ["club_floor_terrazzo","club_wall_panels","club_ceiling_acoustic"]:
		var source:String="res://assets/textures/"+str(name)+".svg"
		var target:String="res://assets/textures/"+str(name)+".png"
		var image:=Image.new()
		var error:=image.load_svg_from_buffer(FileAccess.get_file_as_bytes(source),2.0)
		if error!=OK:
			push_error("无法转换："+source)
			quit(1)
			return
		image.save_png(target)
	quit()
