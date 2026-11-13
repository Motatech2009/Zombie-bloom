class_name InfectedRoster
extends RefCounted
const EXTRA = [
 ["burster","Estourador","c16d4a",85.0,2.6,14.0,1.1],
 ["screamer","Berrador","a67baf",120.0,1.8,14.0,1.1],
 ["mender","Regenerador","5eb38e",120.0,1.8,14.0,1.1],
 ["charger","Investidor","b67962",185.0,2.1,21.0,1.2],
 ["cryo","Criogênico","72b6c9",145.0,1.7,12.0,1.2],
 ["saboteur","Sabotador","68829b",165.0,2.0,16.0,1.1]
]
static func extra_spec(kind: int) -> Resource:
	var entry: Array = EXTRA[clampi(kind-9,0,EXTRA.size()-1)]
	var data := GameSpec.new()
	data.id = entry[0]; data.title = entry[1]; data.color = Color(entry[2])
	data.values = {"health":entry[3],"speed":entry[4],"damage":entry[5],"interval":entry[6],"scale":1.1 if kind==12 else 1.0,"xp":15,"scrap":9}
	return data
