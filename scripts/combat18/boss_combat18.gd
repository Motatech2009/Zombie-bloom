class_name BossCombat18
extends RefCounted

# First impact, spacing between impacts, number of impacts, recovery, cooldown.
const ATTACKS := {
	"quake": [1.12, .68, 3, .48, 13.0],
	"volley": [1.12, 0.0, 1, .64, 12.0],
	"slap": [.48, 0.0, 1, .65, 9.0],
	"scratches": [.66, .45, 2, .50, 8.0],
	"scream": [1.0, 0.0, 1, .65, 13.0],
	"gust": [1.14, 0.0, 1, .84, 10.0],
	"howl": [1.22, 0.0, 1, .76, 14.0],
	"block": [1.10, 0.0, 1, .60, 9.0],
	"clay": [.92, 0.0, 1, .60, 12.0],
	"brood": [1.25, 0.0, 1, .56, 13.0],
	"slam": [1.33, 0.0, 1, .65, 9.0],
	"stakes": [1.28, 0.0, 1, .55, 13.0],
	"vines": [1.43, 0.0, 1, .65, 17.0],
}
const START := {
	"mauler": {"quake": 3.0}, "mortar": {"volley": 4.0, "slap": 0.0},
	"broodmother": {"scratches": 2.7, "scream": 6.0}, "flyer": {"gust": 3.2},
	"hound": {"howl": 5.5}, "potter": {"block": 2.7, "clay": 5.3, "slap": 0.0},
	"hive": {"brood": 4.1}, "titan16": {"slam": 3.0, "stakes": 5.6, "vines": 8.8},
}
const CLAY_RANGE := 15.0
const CLAY_WIDTH := .84
const CLAY_FLIGHT := .48
const BIND_DURATION := 2.3

var enemy: Node3D
var attack := ""
var elapsed := 0.0
var hits := 0
var heading := Vector3.FORWARD
var point := Vector3.ZERO
var origin := Vector3.ZERO
var spots: Array[Vector3] = []
var warnings: Array[Node3D] = []
var cooldowns: Dictionary
var victim: Node3D
var nearby: Node3D
var near_time := 0.0
var clay_hits: Dictionary = {}

func _init(owner: Node3D) -> void:
	enemy = owner
	cooldowns = START.get(enemy.spec.id, {}).duplicate()

func tick(delta: float) -> bool:
	for id in cooldowns:
		cooldowns[id] = maxf(0.0, float(cooldowns[id]) - delta)
	var closest := closest_player()
	var distance := INF if closest == null else flat(closest.global_position - enemy.global_position).length()
	if enemy.spec.id in ["mortar", "potter"]:
		if closest != nearby or distance > 4.0:
			nearby = closest
			near_time = 0.0
		if distance <= 4.0:
			near_time += delta
	if not attack.is_empty():
		enemy.velocity = Vector3.ZERO
		enemy.rig.rotation.y = lerp_angle(enemy.rig.rotation.y, atan2(-heading.x, -heading.z), 1.0 - exp(-delta * 14.0))
		elapsed += delta
		var timing: Array = ATTACKS[attack]
		while hits < int(timing[2]) and elapsed >= float(timing[0]) + float(timing[1]) * hits:
			hits += 1
			impact()
		if attack == "clay" and hits > 0:
			update_clay(timing[0])
		if elapsed >= float(timing[0]) + float(timing[1]) * (int(timing[2]) - 1) + float(timing[3]):
			finish()
		return true
	if closest == null or enemy.windup > 0 or enemy.rush_left > 0 or enemy.leap_left > 0 or enemy.melee_left > 0 or enemy.stun_left > 0:
		return false
	var next := ""
	match enemy.spec.id:
		"mauler":
			if distance <= 9.0 and ready("quake"): next = "quake"
		"mortar":
			if near_time >= 6.0 and ready("slap"): next = "slap"
			elif distance <= 16.0 and ready("volley"): next = "volley"
		"broodmother":
			if distance <= 5.5 and ready("scratches"): next = "scratches"
			elif distance <= 9.0 and ready("scream"): next = "scream"
		"flyer":
			if distance <= 15.0 and ready("gust"): next = "gust"
		"hound":
			if distance <= 13.0 and ready("howl"): next = "howl"
		"potter":
			if near_time >= 8.0 and ready("slap"): next = "slap"
			elif distance <= 15.0 and ready("block"): next = "block"
			elif distance <= CLAY_RANGE and ready("clay"): next = "clay"
		"hive":
			if distance <= 15.0 and ready("brood"): next = "brood"
		"titan16":
			if distance <= 7.0 and ready("slam"): next = "slam"
			elif distance <= 20.0 and ready("vines"): next = "vines"
			elif distance <= 23.0 and ready("stakes"): next = "stakes"
	if next.is_empty(): return false
	begin(next, closest)
	return true

