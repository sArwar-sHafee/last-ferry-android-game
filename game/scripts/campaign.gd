extends RefCounted

# Each chapter lists its backdrop, ambience, ground palette, and arrival text.
# Scene rows use stable source addresses, a title, the entrance height, and section tokens.
# @ marks a checkpoint. Keep previously published keys on retained scenes where possible.
const VOYAGE := [
	["The Landing",preload("res://art/harbor.webp"),0,0,
		"Three short blasts from beyond the bar. A ferry, asking for a light.",[
		[0,"Three Short Blasts",376,"walk ledge @s1 steps"],
		[1,"The Ropewalk",376,"gap @0a skiff"],
		[2,"The Broken Jetty",356,"@1a short_wreck drop"],
	]],
	["The Tidal Quays",preload("res://art/reach00.webp"),0,0,
		"The tide has carried a strip of sailcloth into the winch.",[
		[5,"The Tarred Slip",356,"crate @s2 causeway"],
		[6,"Coal Dogs",346,"@4a hound"],
		[7,"The Pitch Kettle",338,"single_float @5a spikes"],
	]],
	["Mangrove Canopy",preload("res://art/reach02.webp"),2,1,
		"The branches meet above the flood. Something stirs in the leaves.",[
		[20,"Out of Soundings",330,"branches @s5 vine"],
		[21,"The Outer Piles",320,"@16a swarm"],
		[22,"Dogs at Anchor",316,"@17a spider"],
		[23,"The Old Fish Market",312,"@18a monkey"],
	]],
	["The Pumpworks",preload("res://art/pumpworks.webp"),8,2,
		"The pipes tremble. There is still pressure in the old main.",[
		[30,"Below the Gauge",308,"@w4 lockpair"],
		[31,"The Overflow Lip",296,"rocker @4a drain"],
		[34,"The Gauge Keeper",282,"steam @7a spillway"],
	]],
	["The Freightyard",preload("res://art/freightyard.webp"),5,3,
		"A hook still swings above the empty freight line.",[
		[54,"The Swept Rails",276,"@3a trolley"],
		[55,"The Upper Track",266,"@f2 cable_drum @f3 hoist"],
		[59,"The Crane Saddle",254,"balance @7a cargo_net"],
	]],
	["Boar Run",preload("res://art/reach07.webp"),7,4,
		"The boar paws the charcoal road. Beyond the gate, the culverts have washed out.",[
		[68,"Bracken Gate",258,"ride @14a"],
		[69,"The Root Road",253,"ride @15a spillway"],
		[71,"Split Hoof Ford",242,"ride @16a broken_jetty"],
	]],
	["The Engine Galleries",preload("res://art/reach08.webp"),8,5,
		"The keeper leaves the boar at the gate. Heat rolls out of the galleries.",[
		[88,"The Flywheel Pit",232,"@10a vents"],
		[91,"The Sump Bridge",215,"@12a steam_spikes low"],
		[92,"The Boiler Feed",200,"@13a rocker_skiff"],
	]],
	["The Limestone Cut",preload("res://art/reach15.webp"),15,5,
		"Chalk marks lead up the ridge. Fresh tracks cross them.",[
		[93,"A Hollow Knocking",192,"@14a elephant"],
		[94,"The Delivery Main",175,"@15a swarm_planks"],
		[96,"The Pumpman’s Locker",151,"@16a gantry drop"],
	]],
	["The Lens Works",preload("res://art/lensworks.webp"),10,6,
		"Through a crack in the shutters, a thread of light.",[
		[103,"A Line of Prisms",132,"tide @2a ray"],
		[105,"The Silvered Room",103,"@l2 shutters @l3 hoist"],
		[107,"The Prism Bath",76,"@5a wide_causeway gantry"],
	]],
	["The Tower Shaft",preload("res://art/reach12.webp"),12,7,
		"The last service stair rises behind the glassworks.",[
		[129,"The Keeper’s Launch",49,"@3a lockpair storm_island"],
		[131,"The Brass Ladder",10,"@4a key_ladder @ladder-exit aqueduct rocker_skiff"],
		[132,"The Blind Landing",-33,"@5a wide_causeway acid_gate summit"],
	]],
	["The Breakwater",preload("res://art/breakwater.webp"),4,7,
		"The tide breaks against the outer stones.",[
		[133,"The Cable Drum",-65,"gorilla_run chase_planks gap @6a cable_drum wide_causeway"],
		[134,"The Gull Roost",-85,"gorilla_continue @7a hound_spikes monkey_ladder"],
	]],
	["The Lantern Cage",preload("res://art/reach14.webp"),14,7,
		"Rain taps the metal steps like a second pair of boots.",[
		[135,"Storm Glass",-116,"@p9 cargo_net ray"],
		[136,"The Night Watch",-153,"@8a swarm_hound shutters monkey_crossfire"],
	]],
	["The Storm Beacon",preload("res://art/reach13.webp"),13,7,
		"Above the fog there is only the wind, and the turning sea.",[
		[137,"The Winding Floor",-192,"@9a steam_spikes acid_gate"],
		[138,"The Seaward Face",-205,"hound chase_planks gap"],
		[144,"The Mercury Bath",-222,"@15a rocker_skiff shutters"],
		[148,"The Lantern Door",-259,"@18a swarm_planks monkey_ladder"],
		[149,"Light the Fairway",-301,"@p10 gantry @l10 ray summit"],
	]],
]

