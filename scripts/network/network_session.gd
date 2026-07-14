extends Node

signal session_state_changed(state:String)
signal auth_changed(logged_in:bool,username:String,message:String)
signal lobby_rooms_updated(rooms:Dictionary)
signal room_updated(players:Dictionary)
signal match_ready
signal remote_state_received(peer_id:int,state:Dictionary)
signal remote_shot_received(peer_id:int,origin:Vector3,direction:Vector3,weapon:int)
signal authoritative_damage(target_peer:int,current_health:int,amount:float,hit_point:Vector3)

const SERVER_LOCAL_PORT:=27888
const DEFAULT_PORT:=SERVER_LOCAL_PORT
const PUBLIC_HOST:="since-tutu.gl.at.ply.gg"
const PUBLIC_PORT:=28723
const MAX_CLIENTS:=32
const ROOM_CAPACITY:=2
const SERVER_ACCOUNT_FILE:="user://ncc_server_accounts.cfg"

var state:="offline"
var players:Dictionary={}
var lobby_rooms:Dictionary={}
var username:=""
var logged_in:=false
var current_room_id:=0
var dedicated_server:=false
var latest_states:Dictionary={}
var network_health:Dictionary={}

# Dedicated-server-only state.
var server_rooms:Dictionary={}
var peer_room:Dictionary={}
var next_room_id:=1001
var _pending_auth:Dictionary={}
var _public_connection_attempt:=false
var _local_fallback_attempted:=false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(func(): shutdown())
	var args:=OS.get_cmdline_user_args()
	if "--dedicated-lobby" in args:
		dedicated_server=true
		_start_dedicated_server.call_deferred()
	elif "--lobby-test-a" in args:
		_run_lobby_test_client.call_deferred(true)
	elif "--lobby-test-b" in args:
		_run_lobby_test_client.call_deferred(false)
	elif "--public-probe" in args:
		_run_public_probe.call_deferred()
	elif "--net-test-host" in args:
		_run_network_test.call_deferred(true)
	elif "--net-test-client" in args:
		_run_network_test.call_deferred(false)

func _start_dedicated_server() -> void:
	var peer:=ENetMultiplayerPeer.new()
	var error:=peer.create_server(SERVER_LOCAL_PORT,MAX_CLIENTS)
	if error!=OK:
		push_error("DEDICATED_SERVER failed: %s"%error_string(error))
		get_tree().quit(2)
		return
	multiplayer.multiplayer_peer=peer
	_set_state("dedicated_server")
	print("DEDICATED_SERVER_READY udp=",SERVER_LOCAL_PORT," public=",PUBLIC_HOST,":",PUBLIC_PORT)

func connect_lobby() -> Error:
	if dedicated_server: return ERR_UNAVAILABLE
	if state in ["connecting","lobby_connected","authenticated","in_room","match"]: return OK
	_public_connection_attempt=true
	_local_fallback_attempted=false
	return _connect_to_server(PUBLIC_HOST,PUBLIC_PORT)

func _connect_to_server(address:String,port:int) -> Error:
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	var peer:=ENetMultiplayerPeer.new()
	var error:=peer.create_client(address,port)
	if error!=OK: return error
	multiplayer.multiplayer_peer=peer
	_set_state("connecting")
	return OK

func _on_connection_failed() -> void:
	# Lets the server owner use the same client even when the tunnel cannot hairpin.
	if _public_connection_attempt and not _local_fallback_attempted:
		_local_fallback_attempted=true
		_set_state("正在尝试本机服务器")
		_connect_to_server("127.0.0.1",SERVER_LOCAL_PORT)
		return
	shutdown()
	auth_changed.emit(false,"","无法连接大厅服务器，请确认服务器和 Playit 正在运行")

func register_account(name:String,password:String) -> bool:
	return _request_auth(name,password,true)

func login(name:String,password:String) -> bool:
	return _request_auth(name,password,false)

