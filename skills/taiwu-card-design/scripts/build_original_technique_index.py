#!/usr/bin/env python3
"""Build a compact, reproducible index from Taiwu technique Markdown exports."""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path
from statistics import mean
from typing import Iterable


NATIVE_ATTRIBUTES = ("金刚", "紫霞", "玄阴", "纯阳", "归元")
ALL_ATTRIBUTES = (*NATIVE_ATTRIBUTES, "混元")
GRADE_NUMBERS = {
    "一品": 1,
    "二品": 2,
    "三品": 3,
    "四品": 4,
    "五品": 5,
    "六品": 6,
    "七品": 7,
    "八品": 8,
    "九品": 9,
}
FOUNDATION_TYPES = ("内功", "身法", "绝技")
EFFECT_TAGS = {
    "威力提高": (r"威力.{0,12}(?:提高|增加)", r"(?:提高|增加).{0,12}威力"),
    "威力降低": (r"威力.{0,12}(?:降低|减少)", r"(?:降低|减少).{0,12}威力"),
    "直接伤害提高": (r"直接伤害.{0,12}(?:提高|增加)", r"(?:提高|增加).{0,12}直接伤害"),
    "直接伤害降低": (r"直接伤害.{0,12}(?:降低|减少)", r"(?:降低|减少).{0,12}直接伤害"),
    "命中与化解": (r"命中|闪避|化解",),
    "护体与防御": (r"护体|防御|护具",),
    "反震与反击": (r"反震|反击",),
    "内力": (r"内力",),
    "真气": (r"真气",),
    "距离与移动": (r"距离|移动|前进|后退|脚力",),
    "式与蓄式": (r"蓄式|式的|个式|招式",),
    "层数与持续": (r"层|持续|直到战斗结束",),
    "功法干扰": (r"消除|封禁|无法施展|发挥需求|施展速度",),
    "武器与装备": (r"兵器|武器|护具|装备|解封",),
    "伤势与旧伤": (r"伤势|旧伤|重创",),
    "封穴与破绽": (r"封穴|破绽",),
    "毒": (r"毒",),
    "内息紊乱": (r"内息紊乱",),
    "治疗与恢复": (r"疗伤|恢复|治愈",),
}
CSV_FIELDS = (
    "name",
    "grade",
    "grade_number",
    "original_type",
    "type_group",
    "original_attribute",
    "sect",
    "positive_effect",
    "negative_effect",
    "effect_tags",
    "inner_power",
    "slot_cost",
    "best_weapon",
    "footwork_percent",
    "slot_break",
    "slot_agility",
    "slot_guard",
    "slot_acupoint",
    "slot_universal",
    "style_requirement",
    "body_parts",
    "requirements",
    "practice_effect",
    "practice_path",
    "break_body_percent",
    "break_qi_percent",
    "inner_outer_ratio",
    "range_value",
    "strength_weight_percent",
    "strength_multiplier_percent",
    "precision_weight_percent",
    "precision_multiplier_percent",
    "speed_weight_percent",
    "speed_multiplier_percent",
    "qi_charge_percent",
    "stance_percent",
    "source_file",
)


@dataclass
class Technique:
    name: str
    grade: str
    grade_number: int
    original_type: str
    type_group: str
    original_attribute: str
    sect: str
    positive_effect: str
    negative_effect: str
    effect_tags: list[str]
    inner_power: int | None
    slot_cost: int | None
    best_weapon: str
    footwork_percent: float | None
    slot_break: int
    slot_agility: int
    slot_guard: int
    slot_acupoint: int
    slot_universal: int
    style_requirement: str
    body_parts: str
    requirements: str
    practice_effect: str
    practice_path: str
    break_body_percent: float | None
    break_qi_percent: float | None
    inner_outer_ratio: str
    range_value: float | None
    strength_weight_percent: float | None
    strength_multiplier_percent: float | None
    precision_weight_percent: float | None
    precision_multiplier_percent: float | None
    speed_weight_percent: float | None
    speed_multiplier_percent: float | None
    qi_charge_percent: float | None
    stance_percent: float | None
    source_file: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract Taiwu technique metadata and generate comparison matrices."
    )
    parser.add_argument(
        "--source-dir",
        type=Path,
        required=True,
        help="Directory containing the original exported technique Markdown files.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1]
        / "references"
        / "generated"
        / "original-technique-index-v1",
        help="Generated artifact directory.",
    )
    return parser.parse_args()


