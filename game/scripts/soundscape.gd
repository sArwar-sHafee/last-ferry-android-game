extends Node

var accent := AudioStreamPlayer.new()
var cooldown := 0.0
var amb := AudioStreamPlayer.new()
var layers: Array[AudioStreamPlayer] = []
var cursor := 0
var ambience := ""
var enabled := true
var samples := {}
const NAMES := ["estuary","pumphall","lantern","step","land","engage","splash","ratchet","glass","flow","crate","save","signal","homecoming","pursuit","undertow","bark"]

func _ready() -> void:
	for key in NAMES:
		samples[key]=load("res://audio/%s.ogg" % key)
	add_child(accent)
	accent.volume_db=-5
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
		amb.stop()
		for voice in layers: voice.stop()
	elif amb.stream != null:
		amb.play()

func cue(key: String) -> void:
	if not enabled or not samples.has(key): return
	var voice := layers[cursor]
	cursor = (cursor+1)%layers.size()
	voice.stream = samples[key]
	voice.pitch_scale = randf_range(.89,1.1) if key in ["step","land","ratchet","crate"] else 1.0
	voice.volume_db = -11 if key=="step" else (-5 if key=="land" else 0)
	voice.play()

func tick(dt: float) -> void:
	cooldown=maxf(0,cooldown-dt)

func score(key: String) -> void:
	if not enabled or cooldown>0 or accent.playing: return
	accent.stream=samples[key]
	accent.stream_paused=false
	accent.play()
	cooldown=82.0
