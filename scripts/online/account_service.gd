extends Node
## Firebase REST; passwords and session tokens are kept in memory only.
signal changed
const FLUSH_SECONDS := 120.0
const RANK_CACHE_SECONDS := 60
const PAGE_SIZE := 25
var project_id := ""
var api_key := ""
var token := ""
var refresh_token := ""
var token_deadline := 0
var user_id := ""
var nickname := "Sobrevivente"
var status := "Contas online aguardando configuração do Firebase. Você pode jogar como convidado."
var busy := false
var rows: Array = []
var local_summary: Dictionary = {}
var ledger := ProgressLedger.new()
var flush_clock := FLUSH_SECONDS
var retry_seconds := 15.0
var rank_cache: Dictionary = {}
var rank_request_at := -60000
var dirty := false
var disk_clock := 5.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load("res://online.cfg")==OK:
		project_id = str(cfg.get_value("firebase","project_id",""))
		api_key = str(cfg.get_value("firebase","api_key",""))
	var local := ConfigFile.new()
	if local.load("user://profile.cfg")==OK: nickname = str(local.get_value("profile","nickname",nickname)).left(16)
	if configured(): status = "Entre ou crie sua conta. Jogar como convidado continua disponível."

func configured() -> bool:
	return not project_id.is_empty() and not api_key.is_empty() and not project_id.contains("/")

func signed_in() -> bool: return not user_id.is_empty() and not token.is_empty()
func documents_url() -> String:
	return "https://firestore.googleapis.com/v1/projects/"+project_id+"/databases/(default)/documents"
func player_name() -> String:
	return "projects/"+project_id+"/databases/(default)/documents/players/"+user_id
func ledger_path() -> String: return "user://account_progress_"+user_id.sha256_text().left(24)+".json"

func persist() -> void:
	if user_id.is_empty(): return
	var file := FileAccess.open(ledger_path()+".tmp",FileAccess.WRITE)
	if file==null: return
	file.store_string(JSON.stringify(ledger.dump())); file.close()
	if DirAccess.rename_absolute(ledger_path()+".tmp",ledger_path())==OK: dirty = false

func save_nickname(value: String) -> void:
	nickname = value.strip_edges().replace("\n"," ").replace("\r"," ").left(16)
	if nickname.is_empty(): nickname = "Sobrevivente"
	var cfg := ConfigFile.new(); cfg.set_value("profile","nickname",nickname); cfg.save("user://profile.cfg")
	changed.emit()

func request_json(address: String,method: int,payload: Dictionary = {},form: bool = false) -> Dictionary:
	var req := HTTPRequest.new(); req.timeout = 15; add_child(req)
	var headers := PackedStringArray(["Content-Type: application/x-www-form-urlencoded" if form else "Content-Type: application/json"])
	if address.begins_with(documents_url()) and not token.is_empty(): headers.append("Authorization: Bearer "+token)
	var body := ""
	if method!=HTTPClient.METHOD_GET:
		if form:
			for key in payload: body += ("&" if not body.is_empty() else "")+str(key).uri_encode()+"="+str(payload[key]).uri_encode()
		else: body = JSON.stringify(payload)
	var err := req.request(address,headers,method,body)
	var reply := {"ok":false,"data":{},"code":0}
	if err==OK:
		var response: Array = await req.request_completed
		reply = {"ok":response[0]==HTTPRequest.RESULT_SUCCESS and response[1]>=200 and response[1]<300,"data":JSON.parse_string(response[3].get_string_from_utf8()),"code":int(response[1])}
	req.queue_free()
	return reply

func auth_url(action: String) -> String:
	return "https://identitytoolkit.googleapis.com/v1/accounts:"+action+"?key="+api_key.uri_encode()

func auth_error(data: Variant) -> String:
	var message := str(data.get("error",{}).get("message","")) if data is Dictionary else ""
	if message.contains("EMAIL_EXISTS"): return "Este e-mail já tem uma conta. Entre ou recupere a senha."
	if message.contains("TOO_MANY_ATTEMPTS"): return "Muitas tentativas. Aguarde antes de tentar novamente."
	if message.contains("OPERATION_NOT_ALLOWED"): return "Login por e-mail ainda não foi ativado neste Firebase."
	return "Não foi possível conectar. Confira e-mail, senha e conexão."

func refresh_url() -> String:
	return "https://securetoken.googleapis.com/v1/token?key="+api_key.uri_encode()

