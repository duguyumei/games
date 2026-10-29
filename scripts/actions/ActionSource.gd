## 动作来源追踪
##
## 记录「谁产生的这个动作、为什么产生」，完整保留动作链条。
##
## 例：功法A 消耗真气B → 产生运转动作 → 触发内功C 的拦截器 → 入队伤害动作
##   伤害动作的 source 记录：source_kind=gongfa, source_instance_id=A的UID,
##   source_qi_uids=[B的UID], reason="功法A运转"
extends RefCounted
class_name ActionSource

## 来源种类："gongfa" / "neigong" / "qi" / "artifact" / "system"
var source_kind: String = ""

## 来源实例 UID；功法/内功/遗物的本局实例 UID
var source_instance_id: String = ""

## 涉及的真气 UID 列表；功法消耗哪些真气、哪些真气触发了效果
var source_qi_uids: Array[String] = []

## 产生原因的文本描述；供战斗日志展示
var reason: String = ""

## 父动作的来源；形成追溯链
var parent_source: ActionSource = null


## ============================================================
## 工厂方法
## ============================================================

## 从功法创建来源
static func from_gongfa(gongfa_uid: String, qi_uids: Array[String], _reason: String) -> ActionSource:
	var src := ActionSource.new()
	src.source_kind = "gongfa"
	src.source_instance_id = gongfa_uid
	src.source_qi_uids = qi_uids.duplicate()
	src.reason = _reason
	return src


## 从内功创建来源
static func from_neigong(neigong_uid: String, _reason: String) -> ActionSource:
	var src := ActionSource.new()
	src.source_kind = "neigong"
	src.source_instance_id = neigong_uid
	src.reason = _reason
	return src


## 从真气创建来源
static func from_qi(qi_uid: String, _reason: String) -> ActionSource:
	var src := ActionSource.new()
	src.source_kind = "qi"
	src.source_qi_uids = [qi_uid]
	src.reason = _reason
	return src


## 从系统创建来源（回合开始抽牌、战斗结束清理等）
static func from_system(_reason: String) -> ActionSource:
	var src := ActionSource.new()
	src.source_kind = "system"
	src.reason = _reason
	return src


## 创建派生来源；保留父链条。
##
## 用于动作触发另一个动作的场景，例如：
## 功法运转 → 触发内功拦截器 → 入队伤害动作
## 伤害动作的 source 是功法 source 的派生。
func derive(_reason: String) -> ActionSource:
	var src := ActionSource.new()
	src.source_kind = source_kind
	src.source_instance_id = source_instance_id
	src.source_qi_uids = source_qi_uids.duplicate()
	src.reason = _reason
	src.parent_source = self
	return src


## ============================================================
## 调试
## ============================================================

## 返回调试用的文本描述。
func get_debug_text() -> String:
	var parts: Array[String] = []
	if not source_kind.is_empty():
		parts.append("类型=%s" % source_kind)
	if not source_instance_id.is_empty():
		parts.append("实例=%s" % source_instance_id)
	if not source_qi_uids.is_empty():
		parts.append("真气=%d张" % source_qi_uids.size())
	if not reason.is_empty():
		parts.append("原因=%s" % reason)
	return ", ".join(parts) if not parts.is_empty() else "空来源"
