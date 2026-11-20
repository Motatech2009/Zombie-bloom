class_name FirestoreEconomy16
extends RefCounted
## Community economy: rules validate accounting, not authoritative combat.
const COLLECTION := "community16"
const CLASSES := ["engineer","scout","shooter"]
const SLOTS := ["head","outfit","backpack","effect"]
var account: Node
var owner := ""
func _init(service: Node) -> void:
	account = service; owner = service.user_id
static func valid_id(value: String) -> bool:
	var pattern := RegEx.new(); pattern.compile("^[A-Za-z0-9_-]{1,64}$"); return pattern.search(value)!=null
func current() -> bool: return account.user_id==owner and not owner.is_empty()
func name(suffix: String = "") -> String:
	return "projects/"+account.project_id+"/databases/(default)/documents/"+COLLECTION+"/"+owner+suffix
static func encode(value: Variant) -> Dictionary:
	if value is Dictionary:
		if value.size()==1 and value.has("timestampValue"): return value
		var fields := {}
		for key in value: fields[key] = encode(value[key])
		return {"mapValue":{"fields":fields}}
	if value is Array: return {"arrayValue":{"values":value.map(func(v): return encode(v))}}
	if value is int or value is float: return {"integerValue":str(int(value))}
	return {"stringValue":str(value)}
static func decode(value: Dictionary) -> Variant:
	if value.has("mapValue"):
		var fields := {}
		for key in value.mapValue.get("fields",{}): fields[key] = decode(value.mapValue.fields[key])
		return fields
	if value.has("arrayValue"): return value.arrayValue.get("values",[]).map(func(v): return decode(v))
	if value.has("integerValue"): return int(value.integerValue)
	if value.has("timestampValue"): return value
	return str(value.get("stringValue",""))
func read_doc(suffix: String = "") -> Dictionary:
	if not current(): return failure("A conta mudou.")
	var reply: Dictionary = await account.request_json(account.documents_url()+"/"+COLLECTION+"/"+owner+suffix,HTTPClient.METHOD_GET)
	if not current(): return failure("A conta mudou.")
	if reply.ok: reply.value = decode({"mapValue":{"fields":reply.data.get("fields",{})}})
	return reply
static func failure(message: String) -> Dictionary: return {"ok":false,"error":message}
static func blank() -> Dictionary:
	var equipped := {}
	for cls in CLASSES:
		equipped[cls] = {}
		for slot in SLOTS: equipped[cls][slot] = ""
	var epoch := {"timestampValue":"1970-01-01T00:00:00Z"}
	return {"balance":0,"owned":[],"equipped":equipped,"active_seconds":0,"longest_seconds":0,"created_at":epoch,"updated_at":epoch,"last_reward_at":epoch,"reward_day":epoch,"reward_count":0,"active_match":"","action":"init","item_id":"","session_id":""}
static func profile(wallet: Dictionary) -> Dictionary:
	var equipped := {}
	for cls in wallet.equipped:
		var slots := {}
		for slot in wallet.equipped[cls]:
			if not str(wallet.equipped[cls][slot]).is_empty(): slots[slot] = wallet.equipped[cls][slot]
		if not slots.is_empty(): equipped[cls] = slots
	return {"active_match":str(wallet.active_match),"balance":int(wallet.balance),"owned":wallet.owned,"equipped":equipped,"active_seconds":int(wallet.active_seconds),"longest_seconds":int(wallet.longest_seconds)}
func write_doc(suffix: String,wallet: Dictionary,remote: Dictionary,stamps: Array = []) -> Dictionary:
	var write := {"update":{"name":name(suffix),"fields":encode(wallet).mapValue.fields},"currentDocument":{"updateTime":remote.data.updateTime} if remote.get("ok",false) else {"exists":false}}
	if not stamps.is_empty():
		write.updateTransforms = []
		for stamp in stamps: write.updateTransforms.append({"fieldPath":stamp,"setToServerValue":"REQUEST_TIME"})
	return write
func commit(writes: Array) -> Dictionary:
	if not current(): return failure("A conta mudou.")
	return await account.request_json(account.documents_url()+":commit",HTTPClient.METHOD_POST,{"writes":writes})
