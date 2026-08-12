class_name AiStableValueEncoder
extends RefCounted

## AI 协议使用的稳定编码器。所有 Dictionary 递归按字符串键排序，避免
## 插入顺序、Object hash 或平台相关 hash 进入内容和状态指纹。

func canonicalize(value):
    if value is Dictionary:
        var result: Dictionary = {}
        var keys: Array[String] = []
        var values_by_key: Dictionary = {}
        for key in value:
            var stable_key := str(key)
            keys.append(stable_key)
            values_by_key[stable_key] = value[key]
        keys.sort()
        for key in keys:
            result[key] = canonicalize(values_by_key[key])
        return result
    if value is Array:
        var result: Array = []
        for item in value:
            result.append(canonicalize(item))
        return result
    if value is float:
        return 0.0 if is_zero_approx(value) else value
    return value

func encode(value) -> String:
    return JSON.stringify(canonicalize(value))

func sha256(value) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(encode(value).to_utf8_buffer())
    return context.finish().hex_encode()
