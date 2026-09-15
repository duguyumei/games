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

# ---------- 用户存档：不保护，冒烟新局可直接覆盖（原型期存档即弃） ----------

# ---------- 1) 导入缓存（新 class_name/场景必须先过这步，headless 脚本才能解析） ----------
if [ "${1:-}" != "quick" ]; then
	step "import"
	if "$GODOT" --headless --path . --import > /tmp/rc_import.log 2>&1; then
		echo "import OK"
	else
		fails+=("import")
		tail -5 /tmp/rc_import.log
	fi
fi

# ---------- 2) GUT 单元测试 ----------
step "GUT tests"
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit > /tmp/rc_gut.log 2>&1
gut_rc=$?
grep -E "Tests?[ :].*(pass|fail)|passed|failed" /tmp/rc_gut.log | tail -3
if [ $gut_rc -ne 0 ]; then
	fails+=("GUT(rc=$gut_rc)")
	tail -15 /tmp/rc_gut.log
fi

# ---------- 3) 场景冒烟：能起、能跑、零脚本错误 ----------
step "scene smoke"
for scene in title dojo codex battle mahjong_battle; do
	path="scenes/$scene/$scene.tscn"
	"$GODOT" --headless --path . "res://$path" --quit-after 60 > "/tmp/rc_$scene.log" 2>&1
	errs=$(grep -c "SCRIPT ERROR" "/tmp/rc_$scene.log" || true)
	echo "$scene.tscn  script_errors=$errs"
	if [ "$errs" -ne 0 ]; then
		fails+=("$scene-smoke")
		grep -m 3 "SCRIPT ERROR" "/tmp/rc_$scene.log"
	fi
done

# ---------- 4) 行为预览（自校验，退出码即结论） ----------
step "behavior previews"
for pv in m7_click_check m7c_check m7_end_check m8_topbar_check m9_container_check m10_mapeditor_check m11_mapboard_check m12_mahjong_sim m13_ui_autoplay; do
	"$GODOT" --headless --path . "res://previews/$pv.tscn" > "/tmp/rc_$pv.log" 2>&1
	rc=$?
	echo "$pv  exit=$rc"
	if [ $rc -ne 0 ]; then
		fails+=("$pv")
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
