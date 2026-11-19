extends Node2D
# Harbor elevation rendered in three planes. Walkable surfaces have a pale worn lip.
const Book = preload("res://scripts/campaign.gd")
const Passage = preload("res://scripts/passage.gd")
const SERIF = preload("res://art/fonts/Yrsa-Medium.ttf")
const MONO = preload("res://art/fonts/LiberationMono-Regular.ttf")
const SKY := [
	preload("res://art/harbor.webp"), preload("res://art/pumpworks.webp"),
	preload("res://art/freightyard.webp"), preload("res://art/pumpworks.webp"),
	preload("res://art/lensworks.webp"), preload("res://art/breakwater.webp")]
const INK := Color("#152326")
const DARK := Color("#1e3032")
const EDGE := Color("#80908a")
const BRASS := Color("#efc487")
const PAPER := Color("#e9e6d3")
const REACH_SKIES := [preload("res://art/reach00.webp"), preload("res://art/reach01.webp"), preload("res://art/reach02.webp"), preload("res://art/reach03.webp"), preload("res://art/reach04.webp"), preload("res://art/reach05.webp"), preload("res://art/reach06.webp"), preload("res://art/reach07.webp"), preload("res://art/reach08.webp"), preload("res://art/reach09.webp"), preload("res://art/reach10.webp"), preload("res://art/reach11.webp"), preload("res://art/reach12.webp"), preload("res://art/reach13.webp"), preload("res://art/reach14.webp"), preload("res://art/reach15.webp")]
var route: Passage
var mode := "menu"
var age := 0.0
var finale_aim := 0.0
var finale_lit := false
var arrival := 0.0

func poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),color)

func line(a: Vector2,b: Vector2,c: Color,w := 1.0) -> void:
	draw_line(a,b,c,w,true)

func glow(p: Vector2,r: float,power := 1.0) -> void:
	for j in range(5,0,-1):
		draw_circle(p,r*j/5.0,Color(1,.74,.37,(.019+j*.004)*power),true,-1,true)
	draw_circle(p,2.3,BRASS,true,-1,true)

func _draw() -> void:
	var playing := route != null and mode == "play"
	var chapter := Book.district(route.room) if playing else (5 if mode == "ending" else 0)
	var cam := route.camera if playing else 0.0
	var offset := cam/maxf(1,route.width-960) if playing else 0.35
	var sky_rect:=Rect2(-offset*96,-8,1056,550)
	if playing:
		sky_rect=Rect2(-offset*212,route.camera_y-132+minf(125,-route.camera_y*.23),1218,686)
	var sky:Texture2D=SKY[chapter]
	if playing:
		var reach:int=Book.ENVIRONMENTS[Book.chapter(route.room)]
		sky=REACH_SKIES[15 if reach==9 and offset>.24 and offset<.83 else reach]
	draw_texture_rect(sky,sky_rect,false)
	if playing:
		draw_weather(cam,chapter)
		draw_waterfront(cam,chapter)
		# Lit windows and running machinery accumulate as the station comes back on line.
		if chapter>=2:
			for light_no in mini(10,chapter+route.completed.size()):
				var wx:=fposmod(243+light_no*183.9-cam*.075,1030)-28
				var wy:=322+sin(light_no*8.2)*18
				draw_rect(Rect2(wx,wy,3,2),Color(.95,.78,.49,.62))
		var drift := fmod(cam*0.25,370)
		for k in range(-1,4):
			var x := k*370.0+224-drift
			if chapter in [0,2,5]:
				line(Vector2(x,323),Vector2(x+4,474),Color(.15,.21,.22,.45),5)
				line(Vector2(x,356),Vector2(x+69,431),Color(.16,.22,.22,.38),3)
		for s in route.structures:
			var x:float = s.x-cam
			if x < -220 or x>1000: continue
			if s.type=="drain":
				var wet:=1.0
				if route.completed.has(s.key):
					wet=clampf(1.0-(route.time-float(route.restored_at.get(s.key,-5.0)))/2.3,0,1)
				var water_y:=float(s.y)+83-67*wet
				draw_rect(Rect2(x,water_y,s.w,540-water_y),Color(.12,.30,.32,.64))
				line(Vector2(x,water_y),Vector2(x+s.w,water_y),Color("#8ea9a0"),1.5)
				for k in range(12,int(s.w)-4,30):
					line(Vector2(x+k,s.y-9),Vector2(x+k,s.y),DARK,3)
			draw_rect(Rect2(x,s.y,s.w,14),DARK)
			for j in ceili(float(s.w)/20):
				draw_rect(Rect2(x+j*20,s.y+12,4,11),INK)
			line(Vector2(x,s.y+1),Vector2(x+s.w,s.y+1),EDGE,2)
		for p in route.platforms:
			if p.style in ["hoist","cage"]: draw_lift_support(p,cam)
		for p in route.platforms:
			if float(p.pos.x)+float(p.w)<cam-15 or float(p.pos.x)>cam+975: continue
			draw_platform(p,cam)
		draw_dock_details(cam,chapter)
		for d in route.devices:
			if d.type in ["hound","spider","swarm"] or absf(float(d.x)-cam-480)<745: draw_device(d,cam)
		for box in route.freight:
			if absf(float(box.x)-cam-480)<540:
				draw_crate(Vector2(box.x-cam,box.y))
		for i in route.stations.size():
			var s:Dictionary=route.stations[i]
			if absf(float(s.x)-cam-480)>610: continue
			if route.needs_console(i) or s.get("was_console",false):
				draw_station(s,cam,route.completed.has(s.key))
			else:
				var post:=Vector2(s.x-cam,s.y)
				line(post,post+Vector2(0,-36),DARK,4)
				draw_arc(post+Vector2(0,-37),5,0,TAU,20,BRASS,2,true)
		var end_x := route.width-82-cam
		if end_x < 1020:
			draw_exit(end_x,route.platforms.back().pos.y,route.completed.size()==route.stations.size())
		for i in route.rides.size():
			var ride:Dictionary=route.rides[i]
			var foot:Vector2=ride.position-Vector2(cam,0)
			if foot.x>-45 and foot.x<1005: draw_mount(foot,ride.type,route.stride if i==route.active_ride else 0.0)
		if route.death_timer <= 0.1:
			if route.ledge>=0:
				draw_climber(cam)
			elif not route.mounted.is_empty():
				var foot:=route.pos-Vector2(cam,0)
				draw_keeper(foot-Vector2(0,13),1,0,false,0)
			elif route.held_crate>=0:
				draw_hauling_keeper(cam)
			else:
				draw_keeper(route.pos-Vector2(cam,0),route.face,route.stride,route.is_grounded(),route.vel.x)
		water(cam)
	elif mode == "ending":
		var p := Vector2(155,219)
		var target := Vector2(308+finale_aim*560,321)
		var normal := (target-p).normalized().orthogonal()
		poly([p-normal*2,target-normal*17,target+normal*17,p+normal*2],Color(.96,.82,.54,.14 if not finale_lit else .32))
		line(p+Vector2(-6,15),p+Vector2(-9,265),INK,9)
		line(p+Vector2(11,15),p+Vector2(17,265),INK,7)
		for iy in [-15,15]: draw_rect(Rect2(p+Vector2(-17,iy),Vector2(39,5)),INK)
		for ix in [-14,16]: line(p+Vector2(ix,-14),p+Vector2(ix,16),DARK,3)
		glow(p,44)
		var ship := Vector2(663+minf(arrival,12)*5.8,321+minf(arrival,12)*2+sin(age)*1.5)
		draw_ferry(ship)
		if finale_lit: glow(ship+Vector2(-4,-15),19,1.6)
		line(Vector2(784,0),Vector2(806,540),INK,13)
		line(Vector2(892,0),Vector2(870,540),INK,19)
		draw_rect(Rect2(0,479,960,61),INK)
		line(Vector2(0,480),Vector2(960,480),EDGE,2)
		draw_keeper(Vector2(760,479),-1,0,true,0)
	else:
		# Tide idles under the title; the first three answering blasts belong to the story.
		for j in 18:
			var x := fmod(j*131.7+age*(2+j%3),1080)-50
			var y := 390+fmod(j*59.2,140)
			line(Vector2(x,y),Vector2(x+20+j%12,y),Color(.82,.85,.77,.11),1)
	atmosphere(cam)
	if playing:
		var region:int=Book.ENVIRONMENTS[Book.chapter(route.room)]
		if region==13:
			var phase:=fposmod(route.time,18)
			var since:=phase if phase<5 else (phase-5 if phase<11 else phase-11)
			draw_rect(Rect2(0,route.camera_y,960,540),Color(0.01,.018,.028,smoothstep(.72,1,since)))
		elif region==9 and offset>.24 and offset<.83:
			var center:=route.pos-Vector2(cam,21)
			for k in 48:
				var a:=Vector2.from_angle(TAU*k/48.0)
				var b:=Vector2.from_angle(TAU*(k+1)/48.0)
				poly([center+a*104,center+b*104,center+b*1500,center+a*1500],Color(.014,.022,.025))
				draw_colored_polygon(PackedVector2Array([center+a*65,center+b*65,center+b*104,center+a*104]),Color(0,0,0,.35))

