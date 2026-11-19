extends RefCounted

# Four named crossings connect each pair of the original harbor landmarks.
# Each line selects an approach, a working section, and an exit in its district.
# A lamp between sections gives the player a dry checkpoint.
const DISTRICTS := [
	{
		"approach":["ledge gap causeway","crate steps skiff","float spillway gap","drop loose ledge","steps crate spillway"],
		"works":["skiff loose causeway","hound ledge gap","balance crate hoist","tide skiff rocker","loose drop gantry"],
		"exit":["gap float ledge","loose skiff steps","ledge crate drop","causeway tide skiff","hound gap loose"],
		"places":[
			["The Ropewalk",0,1,0],["The Broken Jetty",3,0,1,["drop causeway", "longwreck", "skiff ledge"]],["The Boatbuilder’s Yard",1,2,2],["The Eel Weir",2,3,3],
			["Coal Dogs",4,1,4,["crate steps", "hound", "gantry gap"]],["The Pitch Kettle",3,2,0],["Half-tide Steps",2,0,2],["The Mooring Chains",0,3,1],
			["A Bell in the Fog",1,0,3],["The Net Sheds",3,4,2],["Timber Afloat",2,3,1],["The Winchman’s Walk",4,2,0],
			["The Plank Road",0,4,1],["Salvage Row",1,2,4],["The Ballast Wall",4,0,2],["The Turn of the Tide",2,1,3],
			["The Outer Piles",3,3,0],["Dogs at Anchor",0,4,2],["The Old Fish Market",1,2,3],["A Green Lamp",2,0,4]
		]
	},
	{
		"approach":["low ledge tide","spillway low float","loose drop steam","crate steps drain","float ledge skiff"],
		"works":["rocker causeway drain","steam low tide","skiff loose vents","crate hoist gantry","causeway balance float"],
		"exit":["drain steps ledge","aqueduct loose skiff","steam spillway gap","hoist drop tide","vents low ledge"],
		"places":[
			["The North Intake",0,0,1],["The Tidal Sill",1,4,0,["low spillway", "single_float causeway", "rocker drain"]],["Warm Brick",2,1,4],["The Valve Chest",3,3,2],
			["The Overflow Lip",4,2,3],["The Siphon",0,1,0],["The Stilling Well",1,0,2],["The Gauge Keeper",3,4,3],
			["The Blind Culvert",0,2,4],["The Plunge Pool",4,0,1],["The Scoured Channel",2,3,0],["The Copper Stairs",3,1,3],
			["Seven Flood Marks",1,4,2],["The Spill Apron",2,0,1],["The Inspection Launch",4,2,0],["The Drowned Passage",0,3,1],
			["Floodwall Footings",3,4,4],["The Stone Mouth",1,3,0],["The Weeping Gate",2,1,2],["The Lower Basin",4,0,3]
		]
	},
	{
		"approach":["crate ledge hoist","loose steps gap","balance drop crate","skiff ledge tide","shutters crate steps"],
		"works":["balance hoist crate","hound ledge loose","hoist rocker drop","shutters steam ledge","crate skiff balance"],
		"exit":["gantry hoist gap","ledge crate steps","balance loose hoist","skiff tide drop","gantry ledge crate"],
		"places":[
			["The Goods Inward",0,0,1],["The Weighbridge",2,2,2],["The Runner’s Hut",1,1,4],["The Swept Rails",4,3,0],
			["The Water Crane",3,4,3],["The Chain Store",0,2,1],["A Snapped Axle",1,3,0],["The Crane Saddle",2,0,2,["crate balance", "gantry viaduct_walk", "hoist drop"]],
			["Night Freight",4,1,3],["The Long Hook",0,4,0],["The Tarpaulin Shed",3,2,4],["The Riveter’s Bench",2,3,1],
			["Tracks Under Water",3,4,2],["The Shunting Lane",4,0,3],["The Dogman’s Post",1,1,0],["The Stacked Pallets",0,2,2],
			["The Empty Wagon",2,4,4],["The Customs Scale",4,2,1],["A Rope of Sparks",1,3,2],["The Outbound Rail",3,0,0]
		]
	},
	{
		"approach":["steam low ledge","vents drop float","spillway low tide","loose crate drain","steps hoist steam"],
		"works":["vents drain gantry","balance steam hoist","causeway rocker float","shutters low steam","loose skiff vents"],
		"exit":["low ledge vents","tide steam float","hoist loose drop","aqueduct drain steps","shutters ledge skiff"],
		"places":[
			["The Valve Forest",0,0,3],["The Hot Well",1,3,1],["The Air Vessel",2,2,4],["The Condenser Deck",4,1,2],
			["Black Pipe Alley",3,4,0],["The Bypass",0,3,3],["The Water Hammer",1,0,1],["The Lift Pump",4,2,2,["steam low", "gantry", "viaduct_walk vents"]],
			["The Clogged Strainer",2,4,1],["The Iron Lungs",3,0,0],["The Flywheel Pit",4,1,4],["The Leaking Flange",0,3,1],
			["The Sump Bridge",2,2,2],["The Boiler Feed",1,1,0],["A Hollow Knocking",3,4,4],["The Delivery Main",4,0,3],
			["The Pumpman’s Locker",3,1,2],["The Header Tank",2,0,4],["The Relief Port",1,3,0],["Air in the Lines",0,2,1]
		]
	},
	{
		"approach":["ledge drop shutters","loose steps hoist","rocker float ledge","crate low steam","skiff gap shutters"],
		"works":["ray loose shutters","shutters ledge ray","hoist gantry ray","hound drop ray","steam balance shutters"],
		"exit":["ray ledge loose","shutters tide skiff","hoist ray steps","spillway low shutters","loose crate ledge"],
		"places":[
			["The Polishing Shop",0,0,2],["The Masking Booth",3,1,0],["A Line of Prisms",1,2,4],["The Glass Ferry",4,0,1],
			["The Prism Bath",2,2,3],["The Split Beam",0,1,2],["The Shard Yard",1,3,4],["The Silver Room",3,4,0],
			["The Shadow Bridge",4,1,1,["ledge shutters", "ray aqueduct", "ray drop"]],["The Focal Stair",0,0,0],["The Mirror Gantry",1,2,2],["The Glassblower’s Door",3,4,3],
			["The Dark Lantern",2,3,0],["Half a Reflection",4,2,1],["The North Window",0,1,3],["The Frosted Gallery",2,0,2],
			["The Winking Sill",1,4,4],["The Last Mirror",3,3,1],["The Shutter Cable",4,1,2],["A Pin of Light",2,0,0]
		]
	},
	{
		"approach":["ledge hoist steps","causeway skiff loose","crate drop vents","shutters steps ledge","gap balance float"],
		"works":["hoist loose ray","gantry skiff tide","vents ledge shutters","balance crate hoist","hound gap ray"],
		"exit":["ledge shutters hoist","loose float skiff","ray steps ledge","balance hoist crate","rocker aqueduct drop"],
		"places":[
			["The Lower Switchback",0,0,0],["The Counterweight Shaft",4,3,3],["The Storm Steps",3,2,2],["The Keeper’s Launch",1,1,1,["causeway skiff", "flotilla", "steps gantry"]],
			["The Brass Ladder",0,3,0],["The Blind Landing",2,4,2],["The Cable Drum",4,0,3],["The Gull Roost",1,2,1],
			["The Night Watch",3,4,2],["The Winding Floor",0,0,3],["The Seaward Face",1,1,4],["The Oil Store",2,2,0],
			["The Bell Ropes",4,3,2],["The Wind Gallery",3,0,1],["The Rain Chain",1,1,0],["The Mercury Bath",2,3,4],
			["The Upper Cradle",0,2,3],["The Weather Vane",3,4,0,["gantry viaduct_walk", "rocker", "ledge hoist"]],["The Clockkeeper’s Rest",4,1,4],["The Lantern Door",2,0,2]
		]
	}
]