func ensure_token() -> bool:
	if not signed_in(): return false
	if Time.get_ticks_msec()<token_deadline: return true
	var reply := await request_json(refresh_url(),HTTPClient.METHOD_POST,{"grant_type":"refresh_token","refresh_token":refresh_token},true)
	if reply.ok and reply.data is Dictionary:
		token = str(reply.data.get("id_token","")); refresh_token = str(reply.data.get("refresh_token",refresh_token))
		token_deadline = Time.get_ticks_msec()+maxi(30,int(reply.data.get("expires_in",3600))-60)*1000
		return not token.is_empty()
	status = "Sessão sem conexão. Seus resultados continuam guardados neste aparelho."
	return false

func authenticate(email: String,password: String,signup: bool = false) -> void:
	if busy or signed_in(): return
	if not configured(): changed.emit(); return
	if not email.contains("@") or password.length()<8:
		status = "Informe e-mail e senha de pelo menos 8 caracteres."; changed.emit(); return
	busy = true; status = "Conectando…"; changed.emit()
	var reply := await request_json(auth_url("signUp" if signup else "signInWithPassword"),HTTPClient.METHOD_POST,{"email":email.strip_edges(),"password":password,"returnSecureToken":true})
	if reply.ok and reply.data is Dictionary and reply.data.has("idToken") and reply.data.has("localId"):
		token = str(reply.data.idToken); user_id = str(reply.data.localId); refresh_token = str(reply.data.get("refreshToken",""))
		token_deadline = Time.get_ticks_msec()+maxi(30,int(reply.data.get("expiresIn",3600))-60)*1000
		ledger = ProgressLedger.new()
		if FileAccess.file_exists(ledger_path()):
			var saved = JSON.parse_string(FileAccess.get_file_as_string(ledger_path()))
			if saved is Dictionary: ledger.restore(saved)
		if ledger.device.is_empty(): ledger.device = Crypto.new().generate_random_bytes(16).hex_encode(); persist()
		var profile := await request_json(documents_url()+"/players/"+user_id,HTTPClient.METHOD_GET)
		if profile.ok and profile.data is Dictionary:
			var values := decode_fields(profile.data.get("fields",{})); local_summary = values
			save_nickname(str(values.get("nickname",nickname)))
		elif int(profile.get("code",0))==404:
			if not await write_profile(): profile.code = 503
		status = "Conectado como "+nickname+". Resultados sincronizados em lote."
		if not profile.ok and int(profile.get("code",0))!=404: status = "Login concluído. O ranking está indisponível; confira a configuração do Firestore."
		flush_clock = 1
	else: status = auth_error(reply.data)
	busy = false; changed.emit()

static func decode_fields(fields: Dictionary) -> Dictionary:
	var values := {}
	for key in fields:
		var field: Dictionary = fields[key]
		values[key] = int(field.integerValue) if field.has("integerValue") else str(field.get("stringValue",""))
	return values

func write_profile() -> bool:
	var reply := await request_json(documents_url()+":commit",HTTPClient.METHOD_POST,{"writes":[{"update":{"name":player_name(),"fields":{"nickname":{"stringValue":nickname}}},"updateMask":{"fieldPaths":["nickname"]}}]})
	return bool(reply.ok)

func save_online_profile(value: String) -> void:
	if busy: return
	save_nickname(value)
	if not signed_in(): return
	busy = true
	var ok := false
	if await ensure_token(): ok = await write_profile()
	status = "Apelido público salvo." if ok else "Apelido salvo no aparelho. Tente salvar online novamente."
	busy = false; changed.emit()

func record_progress(run: String,values: Dictionary,baseline: bool = false) -> void:
	if not signed_in(): return
	if ledger.observe(run,values,baseline): dirty = true

func _process(delta: float) -> void:
	if not signed_in(): return
	disk_clock -= delta
	if dirty and disk_clock<=0: persist(); disk_clock = 5
	flush_clock -= delta
	if flush_clock<=0 and not busy: flush_progress()

