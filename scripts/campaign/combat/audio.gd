extends Node
## One shared 0.1 s mono waveform, four voices, no imported sound dependency.
static var _thud: AudioStreamWAV
var voices: Array[AudioStreamPlayer] = []
func _ready() -> void:
	if DisplayServer.get_name()=="headless": return
	if _thud==null:
		_thud=AudioStreamWAV.new(); _thud.format=AudioStreamWAV.FORMAT_16_BITS; _thud.mix_rate=22050
		var pcm := PackedByteArray(); pcm.resize(4410)
		for i in 2205:
			var time := i/22050.0
			var sample := (sin(TAU*(115-400*time)*time)+0.2*sin(TAU*1100*time))*exp(-time*46)*0.38
			pcm.encode_s16(i*2,roundi(sample*32767))
		_thud.data=pcm
	for i in 4:
		var voice := AudioStreamPlayer.new(); voice.stream=_thud; voice.volume_db=-14; add_child(voice); voices.append(voice)
func thud() -> void:
	for voice in voices:
		if not voice.playing: voice.play(); return
