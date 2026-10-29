#!/bin/zsh
## 静默探针跑批 v3（2026-10-28 提速轮）。
##  · 默认＝HEADLESS 组（纯逻辑/几何/流程）——零窗口零打扰，probe_lib.fit 矫正无头视口 1920×1080。
##  · 失败自动重试一次（离屏窗口垃圾鼠标类 flake 一次即愈，免整批重跑）；重试过标 (重试)。
##  · INPUT 组（原生拖放/点击/悬停）依赖真 DisplayServer——Godot 4.7 无头实测不派发 GUI 输入
##    （push_input/parse_input_event 全灭，实验留档）。**默认不跑**；仅交互代码改动后加 --input
##    跑一批：离屏窗口尽力全静默。
##  · 尾行报整批耗时（提速可见）。
## 用法：zsh qiforge/tools/run_probes.sh              # 默认：仅静默组
##       zsh qiforge/tools/run_probes.sh --input      # 静默组＋交互组
##       zsh qiforge/tools/run_probes.sh qiv3 prep    # 只跑指名探针（按组自动选模式）
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
PROJ="/Users/cc/Documents/qi-forge-2"
HEADLESS=(battle_logic upgrade shop_deny longtext dialog battle_ui qiv3 prep geo reward flow_win save)
INPUT=(battle_drag prep_drag detail modal_tip drag_shot)
WATCH_S=150
RUN_INPUT=0
[[ "$1" == "--input" ]] && { RUN_INPUT=1; shift; }

typeset -a TOTAL
SECONDS=0

_run_once() {
	# $1=探针名 $2=模式(headless|input) $3=日志后缀(空=首轮 ".retry"=重试轮)
	local name=$1 mode=$2 sfx=$3
	local log="/tmp/probe_${name}${sfx}.log"
	local p guard e
	if [[ "$mode" == "input" ]]; then
		rm -f "$log"
		"$GODOT" --path "$PROJ" --position 19000,19000 \
			--script "res://qiforge/tools/probe_${name}.gd" > "$log" 2>&1 &
	else
		"$GODOT" --headless --path "$PROJ" --script "res://qiforge/tools/probe_${name}.gd" > "$log" 2>&1 &
	fi
	p=$!
	( sleep $WATCH_S; kill -9 $p 2>/dev/null ) & guard=$!
	wait $p; e=$?
	kill $guard 2>/dev/null
	_summarize "$name" "$e" "$log" "$sfx"
}

_summarize() {
	# $4 非空＝重试轮（不计入新 TOTAL 槽位，替换末位）
	local name=$1 e=$2 log=$3 sfx=$4
	local fails=$(grep -cE "^FAIL" "$log"); local errs=$(grep -cE "SCRIPT ERROR" "$log")
	local mark="OK  "; [[ $e -ne 0 || $fails -ne 0 || $errs -ne 0 ]] && mark="FAIL"
	if [[ -n "$sfx" ]]; then
		print "    ↻ 重试：${mark} ${name}  exit=${e} fails=${fails} errs=${errs}"
	else
		print "${mark} ${name}  exit=${e} fails=${fails} errs=${errs}"
	fi
	if [[ "$mark" == "FAIL" ]]; then
		grep -E "^FAIL|SCRIPT ERROR" "$log" | head -5 | sed 's/^/      /'
	fi
	if [[ -n "$sfx" ]]; then
		TOTAL[-1]="${mark}${name}(重试)"
	else
		TOTAL+=("${mark}${name}")
	fi
}

run_probe() {
	local name=$1 mode=$2
	_run_once "$name" "$mode" ""
	# 失败自动重试一次（flake 一次即愈；真坏重试仍红）
	if [[ "${TOTAL[-1]}" == FAIL* ]]; then
		_run_once "$name" "$mode" ".retry"
	fi
}

cd "$PROJ" || exit 2
if [[ $# -gt 0 ]]; then
	for n in "$@"; do
		if [[ " ${INPUT[@]} " == *" ${n} "* ]]; then run_probe "$n" input; else run_probe "$n" headless; fi
	done
else
	print "—— 静默组（无头·零窗口）——"
	for n in $HEADLESS; do run_probe "$n" headless; done
	if [[ $RUN_INPUT -eq 1 ]]; then
		print "—— 交互组（离屏，失败自动重试一次）——"
		for n in $INPUT; do run_probe "$n" input; done
	else
		print "—— 交互组（${INPUT}）：默认跳过——改了拖放/点击/悬停交互时加 --input 跑一批 ——"
	fi
fi
local bad=0; for t in $TOTAL; do [[ "$t" == FAIL* ]] && (( bad++ )); done
print "SUITE: ${#TOTAL} ran, ${bad} failed  （耗时 ${SECONDS}s）"
exit $(( bad > 0 ? 1 : 0 ))
