#!/usr/bin/env bash
# 一键验证（《禁地牌局》架构升级安全网）。
# 步骤：import 缓存 → GUT 单元测试 → 四场景冒烟（计脚本错误）→ 四个行为预览。
# 用法：
#   bash tools/run_checks.sh          # 全套
#   bash tools/run_checks.sh quick    # 跳过 import（未新增 class_name/资源时用）
#   GODOT_BIN=... bash tools/run_checks.sh   # 指定 Godot 可执行文件
#
# 冒烟会开新局并写 expedition_save.json（原型期允许覆盖）。
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$ROOT"

fails=()
step() { printf '\n===== %s =====\n' "$1"; }

# 限时执行（看门狗，2026-09-17）：$1=秒数，其余=命令；超时强杀按 137 记败。
# 动机：预览脚本解析失败/不退出时 Godot 会无限运行（两次套件挂死的根源）——超时兜底，
# 坏档当轮就红，不再挂着等人发现。
run_with_timeout() {
	local secs=$1; shift
	"$@" &
	local pid=$!
	( sleep "$secs"; kill -9 "$pid" 2>/dev/null ) &
	local wpid=$!
	wait "$pid"
	local rc=$?
	kill "$wpid" 2>/dev/null
	wait "$wpid" 2>/dev/null
	return $rc
}

# 运行时错误计数（2026-09-17 审计项：冒烟曾对 "Can't add child" 类静默失败全绿）。
# 排除已知的良性尾部错误（退出期资源/泄漏诊断类），其余 ERROR: 一律记败。
count_runtime_errors() {
	grep "^ERROR:" "$1" 2>/dev/null \
		| grep -v "resources still in use" \
		| grep -v "RID allocations of type" \
		| grep -v "at: clear (core/io/resource" \
		| grep -v "at: cleanup (core/object" \
		| grep -v "at: _load (core/io/resource_loader" \
		| wc -l | tr -d ' '
}

# ---------- 用户存档：不保护，冒烟新局可直接覆盖（原型期存档即弃） ----------

# ---------- 1) 导入缓存（新 class_name/场景必须先过这步，headless 脚本才能解析） ----------
if [ "${1:-}" != "quick" ]; then
	step "import"
	if run_with_timeout 300 "$GODOT" --headless --path . --import > /tmp/rc_import.log 2>&1; then
		echo "import OK"
	else
		fails+=("import(rc=$?)")
		tail -5 /tmp/rc_import.log
	fi
fi

# ---------- 2) GUT 单元测试 ----------
step "GUT tests"
run_with_timeout 900 "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit > /tmp/rc_gut.log 2>&1
gut_rc=$?
grep -E "Tests?[ :].*(pass|fail)|passed|failed" /tmp/rc_gut.log | tail -3
if [ $gut_rc -ne 0 ]; then
	fails+=("GUT(rc=$gut_rc)")
	tail -15 /tmp/rc_gut.log
fi

# ---------- 3) 场景冒烟：能起、能跑、零脚本错误 ----------
step "scene smoke"
for scene in title dojo codex battle mahjong_battle challenge/deck_select challenge/challenge_hub challenge/settlement challenge/xiuxi; do
	local_name="${scene##*/}"
	# 挑战层四屏是平铺的（scenes/challenge/xxx.tscn）；旧模板曾拼出不存在的嵌套路径
	# ——四屏冒烟一直空跑白绿（2026-09-17 运行时闸抓出的存量洞，本轮修）。
	if [[ "$scene" == */* ]]; then
		path="scenes/$scene.tscn"
	else
		path="scenes/$scene/${local_name}.tscn"
	fi
	run_with_timeout 120 "$GODOT" --headless --path . "res://$path" --quit-after 60 > "/tmp/rc_${local_name}.log" 2>&1
	rc=$?
	errs=$(grep -c "SCRIPT ERROR" "/tmp/rc_${local_name}.log" || true)
	rterr=$(count_runtime_errors "/tmp/rc_${local_name}.log")
	echo "${local_name}.tscn  script_errors=$errs runtime_errors=$rterr rc=$rc"
	if [ "$errs" -ne 0 ] || [ $rc -ne 0 ] || [ "$rterr" -ne 0 ]; then
		fails+=("$scene-smoke(rc=$rc,rterr=$rterr)")
		grep -m 3 "SCRIPT ERROR" "/tmp/rc_${local_name}.log"
	fi
done

# ---------- 4) 行为预览（自校验，退出码即结论） ----------
step "behavior previews"
for pv in m7_click_check m7c_check m7_end_check m8_topbar_check m12_mahjong_sim m13_ui_autoplay m14_run_sim; do
	run_with_timeout 300 "$GODOT" --headless --path . "res://previews/$pv.tscn" > "/tmp/rc_$pv.log" 2>&1
	rc=$?
	rterr=$(count_runtime_errors "/tmp/rc_$pv.log")
	if [ $rc -eq 137 ]; then
		echo "$pv  TIMEOUT(300s)"
	elif [ $rc -ne 0 ]; then
		echo "$pv  exit=$rc"
	else
		echo "$pv  exit=0"
	fi
	if [ $rc -ne 0 ] || [ "$rterr" -ne 0 ]; then
		fails+=("$pv(rc=$rc,rterr=$rterr)")
		tail -8 "/tmp/rc_$pv.log"
	fi
done

# ---------- 结论 ----------
step "RESULT"
if [ ${#fails[@]} -eq 0 ]; then
	echo "ALL GREEN"
	exit 0
else
	echo "FAILED: ${fails[*]}"
	exit 1
fi