func draw_weather(cam: float,chapter: int) -> void:
	var reach:=route.room%Book.ROOMS_PER_DISTRICT
	# Light follows the tide, from a grey landing through storm to the first dawn.
	var tint:Color=[Color(.46,.57,.55,.10),Color(.14,.31,.36,.20),Color(.48,.36,.24,.12),
		Color(.14,.25,.26,.17),Color(.42,.48,.55,.13),Color(.55,.47,.34,.16)][chapter]
	draw_rect(Rect2(0,route.camera_y,960,540),tint)
	if chapter in [1,5] or (chapter==0 and reach>=16):
		var drops:=32 if reach%5>=2 else 15
		for i in drops:
			var x:=fposmod(i*127.43-age*81-cam*.21,1000)-12
			var y:=route.camera_y+fposmod(i*63.1+age*302,540)
			line(Vector2(x,y),Vector2(x-2.5,y+9),Color(.79,.84,.83,.15),1)
	elif chapter in [0,2,4]:
		var flock:=fposmod(age*10-cam*.09+reach*103,1430)-210
		for i in 5:
			var x:=flock+i*15
			var y:=route.camera_y*.76+138+sin(i*1.21+reach)*16+sin(age*.58+i)*3
			var wing:=sin(age*4+i)*3
			draw_polyline(PackedVector2Array([Vector2(x-4,y+wing),Vector2(x,y+1),Vector2(x+4,y+wing)]),Color(.15,.21,.22,.52),1.4,true)

