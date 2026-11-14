extends SceneTree
class FakeRouter extends RefCounted:
	var deleted: int = 0
	var renewed: int = 0
	func delete_port_mapping(_port: int,_proto: String) -> int: deleted += 1; return 0
	func add_port_mapping(_a: int,_b: int,_desc: String,_proto: String,_duration: int) -> int: renewed += 1; return 0
	func query_external_address() -> String: return "1.1.1.1"
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func settle(service: Node) -> void:
	var deadline := Time.get_ticks_msec()+3000
	while service.worker!=null and Time.get_ticks_msec()<deadline:
		await create_timer(.01).timeout
func run() -> void:
	for address in ["10.1.2.3","172.20.0.1","192.168.1.1","100.64.0.1","100.127.1.2","127.0.0.1","169.254.1.2","224.0.0.1","203.0.113.1","invalid","::1"]:
		check(not InternetRoom.public_ipv4(address),"non-public/router-only address is not advertised: "+address)
	check(InternetRoom.public_ipv4("1.1.1.1"),"valid public IPv4 can be advertised")
	check(InternetRoom.parse_endpoint(" 100.87.1.2:24568 ",24567)=={"address":"100.87.1.2","port":24568},"friends can paste a VPN address and port")
	check(InternetRoom.parse_endpoint("example.org",24567)=={"address":"example.org","port":24567},"manual hostname preserves the selected default port")
	check(InternetRoom.parse_endpoint("[2001:db8::1]:24569",24567).port==24569,"bracketed IPv6 endpoint is parsed without corrupting its host")
	for address in ["http://example.org","example.org:0","127.0.0.1:99999","bad host","[::1","x:abc"]:
		check(InternetRoom.parse_endpoint(address,24567).is_empty(),"malformed endpoint is rejected: "+address)
	var service := InternetRoom.new(); root.add_child(service)
	var router := FakeRouter.new()
	service.setup_task = func(port: int): return {"status":"ready","mapping":router,"port":port,"address":"1.1.1.1:"+str(port)}
	check(not service.enable(80),"automatic router configuration rejects invalid game ports")
	check(service.enable(24567) and service.worker!=null,"router setup starts in a worker instead of blocking the frame")
	check(not service.enable(24567),"repeated setup cannot create concurrent mappings")
	await settle(service)
	check(service.requested and service.public_address=="1.1.1.1:24567" and service.mapping==router,"finished worker publishes only its configured external endpoint")
	service.renew_left = 0; service._process(.1)
	await settle(service)
	check(router.renewed==1 and service.renew_left>290,"temporary port mapping is renewed in a worker")
	service.disable(); await settle(service)
	check(router.deleted==1 and service.mapping==null and service.public_address.is_empty(),"closing the service removes its mapping and invitation address")
	check(service.enable(24568),"external setup can be requested again after cleanup")
	service.disable(); await settle(service)
	check(router.deleted==2 and service.public_address.is_empty() and not service.requested,"canceling during discovery cleans a late mapping without advertising it")
	service.setup_task = func(_port: int): return {"mapping":null,"status":"no router"}
	service.enable(24567); await settle(service)
	check(service.status=="no router" and not service.requested and service.public_address.is_empty(),"router failure leaves LAN/VPN available without a false success")
	service.queue_free(); await process_frame
	var coop := root.get_node("Coop")
	check(coop.join_session("invalid/path",24567)==ERR_INVALID_PARAMETER and coop.mode=="offline","invalid invitations do not create a transport session")
	print("INTERNET RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
