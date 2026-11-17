class_name IndividualProgression16
extends Progression15

const IDS = ["damage","rate","capacity","reload","speed","health","gather","engineering","efficiency","cargo"]
var players: Dictionary = {}
var remote_paused := false

func state(actor: Node3D) -> Dictionary:
	var key: String = actor.profile_id
	if not players.has(key):
		players[key] = {"levels":levels.duplicate() if actor.peer_id==1 else {},"queue":[],"through":world.waves.wave,"deferred":false}
	return players[key]

func levels_for(actor: Node3D) -> Dictionary:
	# Preserve the inherited host-level save field for pre-1.6 migrations.
	return levels if actor.peer_id==1 else state(actor).levels

func level_for(actor: Node3D,id: String) -> int:
	return int(levels_for(actor).get(id,0))

func pending_for(actor: Node3D) -> int:
	return state(actor).queue.size()

func current(actor: Node3D) -> Dictionary:
	var queue: Array = state(actor).queue
	return {} if queue.is_empty() else queue[0]

func available(actor: Node3D) -> Array:
	var result: Array = []
	for entry in Catalog.UPGRADES+EXTRA+Catalog16.talents():
		if entry.has("class_id") and entry.class_id!=actor.specialization: continue
		var level := level_for(actor,entry.id)
		if level>=limit_for(entry.id): continue
		var item: Dictionary = entry.duplicate()
		item.level = level; item.maximum = limit_for(entry.id)
		item.text = effect_text(entry.id,level)+" → "+effect_text(entry.id,level+1)
		result.append(item)
	return result

func limit_for(id: String) -> int: return 3 if id in Catalog16.talent_ids() else cap()

func effect_text(id: String,level: int) -> String:
	var talent := Catalog16.talent(id)
	if not talent.is_empty(): return str(talent.effect) % (int(talent.step)*level)
	match id:
		"damage": return "+%d%% dano" % (4*level)
		"rate": return "+%d%% cadência" % (3*level)
		"capacity": return "+%d%% pente" % (4*level)
		"reload": return "-%d%% tempo de recarga" % (2*level)
		"speed": return "+%.1f%% movimento" % (1.5*level)
		"health": return "+%d vida máxima" % (10*level)
		"gather": return "+%.1f%% velocidade de coleta" % (50.0*level/12)
		"engineering": return "-%.1f%% tempo de obra/reparo" % (40.0*level/12)
		"efficiency": return "%.1f%% de chance de poupar bala" % (25.0*level/12)
		"cargo": return "+%.1f%% por pilha elegível" % (100.0*level/12)
	return ""

