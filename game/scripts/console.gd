extends "res://scripts/interface.gd"

const Instrument = preload("res://scripts/instrument.gd")
const Book = preload("res://scripts/campaign.gd")
signal closed
signal restored
signal mechanical(sound: String)
var model: Instrument
var origin := Vector2.ZERO
var tile := 44.0
var cursor := 0
var show_cursor := false
var hint_open := false
var status: Label
var step_label: Label
var restored_time := -1.0
var board_id := ""
var selection_text := ""
var aria: Label

func setup(spec: Dictionary, key: String, room: int, practice := false) -> void:
	model = Instrument.new(spec)
	board_id = key
	position = Vector2.ZERO
	size = Vector2(960,540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var left := 51.0
	var caption:="KEEPER’S LOG   /   PRACTICE" if practice else "%s   /   %s" % ["%02d" % (Book.chapter(room)+1),Book.ROOMS[room][0].to_upper()]
	label(self,Rect2(left,41,350,24),caption,MONO,13,BRASS)
	label(self,Rect2(left,85,340,68),Book.BOARD_TITLES[model.kind],SERIF,39)
	label(self,Rect2(left,164,302,100),Book.RULES[model.kind],ThemeDB.fallback_font,18,PAPER,true)
	aria = label(self,Rect2(left,283,298,81),Book.GESTURES[model.kind],ThemeDB.fallback_font,16,MUTE,true)
	step_label = label(self,Rect2(left,380,270,24),"",MONO,13,BRASS)
	button(self,Rect2(left,433,88,46),"Undo",undo)
	button(self,Rect2(left+99,433,90,46),"Reset",reset_board)
	button(self,Rect2(left+200,433,96,46),"Hint",toggle_hint)
	button(self,Rect2(802,31,99,44),"Close",func(): closed.emit())
	status = label(self,Rect2(404,468,478,37),"",MONO,13,BRASS,true)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bw := model.w if model.kind != "sluice" else model.vessels.size()
	var bh := model.h if model.kind != "sluice" else 3
	tile = minf(426.0/bw,333.0/bh)
	if model.kind=="weights": tile=86
	origin = Vector2(649.0-bw*tile*.5,271.0-bh*tile*.5)
	refresh()

func refresh() -> void:
	step_label.text = "%03d  /  MOVES" % model.moves
	if restored_time >= 0:
		status.text = "Transmission engaged"
	elif model.kind == "chart":
		status.text = "%d / %d buoys charted" % [model.tokens.size(),model.w*model.h-model.data.shoals.size()]
	elif model.kind == "relay":
		status.text = "%d / %d lamps lit" % [model.tokens.count(true),model.tokens.size()]
	elif model.kind == "weights":
		status.text = "%d / %d kg     %d / %d hooks" % [model.hanging_mass(),model.data.target,model.tokens.size(),model.data.hooks]
	elif model.kind == "sluice":
		status.text = "WATER LEVEL  /  TARGET MARK"
	elif model.kind == "pump":
		status.text = "%d / %d fittings under pressure" % [model.lit.size(),model.w*model.h]
	elif model.kind == "lens":
		var rings := 0
		for r in model.data.relays:
			if model.beam.has(int(r)): rings+=1
		status.text = "%d / %d rings illuminated" % [rings,model.data.relays.size()]
	else:
		status.text = "SLIPWAY  /  EAST EXIT" if model.kind == "slip" else "FREIGHT LINE  /  BALLAST RINGS"
	queue_redraw()

func moved(changed: bool) -> void:
	if changed:
		var sounds := {"chart":"glass","relay":"ratchet","weights":"crate","slip":"crate","freight":"crate","sluice":"flow","pump":"ratchet","lens":"glass"}
		mechanical.emit(sounds[model.kind])
		if model.solved():
			restored_time = 0.58
	refresh()

func reset_board() -> void:
	if restored_time >= 0: return
	model.reset()
	mechanical.emit("engage")
	refresh()

func undo() -> void:
	if restored_time >= 0: return
	model.undo()
	mechanical.emit("ratchet")
	refresh()

func toggle_hint() -> void:
	hint_open = not hint_open
	aria.text = Book.HINTS[model.kind] if hint_open else Book.GESTURES[model.kind]
	aria.add_theme_font_size_override("font_size",14 if hint_open else 16)

func _process(dt: float) -> void:
	if restored_time >= 0:
		restored_time -= dt
		if restored_time < 0:
			restored.emit()

func _gui_input(event: InputEvent) -> void:
	if restored_time >= 0 or not event is InputEventMouseButton: return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed: return
	var local: Vector2 = event.position-origin
	var gx := floori(local.x/tile)
	var gy := floori(local.y/tile)
	if model.kind == "sluice":
		if gx>=0 and gx<model.vessels.size() and gy>=0 and gy<3:
			cursor=gx
			moved(model.tap(cursor))
	elif gx>=0 and gx<model.w and gy>=0 and gy<model.h:
		cursor = gx+gy*model.w
		show_cursor = false
		moved(model.tap(cursor))
	accept_event()

func keyboard(key: int) -> bool:
	if restored_time >= 0: return true
	if key==KEY_Z: undo(); return true
	if key==KEY_R: reset_board(); return true
	if key==KEY_H: toggle_hint(); return true
	var dir := [KEY_UP,KEY_RIGHT,KEY_DOWN,KEY_LEFT].find(key)
	if dir >= 0:
		if model.kind == "freight":
			moved(model.walk(dir))
			cursor = model.worker
		elif model.kind=="sluice":
			cursor = clampi(cursor+(1 if dir in [1,2] else -1),0,model.vessels.size()-1)
		else:
			var next := model.neighbor(cursor,dir)
			if next >= 0: cursor=next
		show_cursor = true
		queue_redraw()
		return true
	if key in [KEY_ENTER,KEY_SPACE,KEY_E]:
		show_cursor = true
		moved(model.tap(cursor))
		return true
	return false

func center(i: int) -> Vector2:
	return origin+Vector2(i%model.w+.5,floori(float(i)/model.w)+.5)*tile

func _draw() -> void:
	if not model: return
	draw_rect(Rect2(0,0,960,540),Color("#122223ed"))
	draw_rect(Rect2(25,19,911,501),INK)
	draw_rect(Rect2(25,19,911,501),Color("#61716a"),false,1)
	draw_line(Vector2(377,92),Vector2(377,476),Color("#50605a"),1)
	for v in [Vector2(32,26),Vector2(926,26),Vector2(32,510),Vector2(926,510)]:
		draw_circle(v,2.1,Color("#a1a596"))
	if model.kind=="sluice":
		draw_sluice()
		return
	for i in model.w*model.h:
		var c := center(i)
		var cellrect := Rect2(c-Vector2.ONE*(tile*.5-1),Vector2.ONE*(tile-2))
		draw_rect(cellrect,Color("#253939") if (i%model.w+floori(float(i)/model.w))%2==0 else Color("#293d3c"))
		draw_circle(c,1,Color("#6c7d74"))
	match model.kind:
		"chart": draw_chart()
		"relay": draw_relays()
		"weights": draw_weights()
		"slip": draw_slip()
		"freight": draw_freight()
		"pump": draw_pipes()
		"lens": draw_lens()
	if show_cursor:
		draw_rect(Rect2(center(cursor)-Vector2.ONE*(tile*.5-3),Vector2.ONE*(tile-6)),PAPER,false,2)

func draw_sluice() -> void:
	for i in model.vessels.size():
		var cap := int(model.data.cap[i])
		var value := int(model.vessels[i])
		var target := int(model.data.goal[i])
		var x := origin.x+i*tile+10
		var y := origin.y+28
		var hgt := tile*2.2
		var width := tile-20
		var frame := Rect2(x,y,width,hgt)
		draw_rect(frame,Color("#2f4443"))
		var water := float(value)/cap*hgt
		draw_rect(Rect2(x+2,y+hgt-water,width-4,water),Color("#5d9998"))
		draw_rect(frame,BRASS if model.selected==i else MUTE,false,3)
		for j in range(1,cap):
			var yy := y+hgt-j*hgt/cap
			draw_line(Vector2(x+3,yy),Vector2(x+width*.19,yy),MUTE,1)
		var target_y := y+hgt-hgt*target/cap
		draw_line(Vector2(x-5,target_y),Vector2(x+width+5,target_y),BRASS,3)
		draw_string(MONO,Vector2(x,y-9),String.chr(65+i),HORIZONTAL_ALIGNMENT_CENTER,width,16,BRASS)
		draw_string(MONO,Vector2(x,y+hgt+27),"%d / %d" % [value,target],HORIZONTAL_ALIGNMENT_CENTER,width,16,PAPER)
		draw_string(MONO,Vector2(x,y+hgt+46),"CAP %d" % cap,HORIZONTAL_ALIGNMENT_CENTER,width,12,MUTE)
		if show_cursor and cursor==i: draw_rect(frame.grow(5),PAPER,false,1)

func draw_slip() -> void:
	for i in model.pieces.size():
		var item: Array = model.pieces[i]
		var horizontal := int(item[1])==1
		var n := int(item[2])
		var head := center(int(item[0]))
		var dims := Vector2(n*tile-8,tile*.69) if horizontal else Vector2(tile*.69,n*tile-8)
		var middle := head+(Vector2.RIGHT if horizontal else Vector2.DOWN)*(n-1)*tile*.5
		var rect0 := Rect2(middle-dims*.5,dims)
		var hull := BRASS if i==0 else Color("#70817b")
		draw_rect(rect0,hull)
		draw_rect(rect0.grow(-4),INK,false,1)
		var perp := Vector2.DOWN if horizontal else Vector2.RIGHT
		var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
		for j in n:
			var c := head+axis*j*tile
			draw_line(c-perp*tile*.2,c+perp*tile*.2,INK,3)
			draw_circle(c,3,PAPER)
		if model.selected==i: draw_rect(rect0.grow(2),PAPER,false,2)
	if model.selected>=0:
		for cell in model.slip_stops(model.selected):
			draw_circle(center(cell),tile*.14,BRASS,false,2,true)
	var exit := center(17)+Vector2(tile*.57,0)
	draw_colored_polygon(PackedVector2Array([exit+Vector2(0,-7),exit+Vector2(10,0),exit+Vector2(0,7)]),BRASS)

func draw_freight() -> void:
	for i in model.data.walls:
		var r := Rect2(center(i)-Vector2.ONE*(tile*.5-1),Vector2.ONE*(tile-2))
		draw_rect(r,Color("#121f21"))
		draw_line(r.position+Vector2(2,4),r.position+Vector2(r.size.x-2,4),Color("#52645e"),2)
	for i in model.data.targets:
		draw_arc(center(i),tile*.30,0,TAU,28,BRASS,3,true)
		draw_arc(center(i),tile*.20,0,TAU,24,BRASS,1,true)
	for i in model.boxes:
		var r := Rect2(center(i)-Vector2.ONE*tile*.33,Vector2.ONE*tile*.66)
		draw_rect(r,BRASS if model.data.targets.has(i) else Color("#9b9680"))
		draw_rect(r.grow(-3),INK,false,2)
		draw_line(r.position+Vector2.ONE*5,r.end-Vector2.ONE*5,INK,3)
		draw_line(r.position+Vector2(r.size.x-5,5),r.end-Vector2(r.size.x-5,5),INK,3)
	var p := center(model.worker)
	draw_circle(p,tile*.24,PAPER,true,-1,true)
	draw_circle(p,tile*.14,DARK_CARRIAGE,true,-1,true)
	draw_circle(p,2.5,BRASS)
const DARK_CARRIAGE := Color("#334e50")

func draw_pipes() -> void:
	for i in model.w*model.h:
		var c := center(i)
		var color := BRASS if model.lit.has(i) else Color("#94aaa3")
		var mask := int(model.pipes[i])
		for d in 4:
			if mask & (1<<d):
				var end := c+Vector2(Instrument.DIRS[d])*tile*.5
				draw_line(c,end,INK,tile*.22)
				draw_line(c,end,color,tile*.12)
		draw_circle(c,tile*.13,color,true,-1,true)
		draw_circle(c,tile*.066,INK,true,-1,true)
		if i==int(model.data.source):
			draw_arc(c,tile*.3,0,TAU,28,BRASS,2,true)

func draw_lens() -> void:
	var src := center(int(model.data.entry))-Vector2(tile*.47,0)
	var dst := center(int(model.data.target))+Vector2(tile*.48,0)
	draw_circle(src,6,BRASS)
	draw_arc(dst,7,0,TAU,20,BRASS,2,true)
	var prev := src
	for n in model.beam:
		if int(n)<0: break
		var at := center(n)
		draw_line(prev,at,Color(1,.8,.43,.18),8,true)
		draw_line(prev,at,BRASS,2.5,true)
		prev = at
	if model.reached_exit: draw_line(prev,dst,BRASS,3,true)
	for i in model.data.relays:
		draw_arc(center(i),tile*.22,0,TAU,24,BRASS if model.beam.has(int(i)) else MUTE,3,true)
	for cell in model.mirrors:
		var at := center(cell)
		var diagonal := Vector2(.28,-.28 if int(model.mirrors[cell])==0 else .28)*tile
		draw_line(at-diagonal,at+diagonal,INK,8,true)
		draw_line(at-diagonal,at+diagonal,PAPER,3,true)
		draw_circle(at,2,BRASS)

func draw_chart() -> void:
	for i in model.w*model.h:
		var p:=center(i)
		if model.data.shoals.has(i):
			for n in 3:
				draw_line(p+Vector2(-20+n*9,10),p+Vector2(-5+n*9,-10),MUTE,2,true)
		else:
			draw_arc(p,tile*.12,0,TAU,22,BRASS if i in model.tokens else MUTE,2,true)
	for j in range(1,model.tokens.size()):
		draw_line(center(model.tokens[j-1]),center(model.tokens[j]),BRASS,3,true)
	draw_circle(center(model.tokens.back()),6,BRASS,true,-1,true)
	var flag:=center(int(model.data.harbor))
	draw_line(flag,flag+Vector2(0,-23),PAPER,2,true)
	draw_colored_polygon(PackedVector2Array([flag+Vector2(0,-23),flag+Vector2(14,-19),flag+Vector2(0,-14)]),PAPER)

func draw_relays() -> void:
	for i in model.w*model.h:
		var p:=center(i)
		for d in [1,2]:
			var n:=model.neighbor(i,d)
			if n>=0: draw_line(p,center(n),Color("#61716a"),2,true)
	for i in model.w*model.h:
		var p:=center(i)
		draw_circle(p,tile*.24,INK,true,-1,true)
		draw_circle(p,tile*.17,BRASS if model.tokens[i] else Color("#586763"),true,-1,true)
		if model.tokens[i]: draw_line(p+Vector2(-4,-5),p+Vector2(4,-5),PAPER,2,true)

func draw_weights() -> void:
	var pivot:=Vector2(649,143)
	var angle:=clampf(float(model.hanging_mass()-int(model.data.target))*.022,-.2,.2)
	var bar:=Vector2.from_angle(angle)*100
	draw_line(pivot-bar,pivot+bar,BRASS,5,true)
	draw_circle(pivot,6,PAPER,true,-1,true)
	for arm in [-1,1]:
		var end:Vector2=pivot+bar*float(arm)
		draw_polyline(PackedVector2Array([end+Vector2(-18,20),end,end+Vector2(18,20),end+Vector2(-18,20)]),MUTE,2,true)
	for i in model.w*model.h:
		var p:=center(i)
		var color:=BRASS if i in model.tokens else MUTE
		draw_arc(p-Vector2(0,10),9,PI,TAU,14,color,3,true)
		draw_rect(Rect2(p-Vector2(23,9),Vector2(46,30)),color)
		draw_string(MONO,p+Vector2(-22,13),str(model.data.weights[i]),HORIZONTAL_ALIGNMENT_CENTER,44,19,INK)
