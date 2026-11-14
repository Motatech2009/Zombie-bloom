extends Node
signal status_changed(message: String)
var mode: String = "offline"
var world: Node3D
var peer: ENetMultiplayerPeer
var identity: String = ""
var nickname: String = "Sobrevivente"
var snapshot_left: float = 0
var bulk_left: float = 0
var slow_cache: Dictionary = {}
var input_left: float = 0
var connect_left: float = 0
var scene_confirmed: Dictionary = {}
var last_scene_ack: int = -1
var scene_sent: Dictionary = {}
var input_times: Dictionary = {}
var action_times: Dictionary = {}
var received_snapshots: int = 0
var max_snapshot_raw: int = 0
var max_snapshot_packed: int = 0
var test_input: Dictionary = {}
var internet := InternetRoom.new()
var server_port: int = 24567

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(internet)
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
	var result := peer.create_server(port,3,5)
	if result!=OK: peer = null; status_changed.emit("Não foi possível abrir a porta UDP."); return result
	# Godot 4.6.3 passes max_channels as incoming bandwidth in create_server().
	# Reset the native host before connecting clients, or ENet drops most inputs.
	peer.host.bandwidth_limit(0,0)
	multiplayer.multiplayer_peer = peer
	server_port = port
	mode = "host"
	status_changed.emit("Sala aberta / UDP %d / até quatro jogadores" % port)
	return OK

func join_session(address: String,port: int = 24567,player_name: String = "Sobrevivente") -> Error:
	var endpoint := InternetRoom.parse_endpoint(address,port)
	if endpoint.is_empty(): status_changed.emit("Endereço inválido. Use IP, IP:porta ou nome do anfitrião."); return ERR_INVALID_PARAMETER
	address = endpoint.address; port = int(endpoint.port)
	close_session()
	nickname = player_name.strip_edges().left(16)
	if nickname.is_empty(): nickname = "Sobrevivente"
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_client(address,port,5)
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
	if mode=="client": _join_ready.rpc_id(1,identity,nickname,14)
	elif mode=="host": scene_sent.clear()

func close_session() -> void:
	if is_instance_valid(internet): internet.disable()
	mode = "offline"
	world = null
	scene_sent.clear()
	scene_confirmed.clear(); last_scene_ack = -1
	slow_cache.clear()
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
	scene_confirmed.erase(id)

func _physics_process(delta: float) -> void:
	if mode=="connecting":
		connect_left -= delta
		if connect_left<=0: close_session(); status_changed.emit("Tempo esgotado: confira a conectividade UDP.")
		return
	if not is_instance_valid(world) or mode not in ["host","client"]: return
	if mode=="host":
		snapshot_left -= delta
		bulk_left -= delta
		if snapshot_left>0: return
		snapshot_left += .05
		var include_bulk := bulk_left<=0
		if include_bulk: bulk_left += .333
		for id in world.avatars:
			if id==1 or not multiplayer.get_peers().has(id): continue
			if peer.get_peer(id).get_state()!=ENetPacketPeer.STATE_CONNECTED or peer.get_peer(id).get_channels()<5: continue
			if int(scene_sent.get(id,-1))!=world.peer_revision(id):
				_receive_scene.rpc_id(id,world.net_scene(id))
				scene_sent[id] = world.peer_revision(id)
				slow_cache.erase(id)
			var full: Dictionary = world.net_state(id,include_bulk or not slow_cache.has(id))
			var bulk := {"rev":world.peer_revision(id)}
			for key in ["structures","loot","houses","airdrops","discovered","sector_times","depot"]:
				bulk[key] = full[key]; full.erase(key)
			if include_bulk or not slow_cache.has(id):
				_receive_bulk.rpc_id(id,var_to_bytes(bulk).compress(FileAccess.COMPRESSION_DEFLATE)); slow_cache[id] = true
			var raw := var_to_bytes(full)
			var packed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
			max_snapshot_raw = maxi(max_snapshot_raw,raw.size()); max_snapshot_packed = maxi(max_snapshot_packed,packed.size())
			_receive_state.rpc_id(id,packed)
	else:
		input_left -= delta
		if input_left>0: return
		input_left += 1.0/30
		if world.prediction.enabled() and world.prediction.ready:
			if not world.prediction.history.is_empty(): _input_batch.rpc_id(1,var_to_bytes(world.prediction.history.slice(maxi(0,world.prediction.history.size()-32))).compress(FileAccess.COMPRESSION_DEFLATE),world.last_scene_revision)
		else:
			var frame: Dictionary = test_input.duplicate() if not test_input.is_empty() else world.local_input(world.player)
			_input_frame.rpc_id(1,frame)

func command(action: String,data: Dictionary) -> void:
	if mode=="client": _action.rpc_id(1,action,data)

func blast_event(point: Vector3,radius: float) -> void:
	if mode=="host": _blast_visual.rpc(point,radius)