func prepare(actor: Node3D) -> void:
	var choice := current(actor)
	if choice.is_empty(): return
	var options := available(actor)
	if options.is_empty():
		state(actor).queue.clear(); state(actor).deferred = false
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(choice.id)+JSON.stringify(levels_for(actor)))
	for i in range(options.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var value = options[i]; options[i] = options[j]; options[j] = value
	choice.offers = options.slice(0,3)
	var own := options.filter(func(t): return t.has("class_id"))
	if not own.is_empty() and not choice.offers.any(func(t): return t.has("class_id")): choice.offers[0] = own[0]

func award_horde(wave: int) -> void:
	if world.is_client or wave<=0: return
	for actor in world.avatars.values():
		var entry := state(actor)
		if wave<=int(entry.through): continue
		entry.through = wave
		if available(actor).is_empty(): continue
		entry.queue.append({"id":world.account_run_id+":"+str(wave)+":"+actor.profile_id,"wave":wave,"offers":[]})
		entry.deferred = false
		if entry.queue.size()==1: prepare(actor)
	refresh_local()

func refresh_local() -> void:
	if not is_instance_valid(world.player): return
	var actor: Node3D = world.player if world.is_client else world.avatars.get(1,world.player)
	world.resources.pending = pending_for(actor)
	var choice := current(actor)
	offers = choice.get("offers",[]).duplicate(true)

func roll() -> Array:
	if not world.is_client: prepare(world.player); refresh_local()
	return offers

func choose(index: int) -> bool:
	return choose_for(world.player,index,str(current(world.player).get("id","")))

func choose_for(actor: Node3D,index: int,choice_id: String) -> bool:
	if world.is_client or world.waves.running: return false
	var choice := current(actor)
	if choice.is_empty() or choice_id.is_empty() or choice.get("id")!=choice_id: return false
	var cards: Array = choice.offers
	if index<0 or index>=cards.size(): return false
	var id: String = cards[index].id
	var talent := Catalog16.talent(id)
	if (id not in IDS and talent.is_empty()) or (not talent.is_empty() and talent.class_id!=actor.specialization) or level_for(actor,id)>=limit_for(id): prepare(actor); return false
	var own_levels := levels_for(actor)
	own_levels[id] = int(own_levels.get(id,0))+1
	state(actor).levels = own_levels.duplicate()
	state(actor).queue.pop_front()
	state(actor).deferred = false
	prepare(actor)
	apply_actor(actor)
	refresh_local()
	world.audio.play_tone(740,.18,.12)
	return true

func defer_for(actor: Node3D,choice_id: String) -> bool:
	var choice := current(actor)
	if world.is_client or choice.is_empty() or choice.get("id")!=choice_id: return false
	state(actor).deferred = true
	refresh_local()
	return true

func paused() -> bool:
	if world.is_client: return remote_paused
	for actor in world.avatars.values():
		var entry := state(actor)
		if not entry.deferred and not entry.queue.is_empty(): return true
	return false

func apply_actor(actor: Node3D) -> void:
	var saved := levels
	levels = levels_for(actor)
	super.apply_actor(actor)
	levels = saved
	actor.weapons.rate_multiplier *= 1+Catalog16.bonus(actor,"shot_rate")
	actor.weapons.reload_multiplier *= 1-Catalog16.bonus(actor,"shot_reload")

func private_state(actor: Node3D) -> Dictionary:
	return {"through":int(state(actor).through),"identity":actor.profile_id,"levels":levels_for(actor).duplicate(),"choice":current(actor).duplicate(true),"pending":pending_for(actor),"deferred":state(actor).deferred}

func dump() -> Dictionary:
	for actor in world.avatars.values(): state(actor).levels = levels_for(actor).duplicate()
	return {"schema":1,"players":players.duplicate(true)}

func restore(data: Dictionary,legacy: Dictionary,profiles: Dictionary) -> void:
	players = data.get("players",{}).duplicate(true)
	levels = legacy.duplicate()
	# Each pre-existing profile keeps the formerly shared character bonuses.
	# Historical waves are a baseline, never retroactive reward claims.
	if data.is_empty():
		for key in profiles:
			players[key] = {"levels":legacy.duplicate(),"queue":[],"through":world.waves.wave,"deferred":false}
	for actor in world.avatars.values():
		var entry := state(actor)
		if actor.peer_id==1: levels = entry.levels.duplicate()
		if not entry.queue.is_empty(): prepare(actor)
	refresh_local()

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("schema")!=1 or not data.get("players") is Dictionary or data.players.size()>64: return false
	for key in data.players:
		if not key is String or key.is_empty() or key.length()>64: return false
		var entry = data.players[key]
		if not entry is Dictionary or not entry.get("levels") is Dictionary or not entry.get("queue") is Array or entry.queue.size()>128 or not entry.get("deferred") is bool: return false
		if not integer_in(entry.get("through"),0,100000000): return false
		for id in entry.levels:
			if (id not in IDS and id not in Catalog16.talent_ids()) or not integer_in(entry.levels[id],0,3 if id in Catalog16.talent_ids() else 12): return false
		var seen: Dictionary = {}
		for choice in entry.queue:
			if not choice is Dictionary or not choice.get("id") is String or choice.id.length()>160 or choice.id.is_empty() or seen.has(choice.id): return false
			seen[choice.id] = true
			if not integer_in(choice.get("wave"),1,int(entry.through)) or not choice.get("offers") is Array or choice.offers.size()>3: return false
			var offered: Dictionary = {}
			for card in choice.offers:
				if not card is Dictionary or (card.get("id") not in IDS and card.get("id") not in Catalog16.talent_ids()) or offered.has(card.id): return false
				offered[card.id] = true
	return true

static func integer_in(value: Variant,minimum: int,maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==floor(value) and value>=minimum and value<=maximum
