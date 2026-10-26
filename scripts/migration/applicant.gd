class_name Applicant
extends RefCounted
## 移住希望者1人。紹介(職業・性格の一言・特技)は来訪時に見え、重みは採点表で初めて見える(AC-014, AC-031)。

var id: String = ""
var display_name: String = ""
var profession: String = ""
var personality: String = ""
var specialty: String = ""
## 歩くための体(村人と同じ動き方を使う)
var body := Villager.new()


static func from_data(entry: Dictionary) -> Applicant:
	var a := Applicant.new()
	a.id = str(entry["id"])
	a.display_name = str(entry["name"])
	a.profession = str(entry["profession"])
	a.personality = str(entry["personality"])
	a.specialty = str(entry["specialty"])
	a.body.display_name = a.display_name
	return a


static func find(applicant_id: String) -> Dictionary:
	for entry: Dictionary in GameData.get_dict("applicants")["applicants"]:
		if entry["id"] == applicant_id:
			return entry
	return {}


func intro() -> String:
	return str(GameData.get_dict("applicants")["professions"][profession]["intro"])


## 重み(合計1.0)。採点表を出すまで画面に出さない
func weights() -> Dictionary:
	return GameData.get_dict("applicants")["professions"][profession]["weights"]


func specialty_name() -> String:
	return Specialty.display_name(specialty)


## 来訪時の紹介文。重みは含めない
func introduction() -> String:
	return Texts.t("applicant_intro", {"name": display_name, "intro": intro(), "personality": personality, "specialty": specialty_name()})
