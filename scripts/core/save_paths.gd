class_name SavePaths
extends RefCounted
## 存档目录解析：优先「便携模式」（存档放在可执行文件旁），不可写时逐级回退。
## 之所以不直接用 user://：某些受限环境下系统用户目录不可写，会导致存档静默失败。

const FILE_NAME := "tuanzi_save.json"
const PROBE_NAME := ".tuanzi_write_probe"

static var _cached_dir := ""

## 返回一个确实可写的存档目录（带结尾斜杠）。
static func resolve_dir() -> String:
    if _cached_dir != "" and _is_writable(_cached_dir):
        return _cached_dir
    for d in _candidates():
        if d != "" and _is_writable(d):
            _cached_dir = d
            return d
    # 全部失败时退回 user://，让上层报错可见
    _cached_dir = "user://"
    return _cached_dir

static func save_path() -> String:
    return resolve_dir() + FILE_NAME

static func export_path() -> String:
    return resolve_dir() + "tuanzi_export.json"

static func _candidates() -> Array:
    var out: Array = []
    if OS.has_feature("template"):
        # 已导出：优先与 exe 同目录，方便整包拷走
        out.append(_exe_dir())
        out.append("user://")
    else:
        out.append("user://")
        out.append(_exe_dir())
    out.append(OS.get_temp_dir().replace("\\", "/") + "/")
    return out

static func _exe_dir() -> String:
    var exe := OS.get_executable_path()
    if exe == "":
        return ""
    var d := exe.get_base_dir()
    if d == "":
        return ""
    return d.replace("\\", "/") + "/"

## 真实写一个探针文件来确认可写，而不是只检查目录存在。
static func _is_writable(dir: String) -> bool:
    if dir == "":
        return false
    var probe := dir + PROBE_NAME
    var f := FileAccess.open(probe, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string("ok")
    f.close()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(probe))
    return true

## 供 UI 显示的存档位置说明。
static func describe() -> String:
    var d: String = resolve_dir()
    if d.begins_with("user://"):
        return "系统用户目录"
    var g: String = ProjectSettings.globalize_path(d)
    return g if g != "" else d