func closest_player() -> Node3D:
	var closest: Node3D
	var minimum := 24.1
	for actor in enemy.world.avatars.values():
		if not eligible(actor): continue
		var distance := flat(actor.global_position - enemy.global_position).length()
		if distance < minimum: closest = actor; minimum = distance
	return closest

func eligible(actor: Node3D) -> bool:
	return (is_instance_valid(actor) and not actor.health.dead
		and enemy.world.coord_at(actor.global_position) == enemy.world.coord_at(enemy.global_position)
		and not enemy.world.exp16.safe(actor.global_position))

func ready(id: String) -> bool:
	return float(cooldowns.get(id, INF)) <= 0.0

func begin(id: String, actor: Node3D) -> void:
	finish()
	attack = id
	victim = actor
	origin = flat(enemy.global_position)
	point = flat(actor.global_position)
	var offset := point - origin
	heading = offset.normalized() if offset.length_squared() > .01 else flat(-enemy.rig.global_basis.z).normalized()
	enemy.velocity = Vector3.ZERO
	enemy.melee_left = 0.0
	var timing: Array = ATTACKS[id]
	cooldowns[id] = float(timing[4]) * (.88 if enemy.enraged else 1.0)
	var lead: float = timing[0]
	match id:
		"quake": warn("area", origin, 8.4, 0, lead + 2.0 * float(timing[1]))
		"volley":
			var spread := heading.cross(Vector3.UP)
			var middle := origin + heading * clampf(offset.length(), 5.0, 11.0)
			spots = [middle, middle + spread * 4.8, middle - spread * 4.8, middle + heading * 3.8, middle - heading * 3.8]
			for i in range(spots.size()):
				spots[i] = local_point(origin + (spots[i] - origin).limit_length(15.0))
				warn("acid", spots[i], 1.75, 0, lead + 1.15)
		"slap":
			near_time = 0.0
			warn("line", origin, 4.8, 1.8, lead)
		"scratches": warn("line", origin, 5.5, 2.0, lead + float(timing[1]))
		"scream": warn("area", origin, 9.0, 0, lead)
		"gust": warn("line", origin, 15.0, 2.15, lead)
		"howl": warn("area", origin, 13.0, 0, lead)
		"block":
			point = local_point(point)
			warn("square", point, 2.75, 0, lead)
		"clay": warn("line", origin, CLAY_RANGE, CLAY_WIDTH, lead)
		"brood": warn("thorn", origin, 3.0, 0, lead)
		"slam": warn("area", origin, 6.8, 0, lead)
		"stakes":
			var side := heading.cross(Vector3.UP)
			spots = [local_point(point), local_point(point + side * 4.0 + heading), local_point(point - side * 4.0 - heading)]
			for spot in spots: warn("thorn", spot, 2.4, 0, lead)
		"vines":
			point = local_point(point)
			warn("snare", point, 4.1, 0, lead)

func local_point(candidate: Vector3) -> Vector3:
	var offset: Vector3 = enemy.world.sector_offset(enemy.world.coord_at(origin))
	var local := candidate - offset
	return offset + Vector3(clampf(local.x, -51.0, 51.0), 0.0, clampf(local.z, -51.0, 51.0))

func warn(kind: String, at: Vector3, size: float, width: float, duration: float) -> void:
	var direction := Vector3.FORWARD if kind == "square" else heading
	warnings.append(BossFx18.spawn(enemy.world, kind, at, direction, size, width, duration))

func fx(kind: String, at: Vector3, size: float, width: float, duration: float) -> void:
	BossFx18.spawn(enemy.world, kind, at, heading, size, width, duration)

