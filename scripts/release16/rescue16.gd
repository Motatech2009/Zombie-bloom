class_name Rescue16
extends RefCounted
var world: Node3D
var phase := "search"
var component := false
var left := 0.0
var goal_hp := 500.0
var objective: Node3D
const SIGNAL = Vector2i(1,1)
const STATION = Vector2i(2,1)
func enabled() -> bool: return world.game_mode=="rescue"
func goal_coord() -> Vector2i: return Vector2i.ZERO if phase=="extraction" else STATION
func defending() -> bool: return phase in ["defense","extraction"] and world.waves.running
func hint() -> String:
	match phase:
		"search": return "1/3 · Localize o sinal em (1,1). E / MISSÃO para recuperar o componente."
		"activate": return "2/3 · Leve o componente à estação em (2,1). E / MISSÃO para ativar."
		"defense": return "2/3 · Proteja a estação · %d s · %d PV" % [ceili(left),ceili(goal_hp)]
		"return": return "3/3 · Retorne ao Núcleo (0,0) e solicite a extração."
		"extraction": return "3/3 · Proteja a extração · %d s" % ceili(left)
	return "Expedição concluída."
func interact(actor: Node3D) -> bool:
	if not enabled() or world.is_client or actor.health.dead: return false
	var local: Vector3 = actor.global_position-world.sector_offset(actor.region_coord)
	if local.length()>7: return false
	if phase=="search" and actor.region_coord==SIGNAL:
		component = true; phase = "activate"; world.notify("SINAL RECUPERADO · leve o componente à estação (2,1)."); return true
	if phase=="activate" and component and actor.region_coord==STATION:
		phase = "defense"; create_objective(); return world.waves.start()
	if phase=="return" and actor.region_coord==Vector2i.ZERO:
		phase = "extraction"; return world.waves.start()
	return false
func create_objective() -> void:
	if is_instance_valid(objective): return
	objective = StaticBody3D.new(); objective.set_script(load("res://scripts/release16/rescue_objective16.gd")); objective.director = self
	world.add_child(objective); objective.global_position = world.sector_offset(STATION)
func load_sector() -> void:
	if not enabled() or world.field_root==null: return
	var coord: Vector2i = world.sector_coord
	if coord not in [SIGNAL,STATION]: return
	var visual := Node3D.new(); world.field_root.add_child(visual)
	VisualFactory.box(visual,Vector3(1.8,1.4,1.8),Vector3(0,.7,0),Color("5e817a"))
	VisualFactory.cylinder(visual,.1,3,Vector3(0,2,0),Color("a8a17f"))
	var label := VisualFactory.health_label(visual,4); label.text = "SINAL / COMPONENTE" if coord==SIGNAL else "ESTAÇÃO DE TRANSMISSÃO"; label.font_size = 24
func tick(delta: float) -> void:
	if not enabled() or world.is_client: return
	if phase=="defense" and not world.waves.running and world.waves.wave==1 and world.avatars.values().any(func(a): return a.region_coord==STATION and not a.health.dead): world.waves.start()
	if not defending(): return
	var present: bool = world.avatars.values().any(func(a): return not a.health.dead and a.region_coord==goal_coord() and (a.global_position-world.sector_offset(goal_coord())).length()<28)
	if present: left = maxf(0,left-delta)
	if left<=0 and world.waves.to_spawn==0 and world.waves.alive()==0: world.waves.complete()
func completed() -> void:
	if world.waves.wave==1: left = 75
	elif world.waves.wave==2: phase = "return"; world.notify("ESTAÇÃO ATIVADA · volte ao Núcleo para a extração.")
	elif world.waves.wave==3: phase = "complete"; world.finish(true,"Sinal transmitido, estação protegida e equipe extraída.")
func dump() -> Dictionary: return {"phase":phase,"component":component,"left":left,"hp":goal_hp}
func apply(data: Dictionary) -> void:
	phase = str(data.get("phase","search")); component = bool(data.get("component",false)); left = float(data.get("left",0)); goal_hp = float(data.get("hp",500))