func flush_progress() -> void:
	if busy or not configured() or not signed_in(): return
	flush_clock = FLUSH_SECONDS
	# No database reads or writes while idle.
	if not dirty and ledger.totals==local_summary.get("device_totals",{}): return
	var acknowledged: Dictionary = local_summary.get("device_totals",{"kills":0,"hordes":0,"scrap":0})
	if ledger.delta_from(acknowledged).values().all(func(value): return value==0): return
	persist(); busy = true
	if not await ensure_token():
		busy = false; flush_clock = retry_seconds; retry_seconds = minf(120,retry_seconds*2); changed.emit(); return
	var sync_url := documents_url()+"/players/"+user_id+"/devices/"+ledger.device
	var remote := await request_json(sync_url,HTTPClient.METHOD_GET)
	if not remote.ok and int(remote.get("code",0))!=404:
		sync_failed(); return
	var remote_values := decode_fields(remote.data.get("fields",{})) if remote.ok and remote.data is Dictionary else {}
	var target := ledger.totals.duplicate()
	var delta_values := ledger.delta_from(remote_values)
	if delta_values.values().all(func(value): return value==0):
		local_summary.device_totals = target; busy = false; retry_seconds = 15; changed.emit(); return
	var fields := {}; var transforms: Array = []
	for metric in ProgressLedger.METRICS:
		fields[metric] = {"integerValue":str(target[metric])}
		transforms.append({"fieldPath":metric,"increment":{"integerValue":str(delta_values[metric])}})
	var condition: Dictionary = {"updateTime":remote.data.updateTime} if remote.ok else {"exists":false}
	var reply := await request_json(documents_url()+":commit",HTTPClient.METHOD_POST,{"writes":[
		{"update":{"name":player_name()+"/devices/"+ledger.device,"fields":fields},"currentDocument":condition},
		{"update":{"name":player_name(),"fields":{"nickname":{"stringValue":nickname}}},"updateMask":{"fieldPaths":["nickname"]},"updateTransforms":transforms}
	]})
	if not reply.ok: sync_failed(); return
	for metric in ProgressLedger.METRICS: local_summary[metric] = int(local_summary.get(metric,0))+int(delta_values[metric])
	local_summary.device_totals = target
	status = "Resultados sincronizados."; retry_seconds = 15; busy = false; changed.emit()

func sync_failed() -> void:
	status = "Resultados guardados no aparelho. Nova tentativa quando a conexão permitir."
	flush_clock = retry_seconds; retry_seconds = minf(120,retry_seconds*2); busy = false; changed.emit()

func fetch_ranking(metric: String,_mode: String = "all",_offset: int = 0) -> void:
	if metric not in ProgressLedger.METRICS or busy: return
	rows.clear()
	if not configured(): changed.emit(); return
	if not signed_in(): status = "Entre na conta para consultar o ranking."; changed.emit(); return
	var now := Time.get_ticks_msec()
	if rank_cache.has(metric) and now-int(rank_cache[metric].at)<RANK_CACHE_SECONDS*1000:
		rows = rank_cache[metric].rows.duplicate(true); status = "Ranking recente · atualização a cada 60 segundos."; changed.emit(); return
	if now-rank_request_at<15000: status = "Aguarde alguns segundos antes de atualizar."; changed.emit(); return
	rank_request_at = now; busy = true
	if not await ensure_token(): busy = false; changed.emit(); return
	var reply := await request_json(documents_url()+":runQuery",HTTPClient.METHOD_POST,{"structuredQuery":{"from":[{"collectionId":"players"}],"orderBy":[{"field":{"fieldPath":metric},"direction":"DESCENDING"}],"limit":PAGE_SIZE}})
	if reply.ok and reply.data is Array:
		for entry in reply.data:
			if not entry is Dictionary or not entry.has("document"): continue
			var values := decode_fields(entry.document.get("fields",{}))
			rows.append({"position":rows.size()+1,"nickname":values.get("nickname","Sobrevivente"),"score":values.get(metric,0)})
		rank_cache[metric] = {"at":now,"rows":rows.duplicate(true)}; status = "Top 25 · "+{"kills":"abates","hordes":"hordas vencidas","scrap":"sucata coletada"}[metric]
	else: status = "Ranking indisponível. Tente novamente mais tarde."
	busy = false; changed.emit()

func logout() -> void:
	if busy: return
	await flush_progress()
	persist(); token = ""; refresh_token = ""; user_id = ""; rows.clear(); local_summary.clear(); rank_cache.clear()
	ledger = ProgressLedger.new(); status = "Sessão encerrada. Você pode jogar como convidado."; changed.emit()

func recover(email: String) -> void:
	if busy or not configured(): return
	if not email.contains("@"): status = "Informe seu e-mail para recuperar o acesso."; changed.emit(); return
	busy = true
	var reply := await request_json(auth_url("sendOobCode"),HTTPClient.METHOD_POST,{"requestType":"PASSWORD_RESET","email":email.strip_edges()})
	status = "Se a conta existir, você receberá um link para trocar a senha no e-mail." if reply.ok else "Falha ao solicitar recuperação. Confira o e-mail e tente mais tarde."
	busy = false; changed.emit()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_WM_CLOSE_REQUEST]:
		persist()
		if signed_in() and not busy: flush_progress()
