extends Node
## No password/token persistence. Offline saves never depend on this service.
signal changed
var url := ""
var public_key := ""
var token := ""
var user_id := ""
var nickname := "Sobrevivente"
var status := "Contas online indisponíveis: serviço ainda não configurado."
var busy := false
var rows: Array = []
var local_summary: Dictionary = {}

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://online.cfg")==OK:
		url = str(cfg.get_value("supabase","url","")).trim_suffix("/")
		public_key = str(cfg.get_value("supabase","public_key",""))
	var local := ConfigFile.new()
	if local.load("user://profile.cfg")==OK: nickname = str(local.get_value("profile","nickname",nickname)).left(16)
	if configured(): status = "Entre ou crie sua conta. Offline continua disponível."

func configured() -> bool:
	return url.begins_with("https://") and not public_key.is_empty()

func save_nickname(value: String) -> void:
	nickname = value.strip_edges().left(16)
	if nickname.is_empty(): nickname = "Sobrevivente"
	var cfg := ConfigFile.new(); cfg.set_value("profile","nickname",nickname); cfg.save("user://profile.cfg")
	changed.emit()

func request_json(path: String,method: int,payload: Dictionary = {}) -> Dictionary:
	if busy or not configured(): return {"ok":false,"data":{}}
	busy = true
	var req := HTTPRequest.new(); req.timeout = 15; add_child(req)
	var headers := PackedStringArray(["apikey: "+public_key,"Content-Type: application/json"])
	if not token.is_empty(): headers.append("Authorization: Bearer "+token)
	var err := req.request(url+path,headers,method,"" if method==HTTPClient.METHOD_GET else JSON.stringify(payload))
	var reply: Dictionary = {"ok":false,"data":{}}
	if err==OK:
		var response: Array = await req.request_completed
		var parsed = JSON.parse_string(response[3].get_string_from_utf8())
		reply = {"ok":response[0]==HTTPRequest.RESULT_SUCCESS and response[1]>=200 and response[1]<300,"data":parsed,"code":response[1]}
		if response[1]==401: token = ""; user_id = ""
	req.queue_free(); busy = false
	return reply

func authenticate(email: String,password: String,signup: bool = false) -> void:
	if not configured(): changed.emit(); return
	if busy: return
	if not email.contains("@") or password.length()<8:
		status = "Informe e-mail e senha de pelo menos 8 caracteres."; changed.emit(); return
	status = "Conectando…"; changed.emit()
	var result := await request_json("/auth/v1/signup" if signup else "/auth/v1/token?grant_type=password",HTTPClient.METHOD_POST,{"email":email.strip_edges(),"password":password})
	if result.ok and result.data is Dictionary:
		token = str(result.data.get("access_token",""))
		user_id = str(result.data.get("user",{}).get("id","")) if not token.is_empty() else ""
		status = "Conta criada. Confirme o e-mail e entre." if token.is_empty() else "Conectado. Ranking exige partidas verificadas pelo servidor."
	else: status = "Não foi possível entrar/criar conta. Confira os dados, confirmação de e-mail e conexão."
	if not token.is_empty():
		var profile := await request_json("/rest/v1/rpc/my_profile",HTTPClient.METHOD_POST)
		if profile.ok and profile.data is Array and not profile.data.is_empty(): save_nickname(str(profile.data[0].nickname))
	changed.emit()

func save_online_profile(value: String) -> void:
	save_nickname(value)
	if token.is_empty(): return
	var result := await request_json("/rest/v1/rpc/set_nickname",HTTPClient.METHOD_POST,{"value":nickname})
	status = "Apelido público salvo." if result.ok else "Apelido salvo no aparelho; falha ao salvar online."
	changed.emit()

func fetch_ranking(metric: String,mode: String,offset: int = 0) -> void:
	if metric not in ["kills","hordes","scrap"] or mode not in ["campaign","endless"]: return
	rows.clear()
	if not configured(): changed.emit(); return
	var result := await request_json("/rest/v1/rpc/leaderboard",HTTPClient.METHOD_POST,{"metric":metric,"game_mode":mode,"page_offset":maxi(0,offset)})
	if result.ok and result.data is Array: rows = result.data; status = "Somente eventos de servidores autorizados."
	else: status = "Ranking indisponível. Nenhum total local foi enviado."
	changed.emit()

func logout() -> void:
	if busy: return
	if not token.is_empty(): await request_json("/auth/v1/logout",HTTPClient.METHOD_POST)
	token = ""; user_id = ""; rows.clear(); status = "Sessão encerrada neste aparelho."; changed.emit()

func recover(email: String) -> void:
	if busy or not configured(): return
	var result := await request_json("/auth/v1/recover",HTTPClient.METHOD_POST,{"email":email.strip_edges()})
	status = "Se a conta existir, confira o código no e-mail." if result.ok else "Falha ao solicitar recuperação. Tente mais tarde."
	changed.emit()

func reset_password(email: String,code: String,password: String) -> void:
	if busy or not configured() or password.length()<8: return
	var result := await request_json("/auth/v1/verify",HTTPClient.METHOD_POST,{"email":email.strip_edges(),"token":code.strip_edges(),"type":"recovery"})
	if not result.ok or not result.data is Dictionary:
		status = "Código inválido ou expirado."; changed.emit(); return
	token = str(result.data.get("access_token",""))
	if token.is_empty(): status = "Recuperação sem sessão válida."; changed.emit(); return
	result = await request_json("/auth/v1/user",HTTPClient.METHOD_PUT,{"password":password})
	await logout()
	status = "Senha atualizada. Entre novamente." if result.ok else "Não foi possível atualizar a senha."
	changed.emit()