# Near the water the keeper passes the tide marks on the retaining wall.
# Higher on the line, cables frame a second row of roofs and lamps far below.
func draw_waterfront(cam: float,chapter: int) -> void:
	var elevation:=clampf((344.0-route.pos.y)/178.0,0,1)
	var bank:=Color(.14,.21,.22,.34*(1-elevation))
	if elevation<1 and chapter in [0,1,3]:
		for i in range(-1,7):
			var x:=i*190.0-fposmod(cam*.38,190.0)
			draw_rect(Rect2(x,404,164,65),bank)
			draw_arc(Vector2(x+81,456),38,PI,TAU,20,bank,8,true)
			for k in 4:
				line(Vector2(x+149,415+7*k),Vector2(x+156+(k%2)*4,415+7*k),Color(.65,.68,.62,bank.a),2)
	if elevation<=.01: return
	var steel:=Color(.14,.20,.21,.48*elevation)
	var cable_y:=route.camera_y*.63+159
	for i in range(-1,4):
		var x:=i*420.0-fposmod(cam*.44,420.0)
		draw_polyline(PackedVector2Array([Vector2(x,cable_y),Vector2(x+117,cable_y+23),
			Vector2(x+235,cable_y+33),Vector2(x+340,cable_y+26),Vector2(x+420,cable_y)]),steel,2,true)
		line(Vector2(x,cable_y-12),Vector2(x-12,cable_y+320),steel,5)
		line(Vector2(x-15,cable_y+209),Vector2(x+39,cable_y+271),steel,3)
		var roof_y:=route.camera_y*.70+420
		poly([Vector2(x+52,roof_y+17),Vector2(x+91,roof_y-4),Vector2(x+165,roof_y+3),
			Vector2(x+190,roof_y+17),Vector2(x+190,roof_y+73),Vector2(x+52,roof_y+73)],steel)
		for j in 4:
			draw_rect(Rect2(x+66+j*28,roof_y+26,7,4),Color(.85,.69,.42,.48*elevation))
	if chapter==5 and route.camera_y < -150:
		# Cast iron rings and riveted ribs of the lantern tower.
		var iron:=Color(.15,.21,.22,.47)
		var ring_y:=floorf(route.camera_y/154.0)*154
		for i in range(-1,4):
			var x:=i*380.0-fposmod(cam*.57,380.0)
			line(Vector2(x,ring_y-30),Vector2(x+12,ring_y+720),iron,10)
			for j in 5:
				var y:=ring_y+j*154
				line(Vector2(x,y),Vector2(x+380,y+3),iron,5)
				line(Vector2(x+5,y+7),Vector2(x+85,y+71),iron,3)
				draw_circle(Vector2(x+4,y),3,EDGE)

func draw_lift_support(p: Dictionary,cam: float) -> void:
	# Foundations, rails and sheaves are attached to the dock in world space.
	var left:=float(p.base.x)-cam-13
	var right:=left+float(p.w)+26+float(p.delta.x)
	if right<0 or left>960: return
	var y:=float(p.base.y)-183
	line(Vector2(left,y),Vector2(right,y),INK,7)
	for x in [left,right]:
		line(Vector2(x,y+2),Vector2(x,float(p.base.y)+39),DARK,4)
		line(Vector2(x,y+34),Vector2(x+(25 if x==left else -25),y+2),DARK,3)
		draw_circle(Vector2(x,y),2,BRASS)
	if p.style=="cage":
		# The descending weight takes up the cable paid out by the rising cab.
		var cab_x:=left+float(p.w)*.5+13
		var weight_y:=y+15+float(p.base.y)-float(p.pos.y)
		line(Vector2(cab_x,y),Vector2(right-4,y),EDGE,1.5)
		line(Vector2(right-4,y),Vector2(right-4,weight_y),EDGE,1.5)
		draw_rect(Rect2(right-9,weight_y,10,22),DARK)
		for x in [cab_x,right-4]:
			draw_circle(Vector2(x,y),7,INK)
			draw_arc(Vector2(x,y),5,0,TAU,16,EDGE,1.3,true)

func draw_platform(p: Dictionary,cam: float) -> void:
	var x := float(p.pos.x)-cam
	var y := float(p.pos.y)
	var w := float(p.w)
	var style := str(p.style)
	var solid := route.is_solid(p)
	if style=="vine":
		var anchor:=Vector2(p.base.x-cam+87,p.base.y-143)
		line(anchor,Vector2(x+w*.5,y),DARK,3)
		line(Vector2(x,y+2),Vector2(x+w,y+2),INK,5)
		return
	if style=="branch":
		poly([Vector2(x-8,y+13),Vector2(x+5,y),Vector2(x+w,y),Vector2(x+w-14,y+5),Vector2(x+19,y+8),Vector2(x-21,y+42)],INK)
		line(Vector2(x+3,y),Vector2(x+w-3,y),EDGE,2)
		return
	if style=="loose":
		var timer:=float(p.timer)
		if timer>1.15: return
		var fall:=maxf(0,timer-.74)
		var shake:=sin(timer*49)*2 if timer>=0 else 0.0
		draw_set_transform(Vector2(x,y+shake+470*fall*fall),fall*1.3,Vector2.ONE)
		for k in 4:
			var bx:=k*w/4
			draw_rect(Rect2(bx,0,w/4-1,10),DARK)
			line(Vector2(bx,1),Vector2(bx+w/4-2,1),EDGE,2)
			line(Vector2(bx+4,1),Vector2(bx+8,7),INK,1)
		for end in [5.0,w-5.0]:
			line(Vector2(end,9),Vector2(end-3,24+shake),Color("#8c8169"),2)
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		return
	if style in ["pier","viaduct"]:
		# Battered cutwaters below the spillway and braced trestles above it.
		draw_rect(Rect2(x,y,w,11),DARK)
		line(Vector2(x,y+1),Vector2(x+w,y+1),PAPER,2)
		if style=="pier":
			poly([Vector2(x+6,y+11),Vector2(x+w-6,y+11),Vector2(x+w-13,518),Vector2(x+14,518)],INK)
			for j in 3: line(Vector2(x+6,y+19+j*19),Vector2(x+w-7,y+19+j*19),DARK,2)
		else:
			for j in range(8,int(w)-6,59):
				line(Vector2(x+j,y+11),Vector2(x+j-4,500),INK,6)
				line(Vector2(x+j,y+11),Vector2(x+j+48,y+70),DARK,4)
				line(Vector2(x+j,y+70),Vector2(x+j+48,y+11),DARK,3)
		return
	if style=="rocker":
		var left:=Vector2(x,route.surface_height(p,p.pos.x))
		var right:=Vector2(x+w,route.surface_height(p,p.pos.x+w))
		poly([left,right,right+Vector2(0,12),left+Vector2(0,12)],DARK)
		line(left,right,BRASS,2)
		for j in range(8,int(w),20):
			var seam:=left.lerp(right,j/w)
			line(seam+Vector2(0,2),seam+Vector2(-1,10),INK,1.5)
			draw_circle(seam+Vector2(3,5),1.4,EDGE)
		return
	if style=="cage":
		var roof:=Vector2(x+w*.5,y-43)
		line(Vector2(roof.x,p.base.y-182),roof,EDGE,2)
		for side in [7,w-7]:
			line(roof,Vector2(x+side,y-28),INK,2.5)
			line(Vector2(x+side,y-28),Vector2(x+side,y),DARK,3)
		for k in range(7,int(w),17):
			line(Vector2(x+k,y-28),Vector2(x+k,y),EDGE,2)
		line(Vector2(x+7,y-28),Vector2(x+w-7,y-28),DARK,3)
		draw_rect(Rect2(x,y,w,10),INK)
		line(Vector2(x,y+1),Vector2(x+w,y+1),BRASS,2)
		return
	if style in ["skiff","float","bob","chamber"]:
		if style in ["float","bob"] and p.base.y<315:
			for pin in [8,w-8]:
				line(Vector2(x+pin,p.base.y-135),Vector2(x+pin,y),DARK,2)
			line(Vector2(x-6,p.base.y-136),Vector2(x+w+6,p.base.y-136),INK,4)
		if style == "skiff":
			poly([Vector2(x-7,y-7),Vector2(x+12,y),Vector2(x+w-10,y),Vector2(x+w+8,y-9),Vector2(x+w-5,y+17),Vector2(x+13,y+19)],INK)
			line(Vector2(x+4,y+5),Vector2(x+w-1,y+5),EDGE,2)
			line(Vector2(x+12,y+10),Vector2(x+w-6,y+10),Color("#485650"),2)
		else:
			draw_rect(Rect2(x+4,y+4,w-8,18),DARK)
			draw_rect(Rect2(x,y,w,6),INK)
			for edge in [7,w-10]: draw_rect(Rect2(x+edge,y,4,22),EDGE)
		line(Vector2(x,y),Vector2(x+w,y),PAPER,1.5)
		return
	if style == "hoist":
		# A wheeled trolley travels along the fixed beam. Only its cable pays out.
		var trolley:=Vector2(x+w*.5,p.base.y-183)
		draw_rect(Rect2(trolley-Vector2(10,1),Vector2(20,8)),DARK)
		for side in [-7,7]:
			draw_circle(trolley+Vector2(side,-3),4,INK)
			draw_circle(trolley+Vector2(side,-3),1.5,BRASS)
		var hook:=Vector2(trolley.x,y-29)
		line(trolley+Vector2(0,6),hook,EDGE,2)
		for k in [9,w-9]: line(hook,Vector2(x+k,y),DARK,2.5)
		draw_rect(Rect2(x,y,w,13),INK)
		line(Vector2(x,y),Vector2(x+w,y),BRASS,2)
		return
	if style in ["span","ray","balance"]:
		if not solid:
			draw_rect(Rect2(x,y,w,8),Color(.6,.65,.58,.14))
			return
		draw_rect(Rect2(x,y,w,12),DARK)
		line(Vector2(x,y),Vector2(x+w,y),BRASS if style=="ray" else EDGE,2)
		for k in range(5,int(w)-5,19):
			line(Vector2(x+k,y+2),Vector2(x+k+7,y+10),EDGE,1)
		if style=="ray":
			line(Vector2(x+w*.5,y+10),Vector2(x+w*.5,495),Color(.86,.75,.49,.25),2)
		return
	draw_ground(x,y,w,Book.chapter(route.room))

