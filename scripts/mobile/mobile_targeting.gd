class_name MobileTargeting
extends RefCounted

static func alive(target: Node3D) -> bool:
	return is_instance_valid(target) and not target.is_queued_for_deletion() and target.is_in_group("enemies") and not target.health.dead

static func point(target: Node3D) -> Vector3:
	return target.global_position+Vector3(0,target.aim_height,0)

static func direction(actor: Node3D,target: Node3D) -> Vector3:
	return (point(target)-actor.global_position-Vector3(0,1.15,0)).normalized()

static func can_fire(actor: Node3D,target: Node3D) -> bool:
	if not alive(target) or actor.health.dead: return false
	var weapon := ItemBag.WEAPON_IDS.find(actor.bag.hand())
	if weapon<0: return false
	var origin: Vector3 = actor.global_position+Vector3(0,1.15,0)
	if origin.distance_to(point(target))>float(Arsenal.WEAPONS[weapon].values.range): return false
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,point(target),1|4|8,[actor.get_rid()]))
	# A zombie in front can receive the shot; solid cover cannot.
	return not hit.is_empty() and hit.collider.is_in_group("enemies") and alive(hit.collider)

static func resolve(world: Node3D,actor: Node3D,frame: Dictionary) -> Dictionary:
	if not frame.has("target"): return frame
	var request: Dictionary = frame.target
	var requested: bool = frame.get("fire",false)
	frame.fire = false
	if request.rev!=world.scene_revision: return frame
	for target in world.get_tree().get_nodes_in_group("enemies"):
		if target.net_id!=request.id or not alive(target): continue
		frame.aim = direction(actor,target)
		frame.fire = requested and can_fire(actor,target) and not frame.get("interact",false)
		break
	return frame
