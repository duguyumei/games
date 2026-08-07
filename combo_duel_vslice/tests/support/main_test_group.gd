extends "res://tests/test_runner.gd"


func _run_group(group_name: String, test_methods: Array[String]) -> void:
    if not RuntimeProfileScript.current().is_test():
        push_error("自动化测试必须显式指定 --launch-mode=test")
        quit(2)
        return
    for method_name in test_methods:
        if not has_method(method_name):
            failures.append("测试分组 %s 引用了不存在的方法 %s" % [group_name, method_name])
            continue
        call(method_name)
    if failures.is_empty():
        print("TEST GROUP PASS [%s]: %d assertions" % [group_name, assertions])
        quit(0)
        return
    for failure in failures:
        push_error("TEST GROUP FAIL [%s]: %s" % [group_name, failure])
    print("TEST GROUP FAILURES [%s]: %d / %d assertions" % [
        group_name,
        failures.size(),
        assertions,
    ])
    quit(1)
