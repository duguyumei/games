class_name LocalizationTextFormatter
extends RefCounted

const MISSING_PARAMETER_TEMPLATE := "⟪%s?⟫"
const INVALID_PLACEHOLDER := "⟪invalid-placeholder⟫"


static func interpolate(template: String, parameters: Dictionary = {}) -> String:
    var output := ""
    var index := 0
    while index < template.length():
        var character := template.substr(index, 1)
        if character == "{" and index + 1 < template.length() \
                and template.substr(index + 1, 1) == "{":
            output += "{"
            index += 2
            continue
        if character == "}" and index + 1 < template.length() \
                and template.substr(index + 1, 1) == "}":
            output += "}"
            index += 2
            continue
        if character == "{":
            var closing := template.find("}", index + 1)
            if closing < 0:
                output += INVALID_PLACEHOLDER
                break
            var parameter_name := template.substr(index + 1, closing - index - 1)
            if not _is_valid_parameter_name(parameter_name):
                output += INVALID_PLACEHOLDER
            elif parameters.has(parameter_name):
                output += _parameter_text(parameters[parameter_name])
            else:
                output += MISSING_PARAMETER_TEMPLATE % parameter_name
            index = closing + 1
            continue
        if character == "}":
            output += INVALID_PLACEHOLDER
            index += 1
            continue
        output += character
        index += 1
    return output


static func inspect_placeholders(template: String) -> Dictionary:
    var names: Array[String] = []
    var errors: Array[String] = []
    var index := 0
    while index < template.length():
        var character := template.substr(index, 1)
        if character == "{" and index + 1 < template.length() \
                and template.substr(index + 1, 1) == "{":
            index += 2
            continue
        if character == "}" and index + 1 < template.length() \
                and template.substr(index + 1, 1) == "}":
            index += 2
            continue
        if character == "{":
            var closing := template.find("}", index + 1)
            if closing < 0:
                errors.append("存在未闭合的左花括号")
                break
            var parameter_name := template.substr(index + 1, closing - index - 1)
            if not _is_valid_parameter_name(parameter_name):
                errors.append("非法占位符 {%s}" % parameter_name)
            elif not names.has(parameter_name):
                names.append(parameter_name)
            index = closing + 1
            continue
        if character == "}":
            errors.append("存在未配对的右花括号")
        index += 1
    names.sort()
    return {"names": names, "errors": errors}


static func format_number(value: float, decimals: int = -1, locale: String = "zh_CN") -> String:
    var resolved_decimals := decimals
    if resolved_decimals < 0:
        resolved_decimals = 0 if is_equal_approx(value, round(value)) else 2
    resolved_decimals = clampi(resolved_decimals, 0, 6)
    var raw := ("%.*f" % [resolved_decimals, value])
    if decimals < 0 and raw.contains("."):
        raw = raw.rstrip("0").rstrip(".")
    var parts := raw.split(".")
    var integer_part: String = parts[0]
    var sign := ""
    if integer_part.begins_with("-"):
        sign = "-"
        integer_part = integer_part.substr(1)
    var grouped := ""
    for digit_index in integer_part.length():
        if digit_index > 0 and (integer_part.length() - digit_index) % 3 == 0:
            grouped += ","
        grouped += integer_part.substr(digit_index, 1)
    var decimal_separator := "." if locale in ["zh_CN", "en_US"] else "."
    if parts.size() > 1:
        return sign + grouped + decimal_separator + parts[1]
    return sign + grouped


static func format_percent(ratio: float, decimals: int = 0, locale: String = "zh_CN") -> String:
    return "%s%%" % format_number(ratio * 100.0, decimals, locale)


static func format_keyword(text: String, color: String = "#D6AA52") -> String:
    return "[color=%s][b]%s[/b][/color]" % [color, _escape_bbcode(text)]


static func format_tooltip(title: String, body: String) -> String:
    return "%s\n%s" % [title, body]


static func _is_valid_parameter_name(value: String) -> bool:
    if value.is_empty():
        return false
    var first := value.substr(0, 1)
    if not _is_ascii_letter(first) and first != "_":
        return false
    for index in range(1, value.length()):
        var character := value.substr(index, 1)
        if not _is_ascii_letter(character) and not character.is_valid_int() and character != "_":
            return false
    return true


static func _is_ascii_letter(value: String) -> bool:
    if value.is_empty():
        return false
    var code := value.unicode_at(0)
    return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


static func _escape_bbcode(value: String) -> String:
    return value.replace("[", "[lb]")


static func _parameter_text(value: Variant) -> String:
    if value is float and is_equal_approx(value, round(value)):
        return str(int(value))
    return str(value)
