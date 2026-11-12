class_name CampaignData
extends RefCounted

const WAVES = [18,24,32,40,48,56,65,74,84,94,105,116,128,140,154,168,184,200,218,240]
const WEAPONS = [preload("res://resources/weapons/pistol.tres"),preload("res://resources/weapons/shotgun.tres"),preload("res://resources/weapons/rifle.tres"),preload("res://resources/weapons/smg.tres"),preload("res://resources/weapons/launcher.tres")]
const PRICES = [0,110,220,175,320]

static func wave_count(number: int) -> int:
	if number<=WAVES.size(): return WAVES[maxi(0,number-1)]
	return 240+(number-20)*16

static func health_scale(number: int) -> float:
	var step := maxi(0,number-1)
	return 1.0+.12*step+.003*step*step

const AREAS = [
	{"id":"yard", "title":"PÁTIO DE CARGAS", "wave":0, "count":10, "color":Color("53665b"), "reward":{"scrap":65,"wood":24,"parts":6}, "description":"Caixotes e veículos. Madeira para a primeira linha de defesa."},
	{"id":"suburb", "title":"QUARTEIRÃO RESIDENCIAL", "wave":1, "count":16, "color":Color("55636c"), "reward":{"scrap":95,"wood":30,"parts":10}, "description":"Ruas fechadas, corredores e casas. Reforce seus muros."},
	{"id":"factory", "title":"FÁBRICA ABANDONADA", "wave":3, "count":22, "color":Color("6b6153"), "reward":{"scrap":145,"wood":18,"parts":22}, "description":"Máquinas e blindados. Componentes para torretas melhores."},
	{"id":"depot", "title":"DEPÓSITO MILITAR", "wave":5, "count":30, "color":Color("535f50"), "reward":{"scrap":210,"wood":20,"parts":30}, "description":"Demolidores protegem a última reserva de componentes."}
]
# Barricade, turret, wall, gate, spikes and support station; each cost is paid atomically.
const PIECES = [
	{"id":"barricade","title":"Barricada","size":Vector3(3,1.8,1),"health":220.0,"cost":{"scrap":20,"wood":4,"parts":0},"color":Color("a17149")},
	{"id":"turret","title":"Torreta","size":Vector3(1.6,1.9,1.6),"health":180.0,"cost":{"scrap":75,"wood":0,"parts":4},"color":Color("6e9f9b")},
	{"id":"wall","title":"Muro reforçado","size":Vector3(3,2.4,1),"health":440.0,"cost":{"scrap":35,"wood":6,"parts":2},"color":Color("7b8c8c")},
	{"id":"gate","title":"Portão","size":Vector3(3,2.1,1),"health":320.0,"cost":{"scrap":35,"wood":6,"parts":2},"color":Color("968e69")},
	{"id":"spikes","title":"Estacas","size":Vector3(2,0.65,2),"health":150.0,"cost":{"scrap":15,"wood":5,"parts":0},"color":Color("aa8e60")},
	{"id":"station","title":"Posto de apoio","size":Vector3(2,1.4,2),"health":260.0,"cost":{"scrap":60,"wood":4,"parts":5},"color":Color("709a79")}
]

static func cost_text(cost: Dictionary) -> String:
	return "%d sucata · %d madeira · %d componentes" % [cost.get("scrap",0),cost.get("wood",0),cost.get("parts",0)]

static func enemy_spec(kind: int) -> Resource:
	if kind<3: return Catalog.ENEMIES[kind]
	var data := GameSpec.new()
	var entries := [
		["armored","Blindado",Color("737f8b"),140.0,1.6,17.0,1.1,1.05,14,9],
		["demolisher","Demolidor",Color("a26651"),380.0,1.25,32.0,1.6,1.5,28,18],
		["spitter","Corrosivo",Color("86b04f"),90.0,1.8,10.0,1.5,1.0,14,9],
		["hound","Cão infectado",Color("8c6a50"),55.0,4.8,14.0,.65,.7,9,6],
		["flyer","Asa infectada",Color("946f9c"),75.0,3.3,13.0,.9,.8,12,8],
		["alpha","Colosso Alfa",Color("a84e43"),850.0,1.65,42.0,1.4,1.8,60,35]
	]
	var e: Array = entries[clampi(kind-3,0,entries.size()-1)]
	data.id = e[0]
	data.title = e[1]
	data.color = e[2]
	data.values = {"health":e[3],"speed":e[4],"damage":e[5],"interval":e[6],"scale":e[7],"xp":e[8],"scrap":e[9]}
	return data
