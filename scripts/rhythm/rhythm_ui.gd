extends Control
class_name RhythmUI

signal closed
signal song_confirmed(song: Dictionary, difficulty: Dictionary)
signal retry_requested
signal settings_changed(settings: Dictionary)

enum Screen { HIDDEN, SONG_SELECT, SETTINGS, GAME, RESULT }

const BG := Color("090817")
const PANEL := Color("17152f")
const PANEL_2 := Color("211b3b")
const PINK := Color("ee5f9f")
const CYAN := Color("39cad4")
const MINT := Color("83d8c6")
const CREAM := Color("f3d9cf")
const MUTED := Color("938da8")
const RHYTHM_GAME_SCRIPT := preload("res://scripts/rhythm/rhythm_game.gd")

var screen := Screen.HIDDEN
var songs: Array[Dictionary] = [
	{"title":"AiAe", "artist":"Yuyoyuppe", "bpm":"180", "length":"原曲", "accent":Color("ef6a9d"), "background":"res://assets/rhythm/aiae/bg.png", "audio":"res://assets/rhythm/aiae/aiae.mp3", "difficulties":[
		{"name":"NM","notes":880,"chart":"res://assets/rhythm/aiae/nm.txt"},
		{"name":"HD","notes":1642,"chart":"res://assets/rhythm/aiae/hd.txt"},
		{"name":"MX","notes":2857,"chart":"res://assets/rhythm/aiae/mx.txt"},
		{"name":"SC","notes":3254,"chart":"res://assets/rhythm/aiae/sc.txt"},
		{"name":"Wafles' SHD","notes":4279,"chart":"res://assets/rhythm/aiae/wafles-shd.txt"}
	]}
]
var selected_song := 0
var selected_difficulty := 1
var settings := {"speed":5.3, "offset":0, "volume":80, "lane_opacity":85, "show_fps":false}
var result_data := {"score":986420, "accuracy":98.64, "max_combo":742, "critical":611, "perfect":104, "great":23, "good":4, "miss":0}
var content: Control
var header: HBoxContainer
var title_label: Label
var subtitle_label: Label

func _ready() -> void:
	set_process_input(true)
	visible = false
	_build_base()

func open_song_select() -> void:
	_show_screen(Screen.SONG_SELECT)

func open_settings() -> void:
	_show_screen(Screen.SETTINGS)

func open_game(song := {}, difficulty := {}) -> void:
	if not song.is_empty():
		var index := songs.find(song)
		if index >= 0: selected_song = index
	_show_screen(Screen.GAME)

func show_result(data := {}) -> void:
	if not data.is_empty(): result_data.merge(data, true)
	_show_screen(Screen.RESULT)

func close() -> void:
	screen = Screen.HIDDEN
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_player_enabled(true)
	closed.emit()

func set_song_library(value: Array[Dictionary]) -> void:
	if value.is_empty(): return
	songs = value
	selected_song = clampi(selected_song, 0, songs.size() - 1)
	if screen == Screen.SONG_SELECT: _show_screen(Screen.SONG_SELECT)

func _show_screen(next: Screen) -> void:
	screen = next
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_player_enabled(false)
	header.visible = screen != Screen.GAME
	if screen == Screen.GAME: _rect(content,0,0,1,1,24,18,-24,-24)
	else: _rect(content,0,0,1,1,44,112,-44,-34)
	_clear(content)
	match screen:
		Screen.SONG_SELECT: _build_song_select()
		Screen.SETTINGS: _build_settings()
		Screen.GAME: _build_game()
		Screen.RESULT: _build_result()

func _input(event: InputEvent) -> void:
	if screen == Screen.HIDDEN: return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if screen == Screen.SETTINGS: open_song_select()
		elif screen == Screen.GAME: open_song_select()
		elif screen == Screen.RESULT: open_song_select()
		else: close()

