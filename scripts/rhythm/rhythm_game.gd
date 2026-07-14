extends Control
class_name RhythmGame

signal finished(stats: Dictionary)

const PENDING := 0
const HIT := 1
const MISS := 2
const HOLDING := 3
const RELEASED := 4
const WINDOWS := [16.0, 40.0, 80.0, 105.0]
const SCORES := [1000, 900, 650, 300]
const KEY_CODES := [KEY_D, KEY_F, KEY_J, KEY_K]

var notes: Array[Dictionary] = []
var lane_notes: Array[Array] = [[], [], [], []]
var lane_pointers := PackedInt32Array([0, 0, 0, 0])
var holding := PackedInt32Array([-1, -1, -1, -1])
var pressed := PackedByteArray([0, 0, 0, 0])
var audio := AudioStreamPlayer.new()
var chart_offset := 0.0
var speed := 5.3
var started := false
var finished_once := false
var last_time := 0.0
var score := 0
var max_score_units := 1
var combo := 0
var max_combo := 0
var counts := PackedInt32Array([0, 0, 0, 0, 0])
var judge_text := ""
var judge_delta := 0.0
var judge_life := 0.0

func _ready() -> void:
	set_process(false)
	set_process_input(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(audio)

func start(chart_path: String, audio_path: String, game_speed: float, offset_ms: float, volume: float) -> void:
	if not _load_chart(chart_path):
		push_error("Unable to load rhythm chart: " + chart_path)
		return
	speed = game_speed
	chart_offset = offset_ms
	audio.stream = AudioStreamMP3.load_from_file(ProjectSettings.globalize_path(audio_path))
	if audio.stream == null:
		push_error("Unable to decode rhythm audio: " + audio_path)
		return
	audio.volume_db = linear_to_db(clampf(volume / 100.0, 0.001, 1.0))
	_reset()
	audio.play()
	started = true
	set_process(true)
	queue_redraw()

func stop() -> void:
	started = false
	audio.stop()
	set_process(false)

func _process(delta: float) -> void:
	if not started: return
	last_time = _song_time()
	_update_misses(last_time)
	judge_life = maxf(0.0, judge_life - delta)
	queue_redraw()
	if not finished_once and not notes.is_empty() and last_time > float(notes[-1].end) + 1200.0:
		finished_once = true
		started = false
		set_process(false)
		finished.emit(_stats())

func _input(event: InputEvent) -> void:
	if not started or not event is InputEventKey: return
	var key := event as InputEventKey
	if key.echo: return
	var lane := KEY_CODES.find(key.physical_keycode)
	if lane < 0: return
	get_viewport().set_input_as_handled()
	if key.pressed: _key_down(lane, _song_time())
	else: _key_up(lane, _song_time())

func _key_down(lane: int, at: float) -> void:
	if pressed[lane] == 1: return
	pressed[lane] = 1
	var index := _next_pending(lane)
	if index < 0: return
	var delta := at - float(notes[index].time)
	var judgement := _judge(absf(delta))
	if judgement < 0: return
	if float(notes[index].duration) > 0.0:
		notes[index].state = HOLDING
		holding[lane] = index
		_commit(judgement, delta, false)
	else:
		notes[index].state = HIT
		lane_pointers[lane] += 1
		_commit(judgement, delta, false)

func _key_up(lane: int, at: float) -> void:
	pressed[lane] = 0
	var index := holding[lane]
	if index < 0: return
	var delta := at - float(notes[index].end)
	var judgement := _judge(absf(delta))
	if judgement < 0:
		notes[index].state = MISS
		_commit(4, delta, true)
	else:
		notes[index].state = RELEASED
		_commit(judgement, delta, true)
	holding[lane] = -1
	lane_pointers[lane] += 1

func _update_misses(now: float) -> void:
	for lane in 4:
		var list := lane_notes[lane]
		var pointer := lane_pointers[lane]
		while pointer < list.size():
			var index: int = list[pointer]
			var state: int = notes[index].state
			if state == HIT or state == RELEASED or state == MISS:
				pointer += 1
				continue
			if state == HOLDING:
				if now > float(notes[index].end) + WINDOWS[3]:
					notes[index].state = MISS
					holding[lane] = -1
					_commit(4, now - float(notes[index].end), true)
					pointer += 1
				continue
			if now <= float(notes[index].time) + WINDOWS[3]: break
			notes[index].state = MISS
			_commit(4, now - float(notes[index].time), false)
			pointer += 1
		lane_pointers[lane] = pointer

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var board_width := minf(size.x * 0.58, 520.0)
	var board_x := (size.x - board_width) * 0.5
	var lane_width := board_width / 4.0
	var judge_y := size.y * 0.88
	var top_y := -size.y * 0.08
	var travel_height := judge_y - top_y
	var approach := 2700.0
	var travel := maxf(120.0, approach / speed)
	var radius := maxf(30.0, lane_width * 0.36)
	for lane in 4:
		if pressed[lane] == 1:
			draw_rect(Rect2(board_x + lane * lane_width + lane_width * 0.12, 0, lane_width * 0.76, judge_y + 42), Color(0.71,1.0,0.77,0.08))
	for note in notes:
		var start := float(note.time)
		if start > last_time + approach: break
		var state: int = note.state
		if state == HIT: continue
		if (state == RELEASED or state == MISS) and float(note.duration) <= 0.0: continue
		var center_x := board_x + int(note.lane) * lane_width + lane_width * 0.5
		var y := judge_y - ((start - last_time) / travel) * travel_height
		if float(note.duration) > 0.0:
			var end_y := judge_y - ((float(note.end) - last_time) / travel) * travel_height
			if maxf(y,end_y) < -radius*2.0 or minf(y,end_y) > size.y+radius*2.0: continue
			var color := Color("bafac4") if state == HOLDING else Color(0.71,0.93,0.73,0.76)
			if state == MISS: color = Color(0.98,0.44,0.52,0.62)
			draw_rect(Rect2(center_x-radius,minf(y,end_y),radius*2.0,maxf(absf(end_y-y),radius*2.0)),color)
		if y >= -radius*2.0 and y <= size.y+radius*2.0:
			draw_circle(Vector2(center_x,y),radius,Color("fb7185") if state==MISS else Color("a8f3b4"))
			draw_arc(Vector2(center_x,y),radius,0,TAU,40,Color(0.9,1.0,0.91,0.7),maxf(1.5,radius*0.055))
	for lane in 4:
		var center := Vector2(board_x+lane*lane_width+lane_width*0.5,judge_y)
		draw_arc(center,radius*1.02,0,TAU,48,Color("b8ffc5") if pressed[lane]==1 else Color.WHITE,maxf(3.5,radius*0.075))
		if pressed[lane]==1: draw_circle(center,radius*0.72,Color(0.66,0.96,0.72,0.42))
	var font := ThemeDB.fallback_font
	var combo_text := "COMBO %d" % combo
	draw_string(font,Vector2(size.x*0.5-font.get_string_size(combo_text,HORIZONTAL_ALIGNMENT_LEFT,-1,34).x*0.5,size.y*0.34),combo_text,HORIZONTAL_ALIGNMENT_LEFT,-1,34,Color.WHITE)
	if judge_life > 0.0:
		var text := "%s  %+.0fms" % [judge_text,judge_delta]
		draw_string(font,Vector2(size.x*0.5-font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,26).x*0.5,size.y*0.42),text,HORIZONTAL_ALIGNMENT_LEFT,-1,26,_judge_color())
	var hud_score := "SCORE  %07d" % _normalized_score()
	var hud_acc := "ACC  %.2f%%" % _current_accuracy()
	var hud_width := maxf(font.get_string_size(hud_score,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x,font.get_string_size(hud_acc,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x)
	draw_string(font,Vector2(size.x-hud_width-26,34),hud_score,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
	draw_string(font,Vector2(size.x-hud_width-26,60),hud_acc,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("a8f3b4"))

func _song_time() -> float:
	return (audio.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()) * 1000.0 - chart_offset

func _next_pending(lane: int) -> int:
	var list := lane_notes[lane]
	for p in range(lane_pointers[lane],list.size()):
		var index: int = list[p]
		if notes[index].state == PENDING: return index
		if notes[index].state == HOLDING: return -1
	return -1

func _judge(delta: float) -> int:
	for i in WINDOWS.size():
		if delta <= WINDOWS[i]: return i
	return -1

func _commit(judgement: int, delta: float, tail: bool) -> void:
	if judgement >= 4:
		combo = 0; counts[4] += 1; judge_text = "MISS"
	else:
		combo += 1; max_combo = maxi(max_combo,combo); score += SCORES[judgement]; counts[judgement] += 1
		judge_text = ["CRITICAL PERFECT","PERFECT","GREAT","GOOD"][judgement]
	if tail: judge_text += " TAIL"
	judge_delta = delta; judge_life = 0.48

func _judge_color() -> Color:
	if judge_text.begins_with("CRITICAL"): return Color("fff4a3")
	if judge_text.begins_with("PERFECT"): return Color("facc15")
	if judge_text.begins_with("GREAT"): return Color("86efac")
	if judge_text.begins_with("MISS"): return Color("fb7185")
	return Color("cbd5e1")

func _stats() -> Dictionary:
	return {"score":_normalized_score(),"accuracy":_current_accuracy(),"max_combo":max_combo,"critical":counts[0],"perfect":counts[1],"great":counts[2],"good":counts[3],"miss":counts[4]}

func _normalized_score() -> int:
	return clampi(roundi(float(score) / float(max_score_units * 1000) * 1000000.0),0,1000000)

func _current_accuracy() -> float:
	var total := 0
	for value in counts: total += value
	if total == 0: return 100.0
	var weighted := counts[0]+counts[1]+counts[2]*0.8+counts[3]*0.5
	return float(weighted)/float(total)*100.0

func _reset() -> void:
	lane_notes = [[],[],[],[]]; lane_pointers = PackedInt32Array([0,0,0,0]); holding = PackedInt32Array([-1,-1,-1,-1]); pressed = PackedByteArray([0,0,0,0])
	for i in notes.size(): notes[i].state=PENDING; lane_notes[int(notes[i].lane)].append(i)
	max_score_units=0
	for note in notes: max_score_units += 2 if float(note.duration)>0.0 else 1
	max_score_units=maxi(1,max_score_units)
	score=0; combo=0; max_combo=0; counts=PackedInt32Array([0,0,0,0,0]); last_time=0; finished_once=false

func _load_chart(path: String) -> bool:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return false
	notes.clear(); var section := ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#") or line.begins_with("//"): continue
		if line.begins_with("["):
			section=line.trim_prefix("[").trim_suffix("]").to_lower(); continue
		if section != "notes": continue
		var parts:=line.split(",")
		if parts.size()<3: continue
		var time:=float(parts[0]); var lane:=int(parts[1]); var duration:=float(parts[3]) if parts.size()>3 else 0.0
		notes.append({"time":time,"lane":lane,"duration":duration,"end":time+duration,"state":PENDING})
	notes.sort_custom(func(a,b):return a.time<b.time)
	return not notes.is_empty()
