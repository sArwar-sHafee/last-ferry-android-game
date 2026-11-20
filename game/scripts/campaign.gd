extends RefCounted

# First scene, title, backdrop, and ambience for each chapter.
const CHAPTERS := [
	[0,"The Landing",preload("res://art/harbor.webp"),0],
	[4,"The Tidal Quays",preload("res://art/reach00.webp"),0],
	[8,"The Customs Reach",preload("res://art/reach01.webp"),1],
	[13,"Mangrove Canopy",preload("res://art/reach02.webp"),2],
	[18,"The Sluice House",preload("res://art/reach03.webp"),3],
	[23,"The Pumpworks",preload("res://art/pumpworks.webp"),8],
	[28,"The Sea Wall",preload("res://art/reach04.webp"),4],
	[33,"The Freight Approach",preload("res://art/reach05.webp"),5],
	[37,"The Freightyard",preload("res://art/freightyard.webp"),5],
	[42,"The Upper Sidings",preload("res://art/reach06.webp"),6],
	[47,"Boar Run",preload("res://art/reach07.webp"),7],
	[52,"Charcoal Ridge",preload("res://art/reach09.webp"),9],
	[57,"The Engine Galleries",preload("res://art/reach08.webp"),8],
	[62,"The Limestone Cut",preload("res://art/reach15.webp"),15],
	[67,"The Prism House",preload("res://art/reach10.webp"),10],
	[72,"The Lens Works",preload("res://art/lensworks.webp"),10],
	[77,"The Shutter House",preload("res://art/reach11.webp"),11],
	[82,"The Tower Shaft",preload("res://art/reach12.webp"),12],
	[85,"The Breakwater",preload("res://art/breakwater.webp"),4],
	[87,"The Lantern Cage",preload("res://art/reach14.webp"),14],
	[89,"The Storm Beacon",preload("res://art/reach13.webp"),13],
]
const REGION_STARTS := [0,12,23,35,47,59,70,82,94]
const ENVIRONMENTS := [0,2,3,6,7,9,10,13]
# Source addresses also migrate logbooks from the original 150-location route.
const SOURCE_ROOMS := [
	0,1,2,4,5,6,7,8,9,10,12,17,
	19,20,21,22,23,24,25,26,27,28,29,
	30,31,32,33,34,35,37,39,40,42,44,47,
	51,53,54,55,57,59,60,61,62,64,66,67,
	68,69,70,71,72,73,74,75,76,77,78,79,
	88,91,92,93,94,95,96,97,98,99,100,
	101,102,103,104,105,106,107,108,109,110,114,118,
	129,131,132,133,134,135,136,137,144,147,148,149]
