extends "res://scripts/interface.gd"

const Book = preload("res://scripts/campaign.gd")
const Passage = preload("res://scripts/passage.gd")
var route: Passage
var screen := "menu"
var age := 0.0
var intro := 0.0
var fade := 0.0
var notice := ""
var actions: Array = []
var touched: Array = []
var touch_device := false
var button_scale := 1.0
const SKIP_SCENE_RECT := Rect2(822,14,45,43)
var scene_skip_enabled := false
var replay := false
var title_gradient: GradientTexture2D
var header_gradient: GradientTexture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size=Vector2(960,540)
	title_gradient = fade_texture(Color(.035,.075,.085,.95),Color(.04,.08,.09,0),Vector2(.80,.5))
	header_gradient = fade_texture(Color(.035,.075,.085,.8),Color(.04,.08,.09,0),Vector2(.5,1))

func fade_texture(start: Color,end: Color,finish: Vector2) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([start,end])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0,.5) if finish.x!=.5 else Vector2(.5,0)
	texture.fill_to = finish
	return texture

func zones() -> Dictionary:
	var y:=540-24-42*button_scale
	return {"left":Vector2(32+42*button_scale,y),"right":Vector2(32+127*button_scale,y),
		"use":Vector2(960-34-139*button_scale,y),"jump":Vector2(960-34-44*button_scale,y-13*button_scale)}

func zone_at(p: Vector2) -> String:
	if scene_skip_enabled and SKIP_SCENE_RECT.has_point(p): return "skip_scene"
	for key in zones():
		if p.distance_to(zones()[key]) <= button_scale*(44 if key=="jump" else 40): return key
	if Rect2(869,12,69,56).has_point(p): return "pause"
	return ""