# The flat upper edge is the collision surface. Material details hang below it.
func draw_ground(x: float,y: float,w: float,chapter: int) -> void:
	var origin:=Vector2(x,y)
	draw_set_transform(origin,0,Vector2.ONE)
	match chapter:
		0: # Solid tarred timbers with a warm cut end and iron straps.
			draw_rect(Rect2(0,0,w,21),Color("#674433"))
			for k in range(4,int(w)-4,31):
				line(Vector2(k,7),Vector2(minf(w,k+22),5),Color("#ad8060"),1)
				draw_rect(Rect2(k,0,3,20),Color("#342e2d"))
			line(Vector2.ZERO,Vector2(w,0),Color("#d7ae7b"),2)
		1: # Grass mats and exposed roots.
			poly([Vector2.ZERO,Vector2(w,0),Vector2(w-5,18),Vector2(w*.6,22),Vector2(9,31)],Color("#534439"))
			draw_rect(Rect2(0,0,w,6),Color("#779c50"))
			for k in range(4,int(w)-3,9):
				line(Vector2(k,2),Vector2(k+3,-3-(k%4)),Color("#b2ca70"),1.5)
				line(Vector2(k,11),Vector2(k-3,22+k%11),Color("#766247"),1)
		2: # Blue-grey lock masonry, laid in staggered courses.
			draw_rect(Rect2(0,0,w,53),Color("#40566a"))
			for row in 3:
				for k in range(-24*(row%2),int(w),48):
					var start:=maxf(0,k+1)
					draw_rect(Rect2(start,row*17+1,minf(w,k+47)-start,15),Color("#84939a").darkened(.09*((row+k+24)%4)))
		3: # Galvanized rail girders, open web and rivets.
			for yy in [0,20]: draw_rect(Rect2(0,yy,w,4),Color("#b6c5cb"))
			for k in range(2,int(w)-2,23):
				line(Vector2(k,4),Vector2(minf(w,k+20),20),Color("#707f89"),3)
				draw_circle(Vector2(k,2),1.3,INK)
		4: # Rust-red packed clay over charcoal.
			poly([Vector2.ZERO,Vector2(w,0),Vector2(w-4,22),Vector2(w*.63,30),Vector2(6,25)],Color("#724b42"))
			draw_rect(Rect2(0,0,w,5),Color("#bd7951"))
			for k in range(4,int(w)-5,17): draw_circle(Vector2(k,10+k%9),2+k%3,Color("#453b39"))
		5: # Jagged limestone shelves with cleaved facets.
			for k in range(0,int(ceil(w)),32):
				var end:=minf(k+32,w)
				poly([Vector2(k,0),Vector2(end,0),Vector2(end,14),Vector2(k+(end-k)*.4,31+k%13),Vector2(k,17)],Color("#949084"))
				poly([Vector2(k,0),Vector2(end,14),Vector2(k+(end-k)*.4,31+k%13)],Color("#645f61"))
			line(Vector2.ZERO,Vector2(w,0),Color("#dbd2bc"),2)
		6: # Sea-green leaded glass.
			draw_rect(Rect2(0,0,w,19),Color("#568d8d"))
			for k in range(0,int(w),27):
				line(Vector2(k,17),Vector2(minf(w,k+17),1),Color("#b4ded1"),2)
			line(Vector2.ZERO,Vector2(w,0),Color("#d5f4e9"),3)
		7: # A bank of cloud with scalloped undersides and a lit crest.
			for k in range(0,int(ceil(w)),16):
				var radius:=minf(12,(w-k)*.5)
				draw_circle(Vector2(k+radius,12),radius,Color("#aab6cf"))
			draw_rect(Rect2(0,0,w,12),Color("#d1d7e2"))
			line(Vector2.ZERO,Vector2(w,0),Color("#f0ebda"),2)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func draw_crate(at: Vector2) -> void:
	var box := Rect2(at-Vector2(21,45),Vector2(42,45))
	draw_rect(box,Color("#4c4940"))
	draw_rect(box,INK,false,3)
	for i in 4:
		line(box.position+Vector2(4,i*9+7),box.position+Vector2(38,i*9+7),DARK,2)
	line(box.position+Vector2(4,4),box.end-Vector2(4,4),INK,6)
	line(box.position+Vector2(38,4),box.position+Vector2(4,41),INK,6)
	draw_rect(Rect2(box.position+Vector2(2,2),Vector2(38,4)),EDGE)
	draw_circle(box.position+Vector2(20,22),4,BRASS,true,-1,true)