func _request_auth(name:String,password:String,is_register:bool) -> bool:
	name=name.strip_edges()
	if name.length()<3 or password.length()<6:
		auth_changed.emit(false,"","用户名至少 3 位，密码至少 6 位")
		return false
	_pending_auth={"name":name,"password_hash":password.sha256_text(),"register":is_register}
	if state=="offline":
		var error:=connect_lobby()
		if error!=OK:
			auth_changed.emit(false,"","无法启动大厅连接：%s"%error_string(error))
			return false
	elif state not in ["connecting","正在尝试本机服务器"]:
		_send_pending_auth()
	return true

func _send_pending_auth() -> void:
	if _pending_auth.is_empty() or multiplayer.is_server(): return
	_server_auth.rpc_id(1,str(_pending_auth.name),str(_pending_auth.password_hash),bool(_pending_auth.register))

@rpc("any_peer","call_remote","reliable")
func _server_auth(name:String,password_hash:String,is_register:bool) -> void:
	if not multiplayer.is_server(): return
	var peer_id:=multiplayer.get_remote_sender_id()
	name=name.strip_edges().left(20)
	if name.length()<3 or password_hash.length()!=64:
		_auth_result.rpc_id(peer_id,false,"","账号格式不正确")
		return
	var cfg:=ConfigFile.new()
	cfg.load(SERVER_ACCOUNT_FILE)
	if is_register:
		if cfg.has_section_key("accounts",name):
			_auth_result.rpc_id(peer_id,false,"","用户名已存在")
			return
		var salt:=(name+str(Time.get_unix_time_from_system())+str(randi())).sha256_text()
		cfg.set_value("accounts",name,salt+":"+(salt+password_hash).sha256_text())
		if cfg.save(SERVER_ACCOUNT_FILE)!=OK:
			_auth_result.rpc_id(peer_id,false,"","服务器无法保存账号")
			return
	else:
		if not cfg.has_section_key("accounts",name):
			_auth_result.rpc_id(peer_id,false,"","账号不存在")
			return
		var parts:=str(cfg.get_value("accounts",name,"")).split(":")
		if parts.size()!=2 or (str(parts[0])+password_hash).sha256_text()!=str(parts[1]):
			_auth_result.rpc_id(peer_id,false,"","密码错误")
			return
	players[peer_id]={"name":name,"ready":false,"authenticated":true}
	_auth_result.rpc_id(peer_id,true,name,"注册并登录成功" if is_register else "登录成功")
	_broadcast_lobby()

@rpc("authority","call_local","reliable")
func _auth_result(ok:bool,name:String,message:String) -> void:
	logged_in=ok
	if ok:
		username=name
		_pending_auth.clear()
		_set_state("authenticated")
	auth_changed.emit(ok,name,message)

func create_room(room_name:String) -> void:
	if not logged_in: auth_changed.emit(false,"","请先登录大厅"); return
	_server_create_room.rpc_id(1,room_name.strip_edges().left(24))

func join_room(room_id:int) -> void:
	if not logged_in: auth_changed.emit(false,"","请先登录大厅"); return
	_server_join_room.rpc_id(1,room_id)

func leave_room() -> void:
	if state=="offline": return
	_server_leave_room.rpc_id(1)

@rpc("any_peer","call_remote","reliable")
func _server_create_room(room_name:String) -> void:
	if not multiplayer.is_server(): return
	var peer_id:=multiplayer.get_remote_sender_id()
	if not _is_authenticated(peer_id): return
	_server_remove_from_room(peer_id)
	var room_id:=next_room_id; next_room_id+=1
	server_rooms[room_id]={"name":room_name if not room_name.is_empty() else "%s 的房间"%players[peer_id].name,"owner":peer_id,"members":[peer_id],"ready":{peer_id:false},"status":"等待玩家"}
	peer_room[peer_id]=room_id
	_send_room_to_members(room_id)
	_broadcast_lobby()

@rpc("any_peer","call_remote","reliable")
func _server_join_room(room_id:int) -> void:
	if not multiplayer.is_server(): return
	var peer_id:=multiplayer.get_remote_sender_id()
	if not _is_authenticated(peer_id) or not server_rooms.has(room_id): return
	var room:Dictionary=server_rooms[room_id]
	if room.members.size()>=ROOM_CAPACITY or room.status=="对局中":
		_room_notice.rpc_id(peer_id,"房间已满或正在对局")
		return
	_server_remove_from_room(peer_id)
	room=server_rooms[room_id]
	room.members.append(peer_id); room.ready[peer_id]=false; room.status="等待准备"
	server_rooms[room_id]=room; peer_room[peer_id]=room_id
	_send_room_to_members(room_id)
	_broadcast_lobby()