def parse_number(value: str) -> float | None:
    match = re.search(r"[-+]?\d+(?:\.\d+)?", value.replace(",", ""))
    return float(match.group()) if match else None


def parse_int(value: str) -> int | None:
    number = parse_number(value)
    return int(number) if number is not None else None


def clean_cell(value: str) -> str:
    return value.strip().strip("|").strip()


def parse_facts(line: str) -> dict[str, str]:
    facts: dict[str, str] = {}
    pattern = re.compile(r"\*\*([^*]+)\*\*\s*([^*]*?)(?=\s*\*\*[^*]+\*\*|$)")
    for match in pattern.finditer(line.strip()):
        facts[match.group(1).strip()] = match.group(2).strip(" ：:")
    return facts


def parse_tables(lines: list[str]) -> dict[str, str]:
    values: dict[str, str] = {}
    index = 0
    while index + 2 < len(lines):
        header = lines[index].strip()
        separator = lines[index + 1].strip()
        data = lines[index + 2].strip()
        if (
            header.startswith("|")
            and separator.startswith("|")
            and data.startswith("|")
            and set(separator.replace("|", "").replace("-", "").replace(":", "").strip())
            == set()
        ):
            headers = [clean_cell(cell) for cell in header.strip("|").split("|")]
            row = [clean_cell(cell) for cell in data.strip("|").split("|")]
            if len(headers) == len(row):
                values.update(zip(headers, row))
            index += 3
            continue
        index += 1
    return values


def parse_section(text: str, heading: str) -> str:
    match = re.search(
        rf"^##\s+{re.escape(heading)}\s*$\n(.*?)(?=^##\s+|\Z)",
        text,
        re.MULTILINE | re.DOTALL,
    )
    if not match:
        return ""
    body = match.group(1).strip()
    parts: list[str] = []
    for line in body.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith(("|", ">")):
            continue
        line_facts = parse_facts(stripped)
        if line_facts:
            parts.extend(
                f"{name} {value}".strip()
                for name, value in line_facts.items()
                if name != "运功路径"
            )
        else:
            parts.append(stripped)
    return "；".join(parts)


def parse_hit_cell(value: str) -> tuple[float | None, float | None]:
    match = re.search(r"(\d+(?:\.\d+)?)成[·・]?\s*(\d+(?:\.\d+)?)%", value)
    if not match:
        return None, None
    return float(match.group(1)) * 10, float(match.group(2))


def classify_tags(effect_text: str) -> list[str]:
    return [
        tag
        for tag, patterns in EFFECT_TAGS.items()
        if any(re.search(pattern, effect_text) for pattern in patterns)
    ]


def type_group(original_type: str) -> str:
    return original_type if original_type in FOUNDATION_TYPES else "催破"