const BOAR_ROAD_NAMES := ["Bracken Gate","The Root Road","Charcoal Mile","Split Hoof Ford","The Ash Mounds","Three Culverts","The Kiln Mouth","Slumped Embankment","Coppice Run","The Turf Bridge","Broken Cartway","The Last Gallop"]

static func assemble(landmarks: Array) -> Array:
	var voyage: Array = []
	for i in landmarks.size():
		var district: Dictionary = DISTRICTS[floori(i / 5.0)]
		# The voyage opens on the original landing and ends at the original beacon.
		if i != landmarks.size()-1: voyage.append(landmarks[i])
		for j in 4:
			var n := (i % 5)*4+j
			var place: Array = district.places[n]
			var legs:Array=[district.approach[place[1]],district.works[place[2]],district.exit[place[3]]]
			if place.size()>4: legs=place[4]
			var section := "%s @%da %s @%db %s" % [legs[0],n,legs[1],n,legs[2]]
			voyage.append([place[0],section])
		if i == landmarks.size()-1: voyage.append(landmarks[i])
	# Substitute working sections between existing checkpoint lamps.
	var crossings := {12:"lockpair",33:"lockpair",44:"lockpair",88:"lockpair",107:"lockpair",129:"lockpair",
		21:"branches spider",23:"branches swarm",27:"swarm branches",29:"spider branches",
		54:"spider",96:"spider",116:"spider",126:"spider"}
	var specialties := {
		"barge":[11,14,17], "branches":[19,22,24,26,28], "wave":[41,43,47],
		"balance":[51,53,57], "trolley":[61,64,67], "ride":[68,69,71,72,73,74,76,77,78,79],
		"piston":[81,84,87], "ray":[102,104,108], "shutters":[112,114,118],
		"gantry":[122,124,128], "causeway":[132,134,137]}
	for token in specialties:
		for index in specialties[token]: crossings[index]=token
	for room in crossings:
		var legs:=str(voyage[room][1]).split(" @")
		var next_lamp:=legs[1].get_slice(" ",0)
		legs[1]=next_lamp+" "+str(crossings[room])
		voyage[room][1]=" @".join(legs)
	# Preserve the checkpoint identifiers while composing the canopy, mounted road
	# and storm causeway around their own movement rules.
	for index in range(19,30):
		var canopy:=str(voyage[index][1]).split(" ")
		for j in canopy.size():
			if canopy[j] in ["loose","gap","ledge"]: canopy[j]="branches"
			elif canopy[j]=="skiff": canopy[j]="vine"
		voyage[index]=[voyage[index][0]," ".join(canopy)]
	for index in range(68,80):
		var road:=PackedStringArray(["ride"])
		for token in str(voyage[index][1]).split(" "):
			if token.begins_with("@"):
				road.append(token)
				road.append("ride")
		voyage[index]=[BOAR_ROAD_NAMES[index-68]," ".join(road)]
	for index in range(131,138):
		var causeway:=PackedStringArray(["storm_island"])
		for token in str(voyage[index][1]).split(" "):
			if token.begins_with("@"): causeway.append(token)
			elif token in ["loose","gap","steps","ledge","drop"]: causeway.append(token)
			else: continue
			causeway.append("storm_island")
		voyage[index]=[voyage[index][0]," ".join(causeway)]
	return voyage