@rpc("any_peer","call_remote","reliable")
func _server_leave_room() -> void:
	if not multiplayer.is_server(): return
	_server_remove_from_room(multiplayer.get_remote_sender_id())
	_broadcast_lobby()

func _server_remove_from_room(peer_id:int) -> void:
	if not peer_room.has(peer_id): return
	var room_id:=int(peer_room[peer_id]); peer_room.erase(peer_id)
	if not server_rooms.has(room_id): return
	var room:Dictionary=server_rooms[room_id]
	room.members.erase(peer_id); room.ready.erase(peer_id)
	latest_states.erase(peer_id); network_health.erase(peer_id)
	if room.members.is_empty():
		server_rooms.erase(room_id)
		return
	if int(room.owner)==peer_id: room.owner=int(room.members[0])
	room.status="等待玩家" if room.members.size()<2 else "等待准备"
	server_rooms[room_id]=room
	_send_room_to_members(room_id)

func _is_authenticated(peer_id:int) -> bool:
	return players.has(peer_id) and bool(players[peer_id].get("authenticated",false))

func _broadcast_lobby() -> void:
	if not multiplayer.is_server(): return
	var snapshot:Dictionary={}
	for room_id in server_rooms:
		var room:Dictionary=server_rooms[room_id]
		snapshot[room_id]={"name":room.name,"count":room.members.size(),"capacity":ROOM_CAPACITY,"status":room.status}
	if not multiplayer.get_peers().is_empty(): _receive_lobby_rooms.rpc(snapshot)

@rpc("authority","call_local","reliable")
func _receive_lobby_rooms(snapshot:Dictionary) -> void:
	lobby_rooms=snapshot.duplicate(true)
	lobby_rooms_updated.emit(lobby_rooms)

func _send_room_to_members(room_id:int) -> void:
	if not server_rooms.has(room_id): return
	var room:Dictionary=server_rooms[room_id]
	var snapshot:Dictionary={}
	for peer_id in room.members:
		if players.has(peer_id): snapshot[peer_id]={"name":players[peer_id].name,"ready":bool(room.ready.get(peer_id,false))}
	var connected:=multiplayer.get_peers()
	for peer_id in room.members:
		if int(peer_id) in connected: _receive_room.rpc_id(int(peer_id),snapshot,room_id)

@rpc("authority","call_local","reliable")
func _receive_room(snapshot:Dictionary,room_id:int) -> void:
	players=snapshot.duplicate(true)
	current_room_id=room_id
	_set_state("in_room")
	room_updated.emit(players)

@rpc("authority","call_local","reliable")
func _room_notice(message:String) -> void:
	auth_changed.emit(logged_in,username,message)

func set_local_ready(value:bool) -> void:
	if current_room_id<=0: return
	_server_set_ready.rpc_id(1,value)

@rpc("any_peer","call_remote","reliable")
func _server_set_ready(value:bool) -> void:
	if not multiplayer.is_server(): return
	var peer_id:=multiplayer.get_remote_sender_id()
	if not peer_room.has(peer_id): return
	var room_id:=int(peer_room[peer_id]); var room:Dictionary=server_rooms[room_id]
	room.ready[peer_id]=value; server_rooms[room_id]=room
	_send_room_to_members(room_id)
	if room.members.size()==ROOM_CAPACITY:
		var all_ready:=true
		for member in room.members:
			if not bool(room.ready.get(member,false)): all_ready=false
		if all_ready:
			room.status="对局中"; server_rooms[room_id]=room
			for member in room.members: _announce_match_ready.rpc_id(member)
			_broadcast_lobby()

@rpc("authority","call_local","reliable")
func _announce_match_ready() -> void:
	_set_state("match")
	match_ready.emit()