def parse_technique(path: Path, source_dir: Path) -> Technique:
    text = path.read_text(encoding="utf-8-sig")
    lines = text.splitlines()
    name_match = re.search(r"^#\s+(.+?)\s*$", text, re.MULTILINE)
    metadata_match = re.search(
        r"^\*\*([^·\r\n]+?)\s+·\s+([^·\r\n]+?)\s+·\s+([^·\r\n]+?)\s+·\s+(.+?)\*\*\s*$",
        text,
        re.MULTILINE,
    )
    if not name_match or not metadata_match:
        raise ValueError("missing title or four-part metadata line")

    grade, original_type, attribute, sect = (
        value.strip() for value in metadata_match.groups()
    )
    facts: dict[str, str] = {}
    for line in lines:
        facts.update(parse_facts(line))
    tables = parse_tables(lines)

    positive_match = re.search(r"^-\s+\*\*正练\*\*[：:]\s*(.+?)\s*$", text, re.MULTILINE)
    negative_match = re.search(r"^-\s+\*\*逆练\*\*[：:]\s*(.+?)\s*$", text, re.MULTILINE)
    positive = positive_match.group(1).strip() if positive_match else ""
    negative = negative_match.group(1).strip() if negative_match else ""
    effect_text = f"{positive}\n{negative}"

    slot_text = facts.get("栏位", "")
    slots = {
        name: int(value)
        for name, value in re.findall(r"(摧破|轻灵|护体|奇窍|通用)\s*\+(\d+)", slot_text)
    }
    strength_weight, strength_multiplier = parse_hit_cell(tables.get("力道", ""))
    precision_weight, precision_multiplier = parse_hit_cell(tables.get("精妙", ""))
    speed_weight, speed_multiplier = parse_hit_cell(tables.get("迅疾", ""))

    return Technique(
        name=name_match.group(1).strip(),
        grade=grade,
        grade_number=GRADE_NUMBERS.get(grade, 0),
        original_type=original_type,
        type_group=type_group(original_type),
        original_attribute=attribute,
        sect=sect,
        positive_effect=positive,
        negative_effect=negative,
        effect_tags=classify_tags(effect_text),
        inner_power=parse_int(facts.get("内力", "")),
        slot_cost=parse_int(facts.get("消耗格子", "")),
        best_weapon=facts.get("最适", ""),
        footwork_percent=parse_number(facts.get("脚力", "")),
        slot_break=slots.get("摧破", 0),
        slot_agility=slots.get("轻灵", 0),
        slot_guard=slots.get("护体", 0),
        slot_acupoint=slots.get("奇窍", 0),
        slot_universal=slots.get("通用", 0),
        style_requirement=facts.get("蓄式", ""),
        body_parts=facts.get("部位", ""),
        requirements=parse_section(text, "施展需求"),
        practice_effect=parse_section(text, "运功效果"),
        practice_path=facts.get("运功路径", ""),
        break_body_percent=parse_number(tables.get("破体", "")),
        break_qi_percent=parse_number(tables.get("破气", "")),
        inner_outer_ratio=tables.get("内外比", ""),
        range_value=parse_number(tables.get("范围", "")),
        strength_weight_percent=strength_weight,
        strength_multiplier_percent=strength_multiplier,
        precision_weight_percent=precision_weight,
        precision_multiplier_percent=precision_multiplier,
        speed_weight_percent=speed_weight,
        speed_multiplier_percent=speed_multiplier,
        qi_charge_percent=parse_number(tables.get("提气", "")),
        stance_percent=parse_number(tables.get("架势", "")),
        source_file=str(path.relative_to(source_dir)),
    )


def load_techniques(source_dir: Path) -> tuple[list[Technique], list[str]]:
    techniques: list[Technique] = []
    errors: list[str] = []
    for path in sorted(source_dir.glob("*.md"), key=lambda item: item.name):
        try:
            techniques.append(parse_technique(path, source_dir))
        except (OSError, UnicodeError, ValueError) as exc:
            errors.append(f"{path.name}: {exc}")
    return techniques, errors


def csv_row(technique: Technique) -> dict[str, object]:
    row = asdict(technique)
    row["effect_tags"] = ";".join(technique.effect_tags)
    return row


