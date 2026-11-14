class_name RankProgress
extends RefCounted
const THRESHOLDS := [100,500,1000,1500,2000,3000,4000,6000,8000,10000]
const TITLES := ["Sem classificação","Recruta","Vigia","Sentinela","Guardião","Veterano","Bastião","Carrasco","Colosso","Lenda","Imortal"]
static func tier(kills: int) -> int:
	var result := 0
	for threshold in THRESHOLDS:
		if kills>=threshold: result += 1
	return result
static func next_goal(kills: int) -> int:
	return THRESHOLDS[tier(kills)] if tier(kills)<10 else 10000
static func summary(kills: int) -> String:
	var level := tier(kills)
	return "%s · %d abates%s" % [TITLES[level],kills," · faltam %d para o próximo elo" % (next_goal(kills)-kills) if level<10 else " · elo máximo"]
