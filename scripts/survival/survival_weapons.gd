extends "res://scripts/campaign/campaign_weapons.gd"
var hand_weapon: int = -1
var last_model: int = -2

func _init() -> void:
	super()
	ammo.assign([12,0,0,0,0])

func sync_hand() -> void:
	for i in range(5): owned[i] = actor.bag.count(ItemBag.WEAPON_IDS[i])>0
	var next_hand := ItemBag.WEAPON_IDS.find(actor.bag.hand())
	if next_hand!=hand_weapon: reload_left = 0
	hand_weapon = next_hand
	if hand_weapon>=0 and hand_weapon!=slot: equip(hand_weapon)
	if last_model!=hand_weapon and is_instance_valid(actor.rig): rebuild_model()

func equip(index: int) -> void:
	if index<0 or index>=5 or actor.bag.count(ItemBag.WEAPON_IDS[index])==0: return
	for i in range(9):
		if actor.bag.slots[i].id==ItemBag.WEAPON_IDS[index]: actor.bag.selected = i; break
	slot = index
	hand_weapon = index
	reload_left = 0
	cooldown = maxf(cooldown,.15)

func _process(delta: float) -> void:
	if world.is_client: return
	cooldown = maxf(0,cooldown-delta)
	if reload_left<=0: return
	reload_left = maxf(0,reload_left-delta)
	if reload_left==0:
		var id: String = ItemBag.AMMO_IDS[slot]
		var transfer := mini(capacity()-ammo[slot],actor.bag.count(id))
		if transfer>0 and actor.bag.remove(id,transfer): ammo[slot] += transfer

func reload() -> bool:
	if hand_weapon<0 or reload_left>0 or ammo[slot]>=capacity() or actor.bag.count(ItemBag.AMMO_IDS[slot])<=0: return false
	reload_total = maxf(.3,float(spec().values.reload)*reload_multiplier)
	reload_left = reload_total
	return true

func shoot(direction: Vector3) -> bool:
	if world.is_client or hand_weapon<0 or actor.gather_target!=null or actor.health.dead: return false
	# Campaign implementation handles the raycast/projectile; overridden reload is finite for all guns.
	world.shot_owner = actor.peer_id
	var result := super.shoot(direction)
	world.shot_owner = 1
	return result

func rebuild_model() -> void:
	last_model = hand_weapon
	var gun: MeshInstance3D = actor.rig.get_node("Gun")
	gun.visible = hand_weapon>=0
	for child in gun.get_children(): child.queue_free()
	if hand_weapon<0: return
	gun.scale = Vector3.ONE
	var size := Vector3(.16,.18,.42) if hand_weapon==0 else Vector3(.22,.23,.95) if hand_weapon==1 else Vector3(.2,.2,1.2) if hand_weapon==2 else Vector3(.22,.25,.65) if hand_weapon==3 else Vector3(.38,.38,1.3)
	var mesh := BoxMesh.new()
	mesh.size = size
	gun.mesh = mesh
	if hand_weapon==1:
		for x in [-.09,.09]: VisualFactory.box(gun,Vector3(.1,.1,.7),Vector3(x,0,-.5),Color("2c4148"))
	elif hand_weapon in [2,3]:
		VisualFactory.box(gun,Vector3(.12,.26,.2),Vector3(0,-.2,-.05),Color("344a4f"))
		VisualFactory.box(gun,Vector3(.2,.15,.3),Vector3(0,.02,.6),Color("6f7355"))
	elif hand_weapon==4: VisualFactory.cylinder(gun,.23,.25,Vector3(0,0,-.7),Color("96744c"))