def write_index(output_dir: Path, techniques: list[Technique]) -> None:
    json_path = output_dir / "techniques.json"
    json_path.write_text(
        json.dumps([asdict(item) for item in techniques], ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    with (output_dir / "techniques.csv").open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_FIELDS)
        writer.writeheader()
        writer.writerows(csv_row(item) for item in techniques)


def average(items: Iterable[float | int | None]) -> float | None:
    values = [float(item) for item in items if item is not None]
    return round(mean(values), 2) if values else None


def aggregate(items: list[Technique], key_name: str) -> list[dict[str, object]]:
    grouped: dict[str, list[Technique]] = defaultdict(list)
    for item in items:
        grouped[getattr(item, key_name)].append(item)

    preferred_order = ALL_ATTRIBUTES if key_name == "original_attribute" else ()
    keys = list(preferred_order) + sorted(set(grouped) - set(preferred_order))
    rows: list[dict[str, object]] = []
    for key in keys:
        group = grouped.get(key, [])
        if not group:
            continue
        type_counts = Counter(item.type_group for item in group)
        attribute_counts = Counter(item.original_attribute for item in group)
        tag_counts = Counter(tag for item in group for tag in item.effect_tags)
        row: dict[str, object] = {
            key_name: key,
            "total": len(group),
            "内功": type_counts["内功"],
            "催破": type_counts["催破"],
            "身法": type_counts["身法"],
            "绝技": type_counts["绝技"],
            "avg_slot_cost": average(item.slot_cost for item in group),
            "avg_break_body_percent": average(item.break_body_percent for item in group),
            "avg_break_qi_percent": average(item.break_qi_percent for item in group),
            "avg_range": average(item.range_value for item in group),
        }
        row.update({f"属性_{name}": attribute_counts[name] for name in ALL_ATTRIBUTES})
        for name in EFFECT_TAGS:
            row[f"标签_{name}"] = tag_counts[name]
            row[f"标签率_{name}"] = round(tag_counts[name] * 100 / len(group), 1)
        rows.append(row)
    return rows


def aggregate_attribute_sects(items: list[Technique]) -> list[dict[str, object]]:
    grouped: dict[tuple[str, str], list[Technique]] = defaultdict(list)
    for item in items:
        if item.original_attribute in NATIVE_ATTRIBUTES:
            grouped[(item.original_attribute, item.sect)].append(item)

    rows: list[dict[str, object]] = []
    for attribute in NATIVE_ATTRIBUTES:
        keys = sorted(
            (key for key in grouped if key[0] == attribute),
            key=lambda key: (-len(grouped[key]), key[1]),
        )
        for _, sect in keys:
            group = grouped[(attribute, sect)]
            type_counts = Counter(item.type_group for item in group)
            tag_counts = Counter(tag for item in group for tag in item.effect_tags)
            row: dict[str, object] = {
                "original_attribute": attribute,
                "sect": sect,
                "total": len(group),
                "内功": type_counts["内功"],
                "催破": type_counts["催破"],
                "身法": type_counts["身法"],
                "绝技": type_counts["绝技"],
            }
            for name in EFFECT_TAGS:
                row[f"标签_{name}"] = tag_counts[name]
                row[f"标签率_{name}"] = round(tag_counts[name] * 100 / len(group), 1)
            rows.append(row)
    return rows


def write_matrix_csv(path: Path, rows: list[dict[str, object]]) -> None:
    fieldnames = list(rows[0]) if rows else []
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def markdown_table(headers: list[str], rows: Iterable[Iterable[object]]) -> str:
    output = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join("---" for _ in headers) + " |",
    ]
    for row in rows:
        output.append("| " + " | ".join(str(value) for value in row) + " |")
    return "\n".join(output)


