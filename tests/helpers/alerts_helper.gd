class_name AlertsHelper
extends RefCounted
## テスト用: watch_signals した村の警告のうち、種類が kind の最後のものの引数(なければ空)。
## 物語・定期便などの警告がまぎれても、ほしい警告を探せるようにする。


static func find(t: GutTest, village: Village, kind: String) -> Array:
	var count: int = t.get_signal_emit_count(village, "alert_raised")
	for i in range(count - 1, -1, -1):
		var params: Array = t.get_signal_parameters(village, "alert_raised", i)
		if params[0] == kind:
			return params
	return []