func local_room_slot() -> int:
	var ids:=players.keys(); ids.sort()
	return maxi(0,ids.find(multiplayer.get_unique_id()))

func get_ping_ms() -> int:
	if state in ["offline","connecting","正在尝试本机服务器","dedicated_server"]: return -1
	if not (multiplayer.multiplayer_peer is ENetMultiplayerPeer): return -1
	var enet_peer:=multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var server_peer:=enet_peer.get_peer(1)
	if not server_peer: return -1
	return int(server_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))

func send_player_state(snapshot:Dictionary) -> void:
	if state!="match": return
	_server_player_state.rpc_id(1,snapshot)

@rpc("any_peer","call_remote","unreliable_ordered")
func _server_player_state(snapshot:Dictionary) -> void:
	if not multiplayer.is_server(): return
	var peer_id:=multiplayer.get_remote_sender_id()
	if not peer_room.has(peer_id): return
	latest_states[peer_id]=snapshot.duplicate(true)
	for member in _server_room_members(peer_id):
		if int(member)!=peer_id: _receive_player_state.rpc_id(int(member),peer_id,snapshot)

@rpc("authority","call_local","unreliable_ordered")
func _receive_player_state(peer_id:int,snapshot:Dictionary) -> void:
	if peer_id!=multiplayer.get_unique_id(): remote_state_received.emit(peer_id,snapshot)

func send_shot(origin:Vector3,direction:Vector3,weapon:int,base_damage:float) -> void:
	if state!="match": return
	_server_shot.rpc_id(1,origin,direction.normalized(),weapon,base_damage)

@rpc("any_peer","call_remote","reliable")
func _server_shot(origin:Vector3,direction:Vector3,weapon:int,base_damage:float) -> void:
	if not multiplayer.is_server(): return
	var shooter:=multiplayer.get_remote_sender_id()
	if not peer_room.has(shooter): return
	for member in _server_room_members(shooter): _receive_shot.rpc_id(int(member),shooter,origin,direction,weapon)
	for target_peer in _server_room_members(shooter):
		if int(target_peer)==shooter or not latest_states.has(target_peer): continue
		var snapshot:Dictionary=latest_states[target_peer]
		var feet:Vector3=snapshot.get("position",Vector3.ZERO)
		var crouching:=bool(snapshot.get("crouch",false))
		var head_center:=feet+Vector3.UP*(1.35 if crouching else 1.88)
		var body_center:=feet+Vector3.UP*(0.82 if crouching else 1.15)
		var head_along:=clampf((head_center-origin).dot(direction),0.0,120.0)
		var body_along:=clampf((body_center-origin).dot(direction),0.0,120.0)
		var head_closest:=origin+direction*head_along
		var body_closest:=origin+direction*body_along
		var headshot:=head_closest.distance_to(head_center)<=0.34
		if not headshot and body_closest.distance_to(body_center)>0.64: continue
		var along:=head_along if headshot else body_along
		var closest:=head_closest if headshot else body_closest
		var falloff:=lerpf(1.0,0.58,clampf((along-18.0)/62.0,0.0,1.0))
		var amount:=clampf(base_damage,1.0,100.0)*falloff*(4.0 if headshot else 1.0)
		var hp:=maxi(0,int(network_health.get(target_peer,100))-int(round(amount))); network_health[target_peer]=hp
		for member in _server_room_members(shooter): _receive_damage.rpc_id(int(member),int(target_peer),hp,amount,closest)

@rpc("authority","call_local","reliable")
func _receive_shot(shooter:int,origin:Vector3,direction:Vector3,weapon:int) -> void:
	if shooter!=multiplayer.get_unique_id(): remote_shot_received.emit(shooter,origin,direction,weapon)

@rpc("authority","call_local","reliable")
func _receive_damage(target_peer:int,current_health:int,amount:float,hit_point:Vector3) -> void:
	authoritative_damage.emit(target_peer,current_health,amount,hit_point)

func reset_round_health() -> void:
	if state!="match": return
	_server_reset_round_health.rpc_id(1)

@rpc("any_peer","call_remote","reliable")
func _server_reset_round_health() -> void:
	if not multiplayer.is_server(): return
	var sender:=multiplayer.get_remote_sender_id()
	for peer_id in _server_room_members(sender): network_health[peer_id]=100

