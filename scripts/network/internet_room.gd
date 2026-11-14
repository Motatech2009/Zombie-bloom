class_name InternetRoom
extends Node
signal changed
var requested: bool = false
var port: int = 24567
var public_address: String = ""
var status: String = "Internet opcional: configure a porta ou use uma rede virtual."
var worker: Thread
var operation: String = ""
var mapping: Object
var mapped_port: int = 0
var renew_left: float = 300
var setup_task: Callable = setup_router

static func public_ipv4(address: String) -> bool:
	if not address.is_valid_ip_address() or address.contains(":"): return false
	var parts := address.split(".")
	if parts.size()!=4: return false
	var a := int(parts[0]); var b := int(parts[1]); var c := int(parts[2])
	if a in [0,10,127] or a>=224 or a==169 and b==254 or a==172 and b>=16 and b<=31 or a==192 and b==168 or a==100 and b>=64 and b<=127: return false
	if a==198 and b in [18,19] or a==192 and b==0 or a==198 and b==51 and c==100 or a==203 and b==0 and c==113: return false
	return true

static func parse_endpoint(text: String,default_port: int) -> Dictionary:
	var address := text.strip_edges()
	var chosen := default_port
	if address.begins_with("["):
		var end := address.find("]")
		if end<0: return {}
		var suffix := address.substr(end+1)
		if not suffix.is_empty():
			if not suffix.begins_with(":") or not suffix.substr(1).is_valid_int(): return {}
			chosen = int(suffix.substr(1))
		address = address.substr(1,end-1)
	elif address.count(":")==1:
		var pair := address.split(":")
		if not pair[1].is_valid_int(): return {}
		address = pair[0]; chosen = int(pair[1])
	if chosen<1024 or chosen>65535 or address.is_empty() or address.length()>253 or address.contains("/") or address.contains(" ") or address.contains("@") or address.contains("\\"): return {}
	if not address.is_valid_ip_address():
		for character in address:
			if not character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789.-": return {}
		if address.begins_with(".") or address.ends_with(".") or address.contains(".."): return {}
	return {"address":address,"port":chosen}

static func local_endpoints(server_port: int) -> PackedStringArray:
	var result := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.is_valid_ip_address() and not address.contains(":") and not address.begins_with("127.") and address!="0.0.0.0": result.append(address+":"+str(server_port))
	return result

# Synchronous router APIs run only in this worker, never on the rendering thread.
static func setup_router(server_port: int) -> Dictionary:
	var upnp := UPNP.new()
	var error := upnp.discover(1800,2)
	if error!=UPNP.UPNP_RESULT_SUCCESS or upnp.get_gateway()==null or not upnp.get_gateway().is_valid_gateway(): return {"status":"Roteador UPnP não encontrado. Use Tailscale ou configure UDP manualmente.","mapping":null}
	var address := upnp.query_external_address()
	if not public_ipv4(address): return {"status":"Roteador sem IPv4 público direto (CGNAT ou duplo NAT). Use Tailscale para jogar entre casas.","mapping":null}
	error = upnp.add_port_mapping(server_port,server_port,"Zombie Bloom","UDP",900)
	if error!=UPNP.UPNP_RESULT_SUCCESS: return {"status":"O roteador recusou a porta UDP (código %d). Use outra porta, encaminhamento manual ou Tailscale." % error,"mapping":null}
	return {"status":"Porta UDP configurada. Compartilhe o endereço abaixo; a entrada externa ainda depende da operadora e do firewall.","mapping":upnp,"port":server_port,"address":address+":"+str(server_port)}

static func remove_mapping(gateway: Object,server_port: int) -> Dictionary:
	gateway.delete_port_mapping(server_port,"UDP")
	return {}

static func refresh_mapping(gateway: Object,server_port: int) -> Dictionary:
	var error: int = gateway.add_port_mapping(server_port,server_port,"Zombie Bloom","UDP",900)
	var address: String = gateway.query_external_address()
	return {"ok":error==UPNP.UPNP_RESULT_SUCCESS and public_ipv4(address),"address":address+":"+str(server_port)}

func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS
func enable(server_port: int) -> bool:
	if server_port<1024 or server_port>65535 or requested or worker!=null or mapping!=null: return false
	requested = true; port = server_port; public_address = ""
	status = "Configurando a conexão externa no roteador…"
	_start("setup",setup_task.bind(port)); changed.emit()
	return true

func disable() -> void:
	requested = false; public_address = ""
	if worker==null and mapping!=null: _start("remove",remove_mapping.bind(mapping,mapped_port))
	status = "Conexão externa automática desativada."
	changed.emit()

func _start(kind: String,task: Callable) -> void:
	operation = kind; worker = Thread.new()
	if worker.start(task)!=OK:
		worker = null; status = "Não foi possível iniciar configuração externa."; requested = false

func _process(delta: float) -> void:
	if worker!=null:
		if worker.is_alive(): return
		var result: Dictionary = worker.wait_to_finish(); worker = null
		if operation=="setup":
			mapping = result.get("mapping"); mapped_port = int(result.get("port",port))
			if requested:
				status = str(result.get("status","Não foi possível configurar a conexão externa."))
				public_address = str(result.get("address","")); renew_left = 300
				if mapping==null: requested = false
			elif mapping!=null: _start("remove",remove_mapping.bind(mapping,mapped_port))
		elif operation=="remove": mapping = null; mapped_port = 0
		elif operation=="refresh":
			if requested:
				public_address = str(result.address) if result.get("ok",false) else ""
				if not result.get("ok",false): status = "A renovação da porta falhou. Reconecte a configuração externa ou use Tailscale."
				renew_left = 300
			elif mapping!=null: _start("remove",remove_mapping.bind(mapping,mapped_port))
		changed.emit()
	if requested and mapping!=null and worker==null:
		renew_left -= delta
		if renew_left<=0: _start("refresh",refresh_mapping.bind(mapping,mapped_port))

func _exit_tree() -> void:
	if worker!=null and worker.is_started():
		var result: Dictionary = worker.wait_to_finish()
		if operation=="setup" and result.get("mapping")!=null: mapping = result.mapping; mapped_port = int(result.port)
		elif operation=="remove": mapping = null
	if mapping!=null: mapping.delete_port_mapping(mapped_port,"UDP")