@rpc("any_peer","call_remote","reliable",0)
func _join_ready(token: String,name_text: String,protocol: int = 12) -> void:
	if mode!="host" or not is_instance_valid(world) or token.length()!=32 or not token.is_valid_hex_number(false): return
	var id := multiplayer.get_remote_sender_id()
	if protocol!=14:
		_rejected.rpc_id(id,"Atualize PC e Android para a mesma versão 0.14."); return
	if id<=1 or not multiplayer.get_peers().has(id): return
	for actor in world.avatars.values():
		if actor.profile_id==token: return
	if world.attach_peer(id,token,name_text):
		_receive_scene.rpc_id(id,world.net_scene(id))
		scene_sent[id] = world.peer_revision(id)
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
	if data.has("target"):
		var target = data.target
		if not target is Dictionary or target.size()!=2 or not target.get("id") is int or not target.get("rev") is int or target.id<1 or target.rev<0: return
	world.avatars[id].net_input = {"move":move.limit_length(1),"aim":Vector3(aim.x,0,aim.z).normalized(),"slot":slot,"sprint":data.get("sprint")==true,"fire":data.get("fire")==true,"reload":data.get("reload")==true,"interact":data.get("interact")==true,"time":now}
	if data.has("target"): world.avatars[id].net_input.target = data.target.duplicate()

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
func _receive_state(packet: PackedByteArray) -> void:
	if mode=="client" and is_instance_valid(world) and packet.size()<=262144:
		var unpacked := packet.decompress_dynamic(2097152,FileAccess.COMPRESSION_DEFLATE)
		if unpacked.is_empty(): return
		var data = bytes_to_var(unpacked)
		if not data is Dictionary: return
		if int(data.get("rev",-1))!=world.last_scene_revision: return
		if not slow_cache.has("state") or int(slow_cache.state.rev)!=int(data.rev): return
		data["_bulk"] = slow_cache.get("fresh",false)
		slow_cache.fresh = false
		data.merge(slow_cache.state,false)
		world.apply_net_state(data,multiplayer.get_unique_id())
		if world.client_scene_ready and last_scene_ack!=world.last_scene_revision:
			last_scene_ack = world.last_scene_revision
			_scene_ready.rpc_id(1,last_scene_ack)
		received_snapshots += 1

@rpc("authority","call_remote","unreliable_ordered",2)
func _blast_visual(point: Vector3,_radius: float) -> void:
	if mode=="client" and is_instance_valid(world): world.effects.burst(point,Color("e9a361"),12)

func shot_event(from: Vector3,to: Vector3,color: Color) -> void:
	if mode=="host": _shot_visual.rpc(from,to,color,world.shot_owner)

@rpc("authority","call_remote","unreliable_ordered",4)
func _shot_visual(from: Vector3,to: Vector3,color: Color,owner: int = 0) -> void:
	if mode=="client" and is_instance_valid(world) and owner==multiplayer.get_unique_id() and world.prediction.enabled(): return
	if mode=="client" and is_instance_valid(world): world.shot_visual(from,to,color)

@rpc("authority","call_remote","unreliable_ordered",3)
func _receive_bulk(packet: PackedByteArray) -> void:
	if packet.size()>262144: return
	var raw := packet.decompress_dynamic(2097152,FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty(): return
	var data = bytes_to_var(raw)
	if not data is Dictionary: return
	if mode=="client" and is_instance_valid(world) and data.get("rev") is int and int(data.rev)>=world.last_scene_revision:
		slow_cache.state = data
		slow_cache.fresh = true

@rpc("any_peer","call_remote","unreliable_ordered",1)
func _input_batch(packet: PackedByteArray,revision: int) -> void:
	if packet.size()>16384: return
	var raw := packet.decompress_dynamic(65536,FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty(): return
	var frames = bytes_to_var(raw)
	if not frames is Array: return
	if mode!="host" or not is_instance_valid(world) or world.combat_paused() or frames.size()>32: return
	var id := multiplayer.get_remote_sender_id()
	if not world.avatars.has(id) or revision!=world.peer_revision(id): return
	var actor: Node3D = world.avatars[id]
	for frame in frames:
		if not frame is Dictionary or frame.size()>10 or not frame.get("seq") is int or not frame.get("move") is Vector2 or not frame.get("aim") is Vector3 or not frame.get("slot") is int: return
		if not frame.move.is_finite() or not frame.aim.is_finite() or frame.slot<0 or frame.slot>8 or frame.seq<1: return
		if frame.has("roll") and (not frame.roll is Vector3 or not frame.roll.is_finite() or frame.roll.length_squared()>1.01): return
		if frame.has("target"):
			if not frame.target is Dictionary or frame.target.size()!=2 or not frame.target.get("id") is int or not frame.target.get("rev") is int: return
		if frame.seq<=actor.input_received: continue
		if actor.input_queue.size()>=64: break
		var clean := {"seq":frame.seq,"move":frame.move.limit_length(1),"aim":frame.aim.normalized(),"slot":frame.slot,"fire":frame.get("fire")==true,"sprint":frame.get("sprint")==true,"reload":frame.get("reload")==true,"interact":frame.get("interact")==true}
		if frame.has("target"): clean.target = frame.target.duplicate()
		if frame.has("roll"): clean.roll = frame.roll
		actor.input_stream = true; actor.input_queue.append(clean); actor.input_received = frame.seq

func roll_intent(sequence: int,direction: Vector3,revision: int) -> void:
	if mode=="client": _roll_intent.rpc_id(1,sequence,direction,revision)

@rpc("any_peer","call_remote","reliable",0)
func _roll_intent(sequence: int,direction: Vector3,revision: int) -> void:
	if mode!="host" or not is_instance_valid(world) or sequence<1 or not direction.is_finite() or direction.length_squared()>1.01: return
	var id := multiplayer.get_remote_sender_id()
	if not world.avatars.has(id) or revision!=world.peer_revision(id): return
	var actor: Node3D = world.avatars[id]
	if sequence<=actor.roll_intent_seen: return
	actor.roll_intent_seen = sequence
	if actor.input_ack>=sequence: actor.start_roll(direction)
	elif actor.roll_intents.size()<4 and sequence<=actor.input_received+120: actor.roll_intents[sequence] = direction

@rpc("any_peer","call_remote","reliable",0)
func _scene_ready(revision: int) -> void:
	if mode!="host" or not is_instance_valid(world): return
	var id := multiplayer.get_remote_sender_id()
	if world.avatars.has(id) and revision==world.peer_revision(id): scene_confirmed[id] = revision
