class_name Exploration16
extends RefCounted
var world: Node3D
var sectors: Dictionary = {}
var nodes: Dictionary = {}
var tick_left := 0.0
static func roll(seed_value: int,coord: Vector2i) -> String:
	if coord==Vector2i.ZERO: return "normal"
	var rng := RandomNumberGenerator.new(); rng.seed = hash("special16:%d:%s" % [seed_value,SectorGenerator.key(coord)])
	var n := rng.randi_range(0,99)
	return "titan" if n<int(Catalog16.data().encounters.boss_percent) else "post" if n<int(Catalog16.data().encounters.boss_percent)+int(Catalog16.data().encounters.post_percent) else "normal"
func decorate(d: Dictionary,coord: Vector2i) -> Dictionary:
	if coord==Vector2i.ZERO: return d
	if world.game_mode=="rescue":
		d.special16 = "normal"; return d
	var key := SectorGenerator.key(coord)
	if not sectors.has(key): sectors[key] = {"kind":roll(world.world_seed,coord),"hp":20000.0,"dead":false,"reward":{},"loot_created":false,"stocks":{},"pos":[15.0,0.0]}
	var s: Dictionary = sectors[key]
	d.special16 = s.kind
	if s.kind=="normal": return d
	# Stable special encounter; normal sector cache expiry never rerolls it.
	if s.kind=="post":
		d.risk = 0; d.count = 0; d.roster = []; d.base_count = 0; d.base_roster = []; d.houses = []; d.caches = []; d.rare = -1
	else:
		d.risk = 3
		d.roster = d.roster.map(func(k): return 2 if int(k)==8 else k)
		if d.has("base_roster"): d.base_roster = d.base_roster.map(func(k): return 2 if int(k)==8 else k)
	return d
func kind_at(coord: Vector2i) -> String: return sectors.get(SectorGenerator.key(coord),{}).get("kind","normal")
func safe(point: Vector3) -> bool:
	var coord: Vector2i = world.coord_at(point)
	return kind_at(coord)=="post" and (point-world.sector_offset(coord)).length()<14
func load_sector() -> void:
	if world.is_client or world.field_root==null: return
	var key := SectorGenerator.key(world.sector_coord)
	var s: Dictionary = sectors.get(key,{})
	if s.is_empty() or s.kind=="normal": return
	var root := Node3D.new(); root.name = "Special16"; world.field_root.add_child(root)
	nodes[key] = {"root":root}
	if s.kind=="post": build_post(root)
	elif not s.dead:
		var boss := CharacterBody3D.new(); boss.set_script(load("res://scripts/release16/titan16.gd")); boss.world = world
		boss.spec = CampaignData.enemy_spec(2).duplicate(true); boss.spec.id = "titan16"; boss.spec.title = "Titã Enraizado"
		boss.spec.values.scale = 3.0; boss.spec.values.speed = 1.5; boss.spec.values.damage = 25
		boss.enemy_kind = 20; boss.is_boss = true; boss.field_enemy = true; boss.encounter_index = -1; boss.net_id = world.next_id()
		boss.aim_height = 3.4; boss.position = Vector3(float(s.pos[0]),0,float(s.pos[1])); boss.set_meta("titan16",true); boss.encounter_key = key
		world.field_root.add_child(boss); boss.health.setup(20000); boss.health.current = float(s.hp); boss.set_meta("night_hp",1.0); boss.set_meta("night_damage",1.0); world.v15.day.apply_enemy(boss)
		world.enemy_index[boss.net_id] = boss; var id: int = boss.net_id; boss.tree_exiting.connect(func(): world.enemy_index.erase(id)); nodes[key].boss = boss
		world.notify("AMEAÇA COLOSSAL · Titã Enraizado · combate opcional; as saídas permanecem livres.")
	if s.kind=="titan" and s.dead and not s.reward.is_empty():
		var loot: Node3D = world.spawn_loot(world.field_root.to_global(Vector3(15,0,3)),s.reward.duplicate(),0,"",0,false,true)
		if loot!=null: loot.set_meta("special16",true); world.mark_boss_drop(loot); nodes[key].loot = loot
func build_post(root: Node3D) -> void:
	VisualFactory.cylinder(root,13,.12,Vector3(0,.02,0),Color("62684d"))
	for i in range(32):
		var angle := i*TAU/32
		if i%8 in [0,1,7]: continue
		var post := Vector3(cos(angle)*13,.7,sin(angle)*13)
		VisualFactory.cylinder(root,.13,1.4,post,Color("8b7654"))
		var rail := VisualFactory.box(root,Vector3(2.2,.16,.14),post+Vector3(0,.15,0),Color("786b50")); rail.rotation.y = -angle+PI/2
	if not MobilePlatform.enabled():
		var lamp := OmniLight3D.new(); lamp.position = Vector3(0,3,-3); lamp.light_color = Color("ffd498"); lamp.light_energy = .6; lamp.omni_range = 14; lamp.shadow_enabled = false; root.add_child(lamp)
	for i in range(3):
		var p := Vector3((i-1)*6,0,-4)
		VisualFactory.box(root,Vector3(4,.15,3),p+Vector3(0,2.8,0),[Color("918757"),Color("8c5456"),Color("657b7c")][i])
		VisualFactory.human(root,Color("9d9a7a"),false).position = p
		VisualFactory.box(root,Vector3(3.5,.9,.7),p+Vector3(0,.45,1.2),Color("807451"))
		for side in [-1,1]: VisualFactory.cylinder(root,.1,2.7,p+Vector3(side*1.8,1.35,1),Color("8b7756"))
		VisualFactory.cylinder(root,.14,.32,p+Vector3(1.5,2.4,.7),Color("ffd498"),true)
		var label := VisualFactory.health_label(root,2.7); label.position = p+Vector3(0,2.7,0); label.text = ["Mara · Bolsas","Davi · Médico","Ferrugem · Trocas"][i]; label.font_size = 24
	var title := VisualFactory.health_label(root,4); title.text = "POSTO DO FAROL · E / COLETAR para negociar"; title.font_size = 26
