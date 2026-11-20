class_name BossSoundBank
extends Resource

enum Cue {
	CHARGE, CHARGE_HIT, QUAKE,
	ACID_LAUNCH, ACID_VOLLEY, ACID_SPLASH, SLAP,
	CLAW, SCREAM, SUMMON,
	DIVE, SPORES, GUST,
	LEAP, LAND, HOWL,
	MOLD, CLAY, BIND,
	BROOD, FLOCK,
	SLAM, STAKES, VINES, MELEE_MISS, BURSTER,
}

const RANGE := 36.0
const LEVEL_DB := [
	-11.0, -14.0, -11.0,
	-14.0, -12.0, -18.0, -15.0,
	-14.0, -14.0, -14.0,
	-13.0, -18.0, -12.0,
	-14.0, -12.0, -13.0,
	-12.0, -14.0, -17.0,
	-13.0, -16.0,
	-10.0, -12.0, -14.0, -21.0, -13.0,
]

@export var clips: Array[AudioStreamWAV]

static func valid_cue(cue: int) -> bool:
	return cue >= 0 and cue < LEVEL_DB.size()

static func in_range(source: Vector3, listener: Vector3) -> bool:
	var offset := source - listener
	return Vector2(offset.x,offset.z).length_squared() < RANGE * RANGE