func draw_station(s: Dictionary,cam: float,on: bool) -> void:
	var p := Vector2(s.x-cam,s.y)
	var id := str(s.key).left(1)
	line(p+Vector2(-13,0),p+Vector2(-10,-49),INK,7)
	line(p+Vector2(14,0),p+Vector2(10,-49),INK,7)
	draw_rect(Rect2(p+Vector2(-21,-65),Vector2(42,28)),INK)
	draw_rect(Rect2(p+Vector2(-18,-62),Vector2(36,21)),Color("#4b514b"))
	var center := p+Vector2(0,-52)
	draw_arc(center,8,0,TAU,20,BRASS,2,true)
	for i in 3:
		line(center,center+Vector2.from_angle(i*TAU/3+(.8 if on else 0))*8,BRASS,1.5)
	line(p+Vector2(-13,-64),p+Vector2(-13,-87),INK,3)
	var lamp := p+Vector2(-13,-88)
	glow(lamp,20,.7 if on else 1.0+sin(age*3)*.35)
	draw_circle(lamp,3.5,PAPER if on else BRASS)
	# An attached transmission cable leads all the way to its gate.
	var gate := p+Vector2(94,0)
	draw_polyline(PackedVector2Array([p+Vector2(16,-46),p+Vector2(42,-38),gate+Vector2(0,-77)]),DARK,2,true)
	line(gate+Vector2(0,-113),gate+Vector2(0,-69),INK,5)
	var lift := 68.0 if on else 0.0
	for i in 4:
		line(gate+Vector2(i*6-9,-67-lift),gate+Vector2(i*6-9,-3-lift),INK,4)
	for v in [-57,-16]:
		line(gate+Vector2(-13,v-lift),gate+Vector2(13,v-lift),DARK,5)
	draw_string(MONO,p+Vector2(26,-7),id.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,11,EDGE)

func draw_exit(x: float,y: float,on: bool) -> void:
	line(Vector2(x,y),Vector2(x,y-82),INK,5)
	draw_rect(Rect2(x-17,y-76,43,21),DARK)
	line(Vector2(x-9,y-65),Vector2(x+15,y-65),BRASS if on else EDGE,2)
	line(Vector2(x+10,y-70),Vector2(x+15,y-65),BRASS if on else EDGE,2)
	line(Vector2(x+15,y-65),Vector2(x+10,y-60),BRASS if on else EDGE,2)

