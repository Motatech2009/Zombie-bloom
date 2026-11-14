extends "res://scripts/sectors/roaming_waves.gd"

func start() -> bool:
	if not super.start(): return false
	to_spawn = CampaignData.wave_count(wave)*world.team_multiplier()
	return true

func enemy_type(index: int) -> int:
	if index==0: return 8
	if wave>=6 and index%29==0: return 16
	if wave>=3 and index%31==0: return 15
	if wave>=12 and index%23==0: return 14
	if wave>=8 and index%19==0: return 13
	if wave>=4 and index%7==0: return 12
	if wave>=9 and index%17==0: return 11
	if wave>=7 and index%13==0: return 10
	if wave>=5 and index%11==0: return 9
	return super.enemy_type(index)

func complete() -> void:
	if not running: return
	world.record_victory(wave)
	var enabled: bool = world.checkpoint_enabled
	world.checkpoint_enabled = false
	super.complete()
	world.checkpoint_enabled = enabled
	world.built_this_round = 0
	for survivor in world.avatars.values():
		if survivor.health.dead: survivor.revive(40)
	if world.area_index==-1 and world.phase=="prep": world.save_checkpoint(false)

func rescale() -> void:
	if running: to_spawn = maxi(0,CampaignData.wave_count(wave)*world.team_multiplier()-spawned)