def write_attribute_report(
    output_dir: Path, techniques: list[Technique], attribute_rows: list[dict[str, object]]
) -> None:
    rows_by_attribute = {row["original_attribute"]: row for row in attribute_rows}
    distribution_headers = ["属性", "总数", "内功", "催破", "身法", "绝技", "平均格数"]
    distribution_rows = []
    for attribute in NATIVE_ATTRIBUTES:
        row = rows_by_attribute[attribute]
        distribution_rows.append(
            [attribute, row["total"], row["内功"], row["催破"], row["身法"], row["绝技"], row["avg_slot_cost"]]
        )

    tag_headers = ["属性", *EFFECT_TAGS.keys()]
    tag_rows = []
    for attribute in NATIVE_ATTRIBUTES:
        row = rows_by_attribute[attribute]
        tag_rows.append(
            [
                attribute,
                *(
                    f'{row[f"标签_{tag}"]}（{row[f"标签率_{tag}"]}%）'
                    for tag in EFFECT_TAGS
                ),
            ]
        )

    mixed = rows_by_attribute["混元"]
    sect_distribution_rows = []
    for attribute in NATIVE_ATTRIBUTES:
        sect_counts = Counter(
            item.sect
            for item in techniques
            if item.original_attribute == attribute and item.sect != "无门无派"
        )
        unaligned = sum(
            item.original_attribute == attribute and item.sect == "无门无派"
            for item in techniques
        )
        sect_distribution_rows.append(
            [
                attribute,
                "、".join(f"{sect}{count}" for sect, count in sect_counts.most_common()),
                unaligned,
            ]
        )
    content = f"""# 原作五属性客观对照矩阵 v1

生成方式：`build_original_technique_index.py`  
数据范围：原作导出的全部{len(techniques)}门功法  
状态：结构化证据；不是当前游戏的属性设计结论

> 本矩阵只统计原文类型、数值与效果关键词。关键词出现次数不能直接证明玩法特点；必须结合具体效果、门派、类型和品级复核。

## 1. 五种原生属性类型分布

{markdown_table(distribution_headers, distribution_rows)}

原作另有{mixed['total']}门混元功法，尚未归入当前五属性。混元不得作为当前第六属性使用。

## 2. 五种原生属性效果关键词分布

每个单元格表示该属性中正练或逆练正文命中对应关键词组的功法数量，不是触发次数，也不是强度评分。

{markdown_table(tag_headers, tag_rows)}

## 3. 原生属性与门派构成

{markdown_table(["属性", "所属门派及数量", "无门无派"], sect_distribution_rows)}

五种原生属性均主要由三个门派构成。因此，某个效果在单一属性中高频出现，可能是其中一个门派的个性，而不是属性共性。后续语义分析必须同时比较“同属性的三个门派”和“同类功法在五属性中的差异”。

## 4. 使用边界

- 本表适合发现差异、选择后续精读样本，不直接生成属性特点。
- 同一功法可以命中多个关键词标签。
- “恢复”可能指恢复资源、伤势或距离，需要回到索引中的正逆练原文确认。
- 原作混元必须逐门重新归类；在此之前，五属性结论只覆盖原生属性样本。
"""
    (output_dir / "attribute-matrix.md").write_text(content, encoding="utf-8")


def write_sect_report(
    output_dir: Path, techniques: list[Technique], sect_rows: list[dict[str, object]]
) -> None:
    headers = ["门派", "总数", *ALL_ATTRIBUTES, "内功", "催破", "身法", "绝技"]
    rows = []
    for row in sorted(sect_rows, key=lambda item: (-int(item["total"]), str(item["sect"]))):
        rows.append(
            [
                row["sect"],
                row["total"],
                *(row[f"属性_{attribute}"] for attribute in ALL_ATTRIBUTES),
                row["内功"],
                row["催破"],
                row["身法"],
                row["绝技"],
            ]
        )
    content = f"""# 原作门派功法客观对照矩阵 v1

生成方式：`build_original_technique_index.py`  
数据范围：原作导出的全部{len(techniques)}门功法  
状态：结构化证据；不是当前游戏的门派设计结论

> 门派矩阵用于区分“属性共性”和“门派个性”。无门无派功法包含大量特殊与Boss功法，不能用于推断普通门派的属性身份。

## 1. 门派、属性与类型分布

{markdown_table(headers, rows)}

## 2. 使用边界

- 同一属性在不同门派中可能呈现完全不同的玩法分支。
- 同一门派的原作混元功法需要按当前五属性逐门重新归类。
- 门派效果关键词的完整计数保存在`sect-matrix.csv`，用于后续筛选，不在本页展开为超宽表格。
"""
    (output_dir / "sect-matrix.md").write_text(content, encoding="utf-8")


def write_attribute_sect_report(output_dir: Path, rows: list[dict[str, object]]) -> None:
    table_rows = []
    for row in rows:
        ranked_tags = sorted(
            EFFECT_TAGS,
            key=lambda tag: (-float(row[f"标签率_{tag}"]), tag),
        )
        top_tags = "、".join(
            f'{tag}{row[f"标签率_{tag}"]}%'
            for tag in ranked_tags[:5]
            if float(row[f"标签率_{tag}"]) > 0
        )
        table_rows.append(
            [
                row["original_attribute"],
                row["sect"],
                row["total"],
                row["内功"],
                row["催破"],
                row["身法"],
                row["绝技"],
                top_tags,
            ]
        )
    content = f"""# 原作原生属性与门派交叉矩阵 v1

生成方式：`build_original_technique_index.py`  
数据范围：642门原生五属性功法，不含304门混元  
状态：语义分析证据；不是当前游戏的属性设计结论

> 本矩阵将每个门派中的混元功法排除，只比较原生属性样本。高频标签仍然只是检索线索，不能独立证明属性或门派特点。

{markdown_table(["属性", "门派", "总数", "内功", "催破", "身法", "绝技", "前五项效果标签率"], table_rows)}
"""
    (output_dir / "attribute-sect-matrix.md").write_text(content, encoding="utf-8")


def write_summary(
    output_dir: Path, source_dir: Path, techniques: list[Technique], errors: list[str]
) -> None:
    attributes = Counter(item.original_attribute for item in techniques)
    types = Counter(item.original_type for item in techniques)
    missing_positive = sum(not item.positive_effect for item in techniques)
    missing_negative = sum(not item.negative_effect for item in techniques)
    unknown_grade = sum(item.grade_number == 0 for item in techniques)
    unknown_attribute = sum(item.original_attribute not in ALL_ATTRIBUTES for item in techniques)
    content = f"""# 原作功法结构化索引 v1

生成方式：`build_original_technique_index.py`  
来源目录：`{source_dir}`  
成功解析：{len(techniques)}门  
解析失败：{len(errors)}门

## 1. 覆盖检查

- 属性计数：{json.dumps(dict(sorted(attributes.items())), ensure_ascii=False)}
- 原作类型计数：{json.dumps(dict(sorted(types.items())), ensure_ascii=False)}
- 缺少正练正文：{missing_positive}
- 缺少逆练正文：{missing_negative}
- 未识别品级：{unknown_grade}
- 未识别属性：{unknown_attribute}

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
"""
    if errors:
        content += "\n## 4. 解析错误\n\n" + "\n".join(f"- {error}" for error in errors) + "\n"
    (output_dir / "README.md").write_text(content, encoding="utf-8")


def main() -> int:
    args = parse_args()
    source_dir = args.source_dir.expanduser().resolve()
    output_dir = args.output_dir.expanduser().resolve()
    if not source_dir.is_dir():
        raise SystemExit(f"source directory does not exist: {source_dir}")
    output_dir.mkdir(parents=True, exist_ok=True)

    techniques, errors = load_techniques(source_dir)
    if not techniques:
        raise SystemExit("no technique Markdown files were parsed")

    write_index(output_dir, techniques)
    attribute_rows = aggregate(techniques, "original_attribute")
    sect_rows = aggregate(techniques, "sect")
    attribute_sect_rows = aggregate_attribute_sects(techniques)
    write_matrix_csv(output_dir / "attribute-matrix.csv", attribute_rows)
    write_matrix_csv(output_dir / "sect-matrix.csv", sect_rows)
    write_matrix_csv(output_dir / "attribute-sect-matrix.csv", attribute_sect_rows)
    write_attribute_report(output_dir, techniques, attribute_rows)
    write_sect_report(output_dir, techniques, sect_rows)
    write_attribute_sect_report(output_dir, attribute_sect_rows)
    write_summary(output_dir, source_dir, techniques, errors)

    print(f"parsed={len(techniques)} errors={len(errors)} output={output_dir}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