func interact(actor: Node3D) -> bool:
	return kind_at(actor.region_coord)=="post" and safe(actor.global_position)
func trade(actor: Node3D,id: String) -> bool:
	if world.waves.running or not interact(actor): world.private_notice(actor.peer_id,"Vendedores se abrigaram — volte após a horda."); return false
	var state: Dictionary = sectors[SectorGenerator.key(actor.region_coord)]
	var stock_key := str(world.waves.wave)+":"+id
	var used := int(state.stocks.get(stock_key,0))
	var bag: ItemBag = actor.bag
	if id=="bag":
		if bag.bag_level!=1 or bag.count("scrap")<int(Catalog16.data().bag.upgrade_scrap) or bag.count("parts")<int(Catalog16.data().bag.upgrade_parts): return false
		if not bag.equip_level(2): return false
		bag.remove("scrap",int(Catalog16.data().bag.upgrade_scrap)); bag.remove("parts",int(Catalog16.data().bag.upgrade_parts))
	elif id in ["medkit","light"]:
		var cost := int(Catalog16.data().post.medkit_scrap if id=="medkit" else Catalog16.data().post.light_scrap)
		var count := 1 if id=="medkit" else int(Catalog16.data().post.light_amount)
		if used>=int(Catalog16.data().post.stock_per_horde) or bag.count("scrap")<cost: return false
		var copy := ItemBag.new(); copy.restore(bag.dump()); copy.remove("scrap",cost)
		if copy.add(id,count)!=count: return false
		bag.restore(copy.dump()); state.stocks[stock_key] = used+1
	elif id=="exchange":
		var copy := ItemBag.new(); copy.restore(bag.dump())
		if not copy.remove("wood",20) or copy.add("parts",1)!=1: return false
		bag.restore(copy.dump())
	else: return false
	world.private_notice(actor.peer_id,"Troca concluída · materiais da mochila."); return true
func remember() -> void:
	for key in nodes:
		var entry: Dictionary = nodes[key]; var s: Dictionary = sectors.get(key,{})
		if s.is_empty(): continue
		var boss = entry.get("boss")
		if is_instance_valid(boss) and not boss.health.dead:
			s.hp = clampf(boss.health.current/float(boss.get_meta("night_hp",1)),0,20000); s.pos = [boss.position.x,boss.position.z]
		var loot = entry.get("loot")
		if is_instance_valid(loot): s.reward = loot.contents.duplicate()
func defeated(boss: Node3D) -> void:
	var s: Dictionary = sectors[boss.encounter_key]
	if s.dead: return
	s.dead = true; s.hp = 0
	var rng := RandomNumberGenerator.new(); rng.seed = hash(boss.encounter_key+str(world.world_seed)+"loot16")
	s.reward = {"scrap":rng.randi_range(250,400),"parts":rng.randi_range(8,12),"rifle_ammo":60,"medkit":1}
	s.loot_created = true
	var loot: Node3D = world.spawn_loot(boss.global_position+Vector3(0,0,3),s.reward.duplicate(),0,"",0,false,true)
	if loot!=null: loot.set_meta("special16",true); world.mark_boss_drop(loot); nodes[boss.encounter_key].loot = loot
	world.notify("TITÃ DERROTADO · suprimentos raros compartilhados. Nenhuma moeda é concedida por este abate.")
func tick(delta: float) -> void:
	if world.is_client: return
	tick_left -= delta
	if tick_left>0: return
	tick_left = .2; remember()
	for enemy in world.get_tree().get_nodes_in_group("enemies"):
		if safe(enemy.global_position):
			var center: Vector3 = world.sector_offset(world.coord_at(enemy.global_position))
			var direction: Vector3 = (enemy.global_position-center)*Vector3(1,0,1)
			if direction.length()<.1: direction = Vector3.RIGHT
			enemy.global_position = center+direction.normalized()*18
	for key in nodes.keys():
		if not is_instance_valid(nodes[key].get("root")): nodes.erase(key)
func dump() -> Dictionary: remember(); return {"sectors":sectors.duplicate(true)}
func restore(data: Dictionary) -> void: sectors = data.get("sectors",{}).duplicate(true)
static func valid(data: Variant) -> bool:
	if not data is Dictionary or not data.get("sectors") is Dictionary or data.sectors.size()>8192: return false
	for key in data.sectors:
		var s = data.sectors[key]
		if not key is String or key.length()>24 or not s is Dictionary or s.get("kind") not in ["normal","post","titan"] or not SectorMemory.number(s.get("hp"),0,20000) or not s.get("dead") is bool or not s.get("stocks") is Dictionary or not SectorMemory.contents(s.get("reward")): return false
		if not s.get("pos") is Array or s.pos.size()!=2 or not SectorMemory.number(s.pos[0],-65,65) or not SectorMemory.number(s.pos[1],-65,65): return false
		for value in s.stocks.values():
			if not SectorMemory.number(value,0,2,true): return false
	return true