func _build_base() -> void:
	var bg := ColorRect.new(); bg.color = BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var glow_a := ColorRect.new(); glow_a.color = Color(0.24,0.09,0.28,0.28); _rect(glow_a,0,0,0.38,1,0,0,0,0); bg.add_child(glow_a)
	var glow_b := ColorRect.new(); glow_b.color = Color(0.03,0.24,0.28,0.18); _rect(glow_b,0.72,0,1,1,0,0,0,0); bg.add_child(glow_b)
	header = HBoxContainer.new(); _rect(header,0,0,1,0,44,24,-44,92); header.add_theme_constant_override("separation",18); add_child(header)
	var mark := Label.new(); mark.text="4K"; mark.custom_minimum_size=Vector2(62,62); mark.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; mark.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; mark.add_theme_font_size_override("font_size",26); mark.add_theme_color_override("font_color",BG); mark.add_theme_stylebox_override("normal",_style(CYAN,0,14)); header.add_child(mark)
	var titles := VBoxContainer.new(); titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(titles)
	title_label=Label.new(); title_label.text="ORBIT RHYTHM"; title_label.add_theme_font_size_override("font_size",26); title_label.add_theme_color_override("font_color",CREAM); titles.add_child(title_label)
	subtitle_label=Label.new(); subtitle_label.text="NEON COAST ARCADE SYSTEM"; subtitle_label.add_theme_font_size_override("font_size",12); subtitle_label.add_theme_color_override("font_color",MUTED); titles.add_child(subtitle_label)
	var esc := Label.new(); esc.text="ESC  返回"; esc.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; esc.add_theme_color_override("font_color",MUTED); header.add_child(esc)
	content=Control.new(); _rect(content,0,0,1,1,44,112,-44,-34); add_child(content)

func _build_song_select() -> void:
	title_label.text="曲目选择"; subtitle_label.text="SELECT TRACK / 4 KEY MODE"
	var left:=VBoxContainer.new(); _rect(left,0,0,0.57,1,0,0,-18,0); left.add_theme_constant_override("separation",10); content.add_child(left)
	var section:=Label.new(); section.text="本地曲库   %02d TRACKS"%songs.size(); section.add_theme_font_size_override("font_size",13); section.add_theme_color_override("font_color",CYAN); left.add_child(section)
	for i in songs.size():
		var song:=songs[i]; var button:=Button.new(); button.custom_minimum_size.y=94; button.text="  %02d   %s\n         %s     BPM %s     %s"%[i+1,song.title,song.artist,song.bpm,song.length]; button.alignment=HORIZONTAL_ALIGNMENT_LEFT; button.add_theme_font_size_override("font_size",17); button.add_theme_stylebox_override("normal",_style(PANEL_2 if i==selected_song else PANEL,1,12,PINK if i==selected_song else Color("342e4b"))); button.add_theme_stylebox_override("hover",_style(PANEL_2,1,12,CYAN)); button.pressed.connect(func(): selected_song=i; _show_screen(Screen.SONG_SELECT)); left.add_child(button)
	var detail:=PanelContainer.new(); _rect(detail,0.57,0,1,1,18,0,0,0); detail.add_theme_stylebox_override("panel",_style(PANEL,1,18,Color("39324f"))); content.add_child(detail)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",16); detail.add_child(box)
	var art:=TextureRect.new(); art.texture=_load_image_texture(songs[selected_song].background); art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; art.custom_minimum_size.y=210; box.add_child(art)
	var song=songs[selected_song]; var name:=Label.new(); name.text=song.title; name.add_theme_font_size_override("font_size",34); name.add_theme_color_override("font_color",CREAM); box.add_child(name)
	var meta:=Label.new(); meta.text="%s   ·   BPM %s   ·   %s"%[song.artist,song.bpm,song.length]; meta.add_theme_color_override("font_color",MUTED); box.add_child(meta)
	var diff_row:=HBoxContainer.new(); diff_row.add_theme_constant_override("separation",8); box.add_child(diff_row)
	for i in song.difficulties.size():
		var diff=song.difficulties[i]; var db:=Button.new(); db.text="%s\n%d NOTES"%[diff.name,diff.notes]; db.size_flags_horizontal=Control.SIZE_EXPAND_FILL; db.custom_minimum_size.y=74; db.add_theme_font_size_override("font_size",12); db.add_theme_stylebox_override("normal",_style(PINK if i==selected_difficulty else PANEL_2,1,10,PINK)); db.pressed.connect(func(): selected_difficulty=i; _show_screen(Screen.SONG_SELECT)); diff_row.add_child(db)
	var spacer:=Control.new(); spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(spacer)
	var actions:=HBoxContainer.new(); actions.add_theme_constant_override("separation",10); box.add_child(actions)
	var setting:=_button("游戏设置",false); setting.pressed.connect(open_settings); actions.add_child(setting)
	var play:=_button("开始演奏",true); play.size_flags_horizontal=Control.SIZE_EXPAND_FILL; play.pressed.connect(_confirm_song); actions.add_child(play)