const EPIGRAPHS := [
	"Three short blasts from beyond the bar. A ferry, asking for a light.",
	"The customs lamps have gone out. The old clock is still ticking.",
	"The branches meet above the flood. Something stirs in the leaves.",
	"The tide has entered the station by all the old ways.",
	"A line of salt traces the flood across the masonry.",
	"A hook still swings above the empty freight line.",
	"The passing track climbs above a yard of motionless wagons.",
	"The boar paws the charcoal road. Beyond the gate, the culverts have washed out.",
	"The pipes tremble. There is still pressure in the old main.",
	"Chalk marks lead up the ridge, past the old engine galleries.",
	"Through a crack in the shutters, a thread of light.",
	"The sea appears between the shutters, one blade at a time.",
	"The last service stair rises behind the glassworks.",
	"Rain taps the metal steps like a second pair of boots.",
	"Above the fog there is only the wind, and the turning sea."
]
# Story beats appear at the original landmarks as the keeper approaches the beacon.
const DISPATCHES := [
	"", "The tide has carried a strip of sailcloth into the winch.", "A pencil mark on the gauge reads: ferry draft.", "The boom still bears the dent of her last departure.", "Behind you, the landing lamps stay lit.",
	"", "Someone has chalked the high-water line above the door.", "From somewhere underneath the floor comes the knock of loose timber.", "The wheel turns. Old salt falls from the spokes.", "The water is running out to sea again.",
	"", "The crane hook passes overhead with nothing on it.", "A wet manifest clings to the rail: lamp oil, glass, one bell.", "The rails sing before the carriage comes into view.", "The platform lifts. Through the gap you can see the waiting ship.",
	"", "Cold water pulses in the return pipe.", "A single bubble breaks the slick in the priming well.", "The two pumps fall into step. Their beat carries through the wall.", "For the first time, the air smells of rain instead of oil.",
	"", "The back of the mirror bears a keeper’s thumbprint.", "A blade of daylight finds the far wall.", "The shutters open on a sea the color of lead.", "Far out, a low cabin lamp answers your light.",
	"", "A length of new rope has been spliced into the old drum.", "Rain runs down both sides of the glass.", "The lantern cage turns a little in the wind.", "The last handwheel is warm beneath your fingers."
]
# One continuous, hand-sequenced route per room. @ marks a physical operating station.
const LANDMARKS := [
	["Three Short Blasts", "walk ledge gap @s1 skiff loose walk"],
	["The Tarred Slip", "steps crate @s2 hound span gap"],
	["Float Marks", "gap @s3 steam float steps @w1 float"],
	["The Customs Boom", "loose crate drop @s4 skiff low @s9 balance"],
	["Out of Soundings", "tide @s5 skiff gap @w2 causeway ledge"],
	["Two Chambers", "walk @w3 lockpair steam low"],
	["Below the Gauge", "loose gap @w4 drain steps @s6 skiff"],
	["The Overflow", "steps tide @w5 spillway gap @w12 drain vents"],
	["Flood Door", "crate @w6 drain low @p1 span"],
	["The Dry Culvert", "drop @w7 drain low @s7 skiff hound @w13 aqueduct"],
	["Deadweight", "walk crate @f1 balance ledge gap"],
	["The Upper Track", "steps loose @f2 hoist crate @f3 span"],
	["The Empty Hook", "drop hound crate @f4 balance tide @f11 hoist"],
	["Over the Sidings", "tide loose @f5 balance gap @w8 rocker"],
	["A Load for Two", "crate @f6 hoist drop @s8 skiff @s10 balance hound"],
	["Return Pressure", "steps @p2 steam drain low"],
	["Blackwater Main", "tide @p3 lockpair @w9 drain"],
	["The Priming Well", "gap crate @p4 drain vents steps @p11 gantry"],
	["Twin Impellers", "drop loose @p5 span @f7 hoist"],
	["Breathing Room", "tide @p6 drain low @w10 float steam @f12 balance"],
	["First Light", "walk ledge @l1 ray steps"],
	["The Silvered Room", "gap @l2 loose ray @l3 span"],
	["A Narrow Aperture", "steps crate @l4 ray tide @l11 shutters"],
	["Shutter House", "low @p7 span @l5 shutters"],
	["Across the Dark", "tide @l6 ray hound drop @f8 hoist @s11 balance"],
	["The Service Stair", "steps loose @w11 gantry crate @p8 drain"],
	["The Winding Drum", "gap @f9 balance steps @l7 shutters"],
	["Storm Glass", "tide @p9 span vents low @l8 ray @p12 rocker"],
	["The Lantern Cage", "crate @f10 hoist @l9 shutters steps @l12 ray"],
	["Light the Fairway", "steps @p10 float ledge @l10 ray summit"]
]
static var CHAPTER_STARTS: Array[int] = chapter_starts()

static func chapter_starts() -> Array[int]:
	var starts: Array[int] = []
	for entry in CHAPTERS: starts.append(entry[0])
	starts.append(SOURCE_ROOMS.size())
	return starts

static func region(room: int) -> int:
	return clampi(REGION_STARTS.bsearch(room,false)-1,0,ENVIRONMENTS.size()-1)

static func chapter_name(index: int) -> String:
	return CHAPTERS[index][1]

static func chapter_label(room: int) -> String:
	var index:=chapter(room)
	return "%02d   /   %s" % [index+1,chapter_name(index).to_upper()]

const ROOMS_PER_DISTRICT := 25

static func district(room: int) -> int:
	return floori(float(SOURCE_ROOMS[room])/ROOMS_PER_DISTRICT)

# Surveyed deck heights in world pixels. Neighbouring crossings share an endpoint.
# Water stays at 449. The tower climbs from the shoreline to the lantern gallery.
const DECK_HEIGHTS := [
	[376,350,282,335,402,384,302,237,285,358,402,371,304,228,243,295,357,399,349,283,260,315,365,402,387],
	[375,400,354,306,356,402,375,309,265,318,394,365,302,332,390,346,254,214,274,338,398,369,310,348,388],
	[360,278,206,172,248,302,365,311,224,152,118,185,267,348,395,333,240,165,204,278,317,218,142,196,273],
	[340,390,401,355,289,352,402,365,297,249,294,374,402,352,281,216,273,339,398,361,289,210,235,295,339],
	[309,246,162,109,172,242,310,256,168,91,51,121,201,278,335,270,180,97,35,94,156,231,297,348,383],
	[399,323,237,156,98,138,205,165,85,14,-47,17,95,146,77,1,-69,-133,-74,-17,-88,-154,-210,-248,-304]
]

