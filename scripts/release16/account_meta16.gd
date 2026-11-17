extends Node
signal changed
var uid := ""
var clock := PlayClock16.new()
var world: Node3D
var session_id := ""
var sessions: Dictionary = {}
var pending: Array = []
var registered: Dictionary = {}
var observed_hordes: Dictionary = {}
var confirmed: Dictionary = {"balance":0,"owned":[],"equipped":{},"active_seconds":0,"longest_seconds":0}
var busy := false
var dirty := false
var disk_left := 5.0
var sync_left := 120.0
var api_url := ""
var status := "Entre para sincronizar horas e cosméticos."
var activity := false
var last_horde := 0
var bound_run := ""
var profile_loaded := false
func path() -> String: return "user://meta16_"+(uid if not uid.is_empty() else "guest").sha256_text().left(24)+".json"
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load("res://online.cfg")==OK: api_url = str(cfg.get_value("services16","url",""))
	Account.changed.connect(identity_changed)
	identity_changed()
func identity_changed() -> void:
	if uid==Account.user_id and not session_id.is_empty(): return
	persist(); uid = Account.user_id; profile_loaded = false; clock = PlayClock16.new(); sessions = {}; pending = []; registered = {}; observed_hordes = {}
	confirmed = {"balance":0,"owned":[],"equipped":{},"active_seconds":0,"longest_seconds":0}
	if FileAccess.file_exists(path()):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path()))
		if data is Dictionary:
			observed_hordes = data.get("observed_hordes",{}); sessions = data.get("sessions",{}); pending = data.get("pending",[]); registered = data.get("registered",{}); confirmed = data.get("confirmed",confirmed)
			clock.total = maxf(0,float(data.get("total",0))); clock.longest = maxf(0,float(data.get("longest",0)))
	session_id = Crypto.new().generate_random_bytes(16).hex_encode(); clock.last_ms = Time.get_ticks_msec(); sync_left = 2
	changed.emit()
func _input(event: InputEvent) -> void:
	if not is_instance_valid(world): return
	if event is InputEventKey or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventJoypadButton: activity = true
	if event is InputEventMouseMotion and event.relative.length()>2: activity = true
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: clock.focused = false; persist()
	if what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]: clock.focused = true; clock.last_ms = Time.get_ticks_msec()
	if what==NOTIFICATION_WM_CLOSE_REQUEST: persist()
func _process(delta: float) -> void:
	if is_instance_valid(world) and (not world.is_client or world.client_scene_ready):
		if bound_run!=world.account_run_id: bound_run = world.account_run_id; registered.erase(bound_run)
		var reward_wave: int = int(world.upgrades.state(world.player).get("through",world.waves.wave))
		var prior := int(observed_hordes.get(bound_run,reward_wave))
		if reward_wave>prior:
			for wave in range(prior+1,reward_wave+1): horde(bound_run,wave)
		observed_hordes[bound_run] = maxi(prior,reward_wave)
	var eligible: bool = is_instance_valid(world) and world.phase!="ended" and not get_tree().paused and not world.combat_paused() and (not world.is_client or world.client_scene_ready)
	if eligible and world.network!=null and world.network.mode not in ["offline","host","client"]: eligible = false
	if eligible:
		var frame: Dictionary = world.local_input(world.player)
		activity = activity or frame.get("move",Vector2.ZERO).length_squared()>.01 or bool(frame.get("fire",false)) or bool(frame.get("interact",false))
	if clock.step(Time.get_ticks_msec(),eligible,activity)>0:
		sessions[session_id] = int(clock.session); dirty = true
	activity = false; disk_left -= delta; sync_left -= delta
	if dirty and disk_left<=0: persist(); disk_left = 5
	if sync_left<=0 and not busy: sync()
func persist() -> void:
	if session_id.is_empty(): return
	var file := FileAccess.open(path()+".tmp",FileAccess.WRITE)
	if file==null: return
	file.store_string(JSON.stringify({"observed_hordes":observed_hordes,"sessions":sessions,"total":clock.total,"longest":clock.longest,"pending":pending,"registered":registered,"confirmed":confirmed})); file.close()
	DirAccess.rename_absolute(path()+".tmp",path()); dirty = false
