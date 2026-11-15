class_name Progression15
extends UpgradeManager
const EXTRA = [
 {"id":"gather","title":"COLETA ÁGIL","text":"Velocidade de coleta +4,17% por nível (máx. +50%)","tag":"EXPLORAÇÃO"},
 {"id":"engineering","title":"ENGENHARIA RÁPIDA","text":"Tempo de obra/reparo -3,33% por nível (máx. -40%)","tag":"REFÚGIO"},
 {"id":"efficiency","title":"EFICIÊNCIA DE MUNIÇÃO","text":"Chance de poupar bala +2,08% por nível (máx. 25%)","tag":"EQUIPAMENTO"},
 {"id":"cargo","title":"CAPACIDADE DE CARGA","text":"Pilhas de material/munição +8,33% por nível","tag":"EXPLORAÇÃO"}]
func cap() -> int: return 2 if world.waves.wave<=5 else 7 if world.waves.wave<=10 else 12
func roll() -> Array:
	offers = []
	for entry in Catalog.UPGRADES+EXTRA:
		if int(levels.get(entry.id,0))<cap():
			var item: Dictionary = entry.duplicate()
			item.text = {"damage":"Dano +4% por nível","rate":"Cadência +3% por nível","capacity":"Pente +4% por nível","reload":"Recarga -2% por nível","speed":"Movimento +1,5% por nível","health":"Vida máxima +10 por nível"}.get(item.id,item.text)+" · N%d/%d" % [int(levels.get(item.id,0))+1,cap()]
			offers.append(item)
	offers.shuffle(); offers = offers.slice(0,3)
	# XP may continue rising; never pause forever with no eligible choices.
	if offers.is_empty(): world.resources.pending = 0
	return offers
func choose(index: int) -> bool:
	if world.resources.pending<=0 or index<0 or index>=offers.size(): return false
	var id: String = offers[index].id
	if int(levels.get(id,0))>=cap(): roll(); return false
	offers.clear(); world.resources.pending -= 1; levels[id] = int(levels.get(id,0))+1
	for actor in world.avatars.values(): apply_actor(actor)
	world.audio.play_tone(740,.18,.12)
	return true
func apply_actor(actor: Node3D) -> void:
	var gun = actor.weapons
	gun.damage_multiplier = 1+.04*int(levels.get("damage",0))
	gun.rate_multiplier = 1+.03*int(levels.get("rate",0))
	gun.capacity_multiplier = 1+.04*int(levels.get("capacity",0))
	gun.reload_multiplier = (1-.02*int(levels.get("reload",0)))*(.85 if actor.specialization=="shooter" else 1.0)
	gun.level = 1
	for value in levels.values(): gun.level += int(value)
	actor.speed_multiplier = 1+.015*int(levels.get("speed",0))
	var maximum = 100.0+10*int(levels.get("health",0))
	var gain: float = maxf(0,maximum-actor.health.maximum)
	actor.health.maximum = maximum; actor.health.current = 0 if actor.health.dead else minf(maximum,actor.health.current+gain)
	actor.bag.cargo_level = int(levels.get("cargo",0))