func draw_keeper(at: Vector2,facing: int,phase: float,on_ground: bool,speed: float) -> void:
	var walk := clampf(absf(speed)/110,0,1)
	var swing := sin(phase)*walk if on_ground else -.72
	var bob := absf(cos(phase))*walk*1.5 if on_ground else -1.0
	draw_set_transform(at+Vector2(0,-bob),0,Vector2(facing,1))
	for i in [-1,1]:
		var hip := Vector2(i*3,-19)
		var knee := Vector2(i*4+i*swing*4,-10-absf(swing)*1.2)
		var foot := Vector2(i*4+i*swing*8,-1-maxf(0,-i*swing)*3)
		line(hip,knee,INK,4)
		line(knee,foot,INK,3.4)
		line(foot,foot+Vector2(4,0),INK,3)
	poly([Vector2(-5,-33),Vector2(5,-33),Vector2(10,-18),Vector2(6,-15),Vector2(0,-17),Vector2(-10,-14),Vector2(-8,-25)],Color("#1b2b2c"))
	line(Vector2(-5,-31),Vector2(-9,-18),Color("#62706a"),1.3)
	poly([Vector2(-8,-34),Vector2(-6,-43),Vector2(-1,-48),Vector2(5,-46),Vector2(10,-39),Vector2(5,-38),Vector2(4,-32)],INK)
	line(Vector2(-6,-42),Vector2(-1,-47),EDGE,1)
	line(Vector2(6,-39),Vector2(3,-37),Color("#baaa85"),2)
	poly([Vector2(-5,-34),Vector2(5,-33),Vector2(-1,-29),Vector2(-5,-30),Vector2(-12-walk*3,-25+sin(age*4)*2)],Color("#9b744a"))
	var hand := Vector2(13+swing*1.8,-22)
	line(Vector2(3,-31),Vector2(7,-24),INK,3.5)
	line(Vector2(7,-24),hand,INK,3)
	var light := hand+Vector2(0,7)
	line(hand,light,INK,2)
	glow(light,29,1.0)
	draw_rect(Rect2(light-Vector2(3,4),Vector2(6,8)),INK)
	draw_rect(Rect2(light-Vector2(2,2),Vector2(4,5)),Color("#ffd291"))
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func draw_hauling_keeper(cam: float) -> void:
	var crate:Dictionary=route.freight[route.held_crate]
	var contact:=absf(float(crate.x)-route.pos.x)-21.0
	var pull:=route.hauling_back
	var reach:=Vector2(contact,-26 if pull else -30)
	var beat:=sin(route.stride)*clampf(absf(route.vel.x)/91,0,1)
	var hip:=Vector2(-3,-17+absf(beat))
	var shoulder:=hip+Vector2(-6 if pull else 9,-14)
	draw_set_transform(route.pos-Vector2(cam,0),0,Vector2(route.face,1))
	for side in [-1,1]:
		var foot:=Vector2(side*(8+beat*4),-maxf(0,side*beat*2))
		var knee:=(hip+foot)*.5+Vector2(4+side*2,-2)
		line(hip,knee,INK,5)
		line(knee,foot,INK,3.5)
		line(foot,foot+Vector2(4,0),INK,3)
	poly([shoulder+Vector2(-5,-2),shoulder+Vector2(5,-2),hip+Vector2(8,3),hip+Vector2(-8,4)],INK)
	line(shoulder+Vector2(-4,0),hip+Vector2(-7,2),EDGE,1.2)
	var head:=shoulder+Vector2(1,-6)
	poly([head+Vector2(-7,2),head+Vector2(-6,-7),head+Vector2(0,-11),head+Vector2(6,-8),
		head+Vector2(9,-3),head+Vector2(5,-2),head+Vector2(4,3)],INK)
	line(head+Vector2(-5,-7),head+Vector2(0,-10),EDGE,1.2)
	poly([shoulder+Vector2(-5,-1),shoulder+Vector2(5,0),shoulder+Vector2(-9,6)],Color("#9b744a"))
	for i in 2:
		var palm:=reach+Vector2(0,i*6)
		var elbow:=shoulder.lerp(palm,.48)+Vector2(-2 if not pull else 0,4 if not pull else 1)
		line(shoulder,elbow,DARK if i==0 else INK,4)
		line(elbow,palm,DARK if i==0 else INK,3)
		line(palm,palm+Vector2(1,3),EDGE,2)
	var lamp:=hip+Vector2(-7,6)
	glow(lamp,17,.7)
	draw_rect(Rect2(lamp-Vector2(2,3),Vector2(4,6)),BRASS)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func draw_ferry(p: Vector2) -> void:
	poly([p+Vector2(-39,-4),p+Vector2(41,-4),p+Vector2(31,4),p+Vector2(-27,5)],DARK)
	draw_rect(Rect2(p+Vector2(-21,-12),Vector2(40,9)),DARK)
	draw_rect(Rect2(p+Vector2(-5,-20),Vector2(7,9)),INK)
	for i in 5:
		draw_rect(Rect2(p+Vector2(-17+i*7,-10),Vector2(4,3)),BRASS)

func water(cam: float) -> void:
	var level := 449.0+sin(age*.53)*3
	if level>route.camera_y+545: return
	var points: Array = []
	for i in range(-1,51):
		points.append(Vector2(i*20.0,level+sin(i*.81+age*1.42+cam*.009)*2.1))
	points.append(Vector2(1000,540))
	points.append(Vector2(-20,540))
	poly(points,Color(.07,.14,.16,.84))
	for i in 40:
		var x := fposmod(i*127.41-cam*.7+age*(2+i%4),1050)-60
		var y := level+fposmod(i*31.76,82)
		line(Vector2(x,y),Vector2(x+10+i%29,y),Color(.69,.78,.74,.19 if i%3==0 else .09),1)

func atmosphere(cam: float) -> void:
	for j in 21:
		var x := fposmod(j*133.8-cam*.51+age*(3+j%5),1000)-18
		var y := fposmod(j*77.3-age*(.8+j%3),410)
		draw_circle(Vector2(x,y),1 if j%4 else 1.7,Color(.9,.88,.73,.2+.09*sin(age+j)))