func impact() -> void:
	var world: Node3D = enemy.world
	match attack:
		"quake":
			world.boss_sound(BossSoundBank.Cue.QUAKE, origin)
			fx("quakes", origin, 8.4, 0, .58)
			for body in world.get_tree().get_nodes_in_group("damageable"):
				if body.is_in_group("enemies") or body.health.dead or world.coord_at(body.global_position) != world.coord_at(origin) or not within(body.global_position, origin, 8.4): continue
				if world.avatars.values().has(body): hit(body, 13)
				else: body.take_damage(scaled(3 if body == world.core else 7))
		"volley":
			world.boss_sound(BossSoundBank.Cue.ACID_VOLLEY, origin)
			for spot in spots:
				var projectile: Node3D = world.projectile("acid", enemy.global_position + Vector3.UP*1.7, spot, scaled(12), 1.75, 1.15, false)
				if projectile != null: projectile.set_meta("toxic15", true)
		"slap":
			world.boss_sound(BossSoundBank.Cue.SLAP, origin)
			fx("claw", origin, 4.8, 0, .32)
			for actor in world.avatars.values():
				if lane(actor.global_position, 4.8, 1.8): hit(actor, 7 if enemy.spec.id == "mortar" else 10, heading, 3.4 if enemy.spec.id == "mortar" else 1.1)
		"scratches":
			world.boss_sound(BossSoundBank.Cue.CLAW, origin)
			fx("claw", origin, 5.5, 0, .30)
			for actor in world.avatars.values():
				if lane(actor.global_position, 5.5, 2.0): hit(actor, 13)
		"scream":
			world.boss_sound(BossSoundBank.Cue.SCREAM, origin)
			fx("howl_wave", origin, 9.0, 0, .58)
			for actor in world.avatars.values():
				if within(actor.global_position, origin, 9.0): hit(actor, 5, outward(actor), 3.7)
		"gust":
			world.boss_sound(BossSoundBank.Cue.GUST, origin)
			fx("wind", origin, 15.0, 2.15, .72)
			for actor in world.avatars.values():
				if lane(actor.global_position, 15.0, 2.15): hit(actor, 11, heading, 4.5)
		"howl":
			world.boss_sound(BossSoundBank.Cue.HOWL, origin)
			fx("howl", origin, 13.0, 0, 1.0)
			var chased: Node3D
			for actor in world.avatars.values():
				if not eligible(actor) or not within(actor.global_position, origin, 13.0): continue
				if chased == null or actor == victim: chased = actor
			if chased != null:
				for ally in world.get_tree().get_nodes_in_group("enemies"):
					if ally.is_boss or ally.health.dead or world.coord_at(ally.global_position) != world.coord_at(origin): continue
					ally.force_hunt(chased, 7.0, true)
		"block":
			world.boss_sound(BossSoundBank.Cue.MOLD, point)
			fx("mold", point, 2.75, 0, .72)
			for actor in world.avatars.values():
				var offset := flat(actor.global_position - point)
				if absf(offset.x) <= 2.75 and absf(offset.z) <= 2.75:
					var direction := Vector3(signf(offset.x),0,0) if absf(offset.x) > absf(offset.z) else Vector3(0,0,signf(offset.z))
					if direction == Vector3.ZERO: direction = Vector3(signf(heading.x),0,0) if absf(heading.x) > absf(heading.z) else Vector3(0,0,signf(heading.z))
					hit(actor, 19, direction, 3.6)
		"clay":
			world.boss_sound(BossSoundBank.Cue.CLAY, origin)
			fx("clay", origin, CLAY_RANGE, CLAY_WIDTH, CLAY_FLIGHT)
		"brood":
			world.boss_sound(BossSoundBank.Cue.BROOD, origin)
			fx("brood", origin, 3.0, 0, .70)
			var chased := victim if eligible(victim) else closest_player()
			if chased == null: return
			for i in range(8):
				var angle := TAU * float(i) / 8.0
				var hatch := Vector3(cos(angle),0,sin(angle)) * 2.5
				var minion: Node3D = world.spawn_minion(enemy, 17, i, hatch)
				if minion == null: break
				minion.temporary_left18 = 6.0
				minion.force_hunt(chased, 6.0, false)
		"slam":
			world.boss_sound(BossSoundBank.Cue.SLAM, origin)
			fx("quakes", origin, 6.8, 0, .69)
			for actor in world.avatars.values():
				if within(actor.global_position, origin, 6.8): hit(actor, 27, outward(actor), 1.6)
			enemy.exposed = 3.0
		"stakes":
			world.boss_sound(BossSoundBank.Cue.STAKES, spots[0])
			for spot in spots: fx("stakes", spot, 2.4, 0, 1.2)
			for actor in world.avatars.values():
				for spot in spots:
					if not within(actor.global_position, spot, 2.4): continue
					if hit(actor, 15): actor.slow_left = maxf(actor.slow_left, 2.0)
					break
		"vines":
			world.boss_sound(BossSoundBank.Cue.VINES, point)
			for actor in world.avatars.values():
				if within(actor.global_position, point, 4.1) and hit(actor, 4):
					actor.entangle18(BIND_DURATION)
					fx("vines", flat(actor.global_position), 1.0, 0, BIND_DURATION)