static var CHAPTERS: Array = []
static var CHAPTER_STARTS: Array[int] = []
static var ROOMS: Array = []
static var SOURCE_ROOMS: Array[int] = []
const ROOMS_PER_DISTRICT := 25

static func _static_init() -> void:
	for entry in VOYAGE:
		var start := ROOMS.size()
		CHAPTERS.append([start,entry[0],entry[1],entry[2],entry[3],entry[4]])
		CHAPTER_STARTS.append(start)
		for scene in entry[5]:
			SOURCE_ROOMS.append(scene[0])
			ROOMS.append([scene[1],scene[3],scene[2]])
	CHAPTER_STARTS.append(ROOMS.size())

static func chapter_name(index: int) -> String:
	return CHAPTERS[index][1]

static func chapter_label(room: int) -> String:
	var index:=chapter(room)
	return "%02d   /   %s" % [index+1,chapter_name(index).to_upper()]

static func region(room: int) -> int:
	return CHAPTERS[chapter(room)][4]

static func district(room: int) -> int:
	return floori(float(SOURCE_ROOMS[room])/ROOMS_PER_DISTRICT)

static func deck_height(index: int) -> float:
	return -386.0 if index==ROOMS.size() else float(ROOMS[index][2])

static func migrated_room(source: int) -> int:
	return mini(SOURCE_ROOMS.bsearch(source),SOURCE_ROOMS.size()-1)

static func arrival_text(index: int) -> String:
	var entry: Array = CHAPTERS[chapter(index)]
	if index==entry[0]: return entry[5]
	if index==ROOMS.size()-1: return "The last handwheel is warm beneath your fingers."
	return ""

static func legacy_index(index: int) -> int:
	return migrated_room(149 if index==29 else index*5)

# Assign each campaign board to a stable scene address and checkpoint key.
const STATION_BOARDS := {
	0: {"s1":"chart1"},
	5: {"s2":"relay1"},
	31: {"4a":"weights1"},
	88: {"10a":"l1"},
	96: {"16a":"f2"},
	129: {"3a":"p2"},
	135: {"p9":"s2"},
	144: {"15a":"w2"},
	149: {"l10":"chart2"},
}

