class_name FortressData
extends RefCounted

const BUILD_LIMITS := {
	"turret": 12,
	"cannon": 5,
	"raised_turret": 5,
	"shock": 5,
	"wire": 30,
	"spikes": 30,
}

const EXTRA = [
 {"id":"wire","title":"Arame farpado","size":Vector3(3,.95,1.3),"health":170.0,"cost":{"scrap":25,"wood":2,"parts":1},"color":Color("879ca3")},
 {"id":"bastion","title":"Muralha pesada","size":Vector3(3.5,3,1.5),"health":900.0,"cost":{"scrap":130,"wood":10,"parts":12},"color":Color("87918d")},
 {"id":"cannon","title":"Canhão automático","size":Vector3(2.4,2.2,2.4),"health":280.0,"cost":{"scrap":280,"wood":4,"parts":22},"color":Color("a99065")},
 {"id":"shock","title":"Torre elétrica","size":Vector3(2,2.7,2),"health":230.0,"cost":{"scrap":260,"wood":2,"parts":26},"color":Color("79bbc5")},
 {"id":"recycler","title":"Reciclador","size":Vector3(2,1.8,2),"health":280.0,"cost":{"scrap":150,"wood":8,"parts":8},"color":Color("90a47b")},
 {"id":"raised_turret","title":"Torreta elevada","size":Vector3(2.2,3.8,2.2),"health":150.0,"cost":{"scrap":150,"wood":6,"parts":8},"color":Color("8aab95")}
]
const DESCRIPTIONS = ["Barreira de baixo custo. Madeira → aço → concreto.","Dispara contra solo e ar. Cada nível reforça a carcaça.","Parede com pilares e contrafortes; muda de material.","Portão elevatório. F abre quando estiver desocupado.","Dano de contato. Estacas ganham pontas metálicas.","Cura aliados e repara estruturas entre cercos.","Permite passagem; corta e reduz a velocidade de infectados terrestres.","Alta integridade e grande espessura. Preserve a rota do Núcleo.","Projétil explosivo contra grupos; alcance e dano crescem com o nível.","Descarga em até três alvos; interrompe por instantes. Ataca voadores.","Converte 20 madeira ou uma arma selecionada em componentes. Use o painel da base.","Plataforma elevada: dispara por cima de barricadas baixas quando há linha de tiro. Casas e muralhas bloqueiam."]
const MATERIALS = ["Madeira / sucata","Aço reforçado","Concreto / blindagem"]
static func pieces() -> Array:
	return CampaignData.PIECES+EXTRA
static func passable(id: String) -> bool:
	return id in ["wire","spikes"]
static func turret(id: String) -> bool:
	return id in ["turret","cannon","shock","raised_turret"]

static func reach(id: String,tier: int = 1) -> float:
	return 6.0 if id=="station" else (22.0 if id=="cannon" else 11.0 if id=="shock" else 17.0 if id=="raised_turret" else 15.0)+tier-1
static func muzzle_height(id: String) -> float: return 3.6 if id=="raised_turret" else 1.45
