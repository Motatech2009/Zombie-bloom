class_name Catalog
extends RefCounted

const WEAPONS = [preload("res://resources/weapons/pistol.tres"), preload("res://resources/weapons/shotgun.tres"), preload("res://resources/weapons/rifle.tres")]
const ENEMIES = [preload("res://resources/enemies/walker.tres"), preload("res://resources/enemies/runner.tres"), preload("res://resources/enemies/brute.tres")]
const BUILDINGS = [preload("res://resources/buildings/barricade.tres"), preload("res://resources/buildings/turret.tres"), preload("res://resources/buildings/core.tres")]
const WAVES = [12, 18, 25, 32, 40]
const UPGRADES = [
	{"id": "damage", "title": "PONTA OCA", "text": "+20% de dano em todas as armas", "tag": "PODER DE FOGO"},
	{"id": "rate", "title": "GATILHO LEVE", "text": "+15% de cadência de disparo", "tag": "PODER DE FOGO"},
	{"id": "capacity", "title": "PENTE ESTENDIDO", "text": "+25% de capacidade de munição", "tag": "EQUIPAMENTO"},
	{"id": "reload", "title": "MÃOS RÁPIDAS", "text": "Recarga 15% mais rápida", "tag": "EQUIPAMENTO"},
	{"id": "speed", "title": "PASSO LIGEIRO", "text": "+10% de velocidade de movimento", "tag": "SOBREVIVÊNCIA"},
	{"id": "health", "title": "SEGUNDO FÔLEGO", "text": "+25 de vida máxima e recupera 25", "tag": "SOBREVIVÊNCIA"}
]
const POWER_COLORS = {"speed": Color("65dce5"), "rapid": Color("ffa862"), "shield": Color("a4a1ff")}
const POWER_NAMES = {"speed": "VELOCIDADE", "rapid": "FRENESI", "shield": "ESCUDO"}