func draw_device(d: Dictionary,cam: float) -> void:
	var p:=Vector2(d.x-cam,d.y)
	match d.type:
		"swarm":
			var insect:Vector2=d.flight-Vector2(cam,0)
			for j in 3:
				var body:=insect+Vector2(7*sin(age*4+j*2),6*cos(age*3+j*3))
				draw_circle(body,2,INK)
				line(body,body+Vector2(4,-3-2*sin(age*58)),PAPER,1)
				line(body,body+Vector2(-4,-4),EDGE,1)
		"spider":
			var body:=Vector2(float(d.dog)-cam,d.y-13)
			draw_circle(body,11,INK)
			draw_circle(body+Vector2(d.facing*11,2),7,DARK)
			for leg in 8:
				var side:=1 if leg>=4 else -1
				var knee:=body+Vector2(side*(13+3*(leg%4)),-7+2*(leg%4))
				line(body,knee,INK,2)
				line(knee,body+Vector2(side*(18+4*(leg%4))+3*sin(age*9+leg),13),INK,2)
			draw_circle(body+Vector2(d.facing*15,0),1.5,BRASS)
		"hound":
			var gate:=p+Vector2(8,0)
			poly([gate+Vector2(-22,0),gate+Vector2(-22,-31),gate+Vector2(-5,-46),gate+Vector2(24,-32),gate+Vector2(24,0)],DARK)
			draw_rect(Rect2(gate+Vector2(-12,-25),Vector2(25,25)),INK.darkened(.4))
			line(gate+Vector2(-24,-31),gate+Vector2(-5,-47),EDGE,2)
			var post:=Vector2(float(d.far_post)-cam,d.y)
			line(post,post+Vector2(0,-38),DARK,5)
			for band in [24,32]: line(post+Vector2(-3,-band),post+Vector2(3,-band-2),BRASS,2)
			var grate:=Vector2(float(d.limit)-cam,d.y)
			draw_rect(Rect2(grate-Vector2(23,3),Vector2(47,5)),DARK)
			for j in 7: line(grate+Vector2(-20+6*j,-3),grate+Vector2(-21+6*j,1),EDGE,1.5)

			var dog:=Vector2(float(d.dog)-cam,d.y)
			var run:=sin(route.time*18) if int(d.mode) in [2,4] else 0.0
			var crouch:=5.0 if int(d.mode) in [1,3] else 0.0
			draw_set_transform(dog+Vector2(0,crouch),0,Vector2(float(d.facing),1))
			poly([Vector2(-23,-14),Vector2(-16,-25),Vector2(0,-22),Vector2(10,-27),Vector2(16,-36),Vector2(17,-28),Vector2(24,-25),Vector2(31,-23),Vector2(28,-18),Vector2(18,-18),Vector2(10,-10),Vector2(-3,-12),Vector2(-16,-8)],INK)
			line(Vector2(-17,-21),Vector2(-32,-15+run*3),INK,5)
			line(Vector2(-32,-15+run*3),Vector2(-40,-20),INK,2)
			for j in 4:
				var hip:=Vector2(-16 if j<2 else 9,-15)
				var swing:=run*(1 if j%2==0 else -1)
				var knee:=hip+Vector2(-4+swing*9,7)
				line(hip,knee,INK,3)
				line(knee,knee+Vector2(4+swing*5,8-crouch),INK,2.5)
			draw_circle(Vector2(20,-24),1.7,BRASS)
			draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
			if d.mode==1:
				for j in 2: draw_arc(dog+Vector2(-28,-23),7+j*5,PI*.82,PI*1.18,8,BRASS,1.5,true)
		"rocker":
			poly([p+Vector2(-20,55),p+Vector2(0,7),p+Vector2(20,55)],INK)
			draw_circle(p+Vector2(0,7),7,DARK)
			draw_circle(p+Vector2(0,7),3,BRASS)
			line(p+Vector2(-103,-104*float(d.tilt)+9),p+Vector2(103,104*float(d.tilt)+9),DARK,4)
		"steam":
			if d.get("skin","")=="piston":
				var stroke:=1.0 if d.mode==2 else smoothstep(2.5,3.35,float(d.cycle))*.28
				var head:=p+Vector2(0,-112+108*stroke)
				line(p+Vector2(0,-164),head,EDGE,6)
				draw_rect(Rect2(head-Vector2(20,9),Vector2(40,10)),INK)
				draw_circle(p+Vector2(-27,-17),4,BRASS if d.mode else EDGE)
				return
			if d.get("skin","")=="wave":
				var height:=84.0 if d.mode==2 else (19.0 if d.mode==1 else 3.0)
				for j in 8:
					var crest:=p+Vector2((j-4)*4,-height*(.75+.22*sin(j*.6+age*5)))
					line(p+Vector2((j-4)*4,4),crest,Color(.35,.55,.56,.8),6)
					draw_circle(crest,3,PAPER)
				return
			draw_rect(Rect2(p-Vector2(24,3),Vector2(48,7)),DARK)
			for j in 7: line(p+Vector2(-20+j*6,-4),p+Vector2(-19+j*6,2),EDGE,2)
			var gauge:=p+Vector2(-34,-39)
			line(gauge,p+Vector2(-34,0),INK,4)
			draw_circle(gauge,9,DARK,true,-1,true)
			draw_arc(gauge,8,0,TAU,20,BRASS,1.5,true)
			line(gauge,gauge+Vector2.from_angle(-2.6+float(d.cycle)*.58)*6,PAPER,2)
			if d.mode>0:
				var jet:=int(d.mode)==2
				for j in 10:
					var t:=fposmod(route.time*(1.7 if jet else .9)+j*.108,1)
					var off:=sin(j*4+t*5)*(4+9*t)
					var center:=p+Vector2(off,-t*(107 if jet else 27))
					draw_circle(center,3+t*(18 if jet else 7),Color(.84,.88,.81,(1-t)*(.62 if jet else .35)),true,-1,true)
		"balance":
			var lit: bool=int(d.mode)==1
			draw_rect(Rect2(p+Vector2(-30,-4),Vector2(61,5)),BRASS if lit else EDGE)
			var pulley:=p+Vector2(91,-113)
			line(p+Vector2(0,3),pulley,DARK,2)
			line(pulley,pulley+Vector2(79,0),DARK,2)
			line(pulley+Vector2(79,0),pulley+Vector2(79,240-137*float(d.amount)),DARK,2)
			draw_arc(pulley,8,0,TAU,24,INK,3,true)
			draw_arc(pulley+Vector2(79,0),8,0,TAU,24,INK,3,true)
			draw_string(MONO,p+Vector2(-24,25),"BALLAST",HORIZONTAL_ALIGNMENT_LEFT,-1,12,PAPER)
		"lockpair":
			for j in 2:
				var amount:float=d.first if j==0 else d.second
				var x:=p.x+36+j*140
				var level:=p.y+124-amount*119
				draw_rect(Rect2(x,level,133,maxf(2,539-level)),Color(.13,.32,.34,.70))
				line(Vector2(x,level+1),Vector2(x+133,level+1),Color("#96aaa1"),2)
				line(Vector2(x+119,p.y-36),Vector2(x+119,501),DARK,5)
				for k in 8:
					line(Vector2(x+112,p.y-20+k*15),Vector2(x+120,p.y-20+k*15),BRASS,1.5)
				var value:=Vector2(x+104,p.y-43)
				draw_string(MONO,value,"I" if j==0 else "II",HORIZONTAL_ALIGNMENT_LEFT,-1,14,PAPER)
			draw_valve(p)
			draw_valve(Vector2(p.x+96,p.y+112-float(d.first)*124))
		"shutter":
			var raised:=float(d.amount)*77
			line(p+Vector2(-21,-133),p+Vector2(20,-133),INK,8)
			for k in 4:
				line(p+Vector2(k*7-11,-130),p+Vector2(k*7-11,-68-raised*.64),DARK,3)
			draw_rect(Rect2(p+Vector2(-15,-65-raised),Vector2(30,65)),INK)
			for k in 3:
				line(p+Vector2(-12,-26+k*8-raised),p+Vector2(12,-40+k*8-raised),Color("#af9666"),3)
			draw_circle(p+Vector2(0,-144),5,BRASS if d.amount>.65 else Color("#9b7850"),true,-1,true)