func update_clay(launch: float) -> void:
	var front := CLAY_RANGE * clampf((elapsed - launch) / CLAY_FLIGHT, 0.0, 1.0)
	var back := front - 2.0
	for actor in enemy.world.avatars.values():
		var offset := flat(actor.global_position - origin)
		var depth := offset.dot(heading)
		var id: int = actor.get_instance_id()
		if depth > front or depth < maxf(0, back) or not lane(actor.global_position, CLAY_RANGE, CLAY_WIDTH) or clay_hits.has(id): continue
		if hit(actor, 12):
			clay_hits[id] = true
			actor.entangle18(BIND_DURATION)
			enemy.world.boss_sound(BossSoundBank.Cue.BIND, actor.global_position)
			fx("clay_cage", flat(actor.global_position), .75, 0, BIND_DURATION)

func hit(actor: Node3D, damage: float, direction := Vector3.ZERO, push := 0.0) -> bool:
	if not eligible(actor) or actor.roll_left > 0.0 or actor.invulnerable > 0.0: return false
	actor.take_damage(scaled(damage))
	if not actor.health.dead and push > 0.0 and actor.rooted_left18 <= 0.0:
		actor.move_and_collide(direction * push)
	return not actor.health.dead

func scaled(damage: float) -> float:
	return damage * enemy.world.v15.day.damage_factor()

func outward(actor: Node3D) -> Vector3:
	var direction := flat(actor.global_position - origin)
	return direction.normalized() if direction.length_squared() > .01 else heading

func lane(position: Vector3, length: float, half_width: float) -> bool:
	var offset := flat(position - origin)
	var depth := offset.dot(heading)
	return depth >= 0.0 and depth <= length and absf(offset.dot(heading.cross(Vector3.UP))) <= half_width

static func flat(value: Vector3) -> Vector3:
	return Vector3(value.x, 0, value.z)

static func within(position: Vector3, center: Vector3, radius: float) -> bool:
	return flat(position - center).length_squared() <= radius * radius

func finish() -> void:
	for warning in warnings:
		if is_instance_valid(warning) and (attack != "volley" or hits == 0): warning.queue_free()
	warnings.clear()
	attack = ""
	elapsed = 0.0
	hits = 0
	spots.clear()
	clay_hits.clear()

