#!/bin/zsh
## 静默探针跑批 v2（2026-10-28 用户裁定「不要弹窗打断」）。
##  · 默认＝HEADLESS 组（纯逻辑/几何/流程）——零窗口零打扰，probe_lib.fit 矫正无头视口 1920×1080。
##  · INPUT 组（原生拖放/点击/悬停）依赖真 DisplayServer——Godot 4.7 无头实测不派发 GUI 输入
##    （push_input/parse_input_event 全灭，实验留档）。**默认不跑**；仅交互代码改动后经用户
##    点头加 --input 跑一批：用 open -g 后台启动（不抢前台焦点）＋离屏窗口，尽力全静默。
## 用法：zsh qiforge/tools/run_probes.sh              # 默认：仅静默组
##       zsh qiforge/tools/run_probes.sh --input      # 静默组＋交互组（后台离屏一批）
##       zsh qiforge/tools/run_probes.sh qiv3 prep    # 只跑指名探针（按组自动选模式）
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
PROJ="/Users/cc/Documents/qi-forge-2"
HEADLESS=(battle_logic upgrade shop_deny longtext dialog battle_ui qiv3 prep geo reward flow_win save)
INPUT=(battle_drag prep_drag detail modal_tip drag_shot)
WATCH_S=150
RUN_INPUT=0
[[ "$1" == "--input" ]] && { RUN_INPUT=1; shift; }

typeset -a TOTAL
run_headless() {
	local name=$1
	local log="/tmp/probe_${name}.log"
	"$GODOT" --headless --path "$PROJ" --script "res://qiforge/tools/probe_${name}.gd" > "$log" 2>&1 &
	local p=$!
	( sleep $WATCH_S; kill -9 $p 2>/dev/null ) & local guard=$!
	wait $p; local e=$?
	kill $guard 2>/dev/null
	_summarize "$name" "$e" "$log"
}

## 后台离屏：直启二进制后台（2026-10-28 修——open -a 在编辑器已开时无法接管 stdout 重定向，
## 探针日志丢失全挂看门狗）；--position 离屏不抢前台；轮询探针 DONE 标记收账；超时按脚本名杀。
run_input_bg() {
	local name=$1
	local log="/tmp/probe_${name}.log"
	rm -f "$log"
	"$GODOT" --path "$PROJ" --position 19000,19000 \
		--script "res://qiforge/tools/probe_${name}.gd" > "$log" 2>&1 &
	local p=$!
	( sleep $WATCH_S; kill -9 $p 2>/dev/null ) & local guard=$!
	wait $p; local e=$?
	kill $guard 2>/dev/null
	_summarize "$name" "$e" "$log"
}

_summarize() {
	local name=$1 e=$2 log=$3
	local fails=$(grep -cE "^FAIL" "$log"); local errs=$(grep -cE "SCRIPT ERROR" "$log")
	local mark="OK  "; [[ $e -ne 0 || $fails -ne 0 || $errs -ne 0 ]] && mark="FAIL"
	print "${mark} ${name}  exit=${e} fails=${fails} errs=${errs}"
	TOTAL+=("${mark}${name}")
	[[ "$mark" == "FAIL" ]] && grep -E "^FAIL|SCRIPT ERROR" "$log" | head -5 | sed 's/^/      /'
}

cd "$PROJ" || exit 2
if [[ $# -gt 0 ]]; then
	for n in "$@"; do
		if [[ " ${INPUT[@]} " == *" ${n} "* ]]; then run_input_bg "$n"; else run_headless "$n"; fi
	done
else
	print "—— 静默组（无头·零窗口）——"
	for n in $HEADLESS; do run_headless "$n"; done
	if [[ $RUN_INPUT -eq 1 ]]; then
		print "—— 交互组（后台 open -g＋离屏，一批跑完）——"
		for n in $INPUT; do run_input_bg "$n"; done
	else
		print "—— 交互组（${INPUT}）：默认跳过——改了拖放/点击/悬停交互时加 --input 跑一批 ——"
	fi
fi
local bad=0; for t in $TOTAL; do [[ "$t" == FAIL* ]] && (( bad++ )); done
print "SUITE: ${#TOTAL} ran, ${bad} failed"
exit $(( bad > 0 ? 1 : 0 ))