func _draw() -> void:
	match screen:
		"menu":
			draw_texture_rect(title_gradient,Rect2(0,0,960,540),false)
			draw_line(Vector2(52,119),Vector2(117,119),BRASS,2)
		"pause","chapters","settings","credits","confirm","licenses","workshop","support":
			draw_rect(Rect2(0,0,960,540),Color(.035,.075,.085,.56 if screen=="pause" else .91))
		"play":
			if not route: return
			draw_texture_rect(header_gradient,Rect2(0,0,960,111),false)
			draw_string(MONO,Vector2(29,30),Book.chapter_label(route.room),HORIZONTAL_ALIGNMENT_LEFT,-1,13,BRASS)
			draw_string(SERIF,Vector2(28,62),Book.ROOMS[route.room][0],HORIZONTAL_ALIGNMENT_LEFT,-1,29,PAPER)
			var pause_rect := Rect2(881,14,45,43)
			draw_rect(pause_rect,Color(.06,.11,.12,.58))
			for x in [898,906]:
				draw_line(Vector2(x,27),Vector2(x,45),PAPER,3,true)
			if scene_skip_enabled:
				draw_rect(SKIP_SCENE_RECT,Color(.06,.11,.12,.70))
				draw_rect(SKIP_SCENE_RECT,BRASS,false,1)
				var center := SKIP_SCENE_RECT.get_center()
				for x in [-11,-3]:
					var start := center+Vector2(x,0)
					draw_colored_polygon(PackedVector2Array([start+Vector2(0,-7),start+Vector2(8,0),start+Vector2(0,7)]),BRASS)
				draw_line(center+Vector2(9,-7),center+Vector2(9,7),BRASS,2,true)
			draw_controls()
			if intro>0:
				var alpha := minf(1.0,intro)
				var width0 := minf(690,SERIF.get_string_size(notice,HORIZONTAL_ALIGNMENT_LEFT,-1,23).x+42)
				draw_rect(Rect2((960-width0)/2,88,width0,40),Color(.06,.12,.13,.83*alpha))
				draw_string(SERIF,Vector2((960-width0)/2,115),notice,HORIZONTAL_ALIGNMENT_CENTER,width0,23,Color(PAPER,alpha))
			if route.death_timer>0:
				draw_rect(Rect2(0,0,960,540),Color(.04,.09,.11,clampf(route.death_timer*.9,0,.5)))
			var context := ""
			var gate:=route.nearby_key_gate()
			if route.ladder>=0:
				context="Up / Down to climb · Hand to let go" if touch_device else "W / S to climb · E to let go"
			elif gate>=0:
				context=("Hand to unlock" if touch_device else "E to unlock") if route.key_gates[gate].key_taken else "The key is below the catwalk"
			elif route.nearby_ladder()>=0:
				context="Hand to grab the ladder" if touch_device else "E to grab the ladder"
			elif route.ledge>=0 and route.pull_time<0:
				context="Hold toward the ledge to climb"
			elif route.ledge<0 and route.room==0 and route.pos.x>315 and route.pos.x<407:
				context="Jump toward the high quay"
			elif route.near_station>=0:
				context="Operate" if touch_device else "E   /   Operate"
			elif route.near_valve>=0:
				context=route.valve_action if touch_device else "E   /   "+route.valve_action
			elif route.chamber_jump:
				context="Jump to chamber II"
			elif route.mounted=="ride" and route.pos.x<560:
				context="Left slows the boar. Right speeds it up. Jump the gaps."
			elif route.near_crate:
				context="Hold the hand + move" if touch_device else "Hold E + move to shift cargo"
			elif route.room==0 and route.pos.x<230:
				context="Move and jump across the dock" if touch_device else "A D   move     Space   jump     E   use"
			if not context.is_empty():
				var length0:=MONO.get_string_size(context,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+32
				draw_rect(Rect2((960-length0)/2,456,length0,38),Color(.06,.12,.13,.87))
				draw_string(MONO,Vector2((960-length0)/2,481),context,HORIZONTAL_ALIGNMENT_CENTER,length0,15,PAPER)
			if fade>0: draw_rect(Rect2(0,0,960,540),Color(.035,.07,.08,minf(.9,fade*2.1)))
		"aim","arrival":
			draw_texture_rect(header_gradient,Rect2(0,0,960,125),false)
			draw_string(MONO,Vector2(35,37),Book.chapter_label(Book.ROOMS.size()-1),HORIZONTAL_ALIGNMENT_LEFT,-1,14,BRASS)
			draw_string(SERIF,Vector2(34,79),"Light the fairway" if screen=="aim" else "The ferry answers.",HORIZONTAL_ALIGNMENT_LEFT,-1,38,PAPER)
		"final":
			draw_texture_rect(title_gradient,Rect2(0,0,960,540),false)

func draw_controls() -> void:
	var usable:=route.near_station>=0 or route.near_valve>=0 or route.nearby_ladder()>=0 or route.nearby_key_gate()>=0
	for key in zones():
		var p:Vector2=zones()[key]
		var rotation0:=-PI*.5 if route.ladder>=0 and key in ["left","right"] else 0.0
		draw_set_transform(p,rotation0,Vector2.ONE*button_scale)
		p=Vector2.ZERO
		var radius := 36 if key=="jump" else 31
		var lit: bool = key in touched or (key=="use" and usable)
		var ink := BRASS if lit else PAPER
		draw_circle(p,radius,Color(.055,.10,.115,.78 if lit else .55),true,-1,true)
		draw_arc(p,radius,0,TAU,60,Color(ink,.9 if lit else .61),1.5,true)
		match key:
			"left","right":
				var flip := 1 if key=="right" else -1
				draw_polyline(PackedVector2Array([p+Vector2(-5*flip,-10),p+Vector2(6*flip,0),p+Vector2(-5*flip,10)]),ink,3,true)
			"jump":
				draw_line(p+Vector2(0,11),p+Vector2(0,-11),ink,2.5,true)
				draw_polyline(PackedVector2Array([p+Vector2(-9,-3),p+Vector2(0,-12),p+Vector2(9,-3)]),ink,2.5,true)
			"use":
				draw_polyline(PackedVector2Array([p+Vector2(-9,1),p+Vector2(-3,5),p+Vector2(-4,-12),p+Vector2(0,-13),p+Vector2(2,-3),p+Vector2(3,-8),p+Vector2(7,-8),p+Vector2(8,-5),p+Vector2(12,-5),p+Vector2(12,4),p+Vector2(7,12),p+Vector2(-1,12),p+Vector2(-10,4),p+Vector2(-9,1)]),ink,1.8,true)
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