func _build_settings() -> void:
	title_label.text="游戏设置"; subtitle_label.text="PLAY FEEL / AUDIO / DISPLAY"
	var panel:=PanelContainer.new(); _rect(panel,0.13,0,0.87,1,0,0,0,0); panel.add_theme_stylebox_override("panel",_style(PANEL,1,18,Color("39324f"))); content.add_child(panel)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",14); panel.add_child(box)
	_add_slider(box,"流速","调整音符下落的视觉速度；不会改变歌曲播放速度",1.0,10.0,0.1,settings.speed,func(v):settings.speed=v,"x")
	_add_slider(box,"Offset","校准音频与判定时间；正值让判定线时间向后移动",-300,300,1,settings.offset,func(v):settings.offset=int(v)," ms")
	_add_slider(box,"音乐音量","谱面音乐播放音量",0,100,1,settings.volume,func(v):settings.volume=int(v),"%")
	_add_slider(box,"轨道透明度","纯净模式下的轨道背景浓度",20,100,1,settings.lane_opacity,func(v):settings.lane_opacity=int(v),"%")
	var fps:=CheckButton.new(); fps.text="显示 FPS 与帧时间"; fps.button_pressed=settings.show_fps; fps.toggled.connect(func(v):settings.show_fps=v); box.add_child(fps)
	var spacer:=Control.new(); spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(spacer)
	var save:=_button("保存并返回",true); save.pressed.connect(func(): settings_changed.emit(settings.duplicate()); open_song_select()); box.add_child(save)

func _build_game() -> void:
	title_label.text=""; subtitle_label.text=""
	var game:=RHYTHM_GAME_SCRIPT.new(); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); content.add_child(game)
	game.finished.connect(func(stats): show_result(stats))
	var song:Dictionary=songs[selected_song]; var difficulty:Dictionary=song.difficulties[selected_difficulty]
	game.start.call_deferred(difficulty.chart,song.audio,float(settings.speed),float(settings.offset),float(settings.volume))

func _build_result() -> void:
	title_label.text="演奏结算"; subtitle_label.text="PLAY RESULT"
	var panel:=PanelContainer.new(); _rect(panel,0.12,0,0.88,1,0,0,0,0); panel.add_theme_stylebox_override("panel",_style(PANEL,1,18,Color("39324f"))); content.add_child(panel)
	var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",40); panel.add_child(row)
	var grade:=VBoxContainer.new(); grade.custom_minimum_size.x=300; grade.alignment=BoxContainer.ALIGNMENT_CENTER; row.add_child(grade)
	var rank:=Label.new(); rank.text="S"; rank.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; rank.add_theme_font_size_override("font_size",132); rank.add_theme_color_override("font_color",PINK); grade.add_child(rank)
	var accuracy:=Label.new(); accuracy.text="%.2f%%"%result_data.accuracy; accuracy.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; accuracy.add_theme_font_size_override("font_size",30); accuracy.add_theme_color_override("font_color",CYAN); grade.add_child(accuracy)
	var details:=VBoxContainer.new(); details.size_flags_horizontal=Control.SIZE_EXPAND_FILL; details.add_theme_constant_override("separation",10); row.add_child(details)
	var track:=Label.new(); track.text="%s\n%s · %s"%[songs[selected_song].title,songs[selected_song].artist,songs[selected_song].difficulties[selected_difficulty].name]; track.add_theme_font_size_override("font_size",24); track.add_theme_color_override("font_color",CREAM); details.add_child(track)
	var total:=Label.new(); total.text="%07d"%result_data.score; total.add_theme_font_size_override("font_size",52); total.add_theme_color_override("font_color",CREAM); details.add_child(total)
	for key in ["critical","perfect","great","good","miss"]:
		var stat:=Label.new(); stat.text="%-10s %04d"%[key.to_upper(),result_data[key]]; stat.add_theme_font_size_override("font_size",18); stat.add_theme_color_override("font_color",PINK if key=="miss" else MUTED); details.add_child(stat)
	var combo:=Label.new(); combo.text="MAX COMBO   %d"%result_data.max_combo; combo.add_theme_color_override("font_color",CYAN); details.add_child(combo)
	var spacer:=Control.new(); spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL; details.add_child(spacer)
	var actions:=HBoxContainer.new(); actions.add_theme_constant_override("separation",10); details.add_child(actions)
	var back:=_button("返回选歌",false); back.pressed.connect(open_song_select); actions.add_child(back)
	var retry:=_button("再次演奏",true); retry.size_flags_horizontal=Control.SIZE_EXPAND_FILL; retry.pressed.connect(func():retry_requested.emit();open_game()); actions.add_child(retry)