func request(action: String,data: Dictionary = {}) -> Dictionary:
	if not current() or not await account.ensure_token(): return failure("Entre novamente para sincronizar.")
	# A compare-and-set commit retries after competing writes; no blind increments.
	for attempt in range(3):
		var remote := await read_doc()
		if not remote.ok and int(remote.get("code",0))!=404: return failure("Sem acesso à carteira. Confira a conexão e as regras do Firestore.")
		if not remote.ok:
			var initialized := await commit([write_doc("",blank(),remote,["created_at","updated_at"])])
			if not initialized.ok:
				if int(initialized.get("code",0)) in [409,412]: continue
				return failure("Carteira pendente. Publique as regras da economia no Firestore.")
			remote = await read_doc()
			if not remote.ok: return failure("Não foi possível carregar a carteira.")
		var wallet: Dictionary = remote.value.duplicate(true)
		if action=="profile": return {"ok":true,"profile":profile(wallet)}
		if action=="sync": return await sync_sessions(remote,data.get("sessions",{}))
		var writes: Array = []; var stamps: Array = ["updated_at"]
		wallet.action = action; wallet.item_id = ""; wallet.session_id = ""
		var metadata := {}
		if action in ["start","horde","titan"]:
			var run := str(data.get("match_id",""))
			if not valid_id(run): return failure("Identificador de partida inválido.")
			var suffix := "/matches/"+run
			var match_reply := await read_doc(suffix)
			if not match_reply.ok and int(match_reply.get("code",0))!=404: return failure("Não foi possível carregar a partida.")
			if action=="start":
				wallet.active_match = run
				if not match_reply.ok:
					var baseline := int(data.get("baseline",0)); var mode := str(data.get("mode",""))
					var match_data := {"mode":mode,"baseline":baseline,"wave":baseline,"created_at":{"timestampValue":"1970-01-01T00:00:00Z"},"rewarded_at":{"timestampValue":"1970-01-01T00:00:00Z"}}
					writes.append(write_doc(suffix,match_data,match_reply,["created_at","rewarded_at"]))
					metadata = {"new_registration":true,"confirmed_wave":baseline}
				else: metadata = {"new_registration":false,"confirmed_wave":int(match_reply.value.wave)}
			else:
				if not match_reply.ok or wallet.active_match!=run: return failure("Registre esta partida online antes de receber recompensas.")
				if action=="horde":
					var wave := int(data.get("wave",0)); var match_data: Dictionary = match_reply.value.duplicate(true)
					if wave<=int(match_data.wave): return {"ok":true,"duplicate":true,"profile":profile(wallet)}
					if wave!=int(match_data.wave)+1: return failure("Confirme as hordas na ordem.")
					match_data.wave = wave; wallet.balance = int(wallet.balance)+100
					var today := Time.get_date_string_from_system(true)
					var same_day := str(wallet.reward_day.timestampValue).left(10)==today
					wallet.reward_count = int(wallet.reward_count)+1 if same_day else 1
					stamps.append_array(["last_reward_at","reward_day"])
					writes.append(write_doc(suffix,match_data,match_reply,["rewarded_at"]))
				else:
					if "COS-TITAN-01" in wallet.owned: return {"ok":true,"duplicate":true,"profile":profile(wallet)}
					wallet.item_id = "COS-TITAN-01"; wallet.owned.append("COS-TITAN-01")
		elif action=="purchase":
			var id := str(data.get("item_id","")); var item := Catalog16.cosmetic(id)
			if item.is_empty() or item.has("unlock"): return failure("Este item não está à venda.")
			if id in wallet.owned: return {"ok":true,"duplicate":true,"profile":profile(wallet)}
			if int(wallet.balance)<int(item.price): return failure("Saldo insuficiente.")
			wallet.balance = int(wallet.balance)-int(item.price); wallet.owned.append(id); wallet.item_id = id
		elif action=="equip":
			var cls := str(data.get("class_id","")); var slot := str(data.get("slot","")); var id := str(data.get("item_id",""))
			if cls not in CLASSES or slot not in SLOTS: return failure("Espaço inválido.")
			if not id.is_empty():
				var item := Catalog16.cosmetic(id)
				if id not in wallet.owned or item.is_empty() or item.slot!=slot or item.class_id not in [cls,"all"]: return failure("Você não possui este cosmético para esta classe.")
			wallet.equipped[cls][slot] = id
		else: return failure("Operação desconhecida.")
		writes.push_front(write_doc("",wallet,remote,stamps))
		var result := await commit(writes)
		if not current(): return failure("A conta mudou.")
		if result.ok:
			var latest := await read_doc()
			if not latest.ok: return failure("Operação enviada. Reconecte para confirmar o saldo.")
			metadata.ok = true; metadata.profile = profile(latest.value); return metadata
		if int(result.get("code",0)) not in [409,412]:
			return failure("Recompensa pendente: aguarde o intervalo da horda e sincronize novamente." if action in ["horde","titan"] else "Operação não confirmada. Confira a conexão e as regras do Firestore.")
	return failure("A conta foi atualizada em outro aparelho. Tente novamente.")
func sync_sessions(remote: Dictionary,sessions: Dictionary) -> Dictionary:
	var ack: Array = []; var latest := remote
	var processed := 0
	for id in sessions:
		if processed >= 16: break
		processed += 1
		if not valid_id(str(id)): continue
		var suffix := "/sessions/"+str(id); var previous := await read_doc(suffix)
		if not previous.ok and int(previous.get("code",0))!=404: return failure("Tempo de jogo pendente.")
		var before := int(previous.value.seconds) if previous.ok else 0
		var requested := maxi(before,int(sessions[id]))
		if requested<=before: ack.append(id); continue
		var wallet: Dictionary = latest.value.duplicate(true)
		# Only time since the first online profile is eligible; local hours stay intact.
		var epoch := Time.get_unix_time_from_datetime_string(str(wallet.created_at.timestampValue))
		var capacity := maxi(0,int(Time.get_unix_time_from_system()-epoch)-int(wallet.active_seconds))
		var accepted := mini(requested,before+capacity)
		if accepted<=before: continue
		wallet.action = "sync"; wallet.item_id = ""; wallet.session_id = str(id)
		wallet.active_seconds = int(wallet.active_seconds)+accepted-before
		wallet.longest_seconds = maxi(int(wallet.longest_seconds),accepted)
		var result := await commit([write_doc("",wallet,latest,["updated_at"]),write_doc(suffix,{"seconds":accepted},previous)])
		if not result.ok: return failure("Tempo de jogo pendente; nova tentativa após reconectar.")
		if accepted == requested: ack.append(id)
		latest = await read_doc()
		if not latest.ok: return failure("Perfil pendente.")
	return {"ok":true,"profile":profile(latest.value),"ack_sessions":ack}
