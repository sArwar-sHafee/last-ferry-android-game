extends Node

var accent := AudioStreamPlayer.new()
var cooldown := 0.0
var amb := AudioStreamPlayer.new()
var story := AudioStreamPlayer.new()
var swarm_buzz := AudioStreamPlayer.new()
var layers: Array[AudioStreamPlayer] = []
var cursor := 0
var alternate_monkey_call := false
var ambience := ""
var enabled := true
var samples := {}
const NAMES := [
	"estuary","pumphall","lantern","step","step_wood","step_grass","step_stone",
	"step_clay","step_glass","step_soft","land","engage","splash","impact","ratchet",
	"glass","flow","crate","save","signal","homecoming","pursuit","undertow","bark",
	"monkey_call","monkey_call_alt","elephant_call","rock_throw","gorilla_intro","boar_call","thunder","thunder_distant",
]

func _ready() -> void:
	for key in NAMES:
		samples[key]=load("res://audio/%s.ogg" % key)
	add_child(accent)
	accent.volume_db=-5
	add_child(story)
	story.stream=preload("res://audio/story.ogg")
	add_child(swarm_buzz)
	var buzz: AudioStreamOggVorbis=preload("res://audio/swarm_buzz.ogg")
	buzz.loop=true
	swarm_buzz.stream=buzz
	add_child(amb)
	amb.volume_db = -4
	for i in 6:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		layers.append(voice)

func surround(chapter: int) -> void:
	var choice := "reach%02d" % chapter
	if not samples.has(choice): samples[choice]=load("res://audio/%s.ogg" % choice)
	if choice == ambience and amb.playing: return
	ambience = choice
	var stream := samples[choice] as AudioStreamOggVorbis
	stream.loop = true
	amb.stream = stream
	if enabled: amb.play()

func set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		accent.stop()
		story.stop()
		amb.stop()
		swarm_buzz.stop()
		for voice in layers: voice.stop()
	elif amb.stream != null:
		amb.play()

func play_story(seconds: float) -> void:
	story.stop()
	if not enabled or seconds<=0: return
	story.volume_db=-9
	story.play()

func fade_story(seconds: float) -> void:
	var level:=minf(seconds,1.0) if story.playing else 0.0
	amb.volume_db=lerpf(-4,-9,level)
	if not story.playing: return
	if level<=0:
		story.stop()
	else:
		story.volume_db=-9+linear_to_db(level)

func cue(key: String) -> void:
	if not enabled or not samples.has(key): return
	var voice := layers[cursor]
	cursor = (cursor+1)%layers.size()
	if key=="monkey_call":
		voice.stream=samples["monkey_call_alt" if alternate_monkey_call else "monkey_call"]
		alternate_monkey_call=not alternate_monkey_call
	else:
		voice.stream=samples[key]
	var stepping:=key.begins_with("step")
	voice.pitch_scale = randf_range(.89,1.1) if stepping or key in ["land","ratchet","crate"] else 1.0
	match key:
		"splash": voice.volume_db=-10
		"land": voice.volume_db=-5
		"impact": voice.volume_db=6+linear_to_db(2.0)
		"monkey_call": voice.volume_db=2
		"rock_throw": voice.volume_db=-6
		"boar_call","gorilla_intro","elephant_call": voice.volume_db=-1
		_: voice.volume_db=-11 if stepping else 0
	voice.play()

func update_swarm(distance: float) -> void:
	if not enabled or distance>=365:
		if swarm_buzz.playing: swarm_buzz.stop()
		return
	swarm_buzz.volume_db=lerpf(5,-13,smoothstep(18,365,distance))
	if not swarm_buzz.playing: swarm_buzz.play()

func tick(dt: float) -> void:
	cooldown=maxf(0,cooldown-dt)

func score(key: String) -> void:
	if not enabled or cooldown>0 or accent.playing: return
	accent.stream=samples[key]
	accent.stream_paused=false
	accent.play()
	cooldown=82.0