const FAMILIES := [
	["chart1","chart2"], ["relay1","relay2"], ["weights1","weights2"],
	["l1","l3","l6","l2","l4","l5","l7","l8","l9","l10","l11","l12"], ["f2","f4","f6","f1","f3","f5","f7","f8","f9","f10","f11","f12"], ["p2","p3","p5","p1","p4","p6","p7","p8","p9","p10","p11","p12"],
	["s2","s4","s5","s1","s3","s6","s7","s8","s9","s10","s11"], ["w2","w3","w5","w1","w4","w6","w7","w8","w9","w10","w11","w12","w13"]
]
const NEW_BOARDS := {
	"chart1":{"kind":"chart","w":4,"h":4,"shoals":[1,5],"port":0,"harbor":3,"solution":[4,8,12,13,9,10,14,15,11,7,6,2,3]},
	"chart2":{"kind":"chart","w":4,"h":4,"shoals":[2,6],"port":3,"harbor":0,"solution":[7,11,15,14,10,9,13,12,8,4,5,1,0]},
	"relay1":{"kind":"relay","w":3,"h":3,"switches":[0,4,7],"solution":[0,4,7]},
	"relay2":{"kind":"relay","w":4,"h":3,"switches":[1,3,4,10],"solution":[1,3,4,10]},
	"weights1":{"kind":"weights","w":3,"h":2,"weights":[2,4,5,7,9,11],"target":12,"hooks":2,"solution":[2,3]},
	"weights2":{"kind":"weights","w":3,"h":2,"weights":[3,5,8,11,14,17],"target":22,"hooks":3,"solution":[0,1,4]}
}

const BOARD_TITLES := {"chart":"Pilot’s chart","relay":"Storm relays","weights":"Bell counterpoise","slip":"Harbor slip", "sluice":"Sluice valves", "freight":"Freight carriage", "pump":"Pressure manifold", "lens":"Signal mirrors"}
const RULES := {
	"chart":"Plot a continuous course from the brass port to the flagged harbor. Visit every buoy once. The hatched shoals are impassable.",
	"relay":"Light the whole switchboard. Pressing a relay reverses its lamp and each neighbor directly beside, above or below it.",
	"weights":"Choose the stamped weights to balance the bell. Use exactly the number of hooks shown on the scale.",
	"slip":"Slide the brass skiff to the opening on the right. Hulls travel along their rails.",
	"sluice":"Match the brass gauge marks. Open two valves to pour until the source empties or the receiver fills.",
	"freight":"Use the carriage to push every crate onto a ring. You can push one crate at a time.",
	"pump":"Turn the fittings until pressure reaches every pipe. Every open end needs a matching joint.",
	"lens":"Turn the mirrors. Thread the beam through every ring and out through the receiver on the right."
}
const GESTURES := {
	"chart":"Tap the next adjacent buoy. Undo lets you retrace a turn.",
	"relay":"Tap a lamp to switch its cross of neighbors.",
	"weights":"Tap weights to hang or remove them.",
	"slip":"Select a hull, then tap a lit stop.",
	"sluice":"Tap a source, then a receiver.",
	"freight":"Tap a floor tile to walk, or tap a crate to push.",
	"pump":"Tap a fitting to turn it clockwise.",
	"lens":"Tap a mirror to change its angle."
}
const HINTS := {
	"chart":"A buoy with only one way out can strand you. Work around the outside first and leave the flag for last.",
	"relay":"Switching a lamp twice cancels the move. Work down the board, watching which lamps change in the row above.",
	"weights":"Read the stamped mass on each weight. Compare their sum and the number of occupied hooks with the two targets.",
	"slip":"Work back from the brass hull. Which crosswise hull is blocking its channel? Clear space beyond that hull first.",
	"sluice":"An almost-full receiver measures a small transfer. Use its spare capacity to leave a precise amount behind.",
	"freight":"A box pushed into an unmarked corner stays there. Leave a walking lane behind the next box. Undo backs up one move.",
	"pump":"Start at corners and dead ends. Outward-facing ports can never seal. Follow the lit pipes from the brass inlet.",
	"lens":"Trace the beam from the left. Turn the first mirror that sends it away from a ring, then check the path from the receiver backwards."
}
static func chapter(room: int) -> int:
	return clampi(CHAPTER_STARTS.bsearch(room, false)-1,0,CHAPTERS.size()-1)