func draw_valve(p: Vector2) -> void:
	line(p,p+Vector2(0,-43),INK,5)
	var wheel:=p+Vector2(0,-43)
	draw_arc(wheel,12,0,TAU,30,INK,5,true)
	draw_arc(wheel,11,0,TAU,30,BRASS,2,true)
	for j in 3:
		line(wheel,wheel+Vector2.from_angle(j*TAU/3)*11,BRASS,1.7)
	draw_circle(wheel,3,INK)

func draw_dock_details(cam: float,chapter: int) -> void:
	for i in route.platforms.size():
		var deck:Dictionary=route.platforms[i]
		if deck.style not in ["dock","rail","stone"] or float(deck.w)<84: continue
		var x:=float(deck.pos.x)-cam+23
		var y:=float(deck.pos.y)
		if x< -210 or x>1000: continue
		var decor:=(i+route.room*7)%6
		if decor==0 or (chapter==0 and i==0):
			# A bollard, two turns of mooring line, and a sag between posts.
			for k in [0,59]:
				draw_rect(Rect2(x+k-3,y-28,7,28),DARK)
				draw_rect(Rect2(x+k-7,y-28,15,5),INK)
				for turn in 3: line(Vector2(x+k-4,y-19+turn*2),Vector2(x+k+5,y-18+turn*2),Color("#767565"),1)
			draw_polyline(PackedVector2Array([Vector2(x,y-19),Vector2(x+17,y-13),Vector2(x+34,y-12),Vector2(x+59,y-19)]),DARK,1.5,true)
		elif decor==1 and chapter in [1,3,5]:
			line(Vector2(x-15,y-9),Vector2(x+57,y-9),DARK,12)
			line(Vector2(x+54,y-9),Vector2(x+54,y-29),DARK,12)
			for k in range(0,50,15): line(Vector2(x+k,y-16),Vector2(x+k,y-2),EDGE,2)
		elif decor==2:
			line(Vector2(x,y),Vector2(x,y-53),DARK,3)
			draw_rect(Rect2(x-10,y-54,22,24),DARK)
			draw_string(MONO,Vector2(x-9,y-37),"%02d"%(route.room-Book.CHAPTER_STARTS[Book.chapter(route.room)]+1),HORIZONTAL_ALIGNMENT_CENTER,19,12,PAPER)
		elif decor==3 and chapter in [0,2]:
			var cone:=Vector2(x+10,y-21)
			draw_arc(cone,12,0,TAU,32,Color("#827e69"),4,true)
			for j in 4:
				draw_arc(cone,12,j*PI/2,j*PI/2+.33,6,PAPER,4,true)
			line(cone+Vector2(0,-13),cone+Vector2(0,-27),INK,2)
			line(cone+Vector2(-19,-28),cone+Vector2(6,-28),DARK,4)
			line(cone+Vector2(-17,-29),Vector2(x-7,y),DARK,4)

func draw_climber(cam: float) -> void:
	var foot:=route.pos-Vector2(cam,0)
	var edge:=route.ledge_anchor()-Vector2(cam,0)
	var side:=route.ledge_face
	var t:=clampf(route.pull_time/route.PULL_TIME,0,1)
	draw_set_transform(foot,0,Vector2(side,1))
	var hand:=Vector2((edge.x-foot.x)*side,edge.y-foot.y)
	var hip:=Vector2(-3-5*sin(t*PI),-14+4*sin(t*PI))
	var shoulder:=hip+Vector2(2,-14)
	var knee:=hip+Vector2(9+6*sin(t*PI),6)
	line(hip,knee,INK,5)
	line(knee,Vector2(0,-1),INK,4)
	line(hip,hip+Vector2(-6,11),DARK,4)
	line(hip+Vector2(-6,11),Vector2(-6,0),INK,3)
	poly([shoulder+Vector2(-5,-3),shoulder+Vector2(5,-1),hip+Vector2(8,3),hip+Vector2(-8,5)],INK)
	var head:=shoulder+Vector2(0,-7)
	poly([head+Vector2(-7,5),head+Vector2(-5,-5),head+Vector2(1,-9),head+Vector2(8,-2),head+Vector2(4,5)],INK)
	line(head+Vector2(-5,-5),head+Vector2(0,-8),EDGE,1)
	var elbow:=(shoulder+hand)*.5+Vector2(-5-5*sin(t*PI),2)
	line(shoulder,elbow,INK,4)
	line(elbow,hand,INK,3)
	line(hand,hand+Vector2(5,0),PAPER,2)
	var lamp:=hip+Vector2(-7,5)
	glow(lamp,18,.7)
	draw_rect(Rect2(lamp-Vector2(2,3),Vector2(4,6)),BRASS)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func draw_mount(foot: Vector2,kind: String,phase: float) -> void:
	if kind=="ride":
		poly([foot+Vector2(-24,-13),foot+Vector2(-15,-26),foot+Vector2(6,-24),foot+Vector2(17,-17),foot+Vector2(28,-13),foot+Vector2(26,-8),foot+Vector2(7,-7),foot+Vector2(-15,-6)],INK)
		for j in 4:
			var hip:=foot+Vector2(-15+j*8,-10)
			line(hip,hip+Vector2(4*sin(phase+j*2),10),INK,3)
		line(foot+Vector2(22,-11),foot+Vector2(28,-16),PAPER,2)
	else:
		draw_rect(Rect2(foot-Vector2(23,19),Vector2(46,12)),DARK)
		for j in [-15,15]: draw_circle(foot+Vector2(j,-4),5,INK)
