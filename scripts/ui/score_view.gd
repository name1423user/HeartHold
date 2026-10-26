class_name ScoreView
extends RefCounted
## 採点表の表示内容。足りなかった項目(最大2つ)を強調する(AC-032)。


static func rows(result: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var weak: Array = result.get("weak", [])
	for key: String in ScoreCard.ITEMS:
		out.append({
			"key": key,
			"text": Texts.t("score_row", {"item": ScoreCard.item_name(key), "score": roundi(float(result["scores"][key])), "weight": "%.2f" % float(result["weights"][key])}),
			"weak": weak.has(key),
		})
	return out


static func total_text(result: Dictionary) -> String:
	return Texts.t("score_total", {"total": "%.1f" % float(result["total"]), "line": roundi(float(ScoreCard.cfg()["pass_score"]))})


static func verdict_text(result: Dictionary) -> String:
	if result["passed"]:
		return Texts.t("score_passed")
	var names: Array = (result["weak"] as Array).map(func(k: String) -> String: return ScoreCard.item_name(k))
	return Texts.t("score_failed", {"items": "・".join(names)})
