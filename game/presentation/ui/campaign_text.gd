extends RefCounted

const RESOURCES: Dictionary = {"food":"食物", "water":"饮水", "material":"建材", "parts":"零件", "medical":"药品", "fuel":"燃油", "ammo":"弹药"}
const ROLES: Dictionary = {"water":"收集饮水", "cook":"准备食物", "engineering":"回收零件", "medical":"照顾伤员", "guard":"警戒守卫", "rest":"留守休息"}
const ROLE_HINTS: Dictionary = {"water":"每晚 +7 饮水", "cook":"每晚 +4 食物", "engineering":"每晚 +3 建材、+1 零件", "medical":"有药品时，全员 +7 健康、−5 感染", "guard":"夜袭伤害 −5", "rest":"每晚 +26 精力、+6 健康"}
const MESSAGES: Dictionary = {
	"no_campaign":"请先开始一场战役。", "campaign_over":"本次战役已经结束。", "wrong_phase":"请先完成当前行动。", "invalid_character":"请选择一位存活的幸存者。", "need_radio":"先在基地建造短波电台。", "signal_complete":"联络已完成，坚持到第 7 天结束即可迎接救援。", "no_actions":"今天的行动次数已用完，可以结束这一天。", "not_enough_resources":"物资不足，请先检查所需数量。", "already_built":"这座设施已经建成。", "healthy":"这位幸存者暂时不需要治疗。", "exhausted":"精力不足 15，请换一位幸存者或休整一天。", "unknown_location":"这个地点暂时无法进入。", "return_to_exit":"回到左侧绿色撤离点旁，再点击撤离。", "outside_sight":"那里还在视野之外。请逐步探索。", "blocked":"通路被墙壁或感染者挡住了。", "no_crate":"走到未搜刮的黄色补给箱旁，再按 E。", "no_target":"请选择视野内的感染者。", "out_of_range":"目标超出攻击范围，或被墙壁遮挡。", "no_ammo":"弹药用完了。靠近后可使用近战攻击。", "invalid_option":"请选择一个可用选项。", "save_unavailable":"无法读取存档；原文件已保留。可以开始新战役。", "save_failed":"存档写入失败。请确认磁盘空间与目录权限。", "assigned":"工作安排已更新。", "built":"设施已建成，将从今晚开始生效。", "radio":"联络进度已更新。", "healed":"伤口已包扎，感染得到控制。", "sneak_on":"潜行开启：更难被发现。", "sneak_off":"正常移动：脚步声会吸引感染者。", "arrived":"抵达街区。左侧绿色区域是撤离点。", "moved":"保持观察，下一步由你决定。", "found_loot":"找到了补给。撤离后才会带回基地。", "hit":"命中目标。", "miss":"这一击落空了。", "killed":"感染者已被击倒。", "hurt":"遭到攻击！留意健康与感染。", "waited":"原地等待了一个回合。", "reinforcements":"有新的感染者进入街区，尽快撤离。", "unknown_action":"当前无法执行这个动作。"
}

static func message(code: String) -> String:
	return String(MESSAGES.get(code, code))

static func resources(values: Dictionary) -> String:
	var parts: Array[String] = []
	for k in RESOURCES:
		if int(values.get(k,0)) != 0: parts.append("%s %d" % [RESOURCES[k],int(values[k])])
	return "  ·  ".join(parts) if not parts.is_empty() else "无"

static func journal(entry: Dictionary) -> String:
	var d: Dictionary = entry.get("data",{})
	var result: String = ""
	match String(entry.code):
		"arrival": result = "四名幸存者抵达南京避难所。"
		"radio": result = "短波联络进度达到 %d%%。" % int(d.get("signal",0))
		"built": result = "完成了一项基地建设。"
		"departed": result = "派出一名幸存者探索街区。"
		"extracted": result = "平安归来，带回：" + resources(d.get("cargo",{}))
		"fallen": result = "一名幸存者未能返回。携带的补给遗失了。"
		"forced_retreat": result = "被迫撤退，只带回了部分物资。"
		"event": result = "%s：%s" % [d.get("title","夜间事件"),d.get("choice","")]
		"night": result = "度过一夜。消耗：" + resources(d.get("consumed",{}))
		"ending": result = "这段旅程走到了终点。"
	return "第 %02d 天  %s" % [int(entry.day),result]
