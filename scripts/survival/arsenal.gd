class_name Arsenal
extends RefCounted
const WEAPONS = [preload("res://resources/weapons/pistol.tres"),preload("res://resources/weapons/shotgun.tres"),preload("res://resources/weapons/rifle.tres"),preload("res://resources/weapons/smg.tres"),preload("res://resources/weapons/launcher.tres"),preload("res://resources/weapons/revolver.tres"),preload("res://resources/weapons/sniper.tres"),preload("res://resources/weapons/lmg.tres"),preload("res://resources/weapons/tesla.tres")]
const PRICES = [0,110,220,175,320,160,380,420,520]
const DESCRIPTIONS = ["Versátil · munição leve","Curta distância · múltiplos projéteis","Automático · munição de rifle","Cadência alta · munição leve","Explosão em área · dano próprio","Alto impacto · seis disparos","Precisão · atravessa até três infectados","Supressão · pente de sessenta","Descarga encadeada · até quatro alvos"]
const PACKS = {"bat":[1,15],"light":[24,12],"shell":[8,18],"rifle_ammo":[30,25],"heavy":[12,22],"cells":[16,38],"rocket":[3,60],"grenade":[2,45],"medkit":[1,30],"wood":[8,35],"parts":[3,45]}