func _server_room_members(peer_id:int) -> Array:
	if not peer_room.has(peer_id): return []
	var room_id:=int(peer_room[peer_id])
	if not server_rooms.has(room_id): return []
	return server_rooms[room_id].members

# Legacy direct-connect helpers remain for local diagnostics.
func host(port:int=DEFAULT_PORT) -> Error:
	if not logged_in: return ERR_UNAUTHORIZED
	var peer:=ENetMultiplayerPeer.new(); var error:=peer.create_server(port,1)
	if error==OK: multiplayer.multiplayer_peer=peer; _set_state("legacy_host")
	return error

func join(address:String,port:int=DEFAULT_PORT) -> Error:
	return _connect_to_server(address,port)

func _run_network_test(as_host:bool) -> void:
	username="TestHost" if as_host else "TestClient"; logged_in=true
	if not as_host: await get_tree().create_timer(0.65).timeout
	var error:=host(27999) if as_host else join("127.0.0.1",27999)
	print("NETWORK_TEST ","HOST" if as_host else "CLIENT"," error=",error)

func _run_lobby_test_client(creates_room:bool) -> void:
	if not creates_room: await get_tree().create_timer(1.0).timeout
	var error:=_connect_to_server("127.0.0.1",SERVER_LOCAL_PORT)
	print("LOBBY_TEST_CONNECT role=",("A" if creates_room else "B")," error=",error)
	if error!=OK: return
	while state=="connecting": await get_tree().process_frame
	var test_name:="AutoA" if creates_room else "AutoB"
	_pending_auth={"name":test_name,"password_hash":"testpass".sha256_text(),"register":true}
	_send_pending_auth()
	var auth_result=await auth_changed
	if not bool(auth_result[0]):
		_pending_auth={"name":test_name,"password_hash":"testpass".sha256_text(),"register":false}
		_send_pending_auth()
		auth_result=await auth_changed
	print("LOBBY_TEST_AUTH role=",("A" if creates_room else "B")," ok=",auth_result[0])
	if not bool(auth_result[0]): return
	if creates_room:
		create_room("AUTOTEST")
		await room_updated
	else:
		while lobby_rooms.is_empty(): await lobby_rooms_updated
		var ids:=lobby_rooms.keys(); ids.sort(); join_room(int(ids[0])); await room_updated
	set_local_ready(true)
	await match_ready
	print("LOBBY_TEST_MATCH role=",("A" if creates_room else "B")," room=",current_room_id," slot=",local_room_slot())
	send_player_state({"position":Vector3(2.0 if creates_room else -2.0,0.0,0.0),"health":100})
	if creates_room:
		await get_tree().create_timer(0.2).timeout
		send_shot(Vector3.ZERO,Vector3.RIGHT,1,25.0)

func _run_public_probe() -> void:
	var error:=_connect_to_server(PUBLIC_HOST,PUBLIC_PORT)
	print("PUBLIC_PROBE_START endpoint=",PUBLIC_HOST,":",PUBLIC_PORT," error=",error)
	var deadline:=Time.get_ticks_msec()+10000
	while state=="connecting" and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	print("PUBLIC_PROBE_RESULT state=",state)

func shutdown(emit_state:=true) -> void:
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	players.clear(); lobby_rooms.clear(); latest_states.clear(); network_health.clear()
	current_room_id=0; logged_in=false
	if emit_state: _set_state("offline")

func _on_connected_to_server() -> void:
	_set_state("lobby_connected")
	_send_pending_auth()

func _on_peer_connected(peer_id:int) -> void:
	if multiplayer.is_server():
		players[peer_id]={"name":"未登录","ready":false,"authenticated":false}
		_broadcast_lobby()

func _on_peer_disconnected(peer_id:int) -> void:
	if multiplayer.is_server():
		_server_remove_from_room(peer_id)
		players.erase(peer_id)
		_broadcast_lobby()
	else:
		players.erase(peer_id)
		room_updated.emit(players)

func _set_state(value:String) -> void:
	state=value
	session_state_changed.emit(state)