func request(action: String,data: Dictionary = {}) -> Dictionary:
	if api_url.is_empty() or not Account.signed_in(): return {"ok":false,"error":"Serviço 1.6 ainda não publicado."}
	if not await Account.ensure_token(): return {"ok":false,"error":"Entre novamente para sincronizar."}
	var req := HTTPRequest.new(); req.timeout = 15; add_child(req)
	var headers := PackedStringArray(["Content-Type: application/json","Authorization: Bearer "+Account.token])
	var result := {"ok":false,"error":"Sem conexão. Progresso pendente preservado."}
	var owner := uid
	if req.request(api_url,headers,HTTPClient.METHOD_POST,JSON.stringify({"action":action,"data":data}))==OK:
		var response: Array = await req.request_completed
		var body = JSON.parse_string(response[3].get_string_from_utf8())
		if owner==uid and body is Dictionary: result = body; result.ok = response[0]==HTTPRequest.RESULT_SUCCESS and response[1]==200
		elif response[1]==404: result.error = "Serviço 1.6 ainda não publicado. Créditos permanecem pendentes."
	req.queue_free(); return result
func sync() -> void:
	sync_left = 120
	if busy or api_url.is_empty() or uid.is_empty(): return
	var needs_registration: bool = is_instance_valid(world) and not registered.has(world.account_run_id)
	if sessions.is_empty() and pending.is_empty() and profile_loaded and not needs_registration: return
	busy = true; var owner := uid
	var reply := await request("sync",{"sessions":session_batch()}) if not sessions.is_empty() else await request("profile")
	if owner!=uid: busy = false; return
	if reply.ok:
		confirmed = reply.profile; profile_loaded = true; status = "Perfil sincronizado."
		for id in reply.get("ack_sessions",[]): sessions.erase(id)
	else: status = str(reply.get("error","Sincronização pendente."))
	if reply.ok and is_instance_valid(world):
		var run: String = world.account_run_id
		if not registered.has(run):
			var registration := await request("start",{"match_id":run,"mode":world.game_mode,"baseline":int(world.upgrades.state(world.player).get("through",0))})
			if owner!=uid: busy = false; return
			if registration.ok:
				registered[run] = true
				if registration.get("new_registration",false):
					var baseline := int(registration.get("confirmed_wave",0))
					var removed := pending.size()
					pending = pending.filter(func(item): return item.match_id!=run or int(item.wave)>baseline)
					if removed>pending.size(): status = "Partida registrada. Hordas anteriores ao registro online não geram moeda."
			else: status = str(registration.get("error","Registro da partida pendente."))
	if owner==uid and reply.ok:
		var sent := 0
		for item in pending.duplicate(true):
			if not registered.has(item.match_id) or item.match_id!=bound_run: continue
			if sent>=8: break
			sent += 1
			var reward := await request("horde",item)
			if owner!=uid: break
			if reward.ok: confirmed = reward.profile; pending.erase(item); status = "Crédito já confirmado." if reward.get("duplicate",false) else "+100 "+str(Catalog16.data().currency.name)+" confirmado."
			else:
				status = str(reward.get("error","Crédito pendente.")); break
	busy = false; persist(); changed.emit()
func horde(run: String,wave: int) -> void:
	if uid.is_empty() or clock.afk: return
	var item := {"match_id":run,"wave":wave}
	if not item in pending: pending.append(item); dirty = true; persist(); sync_left = 0
func purchase(id: String) -> void:
	if busy: return
	busy = true; var owner := uid
	var reply := await request("purchase",{"item_id":id,"operation_id":Crypto.new().generate_random_bytes(16).hex_encode()})
	if owner==uid:
		if reply.ok: confirmed = reply.profile; status = "Cosmético adquirido."
		else: status = str(reply.get("error","Compra não confirmada."))
	busy = false; persist(); changed.emit()
func equip(class_id: String,slot: String,id: String) -> void:
	if busy: return
	busy = true; var owner := uid
	var reply := await request("equip",{"class_id":class_id,"slot":slot,"item_id":id})
	if owner==uid:
		if reply.ok: confirmed = reply.profile
		else: status = str(reply.get("error","Não foi possível equipar."))
	busy = false; persist(); changed.emit()
func outfit(class_id: String) -> Dictionary: return confirmed.get("equipped",{}).get(class_id,{}).duplicate()

func session_batch() -> Dictionary:
	var result := {}
	for key in sessions:
		if result.size()>=16: break
		result[key] = sessions[key]
	return result
