class_name Sfx
extends Node
## 程序化音效：运行时合成 PCM 波形，不加载任何音频文件。
## 音效本身是「数据 + 合成」，因此可被无头自检断言。

const SAMPLE_RATE := 22050
const MAX_VOICES := 6

## 音效定义：频率、时长、波形、音量
const KINDS := {
    "blip":    { "freq": 660.0, "dur": 0.07, "wave": "sine",     "vol": 0.25 },
    "select":  { "freq": 880.0, "dur": 0.05, "wave": "sine",     "vol": 0.22 },
    "hit":     { "freq": 180.0, "dur": 0.14, "wave": "square",   "vol": 0.20 },
    "crit":    { "freq": 240.0, "dur": 0.18, "wave": "saw",      "vol": 0.24 },
    "heal":    { "freq": 700.0, "dur": 0.22, "wave": "sine",     "vol": 0.22, "slide": 420.0 },
    "capture": { "freq": 520.0, "dur": 0.26, "wave": "triangle", "vol": 0.22, "slide": 260.0 },
    "win":     { "freq": 620.0, "dur": 0.42, "wave": "sine",     "vol": 0.26, "slide": 760.0 },
    "lose":    { "freq": 300.0, "dur": 0.44, "wave": "triangle", "vol": 0.24, "slide": 160.0 },
    "step":    { "freq": 220.0, "dur": 0.04, "wave": "sine",     "vol": 0.12 },
}

var enabled := true
var _players: Array = []
var _next := 0

func _ready() -> void:
    for i in MAX_VOICES:
        var p := AudioStreamPlayer.new()
        add_child(p)
        _players.append(p)

## 合成一段 16-bit 单声道 PCM。
## wave: sine / square / saw / triangle；slide 为结束频率（线性滑音）。
static func build_pcm(dur: float, freq: float, vol: float,
        wave: String = "sine", slide: float = 0.0) -> PackedByteArray:
    var n := int(maxf(0.0, dur) * SAMPLE_RATE)
    var data := PackedByteArray()
    data.resize(n * 2)
    var f_end := slide if slide > 0.0 else freq
    for i in n:
        var t := float(i) / float(SAMPLE_RATE)
        var prog := float(i) / maxf(1.0, float(n))
        var f := lerpf(freq, f_end, prog)
        var phase := TAU * f * t
        var s := 0.0
        match wave:
            "square":   s = 1.0 if sin(phase) >= 0.0 else -1.0
            "saw":      s = 2.0 * (prog - floorf(prog + 0.5))
            "triangle": s = 2.0 * absf(2.0 * (prog - floorf(prog + 0.5))) - 1.0
            _:          s = sin(phase)
        # 起音与收尾包络，避免爆音
        var env := minf(1.0, prog * 12.0) * minf(1.0, (1.0 - prog) * 5.0)
        var v := int(clampf(s * vol * env, -1.0, 1.0) * 32767.0)
        data.encode_s16(i * 2, v)
    return data

## 便捷：直接得到某音效的字节长度（供测试使用）。
static func tone_bytes(kind: String, dur: float, freq: float) -> int:
    var k: Dictionary = KINDS.get(kind, KINDS["blip"])
    return build_pcm(dur, freq, float(k["vol"]), String(k["wave"])).size()

func play(kind: String) -> void:
    if not enabled or not KINDS.has(kind):
        return
    if _players.is_empty():
        return
    var k: Dictionary = KINDS[kind]
    var pcm := build_pcm(float(k["dur"]), float(k["freq"]), float(k["vol"]),
        String(k["wave"]), float(k.get("slide", 0.0)))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SAMPLE_RATE
    stream.stereo = false
    stream.data = pcm
    var p: AudioStreamPlayer = _players[_next]
    _next = (_next + 1) % _players.size()
    p.stream = stream
    p.play()

func set_enabled(on: bool) -> void:
    enabled = on
