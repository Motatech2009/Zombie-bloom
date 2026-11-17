class_name Truce16
extends RefCounted
var world: Node3D
var left := 0.0
var used_after := -1
var pending := false
var active_wave := 0

func activate(actor: Node3D) -> bool:
	if world.is_client or world.game_mode not in ["campaign","endless"] or world.phase=="ended" or world.waves.running or world.combat_paused() or actor.health.dead: return false
	if left>0 or pending or used_after==world.waves.wave or actor.bag.count("decoy16")==0:
		world.private_notice(actor.peer_id,"Uma isca por preparação. Vença a próxima horda para usar outra."); return false
	if not actor.bag.remove("decoy16",1): return false
	active_wave = 0
	left = float(Catalog16.data().truce.seconds); used_after = world.waves.wave; pending = true
	world.notify(actor.display_name+" ativou ISCA DE DESVIO · +10 min de exploração · próxima horda +20% infectados.")
	return true

# Return only the part of this frame not covered by the diversion.
func advance(delta: float) -> float:
	var spent := minf(left,maxf(0,delta)); left -= spent
	if spent>0 and left<=0: world.notify("ISCA ESGOTADA · contagem retomada · próxima horda +20% infectados.")
	return maxf(0,delta-spent)

func begin_wave(wave: int) -> void:
	active_wave = wave if pending else 0
	pending = false

func population(base: int) -> int:
	return ceili(base*(1+float(Catalog16.data().truce.extra_population))) if active_wave==world.waves.wave and active_wave>0 else base

func hint() -> String:
	if left>0: return "DESVIO %02d:%02d · próxima horda +20%%" % [ceili(left)/60,ceili(left)%60]
	if pending: return "PRÓXIMA HORDA · +20% INFECTADOS"
	if active_wave>0 and world.waves.running: return "HORDA REFORÇADA · +20% INFECTADOS"
	return ""

func dump() -> Dictionary: return {"left":left,"used_after":used_after,"pending":pending,"active_wave":active_wave}
func restore(data: Dictionary) -> void:
	left = float(data.get("left",0)); used_after = int(data.get("used_after",-1)); pending = bool(data.get("pending",false)); active_wave = int(data.get("active_wave",0))
static func valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	return SectorMemory.number(data.get("left"),0,600) and SectorMemory.number(data.get("used_after"),-1,1000000,true) and data.get("pending") is bool and SectorMemory.number(data.get("active_wave"),0,1000000,true) and (float(data.left)<=0 or (data.pending and int(data.active_wave)==0))