func _confirm_song() -> void:
	var song:=songs[selected_song]; var difficulty:Dictionary=song.difficulties[selected_difficulty]
	song_confirmed.emit(song,difficulty)
	open_game(song,difficulty)

func _add_slider(parent:VBoxContainer,label_text:String,help:String,min_value:float,max_value:float,step:float,value:float,callback:Callable,suffix:="") -> void:
	var block:=VBoxContainer.new(); block.add_theme_constant_override("separation",4); parent.add_child(block)
	var label:=Label.new(); label.text=label_text; label.add_theme_font_size_override("font_size",18); label.add_theme_color_override("font_color",CREAM); block.add_child(label)
	var desc:=Label.new(); desc.text=help; desc.add_theme_font_size_override("font_size",12); desc.add_theme_color_override("font_color",MUTED); block.add_child(desc)
	var row:=HBoxContainer.new(); block.add_child(row)
	var slider:=HSlider.new(); slider.min_value=min_value; slider.max_value=max_value; slider.step=step; slider.value=value; slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(slider)
	var output:=Label.new(); output.custom_minimum_size.x=80; output.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; output.text=("%.1f"%value if step<1 else str(int(value)))+suffix; row.add_child(output)
	slider.value_changed.connect(func(v):output.text=("%.1f"%v if step<1 else str(int(v)))+suffix;callback.call(v))

func _button(text:String,primary:bool) -> Button:
	var button:=Button.new(); button.text=text; button.custom_minimum_size=Vector2(150,50); button.add_theme_font_size_override("font_size",16); button.add_theme_stylebox_override("normal",_style(PINK if primary else PANEL_2,1,10,PINK if primary else Color("4a425e"))); button.add_theme_stylebox_override("hover",_style(CYAN if primary else Color("30294a"),1,10,CYAN)); return button

func _load_image_texture(path:String) -> Texture2D:
	var image:=Image.load_from_file(ProjectSettings.globalize_path(path))
	if image.is_empty():
		push_error("Unable to decode rhythm image: "+path)
		return null
	return ImageTexture.create_from_image(image)

func _style(color:Color,border:=0,radius:=0,border_color:=Color.TRANSPARENT) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new(); style.bg_color=color; style.border_color=border_color; style.set_border_width_all(border); style.set_corner_radius_all(radius); style.content_margin_left=20; style.content_margin_right=20; style.content_margin_top=14; style.content_margin_bottom=14; return style

func _clear(node:Node) -> void:
	for child in node.get_children(): child.queue_free()

func _rect(control:Control,l:float,t:float,r:float,b:float,ol:float,ot:float,ore:float,ob:float) -> void:
	control.anchor_left=l; control.anchor_top=t; control.anchor_right=r; control.anchor_bottom=b; control.offset_left=ol; control.offset_top=ot; control.offset_right=ore; control.offset_bottom=ob

func _set_player_enabled(enabled:bool) -> void:
	var player:=get_tree().current_scene.get_node_or_null("Player")
	if player and player.has_method("set_controls_enabled"): player.set_controls_enabled(enabled)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE
