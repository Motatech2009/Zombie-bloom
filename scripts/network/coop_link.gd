extends Node
signal status_changed(message: String)
var mode: String = "offline"
var world: Node3D
var peer: ENetMultiplayerPeer
var identity: String = ""
var nickname: String = "Sobrevivente"
var snapshot_left: float = 0
var input_left: float = 0
var connect_left: float = 0
var scene_sent: Dictionary = {}
var input_times: Dictionary = {}
var action_times: Dictionary = {}
var received_snapshots: int = 0
var test_input: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# All traffic is host-authoritative; clients never need peer-to-peer relaying.
	multiplayer.server_relay = false
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): close_session(); status_changed.emit("Não foi possível conectar. Confira IP, porta UDP e sala aberta."))
	multiplayer.server_disconnected.connect(_server_left)
	multiplayer.peer_disconnected.connect(_peer_left)
	var config := ConfigFile.new()
	if config.load("user://coop_identity.cfg")==OK: identity = str(config.get_value("client","id",""))
	if identity.length()!=32:
		identity = Crypto.new().generate_random_bytes(16).hex_encode()
		config.set_value("client","id",identity)
		config.save("user://coop_identity.cfg")

func host_session(port: int = 24567) -> Error:
	close_session()
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_server(port,3,3)
	if result!=OK: peer = null; status_changed.emit("Não foi possível abrir a porta UDP."); return result
	multiplayer.multiplayer_peer = peer
	mode = "host"
	status_changed.emit("Sala aberta / UDP %d / até quatro jogadores" % port)
	return OK

func join_session(address: String,port: int = 24567,player_name: String = "Sobrevivente") -> Error:
	close_session()
	nickname = player_name.strip_edges().left(16)
	if nickname.is_empty(): nickname = "Sobrevivente"
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_client(address,port,3)
	if result!=OK: peer = null; return result
	multiplayer.multiplayer_peer = peer
	mode = "connecting"
	connect_left = 12
	status_changed.emit("Conectando ao anfitrião...")
	return OK

func _connected() -> void:
	mode = "client"
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/survival/SurvivalWorld.tscn")

func bind_world(next_world: Node3D) -> void:
	world = next_world
	if mode=="client": _join_ready.rpc_id(1,identity,nickname)
	elif mode=="host": scene_sent.clear()

func close_session() -> void:
	mode = "offline"
	world = null
	scene_sent.clear()
	input_times.clear()
	action_times.clear()
	# Release the high-level transport before shutting down its ENet peer.
	var previous: ENetMultiplayerPeer = peer
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if previous!=null: previous.close()

func _server_left() -> void:
	var previous: Node3D = world
	close_session()
	if is_instance_valid(previous): previous.finish(false,"O anfitrião encerrou a sala. Volte ao menu para reconectar.")
	status_changed.emit("Sala encerrada pelo anfitrião.")

func _peer_left(id: int) -> void:
	if mode=="host" and is_instance_valid(world): world.detach_peer(id)
	scene_sent.erase(id)

func _physics_process(delta: float) -> void:
	if mode=="connecting":
		connect_left -= delta
		if connect_left<=0: close_session(); status_changed.emit("Tempo esgotado: confira a conectividade UDP.")
		return
	if not is_instance_valid(world) or mode not in ["host","client"]: return
	if mode=="host":
		snapshot_left -= delta
		if snapshot_left>0: return
		snapshot_left = .1
		for id in world.avatars:
			if id==1 or not multiplayer.get_peers().has(id): continue
			if peer.get_peer(id).get_state()!=ENetPacketPeer.STATE_CONNECTED or peer.get_peer(id).get_channels()<3: continue
			if int(scene_sent.get(id,-1))!=world.scene_revision:
				_receive_scene.rpc_id(id,world.net_scene())
				scene_sent[id] = world.scene_revision
			_receive_state.rpc_id(id,world.net_state(id))
	else:
		input_left -= delta
		if input_left>0: return
		input_left = 1.0/30
		var frame: Dictionary = test_input.duplicate() if not test_input.is_empty() else world.local_input(world.player)
		_input_frame.rpc_id(1,frame)

func command(action: String,data: Dictionary) -> void:
	if mode=="client": _action.rpc_id(1,action,data)

func blast_event(point: Vector3,radius: float) -> void:
	if mode=="host": _blast_visual.rpc(point,radius)

@rpc("any_peer","call_remote","reliable",0)
func _join_ready(token: String,name_text: String) -> void:
	if mode!="host" or not is_instance_valid(world) or token.length()!=32 or not token.is_valid_hex_number(false): return
	var id := multiplayer.get_remote_sender_id()
	if id<=1 or not multiplayer.get_peers().has(id): return
	for actor in world.avatars.values():
		if actor.profile_id==token: return
	if world.attach_peer(id,token,name_text):
		_receive_scene.rpc_id(id,world.net_scene())
		scene_sent[id] = world.scene_revision
	else: _rejected.rpc_id(id,"Sala cheia, encerrada ou perfil já ativo.")

@rpc("authority","call_remote","reliable",0)
func _rejected(message: String) -> void:
	if is_instance_valid(world): world.finish(false,message)

@rpc("any_peer","call_remote","unreliable_ordered",1)
func _input_frame(data: Dictionary) -> void:
	if mode!="host" or not is_instance_valid(world): return
	var id := multiplayer.get_remote_sender_id()
	if not world.avatars.has(id) or data.size()>8: return
	var now := Time.get_ticks_msec()
	if now-int(input_times.get(id,0))<12: return
	input_times[id] = now
	var move = data.get("move")
	var aim = data.get("aim")
	var slot = data.get("slot")
	if not move is Vector2 or not aim is Vector3 or not slot is int or slot<0 or slot>8 or not move.is_finite() or not aim.is_finite(): return
	world.avatars[id].net_input = {"move":move.limit_length(1),"aim":Vector3(aim.x,0,aim.z).normalized(),"slot":slot,"sprint":data.get("sprint")==true,"fire":data.get("fire")==true,"reload":data.get("reload")==true,"interact":data.get("interact")==true,"time":now}

@rpc("any_peer","call_remote","reliable",0)
func _action(action: String,data: Dictionary) -> void:
	if mode!="host" or not is_instance_valid(world): return
	var id := multiplayer.get_remote_sender_id()
	var now := Time.get_ticks_msec()
	if now-int(action_times.get(id,0))<40 or data.size()>5: return
	action_times[id] = now
	world.perform_action(id,action,data)

@rpc("authority","call_remote","reliable",0)
func _receive_scene(data: Dictionary) -> void:
	if mode=="client" and is_instance_valid(world): world.apply_net_scene(data)

@rpc("authority","call_remote","unreliable_ordered",2)
func _receive_state(data: Dictionary) -> void:
	if mode=="client" and is_instance_valid(world):
		world.apply_net_state(data,multiplayer.get_unique_id())
		received_snapshots += 1

@rpc("authority","call_remote","unreliable_ordered",2)
func _blast_visual(point: Vector3,_radius: float) -> void:
	if mode=="client" and is_instance_valid(world): world.effects.burst(point,Color("e9a361"),12)

func shot_event(from: Vector3,to: Vector3,color: Color) -> void:
	if mode=="host": _shot_visual.rpc(from,to,color)

@rpc("authority","call_remote","unreliable_ordered",2)
func _shot_visual(from: Vector3,to: Vector3,color: Color) -> void:
	if mode=="client" and is_instance_valid(world): world.shot_visual(from,to,color)
