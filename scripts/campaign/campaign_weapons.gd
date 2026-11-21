extends WeaponSystem

func _init() -> void:
	owned.assign([true,false,false,false,false])
	ammo.assign([12,6,30,40,0])

func spec() -> Resource:
	return CampaignData.WEAPONS[slot]

func capacity(index: int = -1) -> int:
	var chosen := slot if index<0 else index
	return 1 if chosen==4 else maxi(1,ceili(float(CampaignData.WEAPONS[chosen].values.capacity)*capacity_multiplier))

func equip(index: int) -> void:
	if index<0 or index>=owned.size() or not owned[index] or index==slot: return
	slot = index
	reload_left = 0
	cooldown = maxf(cooldown,.15)
	if is_instance_valid(actor) and is_instance_valid(actor.rig):
		var gun: MeshInstance3D = actor.rig.get_node("Gun")
		gun.scale = Vector3(1.8,1.8,1.3) if slot==4 else Vector3.ONE

func _process(delta: float) -> void:
	cooldown = maxf(0,cooldown-delta)
	if reload_left<=0: return
	reload_left = maxf(0,reload_left-delta)
	if reload_left==0:
		if slot==4:
			if world.rockets>0: world.rockets -= 1; ammo[4] = 1
		else: ammo[slot] = capacity()

func reload() -> bool:
	if slot==4 and world.rockets<=0: world.notify("Sem foguetes. Compre munição com Bento."); return false
	return super.reload()

func shoot(direction: Vector3) -> bool:
	if slot!=4:
		return super.shoot(world.air_aim(actor.global_position+Vector3(0,1.15,0),direction,float(spec().values.range)))
	if cooldown>0 or reload_left>0 or not owned[4]: return false
	if ammo[4]<=0: reload(); return false
	var origin: Vector3 = actor.global_position+Vector3(0,1.15,0)+direction*.8
	var aim: Vector3 = world.air_aim(origin,direction,36)
	if world.projectile("rocket",origin,origin+aim*36,130*minf(damage_multiplier,4),4.5,1.1)==null: return false
	ammo[4] -= 1
	cooldown = 1
	world.audio.play_tone(90,.15,.15)
	fired.emit()
	return true
