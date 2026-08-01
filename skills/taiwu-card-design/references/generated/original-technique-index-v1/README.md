# 原作功法结构化索引 v1

生成方式：`build_original_technique_index.py`  
来源目录：`/Users/cc/Library/Application Support/CrossOver/Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/The Scroll Of Taiwu/EncyclopediaExporter_Output/词条/功法`  
成功解析：946门  
解析失败：0门

## 1. 覆盖检查

- 属性计数：{"归元": 128, "混元": 304, "玄阴": 129, "紫霞": 140, "纯阳": 115, "金刚": 130}
- 原作类型计数：{"乐器": 26, "内功": 184, "刀法": 54, "剑法": 80, "奇门": 46, "御射": 20, "拳掌": 88, "指法": 74, "暗器": 33, "绝技": 156, "腿法": 25, "身法": 111, "软兵": 17, "长兵": 32}
- 缺少正练正文：0
- 缺少逆练正文：0
- 未识别品级：0
- 未识别属性：0

## 2. 生成物

- `techniques.json`：保留数组与标签的完整结构化索引；
- `techniques.csv`：便于筛选与表格分析的UTF-8 BOM索引；
- `attribute-matrix.csv`与`attribute-matrix.md`：属性对照证据；
- `sect-matrix.csv`与`sect-matrix.md`：门派对照证据。
- `attribute-sect-matrix.csv`与`attribute-sect-matrix.md`：排除混元后的属性与门派交叉证据。

## 3. 索引边界

- 不收录剧情描述与命中部位倾向表，降低上下文成本；
- 正练、逆练原文保持原样，仅附加可复核的关键词标签；
- 关键词标签不是语义分类，也不代表效果强度；
- 原作术语不自动等同于当前战斗规则术语；
- 原作混元只保存来源属性，不自动归入当前五属性。