static func deck_height(index: int) -> float:
	if index==CHAPTER_STARTS.back(): return -386
	return DECK_HEIGHTS[district(index)][int(SOURCE_ROOMS[index])%ROOMS_PER_DISTRICT]

# Scene addresses for the stretches with wider masonry gaps.
const LONG_CAUSEWAY_SCENES := [8,17,20,34,37,42,91,99]
const BOAR_RUN_APPROACHES := {
	68:"ride loose", 69:"spillway ride", 70:"spider ride",
	71:"ride loose spillway", 72:"ride spider"
}
# Authored revisions from the chapter editor. Keep checkpoint IDs in route order.
const CHAPTER_ROUTE_REVISIONS := {
	1:"ledge gap causeway short_wreck ledge @0a shore ledge gap @0b gap float ledge",
	2:"drop shore tide causeway @1a broken_jetty @1b skiff ledge",
	4:"float spillway gap shore gap @3a tide skiff shore @3b shore tide shore",
	6:"crate steps tide causeway @4a shore @4b gantry gap",
	7:"drop loose ledge skiff gap @5a balance shore hoist @5b gap float ledge",
	8:"float spillway gap loose ledge @6a skiff loose wide_causeway @6b ledge shore drop",
	9:"ledge gap causeway tide causeway @7a tide shore rocker @7b loose hound steps",
	17:"crate steps shore tide wide_causeway @13a barge @13b hound gap loose",
	22:"branches branches causeway branches @17a branches @17b hound branches crate drop",
}
static var ROOMS: Array = curate_rooms()

static func curate_rooms() -> Array:
	var old:=preload("res://scripts/crossings.gd").assemble(LANDMARKS)
	var rooms:=[]
	for i in SOURCE_ROOMS.size():
		var addr:int=SOURCE_ROOMS[i]
		var entry:Array=old[addr].duplicate()
		# Give each retained destination its own approach to a checkpoint.
		var passages:=[["skiff gap","loose ledge","tide causeway"],["branches","vine branches","branches drop"],
			["aqueduct drain","spillway steps","float rocker"],["trolley","viaduct_walk trolley","gantry trolley"],
			["ride","ride","ride"],["steps drop","ledge steps","drop ledge"],
			["ray shutters","ledge ray","shutters steps"],["storm_island gap","steps storm_island","loose storm_island"]]
		if i>0:
			var section:String=BOAR_RUN_APPROACHES.get(addr,passages[region(i)][i%3])
			var lamp:=str(entry[1]).find(" @")
			if lamp>=0:
				if region(i)==6: lamp=str(entry[1]).find(" ",lamp+2)
				if lamp<0: lamp=str(entry[1]).length()
				entry[1]=str(entry[1]).insert(lamp," "+section)
		if addr in LONG_CAUSEWAY_SCENES:
			var sections:=str(entry[1]).split(" ")
			var crossing:=sections.find("causeway")
			if crossing>=0:
				sections[crossing]="wide_causeway"
				entry[1]=" ".join(sections)
		if addr in CHAPTER_ROUTE_REVISIONS: entry[1]=CHAPTER_ROUTE_REVISIONS[addr]
		rooms.append(entry)
	return rooms

static func migrated_room(source: int) -> int:
	return mini(SOURCE_ROOMS.bsearch(source),SOURCE_ROOMS.size()-1)

static func arrival_text(index: int) -> String:
	if index==REGION_STARTS[region(index)]: return EPIGRAPHS[ENVIRONMENTS[region(index)]]
	if index==ROOMS.size()-1: return DISPATCHES.back()
	var source:int=SOURCE_ROOMS[index]
	if source%5==0 and source<145: return DISPATCHES[floori(source/5.0)]
	return ""

static func legacy_index(index: int) -> int:
	return ROOMS.size()-1 if index==LANDMARKS.size()-1 else migrated_room(index*5)

# The stable @ identifiers remain checkpoint addresses for saves from version 1.
const PUZZLE_INTERVAL := 420.0
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

static func board_for(turn: int) -> String:
	var family: Array = FAMILIES[turn % FAMILIES.size()]
	return family[floori(float(turn) / FAMILIES.size()) % family.size()]

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
