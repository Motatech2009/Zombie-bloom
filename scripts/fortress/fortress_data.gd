class_name FortressData
extends RefCounted
const EXTRA = [
 {"id":"wire","title":"Arame farpado","size":Vector3(3,.95,1.3),"health":170.0,"cost":{"scrap":25,"wood":2,"parts":1},"color":Color("879ca3")},
 {"id":"bastion","title":"Muralha pesada","size":Vector3(3.5,3,1.5),"health":900.0,"cost":{"scrap":90,"wood":8,"parts":8},"color":Color("87918d")},
 {"id":"cannon","title":"Canhão automático","size":Vector3(2.4,2.2,2.4),"health":280.0,"cost":{"scrap":180,"wood":4,"parts":15},"color":Color("a99065")},
 {"id":"shock","title":"Torre elétrica","size":Vector3(2,2.7,2),"health":230.0,"cost":{"scrap":150,"wood":2,"parts":18},"color":Color("79bbc5")}
]
const DESCRIPTIONS = ["Barreira de baixo custo. Madeira → aço → concreto.","Dispara contra solo e ar. Cada nível reforça a carcaça.","Parede com pilares e contrafortes; muda de material.","Portão elevatório. F abre quando estiver desocupado.","Dano de contato. Estacas ganham pontas metálicas.","Cura aliados e repara estruturas entre cercos.","Permite passagem; corta e reduz a velocidade de infectados terrestres.","Alta integridade e grande espessura. Preserve a rota do Núcleo.","Projétil explosivo contra grupos; alcance e dano crescem com o nível.","Descarga em até três alvos; interrompe por instantes. Ataca voadores."]
const MATERIALS = ["Madeira / sucata","Aço reforçado","Concreto / blindagem"]
static func pieces() -> Array:
	return CampaignData.PIECES+EXTRA
static func passable(id: String) -> bool:
	return id in ["wire","spikes"]
static func turret(id: String) -> bool:
	return id in ["turret","cannon","shock"]
