#!/bin/bash
## 原版 VC 抽牌动画活体探针（用法见文末）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PYTHONPATH="$SCRIPT_DIR:$PYTHONPATH"

# 找游戏进程
PID=$(pgrep -x "Vampire Crawlers" | head -1)
if [ -z "$PID" ]; then
    echo "ERROR: Vampire Crawlers 没在跑——先启动游戏进战斗，再执行本脚本"
    exit 1
fi
echo "Game PID: $PID"

# lldb 附加 + 导入回调 + 设断点 + 继续
lldb -p "$PID" \
    -o "command script import $SCRIPT_DIR/vc_probe_cb.py" \
    -o "script vc_probe_cb.setup(lldb.debugger.GetSelectedTarget())" \
    -o "continue"
