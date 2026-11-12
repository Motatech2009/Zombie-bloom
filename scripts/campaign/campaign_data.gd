class_name CampaignData
extends RefCounted

const WAVES = [12, 18, 25, 32, 40, 46, 54, 64]
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
	if kind < 3:
		return Catalog.ENEMIES[kind]
	var data := GameSpec.new()
	data.id = "armored" if kind == 3 else "demolisher"
	data.title = "Blindado" if kind == 3 else "Demolidor"
	data.color = Color("737f8b") if kind == 3 else Color("a26651")
	data.values = {"health":140.0 if kind == 3 else 380.0,"speed":1.6 if kind == 3 else 1.25,"damage":17.0 if kind == 3 else 32.0,"interval":1.1 if kind == 3 else 1.6,"scale":1.05 if kind == 3 else 1.5,"xp":14 if kind == 3 else 28,"scrap":9 if kind == 3 else 18}
	return data