func pose() -> bool:
	if not attack.is_empty():
		var timing: Array = ATTACKS[attack]
		var strike: float = timing[0]
		var span := strike
		if int(timing[2]) > 1 and elapsed > strike + .22:
			var index := mini(int(timing[2]) - 1, 1 + int((elapsed - strike - .22) / float(timing[1])))
			strike += index * float(timing[1])
			span = float(timing[1]) - .22
		var lift := smoothstep(strike - span, strike - span*.25, elapsed)
		var swing := smoothstep(strike - span*.25, strike, elapsed)
		var recovery := 1.0 - smoothstep(strike, strike + float(timing[3]), elapsed)
		var wind := lift * (1.0 - swing)
		var hit_pose := swing * recovery
		match attack:
			"quake", "slam":
				human(.26 + 1.38*wind + .56*hit_pose, .32 + 1.35*wind + .56*hit_pose, .21*wind - .43*hit_pose, .025*sin(elapsed*8)*wind, .25*wind - .17*hit_pose, .16*wind)
			"volley":
				var sway := sin(elapsed*11.0)*wind
				human(.28 + 1.1*wind + .56*hit_pose + .23*sway, .28 + 1.1*wind + .56*hit_pose - .23*sway, .20*wind - .22*hit_pose, sway*.16, .12*wind, .24*wind)
			"slap", "scratches":
				var side := -1.0 if attack == "scratches" and strike > float(timing[0]) else 1.0
				var sweep := .32*wind - .42*hit_pose
				var arm := 1.18*wind + .90*hit_pose
				human(.23 + arm*(1.0 if side < 0 else .18), .23 + arm*(1.0 if side > 0 else .18), -.16*hit_pose, side*sweep, -.08*wind, .36*wind)
			"scream":
				human(.22 + .73*wind + .3*hit_pose, .22 + .84*wind + .3*hit_pose, .36*wind - .32*hit_pose, sin(elapsed*29)*.075*hit_pose, .19*wind, .44*(wind + hit_pose))
			"gust":
				flyer(wind*.90 - hit_pose*.47 + sin(elapsed*23)*hit_pose*.33, .25*wind - .32*hit_pose, .28*wind)
			"howl":
				dog(-.20*wind, -.13*hit_pose, .31*wind + .37*hit_pose, -.11*wind, sin(elapsed*26)*.035*hit_pose)
			"block", "clay":
				human(.23 + .41*wind + .24*hit_pose, .23 + 1.52*wind + .71*hit_pose, .18*wind - .26*hit_pose, .15*wind - .10*hit_pose, .16*wind, .15*wind)
			"brood":
				var shake := sin(elapsed*25)*(.13*wind + .23*hit_pose)
				human(.25 + .55*wind + .30*hit_pose, .31 + .49*wind + .25*hit_pose, .08*wind - .29*hit_pose, shake, absf(shake)*.55, .23*wind)
			"stakes", "vines":
				var reach := .88*wind + 1.04*hit_pose
				human(.26+reach, .29+reach*(.74 if attack == "stakes" else 1.1), -.14*wind - .24*hit_pose, sin(elapsed*8)*.028*hit_pose, -.12*wind, .27*wind)
		return true
	if enemy.leap_left > 0.0:
		var progress := clampf(1.0 - enemy.leap_left/.85, 0, 1)
		var crest := sin(progress*PI)
		if enemy.spec.id == "hound":
			dog(.62*crest, -.72*crest, -.32*cos(progress*PI), -.29*smoothstep(.77,1.0,progress), 0.0)
		elif enemy.spec.id == "flyer":
			flyer(.46 + sin(progress*TAU*2.6)*.42, -.28*cos(progress*PI), 0.0)
		return true
	if enemy.landing18 > 0.0:
		var compress := sin(clampf(enemy.landing18/.36, 0.0, 1.0)*PI)
		dog(-.32*compress, .37*compress, -.11*compress, -.21*compress, 0.0)
		return true
	if enemy.windup <= 0.0: return false
	var anticipation := smoothstep(0.0, 1.0, 1.0 - enemy.windup/1.1)
	match enemy.spec.id:
		"hound":
			dog(-.5*anticipation, .48*anticipation, -.19*anticipation, -.28*anticipation, 0.0)
		"flyer":
			flyer(sin(anticipation*TAU*2.4)*(.47 + anticipation*.24), .19*anticipation, .15*anticipation)
		"mortar":
			human(.32 + .88*anticipation, .23 + .46*anticipation, .22*anticipation, -.14*anticipation, .10*anticipation, .12*anticipation)
		"broodmother":
			human(.24 + .82*anticipation, .27 + .68*anticipation, -.12*anticipation, sin(anticipation*TAU)*.12, -.12*anticipation, .38*anticipation)
		"mauler":
			human(.16 + .72*anticipation, .18 + .50*anticipation, -.25*anticipation, .12*anticipation, -.07*anticipation, .12*anticipation)
	return true

func human(left: float, right: float, pitch: float, tilt: float, height: float, spread: float) -> void:
	enemy.rig.rotation.x = pitch
	enemy.rig.rotation.z = tilt
	enemy.rig.position.y = height
	if enemy.rig.has_node("ArmL"):
		enemy.pose_arms(left, right)
		enemy.rig.get_node("ArmL").rotation.z -= spread
		enemy.rig.get_node("ArmR").rotation.z += spread
	for leg in ["LegL","LegR"]:
		var joint: Node3D = enemy.rig.get_node_or_null(leg)
		if joint != null: joint.rotation.x = move_toward(joint.rotation.x, 0, .09)
	if enemy.rig.has_method("sync_pose"): enemy.rig.sync_pose()

func flyer(flap: float, pitch: float, height: float) -> void:
	enemy.rig.rotation.x = pitch
	enemy.rig.position.y = height
	for i in range(enemy.wings.size()):
		enemy.wings[i].rotation = Vector3(flap*.33,0,flap*(1 if i==0 else -1))

func dog(front: float, rear: float, pitch: float, height: float, tilt: float) -> void:
	enemy.rig.rotation.x = pitch
	enemy.rig.rotation.z = tilt
	enemy.rig.position.y = height
	for i in range(enemy.wings.size()):
		enemy.wings[i].rotation.x = (front if i<2 else rear) + .06 * tilt * (1 if i%2==0 else -1)
